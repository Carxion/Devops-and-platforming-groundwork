# DevOps

[← DevOps and Platforming Groundwork](../README.md)

Hands-on material for building and running cloud platforms: infrastructure as code, Kubernetes, the AWS and Azure command lines, observability, Linux, and containers. Everything here is tested in CI: the Terraform stacks plan with mocked providers, the manifests validate, every `aws` and `az` command is checked against the real CLIs, the observability lab starts and fires its alerts, and the scripts run in real RHEL-family and Ubuntu containers.

| Folder | What it is | Start with |
|---|---|---|
| [bash/](bash/README.md) | Bash 101 for RHEL and Ubuntu: basics, text processing, regex, scripting, administration, complex commands broken down, and a tested script library for setting up servers | [Basics](bash/01-basics.md) |
| [docker/](docker/README.md) | Docker 101: images, Dockerfiles, Compose, networking, security, Podman on RHEL, troubleshooting, with example images | [Basics](docker/01-basics.md) |
| [terraform/](terraform/README.md) | Reference AWS and Azure stacks: state, CI identity, networking, container apps, Kubernetes, serverless. Plus setup, operations, and troubleshooting. | [README](terraform/README.md), then [OPERATIONS](terraform/OPERATIONS.md) |
| [kubernetes/](kubernetes/README.md) | Hardened sample apps (web app, worker, scheduled job), a namespace baseline, and administration and troubleshooting commands | [README](kubernetes/README.md), then [OPERATIONS](kubernetes/OPERATIONS.md) |
| [aws/](aws/README.md) | AWS CLI guides for identity, networking, compute, data, logging, security and incident response, and cost; CloudFormation templates for IAM and baseline security | [Setup](aws/README.md#setup) |
| [azure/](azure/README.md) | The same for Azure, with Bicep templates | [Setup](azure/README.md#setup) |
| [observability/](observability/README.md) | What to measure and alert on, a Prometheus guide, a Grafana 101, SLO rules with tests, a Docker Compose lab, and CloudWatch and Azure Monitor alerting | [The local lab](observability/local-stack/README.md) |

## A suggested path

1. **The shell and containers:** [bash](bash/README.md), then [docker](docker/README.md). Everything else assumes them.
2. **Your cloud:** the [AWS](aws/README.md) or [Azure](azure/README.md) setup and identity guides.
3. **Infrastructure as code:** [terraform](terraform/README.md), deploying one stack to a sandbox.
4. **Running workloads:** [kubernetes](kubernetes/README.md) on the cluster that stack built.
5. **Seeing what's happening:** [observability](observability/README.md), starting with the lab.

The [tech lead checklist](../tech-lead/README.md) sections 3 to 8 point into these folders for each "find out" item, and [software/api-testing](../software/api-testing/README.md) tests the serverless APIs the Terraform stacks deploy.
