+++
title = "Understand Axum"
description = ""
date = 2021-05-01T18:20:00+00:00
updated = 2021-05-01T18:20:00+00:00
draft = false
weight = 1040
sort_by = "weight"
template = "docs/page.html"

[extra]
lead = ""
toc = true
top = false
+++

In this chapter you will acquire a solid understanding of
the Axum, Tower and Hyper crates, these are the libraries
underlying our application server. Your will learn how to
compose middleware layers to add cross-cutting features
to your API endpoints.

## The tokio stack

Our web application will be completely based on the `tokio.rs`
family of crates. These are like layers of an onion.

**Tokio** is the async runtime, the foundation of an asynchronous
application, responsible for the scheduling of the async tasks.

**Hyper** is an HTTP client and server implementation, supports both version
1 and version 2 of the HTTP protocol.

**Tower** is a tool to build middleware layers around our endpoints,
like authentication, authorization, request logging, etc.

**Axum** is the actual web application framework, responsible for the
routing and composing those tower service layers with our endpoints.

Now we will explain their roles in our application in a little more detail.

### Tokio

You have already seen how we initialized the tokio runtime with a single
declarative macro:

```rust
#[tokio::main]
async fn main() {
    ...
}
```

But you can initialize the runtime at any point of your application
using the `tokio::runtime::Builder`. This way you can also customize
the configuration of the runtime.

For example, you can start a single-threaded runtime on the current
thread:

```rust
fn main() {
    let rt = runtime::Builder::new_current_thread()
        .unhandled_panic(UnhandledPanic::ShutdownRuntime)
        .build()
        .unwrap();
        
    rt.spawn(async move {
        // your async code goes here
    })
}
```

With a single-threaded executor your application will not scale to multiple
CPU cores, but you won't have to worry about cross-thread synchronization
either.

Of course, the multi-threaded executor is much more flexible, and you will
use that one most of the time:

```rust
fn main() {
    let rt = Builder::new_multi_thread()
        .worker_threads(4)
        .thread_name("my-custom-name")
        .thread_stack_size(3 * 1024 * 1024)
        .build()
        .unwrap();
}
```

As you can see you can set many parameters here. The number of worker threads
should equal the number of cores available in your running environments,
assuming you do not want to spare some of the cores for background processing
for example. Generally you should not hardcode this value in your code,
but let tokio automatically scale to the number of available cores or read
the required number from the `TOKIO_WORKER_THREADS` environment variable.

You can also customize the thread name to make it easier to find specific
threads in the output of `ps` or `top` for example. The thread stack size
is not that interesting - until you manage to bump into that limit.

Tokio can run synchronous, blocking tasks too, but it has to start
distinct threads for them, so they do not interfere with the async tasks.
You can set how many such blocking threads can run concurrently, using the
`max_blocking_threads()` call. It defaults to 512 threads.

The unit of execution in tokio is a `Task`. Either an async or a synchronous
one. The easiest way to spawn a new task is to spawn an async block:

```rust
fn main() {
    let rt = Builder::new_multi_thread().build().unwrap();
    rt.spawn(async move {
        // your async code goes here
    });
}
```

To spawn a blocking, synchronous one, use `spawn_blocking`:

```rust
fn main() {
    let rt = Builder::new_multi_thread().build().unwrap();
    rt.spawn_blocking(|| {
        // your synchronous code goes here
    });
}
```

One thing you must never do: call a blocking function in an asynchronous task
directly. That would block the asynchronous executor thread, and you can run
out of available asynchronous executor threads quite quickly.

You can cancel the started tasks any time using abort:

```rust
let task: JoinHandle = tokio::spawn(async move { // your async code });
...
task.abort();
```

You can also wait for the completion of multiple tasks running parallel 
using the `tokio::join!` macro:

```rust
#[tokio::main]
async fn main() {
    let (first, second) = tokio::join!(
        one_async_task(),
        another_async_task()
    );

    // do something with the values
}
```

Tokio is not just the runtime, but also provides many useful tools for
asynchronous programming.

The `tokio::time` module allows you to add time-based actions to your code,
like sleeping for a given amount of time, executing something at given
time periods or specify timeouts on asynchronous operations.

The `tokio::net` module contains non-blocking implementations of TCP/IP, UDP, 
and Unix Domain Sockets operations.

The `tokio::fs` module provides asynchronous filesystem I/O operations.

The `tokio::signal` module allows asynchronous handling of OS signals on both
Unix-like operating systems and Windows.

The `tokio::process` module enables you to manage child processes.

The `tokio::sync` module provides asynchronous, Go-like communication
channels (one-shot; multi-producer/single-consumer, broadcast and watch).
It also provides asynchronous versions of the `Mutex` and `RwLock`
synchronization primitives and a `Semaphore` implementation which allows
you to limit the concurrency of tasks.

We will see some of them in more detail later.

### Hyper

Hyper is an asynchronous HTTP client and server implementation. We will
not use it directly, but both the server-side tower-axum stack and 
the client-side `reqwest` crate builds on it.

On the server side implementation the core abstraction is the 
`Service` trait:

```rust
pub trait Service<Request> {
    type Response;
    type Error;
    type Future: Future<Output = Result<Self::Response, Self::Error>>;

    // Required method
    fn call(&self, req: Request) -> Self::Future;
}
```

The service receives an HTTP request as defined in the `http` crate's 
`http::request` module. The service has two associated types: a 
`Response` and an `Error` type. The first defines the type for a 
successful response, the second defines the type representing error cases. 
The service itself is implemented by the `call` method:
that method processes the incoming request and returns a future 
`Result` that eventually becomes either a `Response` or an `Error`.

When you start an HTTP server with hyper, you have to pass two
things to it: a TCP listener and an implementation of the 
above `Service` trait.

Both `tower` and `axum` implements this `Service` trait so when you
call `axum::serve` in this example:

```rust
async fn main() {
    let app = Router::new()
        .route("/", get(hello));
        
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
        .await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

it essentially converts the `app` router configuration into a `Service` 
implementation and starts the `hyper` server on the `listener` TCP 
listener with that axum `Service` implementation.

### Tower

Tower adds another layer of abstraction above hyper's service,
the `Layer` trait:

```rust
pub trait Layer<S> {
    /// The wrapped service
    type Service;
    /// Wrap the given service with the middleware, returning a new service
    /// that has been decorated with the middleware.
    fn layer(&self, inner: S) -> Self::Service;
}
```

Essentially a layer wraps a service and returns that as a new service. 
The layer may alter the `Request` going to the original
service or the `Response` and `Error` returned from the original service.
But it does not always have to: you can write a logging layer for example,
that only logs information about the incoming request and the outgoing
response but does not alter them in any way.

Multiple layers can be composed to build a middleware stack for your
application. HTTP request processing aspects such as authentication,
authorization, CORS handling, logging, etc. may be implemented as layers.

Additionally, tower provides a few `Service` implementations that can wrap
other services and act as a middleware too. You can use them for request
rate limiting, concurrency limiting, timeout handling, caching, etc.
We will see examples for some of these middleware services later.

Tower also comes with a `ServiceBuilder` struct to help the building of
middleware chains:

```rust
let svc = SomeService{};

let stack = ServiceBuilder::new()
    .concurrency_limit(10)
    .rate_limit(5, Duration::from_secs(1))
    .service(svc)
```

The returned stack implements the `Layer` trait too. As you can see, you
can add a concurrency limit or rate limit to your service easily.

There is one more crate related to tower: `tower-http` adds http protocol 
specific middlewares to the stack and also extends tower's `ServiceBuilder`
with http-specific features.

A simple example on `tower-http` usage:

```rust
let middleware = ServiceBuilder::new()
    .layer(TraceLayer::new_for_http())
    .layer(TimeoutLayer::new(Duration::from_secs(10)))
    .compression();
```

The first layer adds tracing capabilities to our stack: it will send details
of each HTTP request-response pair to the tracing data collector. The second
one sets a 10 seconds timeout on request processing. The third one enables
response compression. We will show more detailed examples of these later.
 
### Axum

Finally, we arrived to the top of our stack, the `axum` crate. Axum provides
three main features for us: request routing, request data extraction and
response serialization.

The routing setup is quite simple: you define a handler function and
assign it to a specific path and HTTP verb. For example, attach our
`hello_handler` to the `GET` verb of the `/` path:

```rust
async fn hello_handler() -> &'static str {
    "Hello, world!"
}

async fn main() {
    let app = Router::new()
        .route("/", get(hello_handler));
        
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

But what can you return from such a handler function? Basically anything
that can be converted into an HTTP response. Axum defines the `IntoResponse`
trait to specify this:

```rust
pub trait IntoResponse {
    /// Create a response.
    fn into_response(self) -> Response;
}
```

Axum also provides many implementations for this trait: a string slice,
a String or a byte sequence (`Bytes`, `[u8]` or `Vec<u8>`) can be converted
into a `Response`. You can also use `Json<T>` to serialize any serializable
data structure into a JSON formatted response. When you have to specify
an HTTP response status code, you can return a tuple consisting of a 
status code and a response, for example:

```rust
async fn hello_handler() -> (http::StatusCode, &'static str) {
    (http::StatusCode::OK, "Hello, world!")
}
```

Axum can convert various properties of the request, such as headers, path 
elements, query parameters and the request body itself into arguments for our
handler function. These converters are called extractors. We will see them
in great detail later, just a quick example:

```rust
pub async fn get_book(
    Path(book_id): Path<i64>,
) -> Book {
    // find that book somehow ...
}

pub fn setup_routing() -> Router {
    Router::new()
        .route("/books/:id", get(get_book))
}
```

This one converts the path element `:id` into an `i64` argument.

The router setup can combine tower layers on your endpoints too,
for example when you need an authorization layer over
your endpoints. A simple example from the documentation:

```rust
let app = Router::new()
    .route("/foo", get(|| async {}))
    .route_layer(ValidateRequestHeaderLayer::bearer("password"));
```

## Web application structure

We built an application structure for command-line applications in the
previous chapter. Now we will continue this journey by implementing
the `serve` subcommand where we will start up a tokio runtime and 
configure an axum router.

First, add our new dependencies to `cli_application/Cargo.toml`: axum and
tokio:

```toml
[dependencies]
...
axum = "0.7.4"
tokio = { version = "1.35.1", features = ["full"] }
```

Run `cargo build` to download and compile the new dependencies.

We already have a dummy serve CLI subcommand in `commands/serve.rs`, 
now we have to start the tokio runtime there.

```rust
pub fn handle(matches: &ArgMatches, settings: &Settings) -> anyhow::Result<()> {
    let port: u16 = *matches.get_one("port").unwrap_or(&8080);

    start_tokio(port, settings)?;

    Ok(())
}

fn start_tokio(port: u16, settings: &Settings) -> anyhow::Result<()> {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?
        .block_on(async move {
            // TBD ...
            
            Ok::<(), anyhow::Error>(())
        })?;
        
    Ok(())
}
```

So, we:

- start a multi-threaded runtime
- enable all optional drivers (like io and time)
- and pass and async task to it

The `build` and `block_on` methods both may run into errors, that's why
we have to add the question mark after calling them.

So now we have a runtime, we can start axum in it. Similarly to our
first hello world example:

```rust
tokio::runtime::Builder::new_multi_thread()
    .enable_all()
    .build()?
    .block_on(async move {
        let addr = SocketAddr::new(
            IpAddr::V4(Ipv4Addr::new(0, 0, 0, 0)), 
            port
        );
        let router = Router::new();

        let listener = tokio::net::TcpListener::bind(addr).await?;
        axum::serve(listener, router.into_make_service()).await?;

        Ok::<(), anyhow::Error>(())
    })?;
```

A few things changed: we use a `SocketAddr` as the bind address parameter
instead of the string argument, so we can pass on the port number we
received from the command line parameters. Also, our `Router` is empty for 
now, we will configure it shortly.

### Routing

Now it's time to add some routes to our axum server, but first we have to 
think about the route structure a bit. APIs are usually versioned, so it's a 
good practice to start the urls with a `/v1/` prefix for the first version. 
There is a good chance that later API versions will only change a small part 
of the endpoints so it's probably wise to not bind endpoint implementations 
strictly to versions but prepare for a more flexible structure. One possible 
setup:

```
src
  api
    handlers
      mod.rs
      hello.rs
  mod.rs
  v1.rs
```

Where `src/api/mod.rs` builds the whole configuration by nesting all versions:

```rust
use axum::Router;

mod handlers;
mod v1;

pub fn configure() -> Router {
    Router::new().nest("/v1", v1::configure())
}
```

Then `src/api/v1.rs` builds the v1 configuration:

```rust
use super::handlers;
use axum::routing::get;
use axum::Router;

pub fn configure() -> Router {
    Router::new().route("/hello", get(handlers::hello::hello))
}
```
Finally, `src/api/handlers/hello.rs` contains our single hello world endpoint:

```rust
use axum::http::StatusCode;

pub async fn hello() -> Result<String, StatusCode> {
    Ok("Hello world!".to_string())
}
```

We also need the `src/api/handlers/mod.rs` to add `hello.rs` to the build:

```rust
pub mod hello;
```

We also have to include `pub mod api` in `src/lib.rs`. Now we can modify
the `start_tokio` method to use our routes:

```rust
let router = crate::api::configure(state);

let listener = tokio::net::TcpListener::bind(addr).await?;
axum::serve(listener, router.into_make_service()).await?;
```

Run `cargo build` and `./target/debug/cli_application serve` and test the 
application using `curl`. You should receive something like this:

```bash
$ curl -v http://127.0.0.1:8080/v1/hello
*   Trying 127.0.0.1:8080...
* Connected to 127.0.0.1 (127.0.0.1) port 8080 (#0)
> GET /v1/hello HTTP/1.1
> Host: 127.0.0.1:8080
> User-Agent: curl/7.81.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< content-type: text/plain; charset=utf-8
< content-length: 15
< date: Sun, 21 May 2023 11:47:23 GMT
< 

Hello world!

* Connection #0 to host 127.0.0.1 left intact
```

### Application state

We demonstrated earlier how to load application configuration from 
environment variables or files, but our axum handler methods cannot use this 
information yet. To solve this problem we have to introduce application 
state and distribute this state to all the handler methods.

One small change first: we have to make our `Settings` struct cloneable. 
We need this because we pass it to the `serve` function as a reference, 
but the application state has to own its own dedicated copy, otherwise we 
cannot satisfy the Rust borrow checker. All we have to do is add the `Clone` 
trait to the derive macros in `src/settings.rs`:

```rust
#[derive(Debug, Deserialize, Default, Clone)]
#[allow(unused)]
pub struct Database {
    pub url: Option<String>,
}

#[derive(Debug, Deserialize, Default, Clone)]
#[allow(unused)]
pub struct Logging {
    pub log_level: Option<String>,
}

#[derive(Debug, Deserialize, Default, Clone)]
#[allow(unused)]
pub struct ConfigInfo {
    pub location: Option<String>,
    pub env_prefix: Option<String>,
}

#[derive(Debug, Deserialize, Default, Clone)]
#[allow(unused)]
pub struct Settings {
    #[serde(default)]
    pub config: ConfigInfo,
    #[serde(default)]
    pub database: Database,
    #[serde(default)]
    pub logging: Logging,
}
```

Now we can introduce the `ApplicationState` struct. Let's create the 
`src/state/mod.rs` file, and include `mod state` in `lib.rs`:

```rust
use crate::settings::Settings;
use std::sync::Arc;
use arc_swap::ArcSwap;

pub struct ApplicationState {
    pub settings: ArcSwap<Settings>,
}

impl ApplicationState {
    pub fn new(settings: &Settings) -> anyhow::Result<Self> {
        Ok(Self {
            settings: ArcSwap::new(Arc::new((*settings).clone())),
        })
    }
}
```

We use the `ArcSwap` type to wrap our `Settings`. This allows us to distribute
the `Settings` to multiple threads safely and also enables us to replace it 
with a new `Settings` instance any time later. As you can see, the `ArcSwap` 
initialization requires the use of an `Arc` reference-counting pointer too, 
and we have to pass a new, owned clone of the settings to it (not just a 
reference to a `Settings` instance).

Now in the `start_tokio` method we can use the settings passed from the
serve subcommand's `handle` method, build a new `ApplicationState` from it,
and also pass it to all the route configurations:

```rust
pub fn handle(
    matches: &ArgMatches, 
    settings: &Settings
) -> anyhow::Result<()> {
    let port: u16 = *matches.get_one("port").unwrap_or(&8080);

    start_tokio(port, settings)?;

    Ok(())
}

fn start_tokio(port: u16, settings: &Settings) -> anyhow::Result<()> {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?
        .block_on(async move {
            let state = Arc::new(ApplicationState::new(settings)?);
            let router = crate::api::configure(state);

            let addr = SocketAddr::new(
                IpAddr::V4(Ipv4Addr::new(0, 0, 0, 0)), 
                port
            );

            let listener = tokio::net::TcpListener::bind(addr).await?;
            axum::serve(listener, router.into_make_service()).await?;

            Ok::<(), anyhow::Error>(())
        })?;

    Ok(())
}
```

We have to change the signature of the configure methods too. 
First in `api/mod.rs`:

```rust
use crate::state::ApplicationState;
use std::sync::Arc;

pub fn configure(state: Arc<ApplicationState>) -> Router {
    Router::new().nest("/v1", v1::configure(state))
}
```

Then in `api/v1.rs`. Here we use the `with_state` method
to pass our state to the `hello` handler method.

```rust
pub fn configure(state: Arc<ApplicationState>) -> Router {
    Router::new()
        .route(
            "/hello", 
            get(handlers::hello::hello).with_state(state)
        )
}
```

Finally, we can use the `State` extractor from axum to extract
the state we passed in the previous router configuration:

```rust
use crate::state::ApplicationState;
use axum::extract::State;
use axum::http::StatusCode;
use std::sync::Arc;

pub async fn hello(
    State(state): State<Arc<ApplicationState>>
) -> Result<String, StatusCode> {

    Ok(format!(
        "\nHello world! Using configuration from {}\n\n",
        state
            .settings
            .load()
            .config
            .location
            .clone()
            .unwrap_or("[nowhere]".to_string())
    ))
}
```

And that's it, now our handler methods can use application state and the 
loaded settings with it. Build the application, run it with the `serve` 
subcommand, and test the endpoint with `curl`:

```bash
$ curl -v http://127.0.0.1:8080/v1/hello
*   Trying 127.0.0.1:8080...
* Connected to 127.0.0.1 (127.0.0.1) port 8080 (#0)
> GET /v1/hello HTTP/1.1
> Host: 127.0.0.1:8080
> User-Agent: curl/7.81.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< content-type: text/plain; charset=utf-8
< content-length: 52
< date: Mon, 29 May 2023 12:08:00 GMT
< 

Hello world! Using configuration from [nowhere]

* Connection #0 to host 127.0.0.1 left intact
```

Well, we use no configuration file currently ...

### Tracing

You may have noticed that our application is quite silent, it does not
output any information about what is going on under the hood.

We can enable basic tracing to output log messages to the console.
To do this, we have to add a few more crates to `Cargo.toml`:

```toml
[dependencies]
...
tracing = { version = "0.1", features = ["log"] }
tracing-log = { version = "0.1" }
tracing-subscriber = { version = "0.2", features = ["registry", "env-filter"] }
tower-http = { version = "0.3.5", features = ["trace"] }
```

And setup tracing in the `start_tokio` method in `commands/serve.rs`:

```rust
use tower_http::trace::TraceLayer;
use tracing::Level;
use tracing::level_filters::LevelFilter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::fmt;
use tracing_subscriber::util::SubscriberInitExt;
...

tokio::runtime::Builder::new_multi_thread()
    .enable_all()
    .build()?
    .block_on(async move {
            let subscriber = tracing_subscriber::registry()
                .with(LevelFilter::from_level(Level::TRACE))
                .with(fmt::Layer::default());

            subscriber.init();

            let state = Arc::new(ApplicationState::new(settings)?);
            let router = crate::api::configure(state)
                .layer(TraceLayer::new_for_http());
        
        ...
```

This setup creates a subscriber, sets the maximum tracing level to `TRACE`
and then adds the default formatting layer (that one writes the tracing
events to the console). Finally, we initialize the subscriber.

Also, we add a `TraceLayer` to our router configuration, so it will output
trace events on every HTTP request.

Now, if you compile and run the application again and send some request
using curl, you will receive messages on the console like this:

```
2024-02-11T10:53:36.602131Z DEBUG request{method=GET uri=/v1/hello ...
2024-02-11T10:53:36.602225Z DEBUG request{method=GET uri=/v1/hello ...
```

## The domain model

We arrived to the point where we have to define the purpose of our
sample application. Let's try to keep it simple, assume that our
goal is to write the API for a blogging application. Our first two
models will be the `User` who writes blog posts and the `Post` itself.

A `User` has the following properties:

- **id**: a unique identifier, an `i64` number for example
- **username**: also unique, but String and changeable by the user
- **password**: for user authentication
- **status**: to indicate active or blocked state of the user
- **created**: the time when the user was created
- **updated**: the last time when the user's properties were modified
- **last_login**: the last time when the user logged in 

A `Post` has the following properties:

- **id**: a unique id, an `i64` number
- **author_id**: unique id of the author (the User who created the Post)
- **title**: title of the blog post
- **content**: content of the blog post
- **slug**: a unique String identifier derived from the title, suitable
  for usage in URLs
- **status**: to indicate draft or published state of the post
- **created**: the time when the post was created
- **updated**: the last time when the post's properties were modified

We have to handle time, so we have to add the `chrono` crate to our
dependencies in `Cargo.toml`:

```toml
[dependencies]
...
chrono = {  version = "0.4.34", features = ["serde"] }
```

The `serde` feature is necessary if we want to serialize or deserialize
date and time types.

Let's create our model structs! Create a new file in `cli_application/src`
called `model.rs` and reference it from `lib.rs`:

```rust
pub mod model;
```

In `model.rs` we have to crate two enums first: one for the user status
and one for the post status:

```rust
#[derive(Copy, Clone, Serialize, Deserialize)]
pub enum UserStatus {
    Active = 1,
    Blocked = 2,
}

#[derive(Copy, Clone, Serialize, Deserialize)]
pub enum PostStatus {
    Draft = 1,
    Published = 2,
}
```

The `Copy` and `Clone` trait implementations allow us to create copies of
these enum values. The `Serialize` and `Deserialize` implementations
will be required when we have to deserialize a posted JSON into a `Post`
structure for example or when we have to serialize a `Post` into a JSON
response.

Now create our two entity structures:

```rust
#[derive(Clone, Serialize)]
pub struct User {
    pub id: i64,
    pub username: String,
    pub password: String,
    pub status: UserStatus,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
    pub last_login: Option<DateTime<Utc>>,
}

#[derive(Clone, Serialize)]
pub struct Post {
    pub id: i64,
    pub author_id: i64,
    pub slug: String,
    pub title: String,
    pub content: String,
    pub status: PostStatus,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
}
```

The `last_login` property in `User` is optional, because it will not have a 
value until the user logs in the first time.

As you can see, we used the `DateTime` type to store the time of events
like creation, modification and login. The `Utc` type parameter indicates
that we will store all time-related data in UTC timezone. This can be
converted to the required local time zones easily.

We cannot implement the `Copy` trait here, because our structures contain
strings, so we fall back to the `Clone` trait.

Now we have our data model, but we have to store that data somewhere.
Try to keep it simple for now, so we will not use persistence, but store
the data in memory only.

A structure like this can be an option:

```rust
pub struct InMemoryPostStore {
    pub counter: i64,
    pub items: HashMap<i64, Post>,
}
```

We will use the `counter` to generate a unique identifier for our `Post`
instances and store the instances in the `items` hash map.

One problem with this structure: it is not thread-safe and we have to
share it amongst multiple threads (because we use a multi-threaded async 
runtime).

Let's wrap this store in a service that protects the store with a `Mutex`:

```rust
pub struct InMemoryPostService {
    data: Mutex<InMemoryPostStore>,
}
```

Now this data structure is safe to pass between multiple threads.
To be able to instantiate the service, let's implement the `Default` trait 
for it:

```rust
impl Default for InMemoryPostService {
    fn default() -> Self {
        Self {
            data: Mutex::new(InMemoryPostStore {
                counter: 0,
                items: Default::default(),
            }),
        }
    }
}
```

We initialize the service with `counter` set to zero and an empty `items` map,
and wrap the whole thing in a `Mutex`.

Later we will use more complicated implementations of this service, but
we can assume that their interface will be quite similar to our current
implementation. Let's define a trait for this:

```rust
#[allow(async_fn_in_trait)]
pub trait PostService {
    async fn get_all_posts(&self) -> anyhow::Result<Vec<Post>>;
    async fn get_post_by_id(&self, id: i64) -> anyhow::Result<Post>;
    async fn get_post_by_slug(&self, name: &str) -> anyhow::Result<Post>;
    async fn create_post(&self, req: CreatePostRequest) -> anyhow::Result<Post>;
    async fn update_post(&self, req: UpdatePostRequest) -> anyhow::Result<Post>;
    async fn delete_post(&self, id: i64) -> anyhow::Result<()>;
}
```

Async methods in traits are not a thing you should use in libraries for now, 
but they are accepted in applications. This is why we silence the warning about
them.

We defined some simple operations:

- list all the available posts
- get a post by its unique numeric identifier
- lookup a post according to its slug
- create a post
- update a post
- delete a post

As you can see, the input of the create and update operations is not a `Post`
entity but new `CreatePostRequest` and `UpdatePostRequest` structures.
Why? Because when we want to initiate the creation of a `Post`, we do not
know all of its properties. The time of creation and the id field will be
filled for us automatically for example. Same for an update: we
won't be able to change all properties of a `Post`.

We always return an `anyhow::Result` from our methods, because these operations
may fail and the application has to handle the failures later.

Let's see the implementation! Create a directory named `services` in 
`cli_application/src` and a file named `post.rs` in it. Then create a file
named `mod.rs` too and reference the `post` module from it:

```rust
pub mod post;
```

Also reference the `services` module from `lib.rs`:

```rust
pub mod services;
```

Now add the above `PostService` trait, `InMemoryPostStore` and
`InMemoryPostService` structs to it.

Start the implementation of the `PostService` trait for `InMemoryPostService`:

```rust

impl PostService for InMemoryPostService {
    async fn get_all_posts(&self) -> anyhow::Result<Vec<Post>> {
        let data = self.data.lock().await;
        Ok(data.items.values().map(|post| (*post).clone()).collect())
    }
    ...
}
```

First we lock the mutex, then iterate over the values stored in the `HashMap`
and return a clone of each post in a `Vec`. Why the clones? 
Because the callers of our service are not allowed to hold direct 
references into our mutex-protected hash map. That would break the rules of 
the borrow checker. The locked mutex is automatically released when `data`
goes out of scope (when we return from the `get_all_posts` method).

Now lookup a single post, either by id or by slug:

```rust
async fn get_post_by_id(&self, id: i64) -> anyhow::Result<Post> {
    let data = self.data.lock().await;

    match data.items.get(&id) {
        Some(post) => Ok((*post).clone()),
        None => anyhow::bail!("Post not found: {}", id),
    }
}

async fn get_post_by_slug(&self, slug: &str) -> anyhow::Result<Post> {
    let data = self.data.lock().await;
    for (_id, post) in data.items.iter() {
        if post.slug == slug {
            return Ok(post.clone());
        }
    }

    anyhow::bail!("Post not found: {}", slug)
}    
```

As you can see, we return an error when the post cannot be found.
To search by slug, we have to iterate over the items in the hash map and check
them one by one. This it not too effective, but it is good enough for now.

To create a post, we pass in a `CreatePostRequest` structure:

```rust
async fn create_post(&self, req: CreatePostRequest) -> anyhow::Result<Post> {
    let mut data = self.data.lock().await;
    data.counter += 1;
    let ts = chrono::offset::Utc::now();
    let post = Post {
        id: data.counter,
        author_id: req.author_id,
        slug: req.slug,
        title: req.title,
        content: req.content,
        status: req.status,
        created: ts,
        updated: ts,
    };

    data.items.insert(post.id, post);

    match data.items.get(&data.counter) {
        None => {
            anyhow::bail!("Post not found: {}", data.counter)
        }
        Some(post) => Ok(post.clone()),
    }
}
```

Increment the counter to get a new unique identifier, get the current time,
then fill up the `Post` instance with all the data. Finally, insert the
created post into the hash map. The insert operation consumes our `Post`
instance, so we cannot return it directly. We have two choices: create a
clone before the insert or lookup the inserted post from the hash map and
clone that. I implemented the latter but you can use both approaches.

Now in the update method, we update the stored instance directly:

```rust
async fn update_post(&self, req: UpdatePostRequest) -> anyhow::Result<Post> {
    let mut data = self.data.lock().await;
    let post = data
        .items
        .get_mut(&req.id)
        .ok_or(anyhow::anyhow!("Post not found: {}", req.id))?;

    post.slug = req.slug;
    post.title = req.title;
    post.content = req.content;
    post.status = req.status;

    match data.items.get(&data.counter) {
        None => {
            anyhow::bail!("Post not found: {}", req.id)
        }
        Some(post) => Ok(post.clone()),
    }
}
```

The `data.items.get_mut()` method returns a mutable reference to the stored
`Post` instance. At the end of the method we return a clone of the post
again.

Finally, the last operation from the CRUD list:

```rust
async fn delete_post(&self, id: i64) -> anyhow::Result<()> {
    let mut data = self.data.lock().await;
    match data.items.remove(&id) {
        None => {
            anyhow::bail!("Post not found: {}", id)
        }
        Some(_) => Ok(()),
    }
}
```

Here, we have nothing to return in case of a successful deletion.

Now, as an exercise, you can implement the `InMemoryUserService` to 
store the users the same way as we did for posts. You can find the
solution in the code samples of the book.

Finally, we have to extend our `ApplicationState` with our new services:

```rust
use crate::services::post::InMemoryPostService;
use crate::services::user::InMemoryUserService;
use crate::settings::Settings;
use arc_swap::ArcSwap;
use std::sync::Arc;

pub struct ApplicationState {
    pub settings: ArcSwap<Settings>,
    pub user_service: Arc<InMemoryUserService>,
    pub post_service: Arc<InMemoryPostService>,
}

impl ApplicationState {
    pub fn new(settings: &Settings) -> anyhow::Result<Self> {
        Ok(Self {
            settings: ArcSwap::new(Arc::new((*settings).clone())),
            user_service: Arc::new(InMemoryUserService::default()),
            post_service: Arc::new(InMemoryPostService::default()),
        })
    }
}
```

Now our application is ready to store posts in process memory, so we can
start the implementation of the API endpoints for them.

## Basic CRUD endpoints

**CRUD** is the abbreviation of Create, Read, Update, Delete. These are
the basic operations on an entity in the REST API style.

The recommended URL structure for these operations:

- `GET /v1/posts` - list all the posts or query a subset of them
- `GET /v1/posts/:id` or `GET /v1/posts/:slug` - get a specific post
- `POST /v1/posts` - create a new post
- `PUT /v1/posts/:id` - update an existing post
- `DELETE /v1/posts/:id` - delete a post

To implement this URL structure, we have to extend `src/api/v1.rs`:

```rust
pub fn configure(state: Arc<ApplicationState>) -> Router {
    Router::new()
        .route(
            "/hello",
            get(handlers::hello::hello).with_state(state.clone()),
        )
        .route(
            "/posts",
            post(handlers::posts::create).with_state(state.clone()),
        )
        .route(
            "/posts",
            get(handlers::posts::list).with_state(state.clone()),
        )
        .route(
            "/posts/:slug",
            get(handlers::posts::get).with_state(state.clone()),
        )
        .route(
            "/posts/:id",
            put(handlers::posts::update).with_state(state.clone()),
        )
        .route(
            "/posts/:id",
            delete(handlers::posts::delete).with_state(state),
        )
}
```

- the `posts::create` handler will reply to the `POST` requests,
- the `posts::list` handler will reply to the `GET /v1/posts` requests
- the `posts::get` handler will reply to the `GET /v1/posts/:id` requests
- the `posts::update` handler will reply to the `PUT` requests
- finally, the `posts::delete` handler will reply to the `DELETE` requests

As you can see the URL pattern can include placeholders like `:id`
and `:slug` - the handlers will receive these parameters via so-called
extractors. The `POST` and `PUT` requests must contain a JSON request
body, the appropriate handler methods will receive the parsed request
via extractors too.

Now let's see the implementations! First we have to create a new file
named `posts.rs` in `src/api/handlers` and reference the module in
`handlers/mod.rs`:

```rust
pub mod posts;
```

Now in `posts.rs` start with the `create` handler:

```rust
pub async fn create(
    State(state): State<Arc<ApplicationState>>,
    Json(payload): Json<CreatePostRequest>,
) -> Result<Json<SinglePostResponse>, AppError> {
    let post = state.post_service.create_post(payload).await?;

    let response = SinglePostResponse { data: post };

    Ok(Json(response))
}
```

The first parameter of the handler function is the `State` extractor,
this one receives the application state we passed in with the `.with_state()`
method.

The second parameter is a `Json` extractor. The `CreatePostRequest` was
already defined in `services/post.rs`. It implements the `Deserialize` trait, 
so the axum framework can deserialize the JSON request body into it using
the `Json` extractor. We only have to pass the request to the `post_service`
and handle its response. The `Json` extractor may fail when the request
body is not a valid JSON document or its content does not match the structure
of the `CreatePostRequest`. In this case axum will return a `400 Bad Request`
response. We also handle potential errors from the `post_service`, the `?`
operator turns it into an `AppError` and this will result in an
`500 Internal Server Error` response.

If all goes well, we return the newly created post as a JSON, but embed it
in a structure called `SinglePostResponse`. We define this struct in
`api/response/posts.rs`:

```rust
use crate::model::Post;
use serde::Serialize;

#[derive(Serialize)]
pub struct SinglePostResponse {
    pub data: Post,
}
```

It's simply a container for a single post. In the future we will probably
extend this structure with some metadata. It has a sibling, called 
`ListPostsResponse` which can return multiple posts in an array:

```rust
#[derive(Serialize)]
pub struct ListPostsResponse {
    pub data: Vec<Post>,
}
```

The `update` handler is quite similar:

```rust
pub async fn update(
    State(state): State<Arc<ApplicationState>>,
    Path(id): Path<i64>,
    Json(payload): Json<UpdatePostRequest>,
) -> Result<Json<SinglePostResponse>, AppError> {
    let post = state.post_service.update_post(id, payload).await?;

    let response = SinglePostResponse { data: post };

    Ok(Json(response))
}
```

The `Path` extractor receives the `:id` element from the request path,
the `Json` extractor now parses the body into an `UpdatePostRequest`
and we return the updated post the same way as earlier.
The `Path` extractor may fail if the `:id` element is not a number:
that results in a `400 Bad Request` response.

The `delete` handler has no request body and no response body either:

```rust
pub async fn delete(
    State(state): State<Arc<ApplicationState>>,
    Path(id): Path<i64>,
) -> Result<Json<()>, AppError> {
    state.post_service.delete_post(id).await?;

    Ok(Json(()))
}
```

The `list` handler receives no extra parameters and returns a 
`ListPostsResponse` - the one that embeds an array of posts:

```rust
pub async fn list(
    State(state): State<Arc<ApplicationState>>,
) -> Result<Json<ListPostsResponse>, AppError> {
    let posts = state.post_service.get_all_posts().await?;

    let response = ListPostsResponse { data: posts };

    Ok(Json(response))
}
```

Finally, the `get` handler receives the `:slug` path parameter as 
a string via the `Path` extractor:

```rust
pub async fn get(
    State(state): State<Arc<ApplicationState>>,
    Path(slug): Path<String>,
) -> Result<Json<SinglePostResponse>, AppError> {
    let post = state.post_service.get_post_by_slug(&slug).await;

    match post {
        Ok(post) => {
            let response = SinglePostResponse { data: post };

            Ok(Json(response))
        }
        Err(e) => Err(AppError::from((StatusCode::NOT_FOUND, e))),
    }
}
```

and returns a single post in the response or `404 Not Found` when no
matching post was found.

## Authentication and authorization

Up until now we managed to create a few basic CRUD endpoints for our blog
service. Now we have to implement authentication and authorization.

We will try to log in a user on a new `POST /v1/login` API endpoint and 
return a JWT token certifying his identity on success. An API consumer will 
be able to use that JWT token on subsequent calls to authenticate itself.

A JWT token packs a set of information (claims) into a small, easily 
transmittable JSON object. This makes it perfect for scenarios like web 
authentication. JWTs are digitally signed, either with a secret key (HMAC) 
or a public/private key pair (RSA or ECDSA). This signing ensures that the 
information within the token hasn't been tampered with.
When you log into a system, the server can generate a JWT and send it back 
to your browser. Your browser will then include this JWT in subsequent 
requests as Bearer token, proving your identity.

A JWT has three parts separated by dots:

**Header**: Contains metadata about the token itself:

- `alg`: The signing algorithm (e.g., HMAC SHA256, RS256)
- `typ`: Specifies that this is a JWT token 

**Payload**: The core part where your data lives. This includes claims like:

- `iss`: Issuer of the token
- `sub`: Subject of the token (often the user ID)
- `exp`: Expiration time of the token
- `iat`: Issued at time

or any other custom data depending on your use case.

**Signature**: Verifies the integrity of the token. It's computed by combining 
the encoded header, encoded payload, a secret (or private key), and the 
specified algorithm.

The main benefit of JWT is that it is stateless. The server does not have to
store any session data. This makes it easy to scale and use in a distributed
environment.

To test the JWT authentication we will add authorization to the 
`POST /v1/posts` API endpoint, so only authorized users 
will be able to submit new posts.

First, we have to add a new dependency in `cli_application/Cargo.toml`:

```toml
[dependencies]
...
jsonwebtoken = "8.3.0"
```

We will use `jsonwebtoken` for JWT token generation and validation.

We have to extend our project structure: add a `request` folder under 
`src/api` and the appropriate module declaration in `src/api/mod.rs`:

```rust
// ...
pub mod request;
// ...
```

Create a new struct for the login request in `src/api/request/login.rs`:

```rust
use serde::Deserialize;

#[derive(Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}
```

The `Deseralize` macro ensures that we can deserialize this request from JSON.

Also add a `mod.rs` file under `src/api/request`,
referencing the `login` module:

```rust
pub mod login;
```

Create a new struct for the login response in `src/api/response/login.rs`:

```rust
use serde::Serialize;

#[derive(Serialize)]
pub struct LoginResponse {
    pub status: String,
    pub token: String,
}
```

The `Serialize` macro ensures that we can serialize this response into JSON.

And the appropriate module declaration in `src/api/response/mod.rs`: 

```rust
pub mod login;
```

We will also need a struct to store the JWT token claims, 
I placed this into `response/mod.rs` too:

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct TokenClaims {
    pub sub: String,
    pub iat: usize,
    pub exp: usize,
}
```

The `sub` field is the token subject (generally username or user id), 
the `iat` field will store the unix timestamp of the token generation 
and the `exp` field will store the unix timestamp of the token expiration time.

To create a login endpoint, we have to extend our api declaration in 
`src/api/v1.rs`:

```rust
// ...
    .route(
        "/posts/:id",
        delete(handlers::posts::delete).with_state(state.clone()),
    )
    .route(
        "/login", 
        post(handlers::login::login).with_state(state)
    )
```

And implement the login functionality in `src/api/handlers/login.rs`:

```rust
use crate::api::request::login::LoginRequest;
use crate::api::response::login::LoginResponse;
use crate::api::response::TokenClaims;
use crate::state::ApplicationState;
use axum::extract::State;
use axum::http::StatusCode;
use axum::Json;
use jsonwebtoken::{encode, EncodingKey, Header};
use std::sync::Arc;

pub async fn login(
    State(_state): State<Arc<ApplicationState>>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, StatusCode> {

    ...

}
```

Do not forget to add the `pub mod login;` line to `src/api/handlers/mod.rs`!

Let's check the use statements: the `LoginRequest` and `LoginResponse`
structs are for the request and response data respectively. 
I also explained `TokenClaims` earlier. 
We already used `State`, `ApplicationState`, `StatusCode` and the `Json`
extractor so you may know them. I will tackle `jsonwebtoken` shortly.

I will implement a dummy login function for now, always returning success 
without password checking.

We will need some data to populate the `TokenClaims` structure:

```rust
pub async fn login(
    State(_state): State<Arc<ApplicationState>>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, StatusCode> {

    let now = chrono::Utc::now();
    let iat = now.timestamp() as usize;
    let exp = (now + chrono::Duration::minutes(60)).timestamp() as usize;
    let claims = TokenClaims {
        sub: payload.username,
        exp,
        iat,
    };

    // ...
}
```

We use `chrono` to get the current timestamp and convert it into `usize` 
for the `iat` field. The `exp` field is similar, current timestamp 
plus 60 minutes (we will use a configurable timeout parameter later). 
The token subject will store the username for now.

The next step is to encode the token:

```rust
let secret = "secret";

let token = encode(
    &Header::default(),
    &claims,
    &EncodingKey::from_secret(secret.as_bytes()),
)
.unwrap();

let response = LoginResponse {
    status: "success".to_string(),
    token,
};

Ok(Json(response))
```

The secret is not so secret in this case, we will read it from the 
configuration later. Finally, we return the token in the response.

Now extend our configuration to add a token timeout and a token secret 
(`src/settings.rs`):

```rust
pub struct Settings {
    #[serde(default)]
    pub config: ConfigInfo,
    #[serde(default)]
    pub database: Database,
    #[serde(default)]
    pub logging: Logging,
    pub token_secret: Option<String>,
    pub token_timeout_seconds: Option<i64>,
}
```

so we can use them in the login handler:

```rust
let secret = state
    .settings
    .load()
    .token_secret
    .clone()
    .unwrap_or("secret".to_string());
let timeout = state
    .settings
    .load()
    .token_timeout_seconds
    .unwrap_or(3600);
```

To add authentication to the endpoints, we have to implement a middleware:

```rust
pub async fn auth(
    State(state): State<Arc<ApplicationState>>,
    mut req: Request<Body>,
    next: Next,
) -> Result<impl IntoResponse, AppError> {
  // TBD
}
```

The middleware will receive the application state, so it can read
application configuration, etc. It also receives the HTTP request, so it
can extract the `Authorization` header from it. The `next` parameter is
the next middleware in the axum middleware chain.

The middleware will either return an error response or call the next
middleware in the chain.

To implement this middleware, create a new directory in `src/api` called
middleware and a file named `auth.rs` in it. Add the appropriate module
declaration to `src/api/middleware/mod.rs`:

```rust
pub mod auth;
```

Also reference the `middleware` module from `src/api/mod.rs`:

```rust
pub mod middleware;
```

First, we have to extract the token from the `Authorization` header:

```rust
let token = req
    .headers()
    .get(header::AUTHORIZATION)
    .and_then(|auth_header| auth_header.to_str().ok())
    .and_then(|auth_value| {
        auth_value
            .strip_prefix("Bearer ")
            .map(|stripped| stripped.to_owned())
    });
```

We try to get the header value, convert it to a string, then strip
the `Bearer ` prefix from it. If all goes well, we will have the token
value.

Return an error if the token is missing:

```rust
let token = token.ok_or_else(|| {
    AppError::from((
        StatusCode::UNAUTHORIZED, 
        anyhow::anyhow!("Missing bearer token")
    ))
})?;
```

Now load the secret from settings and validate the token:

```rust
let secret = state
    .settings
    .load()
    .token_secret
    .clone()
    .unwrap_or("secret".to_string());

let claims = decode::<TokenClaims>(
    &token,
    &DecodingKey::from_secret(secret.as_bytes()),
    &Validation::default(),
)
    .map_err(|_| {
        AppError::from((
            StatusCode::UNAUTHORIZED, 
            anyhow::anyhow!("Invalid bearer token")
        ))
    })?
    .claims;
```

The default `Validation` configuration ensures that the encryption 
algorithm is `HS256` and the token is not expired.
We return an error if the validation failed.
Finally, we add the claims to the request as an extension
and call the next middleware in the chain:

```rust
req.extensions_mut().insert(claims);
Ok(next.run(req).await)
```

This extension will be the first parameter of the handler function: 
`Extension(_claims): Extension<TokenClaims>,`. 
We simply ignore the claims in this case, but the handler could 
implement more complex authorization rules based on the `sub` value 
of the token (that contains the username).

The token can be more complex and include additional properties of the user,
like roles, etc. This can be useful for more complex authorization rules.

Now we have to add the middleware to the router configuration in
`src/api/v1.rs`. On the `POST /posts` endpoint for example:

```rust
    .route(
        "/posts",
        post(handlers::posts::create)
            .with_state(state.clone())
            .route_layer(middleware::from_fn_with_state(state.clone(), auth)),
    )
```

and modify the handler function to receive the token claims:

```rust
pub async fn create(
    Extension(_claims): Extension<TokenClaims>,
    State(state): State<Arc<ApplicationState>>,
    Json(payload): Json<CreatePostRequest>,
) -> Result<Json<SinglePostResponse>, AppError> {
    let post = state.post_service.create_post(payload).await?;

    let response = SinglePostResponse { data: post };

    Ok(Json(response))
}
```

## The middleware pattern

Axum's middleware or layer concept builds on `tower` and `tower-http`.
Think of middleware as layers that wrap around your route handlers 
(the functions that ultimately respond to web requests). 
Each layer has the power to:

- inspect and modify incoming requests before they reach your route handler
- inspect and modify outgoing responses after your route handler does its work

Axum primarily works with two approaches to create middleware:
middleware from functions and tower::Layer implementations.

A middleware function means you define an async function that takes a 
`Request` and a `Next` (representing the next layer in the chain).
The function does its modifications and then calls `next.run(request).await` 
to pass the potentially modified request to the next middleware 
layer or your route handler. The `auth` middleware we created in the
previous section is an example of this approach.

If you need more complex middleware, you create a struct implementing the 
`tower::Layer` trait. This gives you more control over how middleware is 
applied across your entire application.

Middleware is useful for streamlining common web development concerns:

- authentication, authorization: protect routes by checking if a user is
  logged in and has the necessary permissions.
- logging, tracing: record crucial information about requests and responses
  for debugging or analysis
- CORS handling: enable cross-origin resource sharing for web apps using
  different domains
- compression: reduce response size for faster page loads
- CSRF protection: prevent cross-site request forgery attacks
- rate Limiting: protect against overwhelming request floods
- error handling: provide centralized error management and consistent
  responses to users

These layers can be applied to specific routes, groups of routes, or
applied globally to all routes in your application.

The `tower-http` crate provides a set of ready-to-use middlewares 
that can be used in axum applications.

### Trace

This middleware adds high-level logging for requests and responses, 
including method,  path, status code, and more. Perfect for 
debugging and monitoring.

Simple example:

```rust
let mut service = ServiceBuilder::new()
    .layer(TraceLayer::new_for_http())
    .service_fn(handle);
```

A more detailed one:

```rust
let service = ServiceBuilder::new()
    .layer(
        TraceLayer::new_for_http()
            .make_span_with(
                DefaultMakeSpan::new().include_headers(true)
            )
            .on_request(
                DefaultOnRequest::new().level(Level::INFO)
            )
            .on_response(
                DefaultOnResponse::new()
                    .level(Level::INFO)
                    .latency_unit(LatencyUnit::Micros)
            )
    )
    .service_fn(handle);    
```

Here we can set different tracing levels for requests and responses,
se the measurement unit for latency, decide to include the headers in
the span data, etc.

In the `on_request`, `on_response` and similar methods you can even provide 
your own custom implementations, completely replacing the default ones.

### Compression

This one enables compression mechanisms like gzip to reduce response 
sizes for improved network performance.

Example:

```rust
let mut service = ServiceBuilder::new()
    // Compress responses based on the `Accept-Encoding` header.
    .layer(CompressionLayer::new())
    .service_fn(handle);
```

### Timeout

This middleware sets a time limit for requests to complete, helping prevent 
hanging requests that consume resources endlessly.

Example:

```rust
let svc = ServiceBuilder::new()
    // Timeout requests after 30 seconds
    .layer(TimeoutLayer::new(Duration::from_secs(30)))
    .service_fn(handle);
```

### CORS

This one provides mechanisms to implement Cross-Origin Resource Sharing 
policies, allowing web apps on different domains to interact.

Example:

```rust
let cors = CorsLayer::new()
    // allow `GET` and `POST` when accessing the resource
    .allow_methods([Method::GET, Method::POST])
    // allow requests from any origin
    .allow_origin(Any);
```

### Limit

This middleware limits the size of incoming requests, preventing
attacks that try to overwhelm the server with huge requests.

Example:

```rust
let mut svc = ServiceBuilder::new()
    // Limit incoming requests to 4096 bytes.
    .layer(RequestBodyLimitLayer::new(4096))
    .service_fn(handle);
```

### Rate limiting

If you want to implement some kind of request rate limiting, you can use
the `tower-governor` crate. It provides a middleware that can limit the
number of requests per time period. You can set limits based on 
peer IP address, IP address headers, globally, or via custom keys.
You can also configure burst, like this:

```rust
let governor_conf = Box::new(
    GovernorConfigBuilder::default()
       .per_second(2)
       .burst_size(5)
       .finish()
       .unwrap(),
);
```

### CSRF protection

Two common patterns for CSRF protection are the double submit cookie pattern
and the synchronizer token pattern.

#### Double Submit Cookie Pattern

A random CSRF token is generated and stored in a server-side session.
The same token is set in a cookie with the `HttpOnly` and `SameSite` 
flags for security. Forms include the token as a hidden field.
On submission, the server compares the token in the cookie to the one 
in the form data. This method is primarily used for traditional web
applications that rely on server-side sessions.

#### Synchronizer Token Pattern

CSRF tokens are still generated server-side but may be stored differently 
(e.g., in-memory, distributed cache). Tokens are exposed in a protected API 
endpoint that your frontend calls to fetch them. Frontends include tokens 
in request headers (e.g., X-CSRF-Token).

This method is more suitable for single-page applications and APIs.

There is an implementation of this pattern for axum, but only up to version 0.6 
in the `axum-csrf` crate. Alternatively, you can implement your own middleware 
based on it.

## Graceful shutdown

When you want to stop your application, you should do it gracefully.
This means that you should stop accepting new requests, wait for the
current requests to finish, and then shut down the server.

First, you have to implement a signal handler:

```rust
async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}
```

This function will wait for a `Ctrl+C` signal or a `SIGTERM` signal.
You can use this function to stop the server gracefully. 
The actual implementation in axum 0.7 looks like this, where `signal`
is the signal handler function you created earlier:

```rust
let (signal_tx, signal_rx) = watch::channel(());
let signal_tx = Arc::new(signal_tx);
tokio::spawn(async move {
    signal.await;
    trace!("received graceful shutdown signal. Telling tasks to shutdown");
    drop(signal_rx);
});
```

So when the future returned by `shutdown_signal` function completes,
the spawned task will drop the `signal_rx` sender. The main loop of
axum will notice this and stop accepting new requests:

```rust
let (tcp_stream, remote_addr) = tokio::select! {
    conn = tcp_accept(&tcp_listener) => {
        match conn {
            Some(conn) => conn,
            None => continue,
        }
    }
    _ = signal_tx.closed() => {
        trace!("signal received, not accepting new connections");
        break;
    }
};
```

Now in the `main` function, you can enable the graceful shutdown
this way:

```rust
#[tokio::main]
async fn main() {

    // Create a regular axum app.
    let app = Router::new()
        .route("/slow", get(|| sleep(Duration::from_secs(5))))
        .route("/forever", get(std::future::pending::<()>))
        .layer((
            // Graceful shutdown will wait for outstanding requests 
            // to complete. Add a timeout so requests don't hang forever.
            TimeoutLayer::new(Duration::from_secs(30)),
        ));

    // Create a `TcpListener` using tokio.
    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();

    // Run the server with graceful shutdown
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}
```

Note, that we added a `TimeoutLayer` to the router configuration. 
This will ensure that requests don't hang forever, so the shutdown can 
complete in a reasonable amount of time after the server stopped accepting
new requests.



