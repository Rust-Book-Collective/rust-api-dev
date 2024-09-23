+++
title = "Useful things"
description = ""
date = 2021-05-01T18:20:00+00:00
updated = 2021-05-01T18:20:00+00:00
draft = false
weight = 1030
sort_by = "weight"
template = "docs/page.html"
slug = "useful-things"

[extra]
lead = ""
toc = true
top = false
+++

In this chapter we summarize some basic concepts like error handling, data conversion and serialization.

## Error handling

If you try to start the application when it's already running, you'll see 
this ugly error message:

```
thread 'main' panicked at hello_main/src/main.rs:23:72:
called `Result::unwrap()` on an `Err` value: Os { code: 98, kind: AddrInUse, message: "Address already in use" }
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

### About unwrap vs expect

Instead of unwrap, we could use expect, which allows us to add some context 
to the error message:

```rust
let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
    .await
    .expect("failed to bind TCP listener");
```

Unfortunately, this is still ugly, and is still a panic:

```
thread 'main' panicked at hello_main/src/main.rs:36:10:
failed to bind TCP listener: Os { code: 98, kind: AddrInUse, message: "Address already in use" }
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

Normal, expected errors should be handled more gracefully.

`expect` is useful when the error is unexpected, in other words, if there is 
an error, it is an unrecoverable bug and the application should crash. 
Prefer using it over `unwrap`, as it allows you to add context to your error.

### How Rust handles errors

Rust functions can return a `Result` type, which is an enum with two 
variants, `Ok` and `Err`. The `Err` variant can hold anything, even 
non-errors. Furthermore, there is no standard error type, only an `Error` 
trait, so each time you need to return an error, you must create your
own type.

To simplify this, we will use the [anyhow](https://docs.
rs/anyhow/latest/anyhow/) crate, which introduces its own `Error` that can 
hold arbitrary errors, add context to errors, and create errors on the fly 
from strings.

Let's add anyhow with `cargo add anyhow`.

Anyhow should only be used in applications. For libraries, it is recommended 
to instead use a crate like 
[thiserror](https://docs.rs/thiserror/latest/thiserror/), so as to not 
impose anyhow on consumers of the library.

### Error handling in main

You can find the sample codes on
[GitHub](https://github.com/Rust-Book-Collective/rust-api-code/tree/main/hello-world/error-handling)

A convenient feature of rust is that you can add a `Result` return type to 
your main function, and then just return an error from it. This will print 
"Error: " followed by the error's debug representation, then exit with exit 
code 1.

Normally, the debug representation would not result in a nice error message, but
anyhow's `Error` type pretty prints the errors it carries so it can be returned
from main.

Let's add a return to our main function:

```rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let app = Router::new().route("/", get(hello_json));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    axum::serve(listener, app).await?;

    Ok(())
}
```

This results in a much nicer error message:

```
Error: Address already in use (os error 98)
```

If we wish to add context, we can do so with the `context` method. First, we
need to `use anyhow::Context;` to add the `context` method to error types.
Then we can use `context`:

```rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let app = Router::new().route("/", get(hello_json));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
        .await
        .context("failed to bind TCP listener")?;
    axum::serve(listener, app)
        .await
        .context("axum::serve failed")?;

    Ok(())
}
```

The error message now looks like this:

```
Error: failed to bind TCP listener

Caused by:
    Address already in use (os error 98)
```

### Error handling in handlers

Most of our errors will be inside error request handlers, and will have to 
be returned to the caller along with an appropriate HTTP status code.

Let's modify our hello world handler so that it calls a function that can fail.
We will need the `rand` crate for this, so we will add it with `cargo add rand`.

```rust
async fn hello_json() -> (StatusCode, Json<Response>) {
    let response = Response {
        message: generate_message().expect("failed to generate message"),
    };

    (StatusCode::OK, Json(response))
}

/// Generates the hello world message.
fn generate_message() -> anyhow::Result<&'static str> {
    if rand::random() {
        anyhow::bail!("no message for you");
    }
    Ok("Hello, world!")
}
```

The `anyhow::bail!` macro can be used to return an error on the fly.
For now, we will not handle the error, instead we'll just panic with expect.

Running the app like this and reloading localhost:3000 a couple times will 
eventually result in an empty response, with an error message printed to 
standard error:

```
thread 'tokio-runtime-worker' panicked at hello_main/src/main.rs:14:37:
failed to generate message: no message for you
```

Although the entire app does not crash, the thread handling the request does,
and we get not response. While panics should be exceptional situations and 
should not be used for regular errors, we should still handle them.
Let's add the CatchPanic middleware from the tower-http crate. We will need 
to add the crate and enable the catch-panic feature because the CatchPanic 
middleware is not enabled by default:

```bash
$ cargo add -F catch-panic tower-http
```

Then add the middleware:

```rust
let app = Router::new()
    .route("/", get(hello_json))
    .layer(tower_http::catch_panic::CatchPanicLayer::new()); // added
```

With this change, we'll get a 500 Internal Server error in case of a panic.

Let's now fix our handler so it actually handles the error.
Axum allows handlers to return a Result, but the Error variant must 
implement IntoResponse so the error can be converted into a response. 
Because of this, we need to use a
[newtype](https://doc.rust-lang.org/rust-by-example/generics/new_types.html)
to wrap the anyhow error:

```rust
struct AppError(anyhow::Error);

// This allows ? to automatically convert anyhow::Error to AppError
impl From<anyhow::Error> for AppError {
    fn from(value: anyhow::Error) -> Self {
        Self(value)
    }
}
```

Next, we implement IntoResponse, which is where the actual response format 
for the error is determined. For now, we'll always return an internal server 
error, and we'll use anyhow's debug representation to print the error 
message with the causes:

```rust
impl IntoResponse for AppError {
    fn into_response(self) -> axum::response::Response {
        (StatusCode::INTERNAL_SERVER_ERROR, self.0.to_string()).into_response()
    }
}
```

Finally, we return AppError from our handler in case of an error. The `?` 
operator handles conversion for us since we implemented the `From` trait.

```rust
async fn hello_json() -> Result<(StatusCode, Json<Response>), AppError> {
    let response = Response {
        message: generate_message().context("failed to generate message")?,
    };

    Ok((StatusCode::OK, Json(response)))
}
```

## Conversion between data structures

The Rust standard library provides two traits to convert data between 
various types. They are the `From` and `Into` traits:

```rust
pub trait From<T>: Sized {
    // Required method
    fn from(value: T) -> Self;
}

pub trait Into<T>: Sized {
    // Required method
    fn into(self) -> T;
}
```

Let's see a simple example:

```rust
struct A {
    member: String,
}

struct B {
    value: String,
}

impl From<A> for B {
    fn from(source: A) -> Self {
        Self {
            value: source.member,
        }
    }
}

fn main() {
    let a = A { member: String::from("something") };
    let b = B::from(a);
    
    println!("{}", b.value);
}
```

Here we convert data from struct `A` into struct `B`.  The `Into` trait is 
simply the inverse of the `From`, so if we implement `From<A>` for `B` then 
we can call `let b: B = a.into();` too:

```rust
fn main() {
    let a = A { member: String::from("something") };
    let b: B = a.into();
    
    println!("{}", b.value);
}
```

This does not seem to be so useful, but in reality there are a lot of cases in 
web service development when we have to convert similar data structures into 
each other. Assume for example, that we receive data from a backend service 
and that data can be deserialized into structure A, but we have to return a 
JSON to our client and that JSON can be serialized only from structure B. 
We can do this conversion easily with a `From` implementation.

The `From` trait has no way to return an error. If the conversion can fail, 
we must use `TryFrom` instead:

```rust
pub trait TryFrom<T>: Sized {
    type Error;

    // Required method
    fn try_from(value: T) -> Result<Self, Self::Error>;
}
```

This version returns a `Result` with two potential outcomes: an `Ok` with 
the result of a successful conversion or an `Err` with and error.
The associated type `Error` specifies the exact error type. A simple example:

```rust
use std::num::ParseIntError;

struct Number {
    value: i32,
}

impl TryFrom<String> for Number {
    type Error = ParseIntError;
    
    fn try_from(source: String) -> Result<Self, Self::Error> {
        Ok(Number { value: source.parse()? })
    }
}

fn main() {
    match Number::try_from(String::from("42")) {
        Ok(n) => {
            println!("{}", n.value);
        },
        Err(e) => {
            println!("Conversion failed {:?}", e);
        }
    }

}
```

Here the potential error from `source.parse()` is a `ParseIntError` so we have
to specify it as the `Error` associated type.

In the above example, `42` can be converted into an i32 value, so our `TryFrom`
implementation succeeds, but replace `42` with `notanumber` and you will get
a `ParseIntError`:

```
Conversion failed ParseIntError { kind: InvalidDigit }
```

## Serialization and deserialization

Most of the time we use the `serde` crate for serialization and
deserialization. You can find the full documentation at 
[serde.rs](https://serde.rs). Serde supports more then a dozen serialization
formats, including JSON and XML.

You can easily add serialization and deserialization capabilities
to a struct using the derive macros provided by serde:

```rust
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
struct Message {
    content: String,
}

fn main() {
    let message = Message { content: String::from("something") };

    let serialized = serde_json::to_string(&message).unwrap();

    println!("serialized = {}", serialized);

    let deserialized: Message = serde_json::from_str(&serialized).unwrap();
    println!("deserialized content = {}", deserialized.content);
}
```

The result:

```
serialized = {"content":"something"}
deserialized content = something
```

Serde handles all primitive integer and float types, the corresponding
JSON type is `number`. Char and string types are `string` in JSON too.
The bool type is converted to `boolean`.

```rust
use serde::{Serialize};

#[derive(Serialize)]
struct Message {
    n1: i64,
    n2: f64,
    b: bool,
    c: char,
    s: String,
}

fn main() {
    let message = Message { 
      n1: 42,
      n2: 3.14,
      b: true,
      c: 'C',
      s: String::from("something"), 
    };

    let serialized = serde_json::to_string(&message).unwrap();
    println!("serialized = {}", serialized);
}
```

The result:

```
serialized = {"n1":42,"n2":3.14,"b":true,"c":"C","s":"something"}
```

As you can see, struct are converted to `object`. Tuples, arrays and vectors
are converted to `array`:

```rust
use serde::{Serialize};

#[derive(Serialize)]
struct Message {
    numbers: [i64;5],
    strings: Vec<String>,
    tuple: (i64, String),
}

fn main() {
    let message = Message { 
      numbers: [1,2,3,4,5],
      strings: vec![String::from("one"), String::from("two")],
      tuple: (42, String::from("something")),
    };

    let serialized = serde_json::to_string(&message).unwrap();
    println!("serialized = {}", serialized);
}
```

The result:

```
serialized = {"numbers":[1,2,3,4,5],"strings":["one","two"],"tuple":[42,"something"]}
```

The Rust naming guideline recommends snake_case for variables and struct
members but you (or your clients) may prefer other styles for your API.
Serde offers an easy conversion with the `rename_all` parameter:

```rust
use serde::{Serialize};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Message {
  one_field: i64,
  other_field: i64,
  #[serde(rename = "exception")]
  and_an_exception: i64,
}

fn main() {
    let message = Message {
      one_field: 1,
      other_field: 2,
      and_an_exception: 3,
    };

    let serialized = serde_json::to_string(&message).unwrap();
    println!("serialized = {}", serialized);
}
```

The result:

```
serialized = {"oneField":1,"otherField":2,"exception":3}
```

Also, you can rename any field one by one using the `rename` parameter 
as you can see on the `and_an_exception` field.

The styles supported by `rename_all` are: `lowercase`, `UPPERCASE`, 
`PascalCase`, `camelCase`, `snake_case`, `SCREAMING_SNAKE_CASE`, 
`kebab-case` and `SCREAMING-KEBAB-CASE`.

Rust enums can be represented in four different styles:

- internally tagged
- externally tagged
- adjacently tagged
- and untagged

First, the internally tagged version:

```rust
use serde::{Serialize};

#[derive(Serialize)]
#[serde(tag = "outcome")]
enum Response {
    Success { value: String },
    Failure { error: String },
}

fn main() {
    let message = Response::Success{ value: String::from("result") };
    let serialized = serde_json::to_string(&message).unwrap();
    println!("serialized = {}", serialized);
}
```

In this case the response object has a field named after the `tag` property
with the name of the enum variant, followed by the fields of the
variant:

```
serialized = {"outcome":"Success","value":"result"}
```

The externally tagged one:

```rust
use serde::{Serialize};

#[derive(Serialize)]
enum Response {
    Success { value: String },
    Failure { error: String },
}

fn main() {
    let message = Response::Success{ value: String::from("result") };
    let serialized = serde_json::to_string(&message).unwrap();
    println!("serialized = {}", serialized);
}
```

In this case the response object has a single field, named after the
enum variant, and that contains the fields of the variant:

```
serialized = {"Success": {"value":"result"}}
```

The adjacently tagged one:

```rust
use serde::{Serialize};

#[derive(Serialize)]
#[serde(tag = "outcome", content = "content")]
enum Response {
    Success { value: String },
    Failure { error: String },
}

fn main() {
    let message = Response::Success{ value: String::from("result") };
    let serialized = serde_json::to_string(&message).unwrap();
    println!("serialized = {}", serialized);
}
```

In this case the response object has a field named after the `tag` property
with the name of the enum variant, followed by another field named after the
`content` property. The latter contains the fields of the variant:

```
serialized = {"outcome":"Success","content":{"value":"result"}}
```

Finally the untagged option:

```rust
use serde::{Serialize};

#[derive(Serialize)]
#[serde(untagged)]
enum Response {
    Success { value: String },
    Failure { error: String },
}

fn main() {
    let message = Response::Success{ value: String::from("result") };
    let serialized = serde_json::to_string(&message).unwrap();
    println!("serialized = {}", serialized);
}
```

In this case the response object simply contains the fields of the variant:

```
serialized = {"value":"result"}
```

Deserialization is the exact opposite of serialization, for the tagged
versions this is quite straightforward. Deserialization of the untagged
version can be tricky sometimes, because serde has to identify the
required variant based only on the list of fields and their types.

There is a lot more to serde, you will see some examples later and
the official documentation is also your friend if you need to tweak 
things.

## Async Rust

In synchronous code, if we call a function or method, we always wait for 
it to complete its task and return the result. For example, in the case of a 
slow I/O or network operation, the program may be blocked for seconds or 
minutes. In a single-threaded program, this means that while we are waiting 
for the response, we cannot continue with any other task. The first solution 
to this problem was multithreading. This could be used by organizing slow 
I/O operations into separate threads. This solut on works well until there 
are orders of magnitude more threads than real processor cores. If there are 
too many threads, a lot of time is spent on creating threads and on context 
switching between those threads.

Asynchronous programming was invented for this problem. In an asynchronous 
environment, when we start a task, we don't wait for it to complete its 
operation, we only get back a promise (Future) that the task will return 
with some value one day. The task is then transferred to an execution 
environment (async runtime), which runs it until it is blocked on some 
operation (it could be I/O, network request, waiting for a Mutex to be 
locked, etc.). In this case, the runtime puts the task aside and runs the 
next one, until it is blocked too. From time to time, the runtime also asks 
(polls) the tasks that were put aside, whether they can continue their work. 
If they can, it starts running them again until the next block or until they 
end.

The asynchronous runtime can run on a single thread (node.js works this way) 
or in parallel on several threads at the same time (Rust supports this too). 
In multi-threaded mode, Rust typically start as many threads as many 
virtual processor cores are present on the running machine, but this can be 
tuned as needed. 
There may also be differences in the fact that the tasks 
return control voluntarily to the runtime before blocking (this is the 
cooperative solution) or the runtime decides to interrupt the execution of 
the task from time to time and start running another one (this is the 
preemptive solution). 
The operating system for example runs threads in a preemptive manner, it can 
interrupt a thread at any time to give processor time to another one. The 
asynchronous operation of Rust is cooperative, tasks voluntarily return 
control to the runtime when they are forced to wait. That means that Rust's 
asynchronous tasks are not a good solution when you have to parallelize 
long-running, primarily CPU-heavy tasks. For this case, OS threads are better.

Typically, web servers and web application servers are an area where many 
parallel network operations take place at the same time 
(up to tens of thousands), which can benefit from asynchronous operation.

The example code for asynchronous tasks in Rust looks like this 
(this is a simplified example, the real operation is a bit more 
complicated than this):

```rust
trait SimpleFuture {
    type Output;
    fn poll(&mut self, wake: fn()) -> Poll<Self::Output>;
}

enum Poll<T> {
    Ready(T),
    Pending,
}
```

`SimpleFuture` defines an associated type (`Output`) which will be the return 
value of the task, and a `poll` method with which the execution environment can 
"ask" if the task can be run. The poll causes the task to run until it blocks 
or finishes running. The return value of the poll is the `Poll<T>` enum, 
whose two branches are `Ready(T)` and `Pending`. `Ready(T)` means that the task 
has finished running and returns the return value 
(the type `T` is the same as the `Output` type associated to `SimpleFuture`). 
Pending means that the task is blocked and returns control to the runtime. 
The `wake: fn()` parameter is a callback, which is used so that the task can 
notify the runtime when it becomes executable again. An excerpt from the 
example code:

```rust
pub struct SocketRead<'a> {
    socket: &'a Socket,
}

impl SimpleFuture for SocketRead<'_> {
    type Output = Vec<u8>;

    fn poll(&mut self, wake: fn()) -> Poll<Self::Output> {
        if self.socket.has_data_to_read() {
            // we have data, return uit
            Poll::Ready(self.socket.read_buf())
        } else {
            // we have to wait, so set the wake callback on the socket
            self.socket.set_readable_callback(wake);
            // and return control to the async runtime
            Poll::Pending
        }
    }
}
```

In this example, we pass the `wake` callback to the socket, which the socket
calls when data arrives.

There are two ways to create asynchronous code in Rust: as an asynchronous 
function/method or as an asynchronous block:

```rust
async fn foo() -> u8 { 5 }

fn bar() -> impl Future<Output = u8> {
    // This `async` block results in a type that implements
    // `Future<Output = u8>`.
    async {
        let x: u8 = foo().await;
        x + 5
    }
}
```

The keyword async essentially means that the function or block will not 
return a direct return value (`u8`) but a `Future`: `Future<Output = u8>`
which will eventually result in a `u8` value.
The execution of the task starts by calling await.

In the above simple example, of course, there is actually no asynchronicity, 
because the function never blocks, the first await call will immediately 
return the return value.

In an asynchronous environment, lifetimes are developed in such a way that 
the lifetime of the `Future` depends on the lifetime of the input parameters.
An example:

```rust
async fn foo(x: &u8) -> u8 { *x }

// Is equivalent to this function:
fn foo_expanded<'a>(x: &'a u8) -> impl Future<Output = u8> + 'a {
    async move { *x }
}
```

Here, the lifetime of the `Future` depends on the lifetime of the reference `x` 
received as an input parameter.

This means that `await` must be called before the lifetime of the input 
parameters expires. What is async move? It is similar to the move keyword 
seen in the case of closures: it transfers ownership of the variable `x` 
to the asynchronous `Future`, because without it, it would not live as 
long as the `Future` returned. It is important that this move only transfers 
the ownership of the local variable `x` (which contains a reference), 
not the ownership of the `u8` value referenced by the reference!

A complete example (this one can already be run, on the rust playground 
for example):

```rust
use std::future::Future;

async fn borrow_x(x: &str) {
    println!("value: {}", x);
}

/*
fn bad() -> impl Future<Output = ()> {
    let x = String::from("valami");
    async {
        borrow_x(&x).await // ERROR: `x` does not live long enough
    }
}
*/

fn good() -> impl Future<Output = ()> {
    async {
        let x = String::from("valami");
        borrow_x(&x).await
    }
}

#[tokio::main]
async fn main() {
    // bad().await;
    good().await;
}
```

Here, the bad function is not good because it declares a local variable 
whose lifetime ends at the end of the bad function, but the returned 
`Future` survives the function and would refer to a local variable that no 
longer exists when `await` is called. 
The solution would be `async move`. In the good function, on the other hand, 
we declare the local variable within the async block, so it already lives 
together with the returned `Future`.

The strange thing about Rust is that there is no single "standard" async 
runtime, there are several different implementations. In the web application 
area, `tokio.rs` is perhaps the most common, but there are a few others 
(like `async-std`, `smol`). This also causes compatibility problems, a 
library written for `tokio.rs` will not necessarily work with `async-std` 
and vice versa (but most libraries try to support all common runtimes).

One more important thing about asynchronous codes: in the case of a 
multi-threaded execution environment, the task will go to different threads 
essentially randomly. 
If a task gets blocked, it may easily run on a different thread after the 
restart than before the blocking. In this case, the data referenced by the 
task must be sent to another thread. 
In order to do this, Rust expects that if the operation of an asynchronous 
task is interrupted (the poll returns with a Pending value), the current 
state of the task must not contain a reference to data that cannot be 
safely transferred between threads (they all have to implement the 
Send trait).

An example:

```rust
use std::rc::Rc;

#[derive(Default)]
struct NotSend(Rc<()>);

async fn bar() {}
async fn foo() {
    let x = NotSend::default();
    bar().await;
}

fn require_send(_: impl Send) {}

fn main() {
    require_send(foo());
}
```

The `Rc` reference counter type is not thread-safe, so it does not implement 
th `Send` trait. When we call `bar().await` in the example above, the 
environment still has a live reference to the non-thread-safe variable `x`, 
so Rust will throw an error.

In this case, we have two options: one is to release the variable `x` before 
calling `await`:

```rust
async fn foo() {
    {
        let x = NotSend::default();
    }
    bar().await;
}
```

Another option is to use the thread-safe `Arc` instead of `Rc`, which 
implements the `Send` trait.

To learn more about asynchronous Rust, you should read this book:
[Asynchronous Programming in Rust](https://rust-lang.github.io/async-book/)

## Sending data between threads

The Rustonimicon defines data races with these three simple rules:

- two or more threads concurrently accessing a location of memory
- one or more of them is a write
- one or more of them is unsynchronized

Rust mostly prevents data races with its ownership system: when one
variable holds a mutable reference to a location of memory, no other
variable can hold a reference to it. However, this is a quite strong
restriction, it would be very hard to implement useful multi-threaded
applications without a more flexible system. Reference counting and
interior mutability  allows a more flexible approach but also 
requires a more careful synchronization of operations across threads.

Rust has two automatically derived traits to express safety
of types in a multi-threaded context: `Send` and `Sync`.

A type is `Send` if it is safe to send it to another thread.\
A type is `Sync` if it is safe to share between threads 
(`T` is `Sync` if and only if `&T` is `Send`).

Usually primitive types like integers, floats and characters are
both `Send` and `Sync`. Also, complex types (structs, tuples, enums)
built entirely from primitive types are usually `Send` and `Sync`
too. But these types are not:

- raw pointers are neither `Send` nor `Sync`
  (because they have no safety guards).
- `UnsafeCell` isn't `Sync` (and therefore `Cell` and `RefCell` aren't either).
- `Rc` isn't `Send` nor `Sync` 
  (because the `refcount` is shared and unsynchronized).

And of course any complex types built on these types are not `Send` 
nor `Sync` either.

To make interior mutability usable in a multi-threaded context, we have
two tools: atomics and mutexes. An atomic is a primitive type whose 
value can be changed in a thread-safe way. The `std::sync::atomic`
crate defines them. Some examples are `AtomicBool`, `AtomicI64`, `AtomicPtr`.

We have just seen that `Rc` is not `Send` nor `Sync` because its 
reference counter cannot be changed in a thread-safe way. But if we
replace its simple integer reference counter with an atomic integer,
the resulting type (called `Arc`) becomes both  `Send` and `Sync`.
Why does not use `Rc` an atomic reference counter by default? Because
atomics require CPU-level synchronization of operations and therefore
are much slower to access than simple primitive types.

The `Arc<T>` type solves the problem of cross-thread sharing, but it does
not allow interior mutability yet. To achieve that, we need one more 
layer: the `Mutex<T>` type. The `Mutex` allows a thread to acquire
an exclusive lock on the embedded variable, that way it becomes safe
to change the value of the embedded variable. `Mutex` isn't the only
way to make a shared variable mutable in a multi-threaded context, just
the most commonly used one. Alternatives include `RwLock` - that allows
multiple read locks or a single mutable lock at a time and `ArcSwap` -
that one makes it possible to replace the embedded reference with a
single atomic operation.

