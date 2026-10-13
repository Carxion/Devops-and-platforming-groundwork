# Changelog

Content corrections and notable changes to the guide. Dates are when the change was merged.

## Unreleased

- Added copy-ready templates in `templates/` (stakeholder map, first-conversation questions, findings register, ADR, weekly status).
- Added a phase-ordered checklist view and a tracker-importable CSV in `checklists/`, generated from the README.
- Added contribution guidelines, issue and pull request templates, and CI for Markdown lint, spelling, links, and generated-file freshness.
- Added Terraform reference stacks in `terraform/` for AWS and Azure: state bootstrap, GitHub OIDC, networking, container web app, Kubernetes, and serverless API. Each has offline tests, and CI runs fmt, validate, tests, tflint, and checkov.
- Added an operations guide to `terraform/README.md`: setup, adopting the stacks into a program repository, CI and drift-detection workflows, day-2 operations, and best practices. The `github-oidc` stacks gained `plan_additional_subjects` for drift detection.
- Added Kubernetes reference manifests in `kubernetes/`: a namespace baseline (Pod Security restricted, default-deny network policy, quota, limits), a web app, a worker, and a scheduled job, with dev and per-cloud prod overlays, identity components for EKS and AKS, best practices, and CI for schema and policy checks.
- Added `aws/` and `azure/`: command-line operations guides for identity, networking, compute and containers, storage and data, logging and monitoring, security and incident response, and cost, plus CloudFormation (AWS) and Bicep (Azure) templates for IAM, governance, and baseline security. CI checks every `aws` and `az` command and flag in the docs against the real CLIs, and lints and scans the templates.
- Added `terraform/OPERATIONS.md`: everyday Terraform commands, reading plans, state inspection and recovery, locks, and symptom-by-symptom troubleshooting for the reference stacks.
- Added `kubernetes/OPERATIONS.md`: administration and troubleshooting commands for the sample apps on EKS and AKS, including symptom-by-symptom diagnosis.
- Fixed: the EKS stack now turns on network policy enforcement in the VPC CNI. Before, NetworkPolicy objects were accepted but not enforced.
- The guide is now sector-neutral: contract, authorization, and compliance items use general terms (customer contract, compliance status, security and compliance leads, ISO/IEC 27001 and SOC 2) instead of public-sector terminology. Appendix B is now "Restricted-network environments". Every checklist item is kept.
- Added `GLOSSARY.md`: definitions of software engineering, architecture and domain-driven design, APIs, source control, CI/CD, IaC, Kubernetes, cloud, networking, identity, security, observability, data, cost, and delivery terms, plus a table of equivalent AWS and Azure services.
- Added `api-testing/`: an OpenAPI 3.1 contract for the serverless item API, a standard-library reference server, Postman (Newman), Schemathesis, k6 (smoke, load, stress, spike), and Locust tests with an Azure Load Testing configuration, guides for testing on AWS and Azure, and CI that runs every test against the reference server.
- Fixed in both serverless stacks, found by the new contract tests: item IDs are now validated, bodies over 256 KiB are rejected with 413, and the AWS handler rejects an empty PUT body and returns the key as `id` (it returned `pk`), matching the Azure stack.
- Added `observability/`: principles (signals, RED and USE, OpenTelemetry, SLOs, alerting, cost), a Prometheus guide, a Grafana 101, SLO recording rules and multiwindow burn-rate alerts with promtool unit tests, two Grafana dashboards, a Docker Compose lab that CI starts and checks end to end, and guides and templates for CloudWatch (alarms and dashboard) and Azure Monitor (availability test and log search alerts).
- Added `bash/`: Bash 101 for RHEL and Ubuntu (basics, text processing, regular expressions with a tested pattern library, writing and scheduling scripts, RHEL and Ubuntu side by side, administration and troubleshooting, complex commands broken down), and a script library for server setup (baseline, admin user, SSH hardening, firewall, automatic updates, Docker or Podman) and operations (health report, log summaries, backups, retries). CI lints the scripts, runs Bats tests, and applies the baseline twice in Ubuntu 22.04 and 24.04, Rocky Linux 9, and AlmaLinux 9 containers.
- Added `docker/`: Docker 101 (basics, Dockerfiles, Compose, networking and storage, complex commands, security, Podman and RHEL with Quadlet, troubleshooting), two example images, a Compose example that runs the api-testing smoke test, and audit and cleanup scripts. CI lints, builds, scans, and runs them. Dependabot now proposes base image updates.
- Fixed: the api-testing reference server now handles SIGTERM, so it stops cleanly in a container instead of being killed after the stop timeout.
- Added `ROADMAP.md`: current coverage, and planned areas in three phases, starting with GitLab CI and Jenkins pipelines, Git, Ansible, Helm and GitOps, and secrets management.
- Added a Linux and the shell section to the glossary, and container terms for Podman, Quadlet, OCI, and rootless containers.
- Section 9 phase labels are now headings, so they appear in the document outline and can be linked.

## 2026-09-25

- Initial release.
