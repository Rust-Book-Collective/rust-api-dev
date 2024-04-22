+++
title = "Preface"
description = ""
date = 2021-05-01T18:20:00+00:00
updated = 2021-05-01T18:20:00+00:00
draft = false
weight = 1002
sort_by = "weight"
template = "docs/page.html"

[extra]
lead = ""
toc = true
top = false
+++

If you you are Rust a developer, have a basic knowledge of the language 
and want to expand your knowledge to build resilient REST API services, 
this book is for you. Even if you have experience with API development, 
you may find useful ideas here. The book can be valuable for experienced 
API developers too, who consider switching to Rust from other languages.

You need to have a basic knowledge of the Rust language, the compiler, 
the crate ecosystem. Read the official Rust book if you have not read it yet! 
You do not have to be familiar with async programming, we will explain that shortly.

You will learn the basics of REST APIs, followed by the ecosystem and 
usual system architecture around a typical REST API. We will explain 
how to make your API secure, scalable and observable, so you can move 
it to production confidently. We will also show you how to implement 
automated testing, continuous integration and delivery. We will provide 
examples for cloud deployment scenarios too.

We try to give you a solid theoretical foundation first, explaining
what makes a good API and what makes it resilient. Then show you how 
to achieve those goals step-by-step, fulfilling one requirement at a time.

Readers will learn how to build a simple asynchronous REST API server
based on axum and tokio.rs. Then we will add persistence to SQL and 
NoSQL databases, JWT and OAuth authentication, authorization, tracing
to log files or through OpenTelemetry, collecting metrics, implementing
caching, request throttling.

By the end of the book you will be able to build solid, well designed 
REST API services and deploy it on your own to cloud providers.

