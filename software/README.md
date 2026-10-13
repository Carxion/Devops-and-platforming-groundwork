# Software

[← DevOps and Platforming Groundwork](../README.md)

Material for engineers building and testing the software that runs on the platform: API contracts, testing at every layer, and how tests fit into delivery pipelines.

| Folder | What it is | Start with |
|---|---|---|
| [api-testing/](api-testing/README.md) | An OpenAPI contract for the serverless item API the Terraform stacks deploy, with a reference server and Postman, Schemathesis, k6, and Locust tests that run locally or against AWS and Azure | [Quick start](api-testing/README.md#quick-start-local) |

The [glossary](../GLOSSARY.md#software-engineering) covers software engineering, architecture, and API terms. Building and shipping containers is in [devops/docker](../devops/docker/README.md), and observability for applications (instrumenting with OpenTelemetry, SLOs) is in [devops/observability](../devops/observability/README.md).

More is planned for this folder, including Git and code review, Python for operations, and CI/CD pipelines in GitLab CI and Jenkins. See the [roadmap](../ROADMAP.md).
