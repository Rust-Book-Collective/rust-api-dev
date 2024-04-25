+++
title = "Introduction"
description = ""
date = 2021-05-01T18:20:00+00:00
updated = 2021-05-01T18:20:00+00:00
draft = false
weight = 1010
sort_by = "weight"
template = "docs/page.html"
slug = "introduction"

[extra]
lead = ""
toc = true
top = false
+++


Why would you even consider writing a web service in Rust? As the wise saying
goes: use the right tool for the job. But is Rust the right one? Most 
probably yes, but as always: it depends. If your requirements include 
security, efficiency, and low latency, go no further, you have found the 
right tool.

The Rust language has been purposely created with great emphasis on security
and performance. Low-level languages like C are less restrictive and give broad
freedom to the programmer. Hence, solutions based on these languages are 
notoriously prone to human errors.  

High-level languages like C# and Java provide guardrails and tend to be more
secure, but you have to pay the price when it comes to performance and 
memory management: garbage collectors and large language runtimes do not 
come for free. Rust provides the best of both worlds: efficiency comparable 
to low-level languages and even better security than high-level languages.

Binaries built from Rust are small compared to a C# or Java binary and start up
much faster. Both, especially the latter, can be important in serverless runtime
environments like AWS Lambda, GCP Cloud, or Azure Functions. Serverless 
services are billed based on execution time and used resources. A smaller, 
more resource-efficient binary that starts up faster can significantly lower 
serverless computing costs. This efficiency benefit urges an increasing 
number of companies to reimplement their web services in Rust to reduce their
cloud computing bills.

APIs built with Rust as a backend-for-fronted (BFF) or middleware layer behave
like a translator and firewall between the frontend and the underlying 
systems. Every layer in such a solution adds complexity and also latency. 
With its efficiency and speed, Rust is quite good at minimizing added 
latency between connected layers.

Rust is a strictly typed language. When building APIs, this comes very handy
when you deserialize user input into structs: you instantly get a strong 
validation of the data. That's not always the case with scripting languages 
like PHP or Javascript. Also, it is quite simple to generate JSON
and similar schemas from Rust code that the consumers of your APIs can use to
generate their data models.

As you can see, Rust has the features that make it a great choice if you are
building an API. Before we dive deep into Rust programming specifics, let's 
rehearse some API basics!

## What is an API

The acronym API stands for Application Programming Interface. When an 
application provides a set of services for other applications, there must be 
a contract that defines a stable, documented way to access the services of 
the application. This contract is the API or API definition.

There are many forms of APIs, but in the scope of this book we will always 
assume that the service is provided over the internet, using a protocol 
based on the TCP/IP stack.

Many of these API styles are based on the HTTP protocol, the most popular 
ones being REST, gRPC and GraphQL. But there are other ones like WebSocket 
and AMQP based directly on the TCP protocol.

The bulk of this book is about the REST API style, but we will touch on 
GraphQL, gRPC, WebSocket and AMQP too.

## The REST API style

The acronym REST stands for Representational State Transfer, and it is based 
on the dissertation by [Roy T. Fielding](https://ics.uci.edu/~fielding/): [Architectural Styles and
the Design of Network-based Software Architectures](https://ics.uci.edu/~fielding/pubs/dissertation/top.htm)

REST is a client-server architecture where there are two communicating 
parties: the client, responsible for the presentation of the data, and the 
server, which is responsible for data management tasks like producing, 
processing, transforming, and storage. The two parties communicate over a 
network, most commonly the internet, by interchanging requests and 
responses.

The REST style assumes the communication itself is stateless. Each request 
is independent, and carries all information necessary for the request to be 
processed. The server stores no contextual information related to the 
requests hence the style is stateless. The advantages of stateless 
operation shine in a distributed context: when we have many servers 
processing requests concurrently, each request may be safely processed by 
any of the servers since the requests contain all 
information needed for processing, and they do not need to be pinned to the 
same server throughout consecutive calls.

The REST requests that query data and do not intend to change them are great 
candidates for caching to improve performance.

REST APIs primarily work on resources. A resource is an entity, something 
that has properties, relations to other entities, and operations can be 
executed on them. Resources usually appear as nouns in specifications. They 
are the "things" your application is all about. A resource may be a 
photo, a book, a person, or an abstract thing like the current time.

Every resource must have an identifier in REST. This is how we identify and 
reference them during the operations clients request and the server executes.
Operations can be classified as type read or write, depending on whether the 
operation intends to alter the entity or fetch information.

The properties of a resource may be represented in various ways, and the 
communicating parties must agree on a common representation format. Possible 
representation formats include JSON (Javascript Object Notation), XML 
(Extensible Markup Language), or simple binary forms (like image content). 
Most of the time, we will use the JSON representation.

REST requires the request and response messages to be self-descriptive: the
clients and servers should be able to interpret them without any additional
information.

The REST style assumes that a client may not always communicate directly
with the server. There may be various connectors, components on the way
between them, such as caches, proxies, gateways. A response may be returned
directly from the browser cache for example or provided by a caching proxy.
There may be various gateways: protocol translators (like TLS termination
for the HTTPs protocol), load balancers, api gateways, etc. 
on the route from the client to the server.

Hypermedia as the engine of application state (HATEOAS) is an often neglected
aspect of REST: the responses should include hints for the clients on the
possible operations on the resources. Something like this:

```json
{
    "book": {
        "id": 12,
        "title": "The Title of the Book",
        "links": {
            "buy": "/book/12/buy",
            "rent": "/book/12/rent"
        }
    }
}
```

The links section details the available operations on the book and the
specific URLs for them.

## RESTful APIs - REST applied to web services

When we talk about web services, we usually mean services provided over the 
HTTP protocol. HTTP is a text-based client-server protocol, at least up to 
version 1.1 (the new HTTP 2 version is a bit more complicated). A RESTful 
API is an HTTP-based web service adhering to the principles of REST.

### Basics of the HTTP protocol

To understand how RESTful API data travel over HTTP, we need a deeper 
understanding of the protocol itself. 

Every HTTP request is sent to a unique URL (uniform resource identifier) like
`http://sample.api.com/books`. The URL has three mandatory parts: the scheme, 
the domain, and the path. The scheme identifies the communication protocol, 
`http` in our case. The domain part is a DNS domain name that identifies the 
target system. Finally, the path (`/books`) identifies the exact resource we 
want to interact with.

A sample request would look like as follows:

```
GET /books HTTP/1.0
Host: sample.api.com
Accept: application/json

```

The first word: `GET` is the so-called HTTP verb, which expresses our
intention with the request: we want to get something from the server. Next 
comes `/books`, which is the path of the resource we want to interact with, 
in this case, get information about. 
Finally, the HTTP protocol version: `HTTP/1.0` closes the line. The 
following lines contain HTTP headers. Headers are key-value pairs, 
adding more metadata to the request. The `Host` header identifies the domain 
we want to communicate with. 
This header is not used for domain to IP resolution; rather it carries 
information for the target system about the requested service since the 
server may host multiple services on the same IP address. The server can 
route the traffic to the appropriate service based on the `Host:` 
header.

The `Accept:` header indicates the content MIME type we want the server to 
use for the response. The `application/json` content type means we want to 
receive JSON-formatted responses. Alternatives 
include `text/plain`, which is simple text, or `application/xml`, which is 
XML. You can read more about MIME types on [MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_Types)

The list of headers is followed by an empty line.

A sample response to our request would look like:

```
HTTP/1.0 200 OK
Content-Type: application/json

{
  "books": [
    {
        "id": 1,
        "title": "Book one"
    },
    {
        "id": 2,
        "title": "Book two"
    }
  ]
}
```

In the first line, the `HTTP/1.0` string indicates the HTTP protocol version.
The `200` is the status code. These codes indicate whether the request was 
successful or we ran into an error. 
Status codes in the range 200..299 mean success. It is followed by a short 
textual description of the status: `OK` means all went well and the 
operation was successful. 
This line is followed by HTTP response headers, key-value pairs similar to 
the request headers. Here the `Content-Type` header indicates what format 
the server used for generating the response and how the receiver should 
interpret the response body. The `application/json` content type means it 
should be parsed as JSON.

The list of headers is followed by an empty line. After that empty line 
comes the response body, formatted as indicated by the `Content-Type` header,
in our example in JSON.

### HTTP verbs

The most common HTTP verbs are `GET`, `POST`, `PUT`, `PATCH` and `DELETE`. 
The `GET` verb means we want to get information from the system. 
The `POST` verb means we want to create something new in the system. The 
`PUT` verb means we want to update or overwrite something. The `PATCH` 
verb is similar to `PUT`: it updates something, but while the `PUT` method 
completely overwrites its target, `PATCH` only changes some attributes of it,
not the whole entity. The `DELETE` verb means we want to delete something 
from the server.

The usage of these verbs in RESTful APIs is quite straightforward. Let's see 
an example about books! We want to implement the basic CRUD (create, read, 
update, delete) operations on books.

To create a book, send a `POST` request:

```
POST /books HTTP/1.0
Content-Type: application/json

{
  "title": "Book one"
}
```

To update a book, send a `PUT` request (note that ID of the subject 
book appears in the URL):

```
PUT /books/1 HTTP/1.0
Content-Type: application/json

{
  "title": "Book one fixed"
}
```

To get the list of available books, send a `GET` request to the 
general `books` URL:

```
GET /books HTTP/1.0
Accept: application/json

```

To get information about a specific book, add the ID of the book to the URL:

```
GET /books/1 HTTP/1.0
Accept: application/json

```

Finally, to delete a book, send a `DELETE` request:

```
DELETE /books/1 HTTP/1.0

```

### HTTP response status codes

HTTP response messages come with a status code and a short text message that 
gives clients information about the result of the requested operation. The 
HTTP response status codes are classified into the following groups:

- range 100..199 are informational messages
- range 200..299 means success
- range 300..399 means some kind of redirection
- range 400..499 indicates client-side errors
- range 500..599 indicates server-side errors

A quite exhaustive list of these status codes can be found on [MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)

Some common successful response codes:

- `200 OK`: all went well
- `201 Created`: the POSTed entity has been created successfully
- `204 No Content`: request processed successfully, 
  but there is no content to return

Redirects:

- `301 Moved Permanently`: the URL of the requested resource changed permanently
- `302 Found`: the URL of the requested resources changed temporarily
- `304 Not Modified`: indicates the client can continue to use the cached
  version of a previous response

Client-side errors:

- `400 Bad Request`: the server cannot parse the request
- `401 Unauthorized`: the endpoint requires authentication, and the client
  is not authenticated
- `403 Forbidden`: the client has no sufficient permissions to access the 
  resource
- `404 Not Found`: no resource found at the given URL
- `405 Method Not Allowed`: the given HTTP verb (like DELETE) 
  is not supported on the resource
- `422 Unprocessable Content`: often used to indicate validation errors

Server-side errors:

- `500 Internal Server Error`: generic server-side error status when 
  no other status is applicable
- `501 Not Implemented`: the given HTTP verb is not supported by the server
- `502 Bad Gateway`: an interim proxy or gateway failed to forward the request 
  to the origin server 
- `503 Service Unavailable`: the service is currently unable 
  to process the request
- `504 Gateway Timeout`: the origin server failed to reply in a timely manner

A common mistake in REST implementations is to always return an HTTP 200 OK
response status code and contradict that with an error message in the 
response body.
Always use the HTTP status codes to express the outcome of the operation! 
Of course, you can include a detailed description, more error codes in the 
response body, but always in accordance with the HTTP status code. 

