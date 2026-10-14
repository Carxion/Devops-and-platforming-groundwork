# API testing

A worked example of testing an HTTP API at every layer, from the contract down to load and security. Everything targets one small API, the item store that the [AWS serverless-api](../../devops/terraform/aws/serverless-api/) and [Azure functions-api](../../devops/terraform/azure/functions-api/) stacks deploy. A local reference server lets every test run on a laptop or in CI without a cloud account.

It supports [section 5](../../tech-lead/README.md#5-continuous-integration) and [section 6](../../tech-lead/README.md#6-continuous-delivery-and-deployment) of the guide: which tests run, where in the pipeline, and what blocks a release.

> **Status.** The spec lints clean, and the Postman, Schemathesis, k6 smoke, and short Locust tests pass against the local server. CI doesn't run them; the [quick start](#quick-start-local) runs them all locally. Running them against a deployed stack is documented in the [AWS](aws.md) and [Azure](azure.md) guides but isn't run by this project.

| Path | What it is |
|---|---|
| [openapi/items-api.yaml](openapi/items-api.yaml) | The contract (OpenAPI 3.1). Every test and both cloud implementations follow it. |
| [.spectral.yaml](.spectral.yaml) | Lint rules for the spec |
| [local-server/items_server.py](local-server/items_server.py) | In-memory implementation of the contract, standard-library Python |
| [postman/](postman/) | Functional tests as a Postman collection, run headless with Newman |
| [k6/](k6/) | Smoke and load tests, with SLOs as pass/fail thresholds |
| [locust/](locust/) | The same load test in Locust, with an Azure Load Testing configuration |
| [aws.md](aws.md) | Testing the API on AWS: endpoint, tokens, direct Lambda invokes, logs, throttling, canaries |
| [azure.md](azure.md) | Testing the API on Azure: endpoint, tokens, logs in Application Insights, availability tests, Azure Load Testing |

---

## Layers of API testing

| Layer | Catches | Here | Runs |
|---|---|---|---|
| Spec lint | An unclear or inconsistent contract: missing descriptions, undefined tags, bad references | Spectral | Every pull request |
| Unit | Logic errors in handlers, with dependencies faked | (in each service's own repository) | Every pull request |
| Contract and fuzz | Responses that don't match the spec; crashes and 5xx errors on unusual input; accepting input the spec forbids | Schemathesis | Every pull request, against a local or ephemeral instance |
| Functional | Wrong behavior in real workflows: create, read, replace, delete, error cases | Postman and Newman | Every pull request, and after each deployment |
| Smoke | A deployment that's up but broken | k6 `smoke.js` | Right after every deployment, as a gate before shifting traffic |
| Load, stress, spike | Latency and errors under expected, rising, and sudden load; where the limits are | k6 `load.js` | Before major releases and on a schedule, in a production-sized environment |
| Security | Injection, broken authentication and authorization, data exposure ([OWASP API Security Top 10](https://owasp.org/API-Security/)) | OWASP ZAP API scan | On a schedule, and before exposing a new API |
| Synthetic monitoring | The API breaking in production between deployments | CloudWatch Synthetics, Application Insights availability tests | Continuously, every few minutes |

Fast, cheap tests run often and early; slow and expensive ones run less often and later. A failure at any layer blocks the change at that point.

## Quick start (local)

Python 3.10 or later, Node.js 20 or later, and [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/).

```sh
cd software/api-testing

# 1. Start the reference server (leave it running in its own terminal)
python local-server/items_server.py --port 8080

# 2. Lint the spec
npx @stoplight/spectral-cli lint openapi/items-api.yaml

# 3. Functional tests
npx newman run postman/items-api.postman_collection.json -e postman/environments/local.postman_environment.json

# 4. Contract and fuzz tests, generated from the spec
pipx install schemathesis        # or: pip install schemathesis
schemathesis run openapi/items-api.yaml --url http://127.0.0.1:8080 --checks all

# 5. Smoke test
k6 run k6/smoke.js
```

To point any of these at a deployed stack, take the base URL from Terraform:

```sh
BASE_URL=$(terraform -chdir=devops/terraform/aws/serverless-api output -raw api_endpoint)     # AWS
BASE_URL=$(terraform -chdir=devops/terraform/azure/functions-api output -raw api_base_url)    # Azure
```

Then pass it as `--url "$BASE_URL"` (Schemathesis), `-e BASE_URL="$BASE_URL"` (k6), or `--env-var baseUrl="$BASE_URL"` (Newman, with `-e postman/environments/deployed.postman_environment.json`). If the stack has authentication turned on, see the [AWS](aws.md#get-a-token) or [Azure](azure.md#get-a-token) guide for getting a token.

---

## The contract

[openapi/items-api.yaml](openapi/items-api.yaml) is the single description of the API. The spec, not either implementation, defines correct behavior, and both cloud stacks follow it: same paths, same status codes, same error bodies, same ID rules.

- **Write the spec first** for new APIs, and review it like code. Consumers can build against it, and against a mock, before the implementation exists.
- **Lint it.** [Spectral](https://github.com/stoplightio/spectral) with the built-in `spectral:oas` rules catches structural problems; add your organization's style rules (naming, pagination, error format) to `.spectral.yaml`.
- **Generate from it:** documentation, client SDKs, mock servers, and tests. A spec that nothing depends on drifts from the real API within weeks.
- **Detect breaking changes in pull requests** by diffing the spec against the main branch, with tools such as [oasdiff](https://github.com/oasdiff/oasdiff). Removing a field, adding a required one, or narrowing a type breaks clients.

## Functional tests (Postman and Newman)

[The collection](postman/items-api.postman_collection.json) walks an item through its whole life: create, read, replace (and confirm PUT replaces rather than merges), reject bad input, delete twice (confirming DELETE is idempotent), and confirm it's gone. Each run uses a fresh ID, so runs never collide and can run in parallel against a shared environment.

- **Environments** hold the base URL, token, and latency budget. `local` and `deployed` are provided; keep real tokens out of them and pass them on the command line or from the CI secret store: `--env-var token="$TOKEN"`.
- **Newman** runs the collection headless. Add `--reporters cli,junit --reporter-junit-export results.xml` so the CI system shows each assertion.
- **Tests clean up after themselves.** A test that leaves data behind slowly corrupts the environment it runs in.

## Contract and fuzz tests (Schemathesis)

[Schemathesis](https://schemathesis.readthedocs.io/) reads the spec and generates hundreds of requests from it: valid ones built from the schemas and examples, edge cases at every boundary (empty strings, maximum lengths, unusual characters), and invalid ones the API must reject. Every response is checked against the spec. With `--checks all` it flags:

- 5xx responses, which mean the server crashed on some input
- Responses whose status code, content type, headers, or body the spec doesn't document
- Invalid input that was accepted (a 2xx response) instead of rejected
- Operations that fail when chained through the spec's `links` (here: PUT, then GET and DELETE on the returned ID)

It finds bugs that example-based tests miss, because nobody writes a test for an ID of 128 dots. Run it against a local or short-lived environment, since it sends a lot of unusual data. To test only some operations, use `--include-operation-id getItem`.

**Consumer-driven contract testing** is the other half. Tools such as [Pact](https://docs.pact.io/) record what each consumer actually uses and verify the provider against those expectations, so a provider knows which changes would break which consumer. It's worth adding once several teams depend on one API.

## Load testing (k6)

[k6](https://grafana.com/docs/k6/latest/) scripts are JavaScript, so they live in the repository and run in CI like any other test. [smoke.js](k6/smoke.js) is one user and a few requests; [load.js](k6/load.js) drives a set request rate with three profiles:

```sh
k6 run -e BASE_URL="$BASE_URL" -e RATE=20 -e DURATION=10m k6/load.js                     # load: expected peak, held
k6 run -e BASE_URL="$BASE_URL" -e RATE=20 -e DURATION=5m -e PROFILE=stress k6/load.js    # stress: 2x then 4x, to find the limit
k6 run -e BASE_URL="$BASE_URL" -e RATE=20 -e PROFILE=spike k6/load.js                    # spike: straight to 4x
```

- **Thresholds are the SLOs.** k6 exits non-zero when a threshold fails, so the pipeline fails too. Take the numbers from the service's real objectives ([section 8](../../tech-lead/README.md#8-observability-and-operations)), not from what the test happened to measure last time.
- **Arrival rate, not users.** The `ramping-arrival-rate` executor keeps sending at the target rate even when the API slows down, the way real traffic does. A fixed number of looping users quietly sends less traffic as latency rises, which hides the problem.
- **Know the limits before you start.** The AWS stack throttles at `throttle_rate_limit` requests per second, and Lambda and Functions have concurrency limits. A test that hits them measures the limit, not the API. Raise them in the test environment, or test against them on purpose.
- **Test a production-sized environment, not production,** unless the test is planned with the service's owners. Tell anyone who shares the environment, its alerts will fire.
- **Watch the server side while the test runs.** k6 sees latency and errors; the dashboards in [devops/observability/](../../devops/observability/) show why. A load test without server-side metrics tells you that something is slow but not what.
- **Cold starts.** Serverless functions are slow on their first requests after scaling out. The ramp-up stage absorbs them; a spike test measures them.

## Security testing (OWASP ZAP)

The [ZAP API scan](https://www.zaproxy.org/docs/docker/api-scan/) imports the OpenAPI spec and actively attacks every operation: injection, path traversal, information leaks, and missing security headers.

```sh
# Linux; with Docker Desktop, use host.docker.internal instead of 127.0.0.1 and drop --network host
docker run --rm --network host -v "$(pwd):/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py -t /zap/wrk/openapi/items-api.yaml -f openapi -O http://127.0.0.1:8080 -r zap-report.html
```

- **Active scans send attack payloads.** Run them only against environments you own and have permission to test, never against production without a plan agreed with its owners.
- Check the cloud provider's rules first: [AWS penetration testing policy](https://aws.amazon.com/security/penetration-testing/) and the [Microsoft Cloud penetration testing rules of engagement](https://www.microsoft.com/en-us/msrc/pentest-rules-of-engagement). Load tests at denial-of-service scale have their own rules.
- Scanners miss authorization flaws, the top risks in the [OWASP API Security Top 10](https://owasp.org/API-Security/). Write explicit tests for them: user A can't read user B's items, a read-only token can't write, an expired token is rejected.

---

## In the pipeline

The [quick start](#quick-start-local) runs the whole suite locally: lint the spec, start the local server, then Newman, Schemathesis, the k6 smoke test, and a short Locust run.

In a delivery pipeline, the same tests split across stages:

1. **Pull request:** spec lint and breaking-change check, unit tests, then Schemathesis and Newman against an ephemeral instance (the service in a container, or a short-lived environment).
2. **After deploying to each environment:** k6 smoke test, then Newman. A failure stops the promotion, or rolls back.
3. **Scheduled:** load tests against staging (weekly, or before major releases) and ZAP scans.
4. **Always:** synthetic monitors in production ([AWS](aws.md#synthetic-monitoring-with-cloudwatch-synthetics), [Azure](azure.md#synthetic-monitoring-with-availability-tests)).

The same stages in GitLab CI:

```yaml
stages: [verify, deploy, post-deploy]

spec-lint:
  stage: verify
  image: node:22
  script:
    - npx @stoplight/spectral-cli@6 lint software/api-testing/openapi/items-api.yaml --fail-severity warn

contract-and-functional:
  stage: verify
  image: python:3.13
  script:
    - python software/api-testing/local-server/items_server.py --port 8080 &
    - pip install schemathesis
    - schemathesis run software/api-testing/openapi/items-api.yaml --url http://127.0.0.1:8080 --checks all

smoke:
  stage: post-deploy
  image:
    name: grafana/k6:latest   # pin a version in real pipelines
    entrypoint: [""]
  script:
    - k6 run -e BASE_URL="$API_BASE_URL" -e TOKEN="$API_TOKEN" software/api-testing/k6/smoke.js
```

In Jenkins, the same commands go in `sh` steps. Publish Newman's `junit` reporter output with the JUnit plugin; k6 and Schemathesis fail the step through their exit codes.

## Best practices

- **The spec is the source of truth.** Tests, docs, and SDKs come from it, and pull requests that change behavior change the spec in the same commit.
- **Test behavior, not implementation.** API tests send HTTP requests and check HTTP responses, so they keep working when the service is rewritten.
- **Each test creates its own data** with unique IDs, and cleans it up. Never depend on data another test, or a person, created.
- **Test the unhappy paths:** bad input, missing and expired tokens, someone else's resource, not found, too large, too many requests. Most production incidents are in the error handling.
- **Check idempotency and retries** on every operation a client might retry. If a PUT or DELETE can't be safely repeated, clients will eventually corrupt data.
- **Keep secrets out of collections and scripts.** Pass tokens from the CI secret store, use short-lived tokens, and use test identities with only the access the test needs.
- **Make failures readable.** Name checks for what they prove ("PUT replaced the whole item, not merged"), and publish results in a format the CI system displays.
- **Fix or quarantine flaky tests right away.** A test that fails at random trains everyone to ignore red builds.

## Alternatives

| Need | Here | Common alternatives |
|---|---|---|
| Spec lint | Spectral | Redocly CLI, Vacuum |
| Functional | Postman and Newman | Bruno, Insomnia, Hurl, REST Assured (Java), Karate, pytest with httpx |
| Contract and fuzz | Schemathesis | Pact (consumer-driven), Dredd, RESTler |
| Load | k6 | Apache JMeter, Gatling, Locust, Artillery |
| Security | OWASP ZAP | Burp Suite, Nuclei, StackHawk |
| Mock server | local reference server | Prism (from the spec), WireMock, Mockoon |
