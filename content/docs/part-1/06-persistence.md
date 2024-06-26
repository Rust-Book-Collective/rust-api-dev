+++
title = "Persistence"
description = ""
date = 2021-05-01T18:20:00+00:00
updated = 2021-05-01T18:20:00+00:00
draft = false
weight = 1060
sort_by = "weight"
template = "docs/page.html"
slug = "persistence"

[extra]
lead = ""
toc = true
top = false
+++

In the world of web applications, persistence boils down to remembering stuff. 
Unlike your regular computer programs, web applications are stateless by nature. 
This means every interaction with the web server is treated as a fresh start.  
Here's where persistence comes in: it's the magic that allows web applications 
to hold onto information across different sessions.

There are two main types of persistence in web applications: session persistence
and data persistence.

Session persistence focuses on remembering information within a single 
user's browsing session. Imagine you're adding items to an online shopping cart. 
The web application uses session persistence to keep track of the items 
you've added, even if you navigate to different product pages. 
This is commonly achieved using cookies or storing data on the server-side 
for a limited duration.

Data persistence is the harder one - it's about storing data permanently, 
beyond a single user session. This is where databases come into play. 
Web applications can store user information, product details, or any other 
kind of data in a database, ensuring it survives even after the user 
closes their browser or the server restarts.

Different types of data may require different types of databases. The simplest
data to be stored is a binary blob: a chunk of data that we simply store as
is, and we don't have to look regularly into its contents. This is the kind of 
data which can be stored in a file system as a file.
Of course, storing this way is not ideal for scalability, although with a 
shared file system like AWS EFS, it can be done. Much more common is to use 
a dedicated object storage mechanism like AWS S3, which is designed to store 
and serve large amounts of data. We will cover this topic later.

A more common case is to store simple key-value pairs. This is the kind of data
which can be stored in a key-value store like Redis or Memcached. Sessions
are a good example of this kind of data. There are some Rust based solutions
too, like TiKV, which is a distributed key-value store.

The most common case is to store structured data, which can be stored in a
relational database like MySQL, PostgreSQL, or SQLite, or in a NoSQL database
like MongoDB or DynamoDB. 

Relation databases are the most common, they are based on the relational model
of data, which is based on the idea of a table. Each table has a set of columns,
and each row in the table has a value for each column. The columns are defined
when the table is created, and the rows are added and removed as the data
changes. The SQL language is used to interact with the database.

NoSQL databases are a newer type of database, which are designed to be more
scalable and flexible than relational databases. There are many different
types of NoSQL databases, but they all share the idea of storing data in a
way that is not based on the relational model. This means that they can be
more flexible and scalable, but it also means that they can be harder to work
with, because they don't have the same kind of structure that relational
databases do. Common designs are document stores like MongoDB, the key-value
stores we mentioned before, and graph databases like Neo4j or Amazon Neptune.
Graph databases are designed to store and query data that is connected in
complex ways, like social networks or other kinds of networks.
There is another kind, so called wide-column stores, like Cassandra or 
ScyllaDB. They are designed to store and query large amounts of data, 
and they are often used for time-series data, like logs or sensor data.

We have to mention the concept of **ACID**, which is a set of properties that
guarantee that database transactions are processed reliably. ACID is an acronym
for Atomicity, Consistency, Isolation, and Durability. Atomicity means that
transactions are all or nothing, either all the changes are made, or none of
them are. Consistency means that the database is always in a consistent state,
even if a transaction fails. Isolation means that transactions are processed
independently of each other, so that they don't interfere with each other.
Durability means that once a transaction is committed, it is permanent, even
if the database crashes. ACID is a very important concept in database design,
and it is one of the reasons why relational databases are so popular.

NoSQL databases are often designed to be more scalable than relational 
databases, but they often sacrifice some of the ACID properties in order to
achieve that scalability.

Another topic we have to mention is the **CAP** theorem, which states that it is
impossible for a distributed computer system to simultaneously provide all
three of the following guarantees:

- Consistency: Every read receives the most recent write or an error
- Availability: Every request receives a response, without guarantee that it
  contains the most recent write
- Partition tolerance: The system continues to operate despite an arbitrary
  number of messages being dropped (or delayed) by the network between nodes

In a distributed system, you can only have two of the three. This is a very
important concept in distributed systems design, and it is one of the reasons
why distributed systems are so hard to design and build.

Relational databases are designed primarily to provide consistency. The most
common way of replication in the relational world is to have a primary
database, which is the only one that can accept writes, and one or more
replica databases, which can accept reads. This is called a master-slave
replication. With additional components it is possible to achieve automatic
failover, so that if the primary database fails, one of the replicas can take
over. This is called a high-availability setup.

NoSQL databases offer a variety of trade-offs between consistency and
availability, and they are often designed to be more tolerant of network
partitions. This means that they can provide better availability than
relational databases, but at the cost of consistency. This is why NoSQL
databases are often used in distributed systems, where it is more important to
be able to continue operating in the face of network problems than it is to
have a consistent view of the data. The trade-offs between the C-A-P properties
are sometimes configurable, so you can choose the best setup for your use case.

This chapter will be primarily about data persistence. First we will cover
traditional relational databases. They can be used directly using SQL or
through an ORM (Object-Relational Mapping) library like Diesel or SeaORM.

Then we will cover NoSQL databases, MongoDB primarily. Later we will introduce
SurrealDB, a Rust based NoSQL database. This one can be embedded directly into
your application, and offers a highly flexible data storage layer. It can use
in-memory data storage, local storage based on RocksDB or can connect to a
distributed storage cluster based on TiKV. The data model of SurrealDB is
document based, but it has an SQL-like query language, and it can
be used as a graph database too.

## Adding a database

We will use docker and `docker-compose` to add a database to our project.
We will use MariaDB (which is a fork of MySQL) as our database.
A sample `docker-compose.yml` file is provided in the `05-persistence/sqlx/` 
directory.

```yaml
version: '3'
services:
  db:
    image: mariadb
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: sampledb
      MYSQL_USER: user
      MYSQL_PASSWORD: password
    volumes:
      - data:/var/lib/mysql
    ports:
      - "3306:3306"
volumes:
  data:
```

According to this file, we will have a MariaDB database running in a Docker
container. The database will be named `sampledb`, and it will have a user
named `user` with the password `password`. The database will be accessible
on port 3306.

Let's start up the database using `docker-compose`:

```bash
$ cd 05-persistence/sqlx
$ docker-compose up -d
```

We can check if the database is running using the `docker ps` command:

```bash
$ docker ps
```

We can also check if the database is accessible using the `mysql` command line
client:

```bash
$ mysql -h 127.0.0.1 -u user -p sampledb
```

When it asks for the password, enter `password`. If everything is set up
correctly, you should see a prompt like this:

```bash
MariaDB [sampledb]>
```

Now create tables for our application. We will use the `mysql` command line
client to do this. The SQL commands are in the `05-persistence/sqlx/schema.sql`:

```SQL
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  status INT NOT NULL DEFAULT 1,
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_login TIMESTAMP,
  UNIQUE (username)
);

CREATE TABLE posts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  author_id INT NOT NULL REFERENCES users(id),
  slug VARCHAR(255) NOT NULL,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  status integer NOT NULL DEFAULT 1,
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE (slug)
);
```

We can execute these commands using the `mysql` command line client:

```bash
$ mysql -h 127.0.0.1 -u user -p sampledb < schema.sql
```

Now we have a database set up and ready to use. We can use the `mysql` command
to verify that the tables have been created:

```bash
$ mysql -h 127.0.0.1 -u user -p sampledb
MariaDB [sampledb]> SHOW TABLES;
```

## Using SQLx

SQLx is a modern SQL client for Rust, which is designed to be easy to use and
efficient. It is designed for asynchronous operation, so it depends on 
executors like Tokio or async-std. We will use it with Tokio.

You can find the sample codes on
[GitHub](https://github.com/Rust-Book-Collective/rust-api-code/tree/main/persistence/sqlx)

First, add the `sqlx` and `sqlx-macros` dependencies to the `Cargo.toml` file:

```toml
[dependencies]
sqlx = { version = "0.7", features = [ "mysql", "runtime-tokio", 
 "tls-rustls", "chrono", "macros" ] }
```

About the features:

- `mysql`: This feature enables support for the MySQL database
- `runtime-tokio`: This feature enables support for the `tokio` runtime
- `tls-rustls`: This feature enables support for the `rustls` TLS library
- `chrono`: This feature enables support for the `chrono` date and time library
- `macros`: This feature enables support for the `sqlx` macros, like `query!`

Run `cargo build` to download and compile the dependencies.

Now we can use the `sqlx` library to connect to the database and execute SQL
queries. We will also need the `sqlx` cli tool, to install it run:

```bash
$ cargo install sqlx-cli
```

To use our database with `sqlx`, we need to create a `DATABASE_URL` environment
variable. This variable should contain the connection string for the database.

For example:

```bash
$ export DATABASE_URL=mysql://user:password@127.0.0.1/sampledb 
```

Now run `cargo sqlx prepare --workspace` from the workspace root directory
to check our implementation and store the database schema information 
for later use.

To actually run our application, we need to export the database URL in 
another environment variable, `APP__DATABASE__URL`:

```rust
$ export APP__DATABASE__URL=mysql://user:password@127.0.0.1/sampledb
```

We already had an `ApplicationState` configuration in `src/commands/serve.rs`:

```rust
let state = Arc::new(ApplicationState::new(settings)?);
```

Now we have to extend this with a database connection:

```rust
let db_url = settings
    .database
    .url
    .clone()
    .expect("Database URL is not set");
let pool = sqlx::MySqlPool::connect(&db_url).await?;

let state = Arc::new(ApplicationState::new(settings, pool)?);
```

We create a new `MySqlPool` and pass it to the `ApplicationState` constructor.
In the constructor, we use the pool to configure a new `UserService` 
implementation, this time based on MySQL:

```rust
pub struct ApplicationState {
    pub settings: ArcSwap<Settings>,
    pub user_service: Arc<MySQLUserService>,
    pub post_service: Arc<InMemoryPostService>,
}

impl ApplicationState {
    pub fn new(settings: &Settings, pool: MySqlPool) -> anyhow::Result<Self> {
        Ok(Self {
            settings: ArcSwap::new(Arc::new((*settings).clone())),
            user_service: Arc::new(MySQLUserService::new(pool)),
            post_service: Arc::new(InMemoryPostService::default()),
        })
    }
}
```

The `MySQLUserService` implementation is in `src/services/user.rs`.
It implements the same `UserService` trait as the `InMemoryUserService`, but
uses `sqlx` to interact with the database. The underlying data model and
the request-response structures are the same. The constructor simply
creates a new instance of the service, storing the database pool:

```rust
pub struct MySQLUserService {
    pub pool: MySqlPool,
}

impl MySQLUserService {
    pub fn new(pool: MySqlPool) -> Self {
        Self { pool }
    }
}
```

Now the trait implementation uses the pool to execute SQL queries. For example,
the `get_user_by_id` method looks like this:

```rust
impl UserService for MySQLUserService {
    async fn get_user_by_id(&self, id: i64) -> anyhow::Result<User> {
        let res = sqlx::query!(
            r#"
            SELECT id, username, password, status, created, updated, last_login
            FROM users
            WHERE id = ?
            "#,
            id
        );

        res.fetch_one(&self.pool)
            .await
            .map(|row| User {
                id: row.id as i64,
                username: row.username,
                password: row.password,
                status: UserStatus::from(row.status),
                created: row.created.unwrap_or_default(),
                updated: row.updated.unwrap_or_default(),
                last_login: row.last_login,
            })
            .map_err(|e| anyhow::anyhow!(e).context(format!("Failed to get user by id: {}", id)))
    }
    ...
}
```

The `sqlx::query!` macro is used to create a new SQL query. The question
marks are placeholders for parameter binding. Here we bind a single parameter,
the `id` variable. The `fetch_one` method is used to execute the query and
retrieve a single row from the result set. The row is then converted into a
`User` struct. If the query fails, an error is returned.

The database stores the `status` enum as an integer, so we have to convert it
using the `From` trait in `src/model.rs`:

```rust
impl From<i32> for UserStatus {
    fn from(value: i32) -> Self {
        match value {
            1 => UserStatus::Active,
            2 => UserStatus::Blocked,
            _ => UserStatus::Active,
        }
    }
}

impl From<UserStatus> for i32 {
    fn from(value: UserStatus) -> Self {
        match value {
            UserStatus::Active => 1,
            UserStatus::Blocked => 2,
        }
    }
}
```

The `create_user` method works similarly:

```rust
async fn create_user(&mut self, req: CreateUserRequest) -> anyhow::Result<User> {
    let query = sqlx::query!(
        r#"
            INSERT INTO users ( username, password, status, created, updated, last_login )
            VALUES ( ?, ?, ?, NOW(), NOW(), NULL )
        "#,
         req.username, req.password, i32::from(req.status));

    let res = query.execute(&self.pool)
        .await?
        .last_insert_id();

    let id: i64 = res.try_into().or_else(|_| anyhow::bail!("Failed to convert user id"))?;

    let user = self.get_user_by_id(id).await?;

    Ok(user)
}
```

We create a new SQL query using the `sqlx::query!` macro, bind the parameters
from the `CreateUserRequest` and execute the query. The `last_insert_id` method
retrieves the ID assigned to the newly created user. We have to convert it
into `i64` because we used this type in the `User` struct (another approach
is to use the `u64` type for id fields).

Finally, we retrieve the newly created record, so we can return it to the
client, including the automatically calculated `created`, `updated` fields.

The `update_user` method is quite similar again:

```rust
async fn update_user(&mut self, id: i64, req: UpdateUserRequest) -> anyhow::Result<User> {
    let query = sqlx::query!(
        r#"
            UPDATE users
            SET username = ?, password = ?, status = ?, updated = NOW(), last_login = ?
            WHERE id = ?
        "#,
        req.username, req.password, i32::from(req.status), req.last_login, id);


    query.execute(&self.pool).await?;

    let user = self.get_user_by_id(id).await?;

    Ok(user)
}
```

The `delete_user` method is even more simple, because we don't have to return
anything:

```rust
async fn delete_user(&mut self, id: i64) -> anyhow::Result<()> {
    let query = sqlx::query!(
        r#"
            DELETE FROM users
            WHERE id = ?
        "#,
        id);

    query.execute(&self.pool).await?;

    Ok(())
}
```

After these modifications you can run `cargo sqlx prepare --workspace` and
`cargo build` again and the application will use the database instead of the
in-memory storage to retrieve and store user data. The login method, for
example, will only accept a username when it is present in the database.

You can implement the `MysqlPostService` in a similar way. Try to do it
yourself, and if you get stuck, you can check the solution in the
code samples.

