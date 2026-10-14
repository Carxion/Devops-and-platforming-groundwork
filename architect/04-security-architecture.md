# Security architecture

[← Architect](README.md)

Security is a property of the architecture, not a layer added at the end. Most serious cloud breaches come from architectural choices (long-lived credentials, over-broad permissions, public data stores, flat networks), not exotic attacks. This guide covers the principles and the decisions where architects have the most leverage. The [tech lead checklist's DevSecOps section](../tech-lead/README.md#7-devsecops) covers assessing an existing program.

## Principles

| Principle | Means in practice |
|---|---|
| **Zero trust** | No implicit trust from network location: every request is authenticated, authorized, and encrypted, inside the network or not ([NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final) defines the model) |
| **Identity is the perimeter** | Access decisions rest on who and what is calling, with the network as a second layer, not the first |
| **Least privilege** | Every identity gets only the permissions its job needs, scoped to specific resources, reviewed regularly |
| **Defense in depth** | Independent layers, so one failure isn't a breach: identity, network, workload hardening, data encryption, detection |
| **Secure by default** | The paved path is the secure path: templates, modules, and platforms that are secure without extra effort |
| **Assume breach** | Design to limit and detect damage, not only to prevent entry: segmentation, audit trails, immutable backups |
| **Automate the controls** | Controls as code, checked in CI, so they hold at the speed of change ([fitness functions](01-thinking-like-an-architect.md#fitness-functions-keep-the-architecture-true)) |

## Identity and access

The highest-leverage area. Decisions:

- **No long-lived credentials** anywhere they can be avoided: workload identities for services, OIDC federation for CI/CD, single sign-on for people ([Cloud foundations](02-cloud-foundations.md#identity)). Each remaining secret is listed, owned, and rotated.
- **Permission boundaries** for anything that can create identities (CI pipelines, platform automation), so it can't grant more than it has ([AWS permissions boundary](../devops/aws/cloudformation/iam/permissions-boundary.yaml)).
- **Separate plan and apply identities** for infrastructure pipelines: read-only for pull requests, write only from protected branches ([GitHub OIDC stacks](../devops/terraform/aws/github-oidc/)).
- **One identity per workload,** never shared, so permissions and audit trails are specific ([workload role](../devops/aws/cloudformation/iam/workload-role.yaml)).
- **Regular access reviews,** automated where possible: unused permissions and identities removed.

## Network segmentation

- **Separate environments and workloads** at the account or subscription level first, then networks, then within clusters ([namespace NetworkPolicies](../devops/kubernetes/README.md)).
- **No direct internet exposure** except through defined ingress (load balancer, WAF, API gateway).
- **Private access to data services,** with public endpoints disabled.
- **Egress control:** know and restrict where workloads can send data. Unrestricted egress is how data leaves after a compromise.
- **Mutual TLS between services** where the threat model warrants it, through a service mesh or the platform.

## Data protection

| Decision | Default |
|---|---|
| Classification | Every data store tagged with its data classification; the classification drives the controls below |
| Encryption at rest | Always; customer-managed keys where you need control over key access, rotation, or deletion ([KMS key template](../devops/aws/cloudformation/security/kms-key.yaml)) |
| Encryption in transit | TLS 1.2 or later everywhere, including internal traffic |
| Key management | Keys in KMS or Key Vault, with separate administration and usage permissions |
| Secrets | In a secrets manager, injected at runtime, never in code, images, or environment files in Git |
| Residency | Regions restricted by policy where data must stay in a jurisdiction |
| Deletion | Retention periods defined, and deletion actually implemented, including backups |

## Software supply chain

What runs in production is only as trustworthy as everything that built it:

- **Pinned dependencies and base images** (by digest), updated by automation ([Dockerfiles](../devops/docker/02-dockerfiles.md))
- **Scanning** of dependencies, images, and infrastructure code in CI, with gates on fixable critical findings
- **Build provenance and signing:** artifacts built only in CI, signed, with an SBOM, and verified at deployment ([Docker security](../devops/docker/06-security.md#sboms-and-signing)); the SLSA framework sets levels for this
- **Protected pipelines:** branch protection, required reviews, CI identities that can't be used from developer machines, and pinned CI actions or plugins
- **Minimal runtime images** (distroless or slim), running as non-root with read-only filesystems

## Detection and response

Prevention eventually fails; design for detection:

- **Audit logs** for every control plane, centralized and immutable ([Cloud foundations](02-cloud-foundations.md#logging-and-audit))
- **Threat detection** services turned on (GuardDuty, Defender for Cloud) and routed to people who act on them
- **Runbooks** for the likely incidents: leaked credentials, compromised workload, exposed data store ([AWS](../devops/aws/guides/security-and-incident-response.md) and [Azure](../devops/azure/guides/security-and-incident-response.md) incident guides)
- **Forensic readiness:** the ability to isolate a workload and preserve its state and logs without destroying evidence

## Threat modeling

For every significant design, ask what could go wrong before building it. A lightweight approach that works in a design review:

1. **Draw the data flows** and mark the trust boundaries (where data crosses between networks, accounts, or privilege levels).
2. **Walk each boundary with STRIDE:** spoofing, tampering, repudiation, information disclosure, denial of service, elevation of privilege.
3. **For each credible threat,** record the mitigation or the accepted risk, with an owner.

Thirty minutes of threat modeling in review is cheaper than any finding after release.

## Review questions

- What's the longest-lived credential in this design? Can it be removed?
- If this workload were fully compromised, what else could the attacker reach?
- What data crosses which trust boundary, and how is it protected at each?
- What's exposed to the internet, and through what?
- How would we detect misuse of this component? Who would be alerted?
- How do artifacts get from source to production, and could anything be substituted on the way?
- Which compliance obligations apply, and how does the design produce the evidence automatically?
