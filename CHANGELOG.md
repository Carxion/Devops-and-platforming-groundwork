# Changelog

Content corrections and notable changes to the guide. Dates are when the change was merged.

## Unreleased

- Added `architect/`: considerations for DevOps and platform architects (thinking like an architect, cloud foundations and landing zones, reliability and disaster recovery, security, delivery and IaC, observability and operations, cost, portability and multi-cloud), each linked to the tested implementations in `devops/`, with templates for architecture reviews, decision matrices, and quality attribute requirements. Added architecture terms to the glossary.
- Added tech lead guides: a worked example taking a fictional program through all 90 days with every deliverable filled in, design reviews and RFCs, migrations and cutovers, and working with product and leadership.
- Added manager guides: performance and promotions, structuring platform teams (platform as a product, Team Topologies), and budget, vendors, and contracts.
- Added `tech-lead/assessing-an-inherited-system.md`: how to do the section 2 assessment (map the system, follow a change and an incident, read the commit history, interview, inspect code and configuration, score risks, present findings), and templates for the 30/60/90 deliverables: system inventory, metrics baseline, risk register with a scoring scale, RACI, findings report, roadmap, RFC, and cutover runbook.
- Added `manager/00-first-90-days.md`, a W1/30/60/90 checklist for managers taking over a team, and `manager/templates/`: one-on-ones, career ladder, interview scorecard and question bank, onboarding plan, quarterly planning, on-call policy, incident review, and team charter.
- Reorganized by audience: the checklist, its generated views, and the templates moved to `tech-lead/`; Terraform, Kubernetes, AWS, Azure, observability, Bash, and Docker to `devops/`; API testing to `software/`. Every link, CI workflow, and Dependabot path follows the move. The root README is now an index of the repository, with starting points by role.
- Added `manager/`: starter guides for managing DevOps, platform, and SRE teams (running the team, hiring and onboarding, planning and metrics, on-call and team health, stakeholders and communication).
- Fixed: the glossary described the four original DORA metrics; it now lists the five current ones. The OpenAPI spec and image labels now match the repository's CC BY 4.0 license.
- Renamed the project to DevOps and Platforming Groundwork. The checklist itself is unchanged.
- Added copy-ready templates in `tech-lead/templates/` (stakeholder map, first-conversation questions, findings register, ADR, weekly status).
- Added a phase-ordered checklist view and a tracker-importable CSV in `tech-lead/checklists/`, generated from the README.
- Added contribution guidelines, issue and pull request templates, and CI for Markdown lint, spelling, links, and generated-file freshness.
- Added Terraform reference stacks in `devops/terraform/` for AWS and Azure: state bootstrap, GitHub OIDC, networking, container web app, Kubernetes, and serverless API. Each has offline tests, and CI runs fmt, validate, tests, tflint, and checkov.
- Added an operations guide to `devops/terraform/README.md`: setup, adopting the stacks into a program repository, CI and drift-detection workflows, day-2 operations, and best practices. The `github-oidc` stacks gained `plan_additional_subjects` for drift detection.
- Added Kubernetes reference manifests in `devops/kubernetes/`: a namespace baseline (Pod Security restricted, default-deny network policy, quota, limits), a web app, a worker, and a scheduled job, with dev and per-cloud prod overlays, identity components for EKS and AKS, best practices, and CI for schema and policy checks.
- Added `devops/aws/` and `devops/azure/`: command-line operations guides for identity, networking, compute and containers, storage and data, logging and monitoring, security and incident response, and cost, plus CloudFormation (AWS) and Bicep (Azure) templates for IAM, governance, and baseline security. CI checks every `aws` and `az` command and flag in the docs against the real CLIs, and lints and scans the templates.
- Added `devops/terraform/OPERATIONS.md`: everyday Terraform commands, reading plans, state inspection and recovery, locks, and symptom-by-symptom troubleshooting for the reference stacks.
- Added `devops/kubernetes/OPERATIONS.md`: administration and troubleshooting commands for the sample apps on EKS and AKS, including symptom-by-symptom diagnosis.
- Fixed: the EKS stack now turns on network policy enforcement in the VPC CNI. Before, NetworkPolicy objects were accepted but not enforced.
- The guide is now sector-neutral: contract, authorization, and compliance items use general terms (customer contract, compliance status, security and compliance leads, ISO/IEC 27001 and SOC 2) instead of public-sector terminology. Appendix B is now "Restricted-network environments". Every checklist item is kept.
- Added `GLOSSARY.md`: definitions of software engineering, architecture and domain-driven design, APIs, source control, CI/CD, IaC, Kubernetes, cloud, networking, identity, security, observability, data, cost, and delivery terms, plus a table of equivalent AWS and Azure services.
- Added `software/api-testing/`: an OpenAPI 3.1 contract for the serverless item API, a standard-library reference server, Postman (Newman), Schemathesis, k6 (smoke, load, stress, spike), and Locust tests with an Azure Load Testing configuration, guides for testing on AWS and Azure, and CI that runs every test against the reference server.
- Fixed in both serverless stacks, found by the new contract tests: item IDs are now validated, bodies over 256 KiB are rejected with 413, and the AWS handler rejects an empty PUT body and returns the key as `id` (it returned `pk`), matching the Azure stack.
- Added `devops/observability/`: principles (signals, RED and USE, OpenTelemetry, SLOs, alerting, cost), a Prometheus guide, a Grafana 101, SLO recording rules and multiwindow burn-rate alerts with promtool unit tests, two Grafana dashboards, a Docker Compose lab that CI starts and checks end to end, and guides and templates for CloudWatch (alarms and dashboard) and Azure Monitor (availability test and log search alerts).
- Added `devops/bash/`: Bash 101 for RHEL and Ubuntu (basics, text processing, regular expressions with a tested pattern library, writing and scheduling scripts, RHEL and Ubuntu side by side, administration and troubleshooting, complex commands broken down), and a script library for server setup (baseline, admin user, SSH hardening, firewall, automatic updates, Docker or Podman) and operations (health report, log summaries, backups, retries). CI lints the scripts, runs Bats tests, and applies the baseline twice in Ubuntu 22.04 and 24.04, Rocky Linux 9, and AlmaLinux 9 containers.
- Added `devops/docker/`: Docker 101 (basics, Dockerfiles, Compose, networking and storage, complex commands, security, Podman and RHEL with Quadlet, troubleshooting), two example images, a Compose example that runs the api-testing smoke test, and audit and cleanup scripts. CI lints, builds, scans, and runs them. Dependabot now proposes base image updates.
- Fixed: the api-testing reference server now handles SIGTERM, so it stops cleanly in a container instead of being killed after the stop timeout.
- Added `ROADMAP.md`: current coverage, and planned areas in three phases, starting with GitLab CI and Jenkins pipelines, Git, Ansible, Helm and GitOps, and secrets management.
- Added a Linux and the shell section to the glossary, and container terms for Podman, Quadlet, OCI, and rootless containers.
- Section 9 phase labels are now headings, so they appear in the document outline and can be linked.

## 2026-09-25

- Initial release.
