+++
title = "Application structure"
description = ""
date = 2021-05-01T18:20:00+00:00
updated = 2021-05-01T18:20:00+00:00
draft = false
weight = 1040
sort_by = "weight"
template = "docs/page.html"
slug = "application-structure"

[extra]
lead = ""
toc = true
top = false
+++

In this chapter you will learn how to create a flexible
application architecture. This architecture will provide
a solid base for the chapters ahead of us. You will learn
how to read environment variables, configuration files into
a single unified application configuration. You will also
learn how to add different CLI commands to your application
to make simple tasks like running migrations easier.

## Structure for CLI commands

First we will tackle command line argument parsing, we will use the
`clap` crate for that. You will learn how to create different
subcommands for your CLI application and how to add parameters to them.

We will start from a layout similar to the structure of the `hello_world`
application, but the crate will be called `cli_application` this time.
Create the `Cargo.toml` file for the workspace:

```toml
[workspace]
resolver = "2"

members = [
  "cli_application"
]
```

and initialize the application crate:

```
$ cargo new cli_application
```

In `cli_application/Cargo.toml` add the `clap` crate to the list of
dependencies:

```toml
[package]
name = "cli_application"
version = "0.1.0"
edition = "2021"

[dependencies]
clap = "4"
anyhow = "1"
```

I also added `anyhow` because we will use it for error handling.

Run `cargo build` to ensure that the dependencies are downloaded and
build correctly.

To create a new subcommand with `clap` you have to do two things:

- add the subcommand to the clap configuration
- handle the different commands according to command-line parameters

We could add these code snippets simply to `main.rs` but that way 
the `main.rs` would become bloated really quickly.

I prefer to put these things into a dedicated `commands` rust module.

Let's go to our `cli_application/src` folder and create a new 
`commands` directory:

```bash
$ cd cli_application/src
$ mkdir commands
$ cd commands
```

In the commands directory create a new `mod.rs` file, 
and add two methods: one to configure the command and 
one to handle the CLI arguments:

```rust
use clap::{ArgMatches, Command};

pub fn configure(command: Command) -> Command {
    command.subcommand(Command::new("hello").about("Hello World!"))
}

pub fn handle(matches: &ArgMatches) -> anyhow::Result<()> {
    if let Some((cmd, _matches)) = matches.subcommand() {
        match cmd {
            "hello" => { println!("Hello world!"); },
            &_ => {}
        }
    }

    Ok(())
}
```

The `configure` method simply takes an existing `Command` configuration 
and adds a new `hello` subcommand to it.

The `handle` method takes the argument matches returned by clap and checks 
whether our `hello` subcommand was called. 
If that was the case, it prints `Hello world!` to the console.

Notice the return type `anyhow::Result<()>`: the handle method returns 
nothing by default, but it can return an error result is something goes wrong.

Now to use this code from `main.rs` we have to change it a little:

```rust
mod commands;

use clap::Command;

pub fn main() -> anyhow::Result<()> {

    let mut command = Command::new("Sample CLI application");
    command = commands::configure(command);
    
    let matches = command.get_matches();
    commands::handle(&matches)?;

    Ok(())
}
```

First, we have to add the `mod commands` declaration at the top to 
integrate our new module into the codebase.

In the main method we have to make the command instance mutable, 
because the `commands::configure` method creates a new version of it.

The `get_matches()` method does the heavy lifting: parses the command
line arguments for us.

After calling `command.get_matches()` we also call `commands::handle` 
to handle all the subcommands we configured.

Notice the question mark at the end of the `commands::handle` call: 
when the method returns an error result, the execution of `main` 
will be interrupted here and the `main` method returns an error too.

One more trick: it's usually useful to arrange the crate to 
contain both a `lib.rs` and a `main.rs` file. It will contain 
both a library and a binary at the same time. 
This can make testing, benchmarking easier later.

To do so, add a `lib.rs` file to the `src` directory and move the 
`mod commands` declaration from `main.rs`:

```rust
pub mod commands;
```

We have to make it public, so `main.rs` can use it later. 
Now change the `main.rs` file too:

```rust
use clap::{Arg, Command};
use cli_application::commands;

pub fn main() -> anyhow::Result<()> {
  ...
}
```

The name of the lib module is equivalent to the name of our crate: 
`cli_application`, so to import the `commands` module we add 
`use cli_application::commands` to `main.rs`.

Now make things a little more complicated: add more subcommands. 
To do this, I will split the `commands` module into submodules. 
Add a new `hello.rs` file to the commands folder and move the 
`hello` subcommand configuration and handler there:

```rust
use clap::{ArgMatches, Command};

pub const COMMAND_NAME: &str = "hello";

pub fn configure() -> Command {
    Command::new(COMMAND_NAME).about("Hello World!")
}

pub fn handle(_matches: &ArgMatches) -> anyhow::Result<()> {
    println!("Hello World!");

    Ok(())
}
```

I changed the `configure()` method a little, so it only returns a new 
`Command` and does not configure and existing one. Also, I moved the
`hello` string into a constant, because we will use it in multiple
locations.

Now change `commands/mod.rs` to use the new `hello` submodule:

```rust
mod hello;

use clap::{ArgMatches, Command};

pub fn configure(command: Command) -> Command {
    command
        .subcommand(hello::configure())
        .arg_required_else_help(true)
}

pub fn handle(matches: &ArgMatches) -> anyhow::Result<()> {
    if let Some((cmd, matches)) = matches.subcommand() {
        match cmd {
            hello::COMMAND_NAME => hello::handle(matches)?,
            &_ => {}
        }
    }

    Ok(())
}
```

The `configure` method adds the new `Command` returned by `hello::configure()`
as a subcommand to the main clap configuration.
Another small change: set the `arg_required_else_help` flag to `true`, so
whenever you call your application without any arguments, it will display
a short description of the available subcommands.

The `handle` method simply dispatches the processing to the `handle` method 
of the `hello` module if the specified subcommand was `hello`. 
Notice the question mark: errors are returned immediately.

Now add one more command: the `serve` command will run our webserver later. 
Create a new file called `commands/serve.rs`:

```rust
use clap::{ArgMatches, Command};

pub const COMMAND_NAME: &str = "serve";

pub fn configure() -> Command {
    Command::new(COMMAND_NAME).about("Start HTTP server")
}

pub fn handle(_matches: &ArgMatches) -> anyhow::Result<()> {
 
    println!("TBD: start the webserver on port ??? ");

    Ok(())
}
```

and modify `commands/mod.s` to use the subcommand from `serve.rs` too:

```rust
mod hello;
mod serve;

use clap::{ArgMatches, Command};

pub fn configure(command: Command) -> Command {
    command
        .subcommand(hello::configure())
        .subcommand(serve::configure())
        .arg_required_else_help(true)
}

pub fn handle(matches: &ArgMatches) -> anyhow::Result<()> {
    if let Some((cmd, matches)) = matches.subcommand() {
        match cmd {
            hello::COMMAND_NAME => hello::handle(matches)?,
            serve::COMMAND_NAME => serve::handle(matches)?,
            &_ => {}
        }
    }

    Ok(())
}
```

Do you see the pattern? If you need more subcommands you can simply add 
more submodules and call them in the `configure` and `handle` methods.

Build our project again using `cargo build` and run the resulting
binary from `target/debug/cli_application`. Whenever you call it
without additional arguments, it will simply display a help message:

```bash
$ ./target/debug/cli_application 
Usage: cli_application [COMMAND]

Commands:
  hello  Hello World!
  serve  Start HTTP server
  help   Print this message or the help of the given subcommand(s)

Options:
  -h, --help  Print help
```

But if you specify one of the subcommands, `serve` for example, then
the application will execute it:

```bash
$ ./target/debug/cli_application serve

TBD: start the webserver on port ???

```

You may have noticed that our `serve` method has to start the server
on a specific TCP port, but there is no way to specify is yet. We have
to introduce command line arguments for that. The TCP port is 16-bit
integer value, so we have to parse it into a `u16` variable. Let's
name the parameter `--port` and also add a short version: `-p` to it:

```rust
use clap::{value_parser, Arg, ArgMatches, Command};

pub const COMMAND_NAME: &str = "serve";

pub fn configure() -> Command {
    Command::new(COMMAND_NAME).about("Start HTTP server").arg(
        Arg::new("port")
            .short('p')
            .long("port")
            .value_name("PORT")
            .help("TCP port to listen on")
            .default_value("8080")
            .value_parser(value_parser!(u16)),
    )
}
```

We use the `.long()` method to specify the full parameter name and 
`.short()` to specify the single character short version. We also
have to define a placeholder to be displayed in the help message,
this is `.value_name()`. The `.help()` message describes the parameter. 
When we build and run our CLI application, we can get a detailed help 
message for our subcommand:

```bash
$ ./target/debug/cli_application help serve

Start HTTP server

Usage: cli_application serve [OPTIONS]

Options:
  -p, --port <PORT>  TCP port to listen on [default: 8080]
  -h, --help         Print hel
```

We also specified a default value for the port: 8080 and set the
`value_parser` property, so it will know that the argument must
be parsed into a `u16` value.

Finally, update our handler to use the new argument:

```rust
pub fn handle(matches: &ArgMatches) -> anyhow::Result<()> {
    let port: u16 = *matches.get_one("port").unwrap_or(&8080);

    println!("TBD: start the webserver on port {}", port);

    Ok(())
}
```

The `matches.get_one()` method tries to fetch the argument named `port`.
We use `unwrap_or` to specify a default value for the case when the parsing
runs into and error. The `clap` argument parser displays useful error
messages whenever you try to specify invalid arguments:

```bash
$ ./target/debug/cli_application serve --port notanumber
error: invalid value 'notanumber' for '--port <PORT>': 
    invalid digit found in string

For more information, try '--help'.

$ ./target/debug/cli_application serve --port 100000
error: invalid value '100000' for '--port <PORT>': 100000 is not in 0..=65535

For more information, try '--help'.

$ ./target/debug/cli_application serve --port 
error: a value is required for '--port <PORT>' but none was supplied

For more information, try '--help'.
```

## Command line parameters

TBD: more examples, like alias, required, how to specify and argument
multiple times, etc.

TBD: alternatives style using derive macros.

## Application configuration

Every application needs some configuration. For example: the URL to access a 
backend service or database, the log level, the addresses of telemetry 
data collectors, etc. These configurations can come from many sources:
configuration files, environment variables, .env files, command line arguments,
etc.

The `config` crate provides an easy way to read configuration values from
these sources. Our sample code will start off where we finished the processing
of command line parameters. You can find the sample code for this section in 
the `03-application-structure/application-configuration` folder.

First add our new dependencies to `cli_application/Cargo.toml`:

```toml
[dependencies]
clap = "4"
anyhow = "1"
config = "0.14"
dotenv = "0.15"
serde = { version = "1", features = ["derive"] }
```

We will use the `dotenv` crate to read `.env` files into environment
variables. The `serde` crate will be used to deserialize json format
configuration files.

Next we have to build a structure for our application configuration.
Create a file named `settings.rs` in `cli_application/src` and reference
it from `cli_application/src/lib.rs`:

```rust
pub mod commands;
pub mod settings;
```

Start off with a simple configuration structure: create a `Database` struct
to store database configuration, a `Logging` struct to store logging
configuration and a `Settings` struct that includes both the `Database`
and `Logging` structs. Our `settings.rs` will look like this:

```rust
pub struct Database {
    pub url: String,
}

pub struct Logging {
    pub log_level: String,
}

pub struct Settings {
    pub database: Database,
    pub logging: Logging,
}
```

To be able to deserialize these structs from various formats we have to add 
the `Deserialize` derive macro to the structs. I also add the `Default`
derive macro to be able to instantiate these structs without specifying a 
value for all the fields. The `Debug` macro is also handy, so we can 
easily log the contents of the configuration later.

Now our structs are like this:

```rust
use serde::Deserialize;

#[derive(Debug, Deserialize, Default)]
#[allow(unused)]
pub struct Database {
    pub url: String,
}

#[derive(Debug, Deserialize, Default)]
#[allow(unused)]
pub struct Logging {
    pub log_level: String,
}

#[derive(Debug, Deserialize, Default)]
#[allow(unused)]
pub struct Settings {
    pub database: Database,
    pub logging: Logging,
}
```

I also added the `#allow(unused)` marker, to silence compiler warnings about
unused fields.

There is one more problem with this schema: all the fields are required, so 
you cannot import an empty json for example and use the defaults for all 
configuration options.

There are two possible ways to solve this problem:

- make fields optional with `Option<>`
- or use default values

I usually prefer `Option<>` for basic values like strings, numbers, 
boolean flags. This way we can easily replace missing values 
with defaults later:

```rust
#[derive(Debug, Deserialize, Default)]
#[allow(unused)]
pub struct Database {
    pub url: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[allow(unused)]
pub struct Logging {
    pub log_level: Option<String>
}

...

let log_level = settings.logging.log_level.unwrap_or("info");
```

For structures, I prefer to go with default values, so an empty structure of 
the configuration is always built for us:

```rust
#[derive(Debug, Deserialize, Default)]
#[allow(unused)]
pub struct Settings {
    #[serde(default)]
    pub database: Database,
    #[serde(default)]
    pub logging: Logging,
}
```

The `config` crate can load configuration from both configuration files 
and environment variables. A config file is handy for the bulk of the 
configuration, environment variables are preferable for sensitive values 
like passwords and settings that usually deviate in different environments. 
In a kubernetes-based deployment probably the whole configuration will 
be built from environment variables.

To use both a config file and environment variables, we use a layered 
configuration:

```rust
impl Settings {
    pub fn new(location: &str, env_prefix: &str) -> anyhow::Result<Self> {
        let s = Config::builder()
            .add_source(File::with_name(location))
            .add_source(
                Environment::with_prefix(env_prefix)
                    .separator("__")
                    .prefix_separator("__"),
            .build()?;

        let settings = s.try_deserialize()?;

        Ok(settings)
    }
}
```

First we load a configuration file from `location` then override these 
settings with values found in environment variables.

Assuming an `env_prefix` value of `APP` the environment variable names will 
look like these:

- `APP__DATABASE__URL`
- `APP__LOGGING__LOG_LEVEL`

I also prefer to store the config file location and other parameters 
required to be able to reload the configuration later:

```rust
use config::{Config, Environment, File};

...

#[derive(Debug, Deserialize, Default)]
#[allow(unused)]
pub struct ConfigInfo {
    pub location: Option<String>,
    pub env_prefix: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[allow(unused)]
pub struct Settings {
    #[serde(default)]
    pub config: ConfigInfo,
    #[serde(default)]
    pub database: Database,
    #[serde(default)]
    pub logging: Logging,
}

impl Settings {
    pub fn new(location: &str, env_prefix: &str) -> anyhow::Result<Self> {
        let s = Config::builder()
            .add_source(File::with_name(location))
            .add_source(
                Environment::with_prefix(env_prefix)
                    .separator("__")
                    .prefix_separator("__"),
            )
            .set_override("config.location", location)?
            .set_override("config.env_prefix", env_prefix)?
            .build()?;

        let settings = s.try_deserialize()?;

        Ok(settings)
    }
}
```

We save the `location` and `env_prefix` values into `Setttings` with the 
`set_override` calls.

Now to use this structures, we have to extend our `main.rs`. 
First, add a new command line argument so users can specify the
configuration file location, but assume `config.json` when not specified
otherwise:

```rust
use clap::{Arg, Command};
use cli_application::commands;

fn main() -> anyhow::Result<()> {
    let mut command = Command::new("Sample CLI application")
            .arg(
                Arg::new("config")
                    .short('c')
                    .long("config")
                    .help("Configuration file location")
                    .default_value("config.json"),
            );

    command = commands::configure(command);

    let matches = command.get_matches();

    let config_location = matches
        .get_one::<String>("config")
        .map(|s| s.as_str())
        .unwrap_or("");
    
    commands::handle(&matches)?;

    Ok(())
}
```

The `arg` configuration should be familiar from the previous section.
We read the `config_location` with the `matches::get_one::<String>` call.
We have to specify the type, because the compiler cannot guess it in this
case. An alternative syntax is:

```rust
    let config_location = matches
        .get_one("config")
        .map(|s: &String| s.as_str())
        .unwrap_or("");
```

Here the type specified on closure parameter `s` gives the compiler enough
information, so we do not have to specify it on the `get_one()` call.

Now we can load our configuration in `main.rs`:

```rust
let settings = settings::Settings::new(config_location, "APP")?;

println!(
    "db url: {}",
    settings
        .database
        .url
        .unwrap_or("missing database url".to_string())
);

println!(
    "log level: {}",
    settings.logging.log_level.unwrap_or("info".to_string())
);
```

We used the `println!` to print some configuration values.
As you can see, we substituted the missing values with `unwrap_or()`.

Now go to the project root directory, compile and test our code:

```bash
$ cargo build
...
$ ./target/debug/cli_application hello
Error: configuration file "config.json" not found
```

Well, our `config.json` is missing. Create a simple one:

```json
{
   "database": {
       "url": "pgsql://"
   }
}
```

And run again:

```bash
$ ./target/debug/cli_application hello
db url: pgsql://
log level: info
Hello World!
```

We can see the db url configured in `config.json` and the default log level. 
Now define an environment variable to override the db url:

```bash
$ export APP__DATABASE__URL="mysql://"
$ ./target/debug/cli_application hello
db url: mysql://
log level: info
Hello World!
```

If we add dotenv parsing to the top of the `main()` function:

```rust
fn main() -> anyhow::Result<()> {
    dotenv().ok();

    ...
}
```

Then we can load a `.env` file too. Let's create a simple `.env` file:

```
APP__LOGGING__LOG_LEVEL="warn"
```

And run our application again:

```bash
$ ./target/debug/cli_application 
db url: mysql://
log level: warn
Hello World!
```

As you can see it loaded the `.env` file too.

Currently, you must use a `config.json` to be able to start the application.
You can make it optional and depend entirely on environment variables.
Modify argument handling in `main.rs` slightly:

```rust
let config_location = matches
    .get_one("config")
    .map(|s: &String| Some(s.as_str()))
    .unwrap_or(None);
```

Now our `config_location` is an optional. Modify `settings.rs` too:

```rust
impl Settings {
    pub fn new(location: Option<&str>, env_prefix: &str) -> anyhow::Result<Self> {
        let mut builder = Config::builder();
        if let Some(location) = location {
            builder = builder.add_source(File::with_name(location));
        }

        let s = builder
            .add_source(
                Environment::with_prefix(env_prefix)
                    .separator("__")
                    .prefix_separator("__"),
            )
            .set_override("config.location", location)?
            .set_override("config.env_prefix", env_prefix)?
            .build()?;

        ...
    }
}
```

You have to remove the default value from the `command` configuration as well!
Now you can delete `config.json` and the application still works as expected:

```bash
$ ./target/debug/cli_application hello
db url: mysql://
log level: info
Hello World!
```

The configuration file format is not limited to JSON, the `config` crate
can use TOML, YAML, INI and others too.

### Subcommands

One more thing to do: we have to pass the settings to all the subcommands,
so they can use them. Currently, we call the `commands` module this way
in `main.rs`:

```rust
commands::handle(&matches)?;
```

Let's change it to also pass the settings:

```rust
commands::handle(&matches, &settings)?;
```

We can also remove the two `println!` macros from `main.rs`, they are
not needed anymore.

We have to modify the `handle` method `commands/mod.rs` to accept the new
parameter and pass it to all the subcommands:

```rust
pub fn handle(
    matches: &ArgMatches, 
    settings: &Settings
) -> anyhow::Result<()> {        
    if let Some((cmd, matches)) = matches.subcommand() {
        match cmd {
            hello::COMMAND_NAME => hello::handle(matches, settings)?,
            serve::COMMAND_NAME => serve::handle(matches, settings)?,
            &_ => {}
        }
    }

    Ok(())
}
```

Finally, extend the `handle` methods in both `hello.rs` and `serve.rs`
to accept the `settings` parameter (prefixed with underscore, since we
do not use it now).

```rust
pub fn handle(
    _matches: &ArgMatches, 
    _settings: &Settings
) -> anyhow::Result<()> {        
    ...
}
```

Do not forget to add the `use crate::settings::Settings` statement to
the top of all these command modules.

## Loading configuration

TBD @nikola?

## Different environments

Your application will most probably run in different target environments.
First in your own development environment, then in some staging or
demo environment, finally in one or more production environments.

You can prepare your application for all these target environments in
multiple ways. Some approaches hardcode the list of possible environments
in the application or commit specific configuration files for each
target environment into the source code repository. These approaches
can work when you have only a limited number of fixed environments, but
we do not consider this a good practice.

The best approach is to make configuration and code completely independent
of each other. Of course, you can include a sample configuration with your 
application to showcase all the possible settings, but the actual
configuration should be provided by your target environment.

Assume, for example, that you deliver your application as a docker
container image, this is quite common nowadays. The image itself should
not contain any configuration. You can take two approaches: read all
configuration parameters from environment variables or use a mix of
configuration files and environment variables. When you use environment
variables only, those can be specified in a `docker-compose.yml` file
or in a kubernetes pod definition. When you have to use configuration
files, those can be mounted as volumes on specific locations. Both 
docker-compose and kubernetes allows you to assign these volumes to 
the containers. If you target kubernetes, you can create helm charts
for your application too, these can serve as blueprints for deployment.
We will show you some examples in later chapters.

When you deliver your application as a single binary, it will be started
most probably by some kind of service management: by an init script,
as a systemd unit or by supervisord for example. These solutions can specify 
environment variables and command line arguments for your application
as well. When the application is deployed as a single binary, DevOps
engineers will usually use some kind of configuration management system
(like Ansible, Puppet, Chef, etc.) to automate the deployment of the
application, these can generate the required configuration files from
templates and a predefined set of variables.

