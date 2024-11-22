+++
title = "Resiliency"
description = ""
date = 2021-05-01T18:20:00+00:00
updated = 2021-05-01T18:20:00+00:00
draft = false
weight = 1080
sort_by = "weight"
template = "docs/page.html"
slug = "resiliency"

[extra]
lead = ""
toc = true
top = false
+++

Resiliency means that your software can adapt to changes in the environment 
and continue to function correctly when the traffic increases or something
goes wrong.

The main components of resiliency are: security, availability, observability,
scalability, and testability.

Security means that your software is protected from unauthorized access and
malicious attacks. It can maintain its integrity and protects the 
confidentiality and  integrity of the data flowing through it.

Availability means that your software is always up and
running or at least tries to minimize downtime. Hardware failures, network
issues, and other problems can cause downtime, but your software should
be able to recover from these issues and continue to function correctly.

Observability means that you can monitor and debug your software
in real-time. You can measure its load and performance, detect issues
and troubleshoot them quickly.

Scalability means that your software can handle increased
traffic flexibly. You can add more resources to your software to
handle more users and requests easily. Your software should scale 
horizontally, this way you can simply add more nodes running your 
software to handle more traffic.

Testability means that you can test your software to ensure that
it works correctly. You can write unit tests, integration tests, and
end-to-end tests to verify that your software behaves as expected.


## Security

The first part of security is the integrity of the software itself.
With Rust, we are in good hands, as Rust is designed to prevent
many classes of typical security vulnerabilities like buffer overflows.
We still have to be careful with a lot of things though, like handling and
verifying user input, protecting databases from SQL injections, preventing XSS 
attacks and so on.

The second part of security is the protection of the data flowing
through the software. You should encrypt the data in transit and at rest.
You should also authenticate the users and services accessing your software
properly and maintain a least-privilege principle when authorizing access
to resources and data.

## Availability

The usual way to ensure availability is to run your software on multiple
nodes and use a load balancer to distribute the traffic between them.
This way, if one node fails, the other nodes can take over and continue
to serve the requests. This is easy to do with stateless services, but it
gets more complicated with stateful things like databases and file storage.
You have to ensure proper replication and failover mechanisms to keep
the data consistent and available.

## Observability

To achieve observability, you have to instrument your software for
logging, metrics and tracing. You should log all the important events
and errors in your software, measure the performance and load of your
software and trace the requests through your software to detect bottlenecks
and issues. You can use tools like Prometheus and the Grafana stack to
store these data. OpenTelemetry is a common standard for tracing: you can 
collect your telemetry data using the tokio tracing
library, export it via the OTLP protocol to an OpenTelemetry collector and the 
collector can forward it to various metrics and tracing backends.

## Scalability

To achieve scalability, you have to design your software to be
stateless and horizontally scalable. You should use a load balancer
to distribute the traffic between multiple nodes running your software.
When dealing with databases and file storage, you have multiple choices.
You can rest on the shoulders of giants and use managed services like
Amazon RDS Aurora and S3. You can use distributed databases like TiKV
and distributed filesystems like Ceph. You can also use application-based
sharding, where you partition the data based on some criteria and distribute
it among multiple database nodes or clusters yourself.

## Testability

Rust has good support for testing. You can write unit tests and integration
tests with the built-in testing framework. You can
also create benchmarks to measure the performance of your software. But it
is always your responsibility to design your software to be easily testable.
Software with hardcoded dependencies and tightly coupled components
is hard to test, so you should design your software with inversion
of control and dependency injection in mind.

