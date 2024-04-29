+++
title = "Hello World!"
description = ""
date = 2021-05-01T18:20:00+00:00
updated = 2021-05-01T18:20:00+00:00
draft = false
weight = 1020
sort_by = "weight"
template = "docs/page.html"
slug = "hello-world"

[extra]
lead = ""
toc = true
top = false
+++

In this chapter you will create a simple RESTful webservice, returning nothing 
more than a "hello world" message, formatted as JSON (Javascript Simple Object 
Notation).

We will go through the steps to set up the development environment and a 
simple project.

## Setup the development environment

During the development of this book we used Ubuntu Linux to test the 
examples and I generally recommend to use Linux for Rust development.

You will also need a good IDE. It is possible to write Rust code with a text
editor like vi or emacs, but trust me, an IDE will make your life much easier, 
especially in the beginning. We usually use VS Code with the rust-analyzer 
extension or JetBrains RustRover.

Use should also install `git` to be able to manage your source code 
repositories.

We used Rust version 1.75 during the development of this book.

### Install Rust

First things first: you have to install Rust if you have not done it yet.

The installation process is documented on [rust-lang.org](https://www.rust-lang.org/tools/install)
and in the [Rust Book](https://doc.rust-lang.org/book/ch01-01-installation.html)

A quick recap:

#### Linux

Just run this script:

```bash
$ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

#### Mac

First install a compiler:

```bash
$ xcode-select --install
```

Then run this script:

```bash
$ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

#### Windows

On windows you should probably use one of the standalone installers from here:

[https://forge.rust-lang.org/infra/other-installation-methods.html#standalone-installers](https://forge.rust-lang.org/infra/other-installation-methods.html#standalone-installers)

Or simply start a WSL2 environment and work with Rust within that 
Linux environment.

## Setup the workspace

I usually prefer to start the project with a multi-package workspace. 
This way we can split our application into smaller, loosely coupled 
parts but we don't have to maintain a different repository for each 
of them and we can work with the whole codebase in one IDE window.

You can find the sample codes on 
[GitHub](https://github.com/Rust-Book-Collective/rust-api-code/tree/main/hello-world/hello-world)

### Create a multi-package workspace

To start our new project, let's create a directory to hold the workspace:

```bash
$ mkdir hello-world
$ cd hello-world
```

and create a `Cargo.toml` file there:

```toml
[workspace]

members = [
  "hello_main"
]
```

Newer versions of `cargo` will probably display a warning about the resolver 
version. You should add this line to your `Cargo.toml` to prevent this:

```toml
[workspace]
resolver = "2"
```

This indicates that we opt in to use the new feature resolver introduced 
in Rust 1.51. The new resolver is the default starting with the 2021 
edition of the Rust language.

This configuration indicates that we have a single package for now, 
the `hello_main` package. Also initialize a git repository, 
to prevent `cargo new` from creating a new repository for every package:

```bash
$ git init
```

I use JetBrains RustRover so I usually add a `.gitignore` file to ignore 
the .idea folder and the Rust target folder:

```
.idea
target
```

If you use VS Code then you should add these folders to `.gitignore`:

```
.vscode
.history
```


Now we can create the new package with `cargo`:

```bash
cargo new hello_main
```

If the operating system does not find the `cargo` executable check your 
Rust installation. Maybe your `PATH` does not contain the folder where 
`rustup` installed the binaries.

You can find further troubleshooting tips here: 
[Installation Troubleshooting](https://doc.rust-lang.org/book/ch01-01-installation.html#troubleshooting)

Now our directory structure should look like this:

```
.git
.gitignore
Cargo.toml
hello_main/
  Cargo.toml
  src/
    main.rs
```

The `cargo` utility created the `hello_main` folder and a new `Cargo.toml` 
in it:

```toml
[package]
name = "hello_main"
version = "0.1.0"
edition = "2021"

[dependencies]
```

It contains the package name, a version number and indicates that we use the
2021 edition of the Rust language. The `dependencies` section is empty for now.

Cargo also creates an `src` folder and an initial `main.rs` source file in it:

```rust
fn main() {
    println!("Hello, world!");
}
```

Now we can run cargo build in the main workspace directory. The build creates 
an executable in `target/debug/hello_main` and a single `Cargo.lock` file 
in the main workspace directory. The `Cargo.lock` file locks our dependencies
to specific versions.

Try to execute `./target/debug/hello_main`, it just prints a `Hello, world!`
message to the console.

Let's commit our code:

```bash
$ git add .gitignore Cargo.lock Cargo.toml hello_main/ 
$ git commit -m 'workspace setup'
```

## A simple Axum webserver

We will use the `axum` crate to build our web services. At the time I write
this book the current version is `0.7.4`, so add this 
to the `hello_main/Cargo.toml` file:

```toml
[dependencies]
axum = "0.7.4"
```

Run `cargo build` to download our dependencies and build the `hello_main` 
binary. If you take a look at the `Cargo.lock` file generated in the root 
directory of the project, you will see that it includes a lot more packages, 
not just `axum`. These are the dependencies of `axum`. We will use some 
of them directly in our project, the `tokio` crate for example is required 
to start an async runtime, so add that one too:

```toml
[dependencies]
axum = "0.7.4"
tokio =  { version = "1.35.1", features = ["full"] }
```

Notice that this line is slightly different: we specified not only a 
version number for `tokio`, but a list of features too. The `tokio` 
crate has many optional parts, these are the so-called features. 
For the sake of simplicity we enabled most of them at once 
with the `full` flag.

Now open `hello_main/src/main.rs`, and change our `main` function 
into an async one:

```rust
#[tokio::main]
async fn main() {
    println!("Hello, world!");
}
```

The `#[tokio::main]` macro starts an async runtime for us and the whole `main`
function will run as an async function above that runtime. Later we will see
in detail what this macro does and how can you customize the created runtime.

If you run `cargo build` in the project root directory again and execute the 
resulting binary in `./target/debug/hello_main`, you will see that is just
works the way it did earlier.

Now create our first `axum` request handler in `main.rs`:

```rust
async fn hello() -> &'static str {
    "Hello, world!"
}
```

That's quite simple, just returns a static string slice, 
ontaining `Hello, world!`.

Now setup the routing for our web service in the `main` function, 
and start a simple server:

```rust
async fn main() {
    let app = Router::new()
        .route("/", get(hello));
        
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

The `route` method binds the `hello` function to the `GET` HTTP verb 
on the '/' path. So when a client send this request to our server:

```
GET / HTTP/1.0

```

Then we will respond with our hello message:

```
HTTP/1.0 200 OK
Content-Type: text/plain

Hello world!
```

The `listener` line creates a listener on port 3000 and the 0.0.0.0 address
means that we will not bind our service to a specific IP address but 
respond to requests on all network interfaces. Finally, the `axum::serve` 
call starts our web service and takes the routing configuration from 
the `app` variable set up earlier.

Notice the two `unwrap()` calls at the end of those lines: this is a rather 
sloppy error handling. Both the listener and axum may return error, but for 
now we simply allow the application to panic in that case. You will be able 
to test this easily if you start the application twice parallelly: 
the second one will fail to bind to port 3000 because it is already 
occupied by the first instance. We will learn more sophisticated ways

The `await` keyword is also important: this is the way to run an async method 
to completion, and both `TcpListener::bind` and `axum::serve` 
are async methods.

To make the above code compile, we have to add two `use` statements 
at the top of the `main.rs` file:

```rust
use axum::Router;
use axum::routing::get;
```

Now you can build the application with `cargo build` from the root directory 
of the project and run `./target/debug/hello_main` to start the application.

To test the application, we will use the `curl` binary (but you can open
http://127.0.0.1:3000/ in a browser too). I prefer to use `curl` because 
it will nicely display the full HTTP request and response:

```bash
$ curl -v http://127.0.0.1:3000/

*   Trying 127.0.0.1:3000...
* Connected to 127.0.0.1 (127.0.0.1) port 3000 (#0)
> GET / HTTP/1.1
> Host: 127.0.0.1:3000
> User-Agent: curl/7.81.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< content-type: text/plain; charset=utf-8
< content-length: 13
< date: Sat, 27 Jan 2024 11:10:34 GMT
< 
* Connection #0 to host 127.0.0.1 left intact
Hello, world!
```

As you can see, this response is in plain text, and I promised a JSON response.
Enhance our handler a little to return JSON! We will need the `serde` 
and `serde_json` crates for this. The `serde` crate makes it possible to 
serialize Rust structs into various formats and `serde_json` adds support 
for the JSON format specifically.

Add these dependencies to `hello_main/Cargo.toml`:

```toml
[dependencies]
axum = "0.7.4"
tokio = { version = "1.35.1", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

Now in `main.rs` we can create our response structure:

```rust
#[derive(Serialize)]
struct Response {
    message: &'static str,
}
```

The `Serialize` derive macro provides the serialization capabilities 
for our struct. We can create a new handler method with that:

```rust
async fn hello_json() -> (StatusCode, Json<Response>) {
    let response = Response {
        message: "Hello, world!",
    };
    
    (StatusCode::OK, Json(response))
}
```

This method returns a tuple with two items: the first one will be an HTTP 
status code, the second one will be something to be formatted as JSON. In 
the function body we build a `response` struct with the message `Hello, 
world!` and return that as a JSON, paired with a HTTP/200 OK
status code. A few use statements to add to our `main.rs`:

```rust
use axum::http::StatusCode;
use axum::{Json, Router};
use axum::routing::get;
use serde::Serialize;
```

Now replace the basic `hello` handler with our enchanced `hello_json` handler:

```rust
async fn main() {
    let app = Router::new()
        .route("/", get(hello_json));
        
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

and build our project. The compiler will show warning about the unused `hello` 
function, but we can ignore that for now. Finally, start the `hello_main` 
binary execute the `curl` command again:

```bash
*   Trying 127.0.0.1:3000...
* Connected to 127.0.0.1 (127.0.0.1) port 3000 (#0)
> GET / HTTP/1.1
> Host: 127.0.0.1:3000
> User-Agent: curl/7.81.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< content-type: application/json
< content-length: 27
< date: Sat, 27 Jan 2024 11:28:00 GMT
< 
* Connection #0 to host 127.0.0.1 left intact
{"message":"Hello, world!"}
```

Voila, now our little web service returned a properly formatted JSON response 
with the `Content-Type` header set to `application/json`.

Our first, miniature web service is complete with this, now we can start to 
explore the crates used here in a little more detail: learn the basics of 
serialization and deserialization, a learn a bit about async programming and 
get to know the capabilities of the `axum` crate.


