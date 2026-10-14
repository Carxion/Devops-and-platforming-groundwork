# Delivery and infrastructure-as-code architecture

[← Architect](README.md)

How code and infrastructure changes reach production determines how fast teams can move and how safely. Delivery architecture covers the pipeline, how artifacts are promoted, how infrastructure code is structured, and how policy is enforced along the way. Done well, it lets many teams deploy independently and often, with less risk per change.

## Pipeline principles

| Principle | Means |
|---|---|
| **Build once, promote the same artifact** | One build produces an immutable, versioned artifact (image by digest); every environment deploys that same artifact with different configuration |
| **Everything through the pipeline** | No manual changes to production; the pipeline is the only path, and its identity the only one with write access |
| **Small, frequent changes** | Smaller changes are easier to review, test, and roll back. DORA's research links deployment frequency with lower change failure rates ([metrics](../manager/03-planning-and-metrics.md#measuring-delivery-the-dora-metrics)) |
| **Fast feedback** | The quick checks (lint, unit tests, security scans) run first, and the pipeline fails fast |
| **Automated gates, not meetings** | Approval rules encoded as checks (tests, scans, policy) where possible; human approval reserved for genuinely high-risk changes |
| **Rollback is designed in** | Every deployment can be undone quickly, and the mechanism is tested |

The tool (GitHub Actions, GitLab CI, Jenkins, Azure Pipelines) matters less than these properties.

## Stages and promotion

A typical path for a service:

```text
commit → build and unit test → scan (code, dependencies, image) → publish artifact (signed)
       → deploy to test → integration and contract tests → deploy to pre-production
       → smoke and load checks → deploy to production (progressively) → verify against SLOs
```

- **Environment promotion** moves the same artifact forward; each stage's checks are the gate to the next ([API testing in the pipeline](../software/api-testing/README.md#in-the-pipeline)).
- **Progressive delivery** in production: canary or blue-green, with automatic rollback when error rates or latency exceed the SLO ([Reliability](03-reliability-and-disaster-recovery.md)).
- **Separate deploy from release** with feature flags, so code can ship dark and be enabled (and disabled) without a deployment.

## Push or pull: GitOps

| Model | How | Strengths | Watch out for |
|---|---|---|---|
| **Push** | The pipeline runs deployment commands against the target | Simple, works for anything | The pipeline needs credentials to production; drift goes unnoticed |
| **Pull (GitOps)** | An agent in the target environment (Argo CD, Flux) syncs it to the state declared in Git | No production credentials in CI; continuous drift correction; Git is the audit trail | Another system to run; secrets and ordering need care |

GitOps suits Kubernetes particularly well. Either way, the declared state lives in Git and changes go through review.

## Infrastructure-as-code structure

The decisions that are hardest to change later:

| Decision | Considerations | Default |
|---|---|---|
| **State boundaries** | Each state file (or stack) is a blast radius: one bad apply affects everything in it, and one lock serializes every change to it | Split by lifecycle and ownership: foundations (network, identity) separate from workloads; one stack per workload per environment ([the reference stacks](../devops/terraform/README.md)) |
| **Modules** | Reuse versus flexibility; versioned modules let consumers upgrade on their own schedule | A small set of opinionated, versioned modules for common patterns; avoid wrapping every resource |
| **Environments** | Directories, workspaces, or separate repositories | Same code, different variables per environment; separate state and credentials per environment |
| **Repository layout** | Monorepo (easier cross-cutting changes) or one per team or component (clearer ownership) | Either, with clear ownership (CODEOWNERS) and pipelines that run only what changed |
| **State storage** | Locking, encryption, access, and recovery of state, which contains secrets | Remote state with locking, encrypted, access limited to the pipeline identity, versioned ([bootstrap stacks](../devops/terraform/README.md)) |
| **Drift** | Manual changes make the code untrue | Scheduled plan runs that alert on drift ([drift detection](../devops/terraform/README.md)); guardrails that discourage console changes |
| **Tool** | Terraform or OpenTofu, CloudFormation, Bicep, Pulumi, Crossplane | One primary tool per estate, chosen for team skills and provider coverage; the cloud-native tools fit single-cloud estates well |

## Policy as code

Encode the rules once, check them everywhere:

| Where | Checks | Tools in this repository |
|---|---|---|
| Pull request | IaC misconfigurations, secrets, vulnerable dependencies | checkov, tflint, cfn-lint, Trivy |
| Pipeline | Image policy (signed, scanned, non-root), contract tests | Trivy, Schemathesis |
| Admission (Kubernetes) | Workloads meet the baseline before they run | Pod Security Admission ([namespace baseline](../devops/kubernetes/README.md)); Kyverno or Gatekeeper for custom rules |
| Cloud | Organization-wide guardrails | SCPs and Azure Policy ([Cloud foundations](02-cloud-foundations.md#guardrails)) |

Every policy needs an owner, a reason, and an exception process. Policies that block legitimate work without a way through get disabled.

## Golden paths

A **golden path** (or paved road) is a supported, pre-built way to do a common thing: create a service, add a database, set up a pipeline. It bundles the architecture's decisions (identity, network, observability, security controls) so teams get them by default.

- Make it **easier than the alternative:** a template or self-service action that produces a working, compliant service in minutes.
- Keep it **optional but attractive:** teams with unusual needs can leave the path, and take on what it would have handled.
- **Version and maintain it** like a product, with the platform team as owner ([platform as a product](../manager/07-structuring-platform-teams.md#the-platform-as-a-product)).

## Review questions

- How does a change reach production, and how long does it take?
- Is the artifact deployed to production the same one that was tested?
- Who or what can change production outside the pipeline?
- How does a deployment roll back, and when was that last exercised?
- What's in each infrastructure state, and what's the blast radius of a bad apply?
- Which policies are enforced automatically, at which stage?
- Can a team ship a new service on the golden path without asking the platform team for anything?
