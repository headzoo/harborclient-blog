---
layout: post
title: "How to test REST APIs with Postman"
date: 2026-06-23 21:00:00 +0000
categories: rest-api testing
---

Postman is one of the fastest ways to explore and validate a REST API without writing a full client. You can send requests, inspect responses, and repeat the same checks across environments — all from a single workspace.

This guide walks through a practical workflow for testing REST APIs with Postman, from your first request to a small reusable test suite.

## Why use Postman for REST APIs

REST APIs are tested by sending HTTP requests and verifying the responses. Postman gives you a visual interface for that work, which makes it easy to:

- Try endpoints before frontend or integration code exists
- Share example requests with teammates
- Save headers, auth tokens, and base URLs in one place
- Automate basic response checks with test scripts

For quick manual testing and lightweight automation, Postman is often enough on its own.

## Create your first request

Start with a simple `GET` request:

1. Open Postman and create a new request.
2. Set the method to `GET`.
3. Enter the URL, for example `https://jsonplaceholder.typicode.com/posts/1`.
4. Click **Send**.

You should see a `200 OK` response with a JSON body. That is the basic loop for every REST test: build a request, send it, inspect the result.

## Set method, URL, headers, and body

Most REST APIs use a small set of HTTP methods:

| Method | Typical use |
|--------|-------------|
| `GET` | Read a resource |
| `POST` | Create a resource |
| `PUT` / `PATCH` | Update a resource |
| `DELETE` | Remove a resource |

For each request, configure the parts that matter:

- **URL** — include path parameters, such as `/users/42`
- **Query params** — add filters or pagination, such as `?page=2&limit=10`
- **Headers** — set `Content-Type: application/json` for JSON bodies, and `Accept: application/json` when needed
- **Body** — use raw JSON for `POST` and `PUT` requests

Example JSON body for creating a post:

```json
{
  "title": "Test post",
  "body": "Created from Postman",
  "userId": 1
}
```

Send the request and confirm the API returns the expected status code and payload shape.

## Inspect the response

After each request, check three things:

1. **Status code** — `200`, `201`, `204`, `400`, `401`, and `404` all mean different things
2. **Headers** — look for `Content-Type`, rate-limit headers, and auth-related values
3. **Body** — verify fields, types, and error messages

Postman shows all of this in the response panel. For JSON responses, use the **Pretty** view to scan the structure quickly.

A healthy test usually answers questions like:

- Did the request succeed?
- Did the response include the fields I expected?
- Did the API return a useful error when I sent bad input?

## Use environments and variables

Hard-coding URLs and tokens in every request gets old fast. Postman environments solve that.

Create an environment with variables such as:

- `baseUrl` — `https://api.example.com/v1`
- `accessToken` — your bearer token or API key

Then reference them in requests:

```
{% raw %}{{baseUrl}}{% endraw %}/users
```

And in headers:

```
Authorization: Bearer {% raw %}{{accessToken}}{% endraw %}
```

Switch environments to move between local, staging, and production without rewriting requests. That alone saves a lot of time on real projects.

## Add test scripts

Postman can run JavaScript after each response. This turns a manual check into a repeatable assertion.

Example test script:

```javascript
pm.test("Status code is 200", function () {
  pm.response.to.have.status(200);
});

pm.test("Response is JSON", function () {
  pm.response.to.be.json;
});

pm.test("Post has an id", function () {
  const json = pm.response.json();
  pm.expect(json).to.have.property("id");
});
```

Use the **Test Results** tab to see what passed or failed. Even a few small tests are enough to catch regressions when an endpoint changes.

## Organize requests into collections

As your API grows, group related requests into a **Collection**. A good layout might look like:

- `Users`
  - List users
  - Get user by id
  - Create user
- `Posts`
  - List posts
  - Create post

Collections make it easier to:

- Run the same set of requests in order
- Share API examples with your team
- Export documentation from saved requests

If you are testing auth flows, put login and token refresh requests at the top of the collection so other requests can reuse the token.

## A simple testing checklist

Before you call an endpoint done, run through this list:

- [ ] Correct HTTP method and URL
- [ ] Required headers and auth configured
- [ ] Valid request body for create/update operations
- [ ] Expected success status code
- [ ] Response schema matches the contract
- [ ] Error cases return clear status codes and messages
- [ ] Variables used for base URL, tokens, and IDs
- [ ] Test scripts cover the most important assertions

## Closing thoughts

Postman is not a replacement for full integration tests in your application, but it is an excellent tool for exploring APIs, validating contracts, and building a shared set of working examples.

Start with one endpoint, add variables for anything repeated, then layer in test scripts as the API stabilizes. That progression keeps testing lightweight while still giving you confidence that your REST API behaves the way you expect.
