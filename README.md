# Tensile

**Find the traffic where your API breaks, and why.**

Tensile is a desktop app for testing APIs. Send requests the way you would in Postman, then put them under load: simulate many users at once, watch response times and errors live, and find the exact request rate where your server stops coping. It also tests MCP servers, the tool servers that AI assistants connect to.

Everything runs on your own computer. There is no account, no cloud service, and your requests and results never leave your machine.

**[Download Tensile](https://shubhamsingh047.github.io/tensile/)** for macOS (Apple chip and Intel), Windows and Linux.

![Response times while Tensile raises the traffic step by step and finds the breaking point](assets/shots/breaking-point-chart.png)

## Download

### macOS (Apple chip and Intel)

Open **Terminal** (press Command-Space, type Terminal, press Return), paste this and press Return:

```sh
curl -fsSL https://raw.githubusercontent.com/ShubhamSingh047/tensile/main/install.sh | sh
```

It picks the right version for your Mac, installs Tensile into Applications and the `tensile` command-line tool into `~/.local/bin`, then opens Tensile, with no security warning. Add `-s -- --no-open` after `sh` to install without opening it. It needs nothing extra (no Homebrew), verifies every file against the release's `SHA256SUMS`, and never asks for your password. [Read the script](install.sh) first if you like. The same command works on Linux.

Prefer a file? [Apple chip .zip](https://github.com/ShubhamSingh047/tensile/releases/latest/download/Tensile-macos-arm64.zip) (M1 and newer) or [Intel .zip](https://github.com/ShubhamSingh047/tensile/releases/latest/download/Tensile-macos-x64.zip). macOS warns the first time you open a downloaded copy; see [First launch](#first-launch).

### Windows and Linux

| System | File |
| --- | --- |
| Windows 10 and 11, 64-bit | [Tensile-windows-x64-setup.exe](https://github.com/ShubhamSingh047/tensile/releases/latest/download/Tensile-windows-x64-setup.exe) |
| Linux, 64-bit (AppImage) | [Tensile-linux-x64.AppImage](https://github.com/ShubhamSingh047/tensile/releases/latest/download/Tensile-linux-x64.AppImage) |

## What you can do with it

### Send and check requests

![A request answered with status 200 and three passing tests](assets/shots/request.png)

- Build requests with any method, headers and body, and see the status, headers, formatted JSON and a timing breakdown: DNS, connect, TLS, server wait and download.
- Add **tests** to a request (status code, body text, JSON fields, headers, response time) that turn green or red every time you send it.
- Organise requests into **collections**, stored as plain JSON files in a folder you choose, so they fit in git.
- **Import an OpenAPI or Swagger spec** (JSON or YAML, file or URL) to get every endpoint as a ready-made request.
- Use **environments** and variables such as `{{baseUrl}}` and `{{token}}`. Secret values are kept in your operating system's keychain, never in files.

### Load test

![Load test settings: virtual users, duration and load profile](assets/shots/setup.png)

![A finished load test, explained in plain words](assets/shots/result.png)

- Choose how many **virtual users**, for how long, and a **load profile**: fixed, ramp up, spike or peak.
- Set **pass criteria** such as `p95 < 500 ms` or `error rate < 1%`. They go green or red live while the test runs.
- Read the results in plain words: requests per second, typical and worst-case response times (p50, p90, p95, p99), errors kept separate from unexpected status codes, and every number explained.
- **Run a whole collection** as a user journey: each virtual user sends the requests in order, and results break down per request.
- **Data runs:** send one request once per value in a list you provide (for example, a set of tricky inputs) and get a pass/fail table.

### Find the breaking point

![Breaking point between 420 and 430 requests per second, explained in plain words](assets/shots/breaking-point.png)

Tensile raises the traffic step by step until your limits are crossed, then narrows in. You get a clear answer such as "your API copes with between 180 and 190 requests per second", a table of what each step did, and the reason it failed: too slow, or too many errors.

### Test MCP servers

![MCP security checks flagging a hidden instruction in a tool description](assets/shots/mcp.png)

Connect to an MCP server over HTTP or as a local command, list its tools and call them. Tensile checks tool descriptions for hidden instructions aimed at the AI, looks for exposed credentials, and can load-test tool calls. A built-in practice server lets you try it with one click.

### Workflows

![A workflow on the canvas: sign in, create an order, then get it on success or back off on failure](assets/shots/workflow.png)

Chain requests into a user journey, such as sign in, open the dashboard, place an order. Each step can save a value (a token, an order number) for the steps after it, and steps can run in order, at the same time, or only on success or failure of another. Run a workflow once to check it, or stress-test the whole journey. Workflows are short `.flow.yaml` files you can edit by hand and keep in git.

**Try one:** download a sample, then in Tensile click **Import** under Workflows in the sidebar and press **Run once**. They use free public practice APIs, so please don't stress-test them. Needs Tensile 0.2.0 or newer.

| Sample | What it does |
| --- | --- |
| [shop-sign-in-to-cart.flow.yaml](samples/shop-sign-in-to-cart.flow.yaml) | Sign in, profile, search products and carts in parallel, add to cart ([DummyJSON](https://dummyjson.com)) |
| [blog-create-read-update-delete.json](samples/blog-create-read-update-delete.json) (JSON; also as [.flow.yaml](samples/blog-create-read-update-delete.flow.yaml)) | Find an author, read posts and comments, then create, edit and delete a post ([JSONPlaceholder](https://jsonplaceholder.typicode.com)) |
| [retry-after-failed-sign-in.flow.yaml](samples/retry-after-failed-sign-in.flow.yaml) | A sign-in that fails on purpose, an "on failure" wait, then a successful retry ([DummyJSON](https://dummyjson.com)) |

### History and comparison

Every request and load test is saved. Pick two runs to compare every metric side by side, with changes marked better, worse or unchanged.

## Command-line tool

The `tensile` command runs the same engine from a terminal or a CI pipeline.

```sh
# 50 connections for 30 seconds
tensile bench http://localhost:3000/users -c 50 -d 30s

# Find the highest rate that keeps p95 under 250 ms and errors under 1%
tensile capacity http://localhost:3000/users --p95 250ms --max-error-rate 1%

# CI gate: fail unless 500 requests/s is sustainable, and save the evidence
tensile capacity https://staging.example.com/api --authorized \
  --p95 250ms --require 500 --json capacity.json
```

Install only the command-line tool with `curl -fsSL https://raw.githubusercontent.com/ShubhamSingh047/tensile/main/install.sh | sh -s -- --cli`. On Windows, download [tensile-windows-x64.zip](https://github.com/ShubhamSingh047/tensile/releases/latest/download/tensile-windows-x64.zip) and put `tensile.exe` on your `PATH`.

## First launch

Tensile is not code-signed yet, so your system asks once before opening it.

- **macOS:** installing with the Terminal command above shows no warning. If you downloaded the `.zip` instead, macOS says it "could not verify Tensile is free of malware" the first time. That is expected for an app that is not yet notarized by Apple:
  1. Drag Tensile into Applications and double-click it. When the warning appears, click **Done** (not Move to Bin).
  2. Open **System Settings, Privacy & Security**, scroll to "Tensile was blocked" and click **Open Anyway**.
  3. Enter your Mac password and click **Open Anyway** again. From then on it opens normally.

  Or, after dragging it into Applications, run `xattr -dr com.apple.quarantine /Applications/Tensile.app` once in Terminal.
- **Windows:** if you see "Windows protected your PC", click **More info**, then **Run anyway**.
- **Linux:** make the file executable with `chmod +x Tensile-linux-x64.AppImage`, then run it.

## Use it responsibly

Only load-test systems you own or have permission to test. Heavy traffic can slow down or take down a real service. Tensile asks you to confirm before it sends load to any address other than your own computer, and you can stop any run at any time.

## Updating and uninstalling

Download the latest version from the [download page](https://shubhamsingh047.github.io/tensile/) and replace the old app, or run the install command again. To remove everything the install script added:

```sh
curl -fsSL https://raw.githubusercontent.com/ShubhamSingh047/tensile/main/install.sh | sh -s -- --uninstall
```

## Support

Found a bug or have an idea? [Open an issue](https://github.com/ShubhamSingh047/tensile/issues). Every release and its checksums are listed on the [releases page](https://github.com/ShubhamSingh047/tensile/releases).

---

Screenshots use the app's demo data, so the numbers are examples. This repository hosts the download page and release files for Tensile.
