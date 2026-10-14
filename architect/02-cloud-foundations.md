# Cloud foundations and landing zones

[← Architect](README.md)

The foundation of a cloud estate is its account or subscription structure, identity model, network, and guardrails. These are among the hardest decisions to reverse: moving workloads between accounts, readdressing networks, or changing the identity model can take years. They're worth getting right early, and worth fixing deliberately when inherited badly.

A **landing zone** is a pre-built, governed foundation that new workloads are deployed into. Both providers offer reference designs: [AWS Control Tower](https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html) and the AWS multi-account guidance, and [Azure landing zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/) in the Cloud Adoption Framework.

## Account and subscription structure

**Use many accounts (AWS) or subscriptions (Azure), not one.** They're the strongest isolation boundary the cloud offers: for security (a compromised workload can't reach others), for limits and quotas, for cost attribution, and for blast radius.

| Consideration | Default |
|---|---|
| Separate production from non-production | Always: different accounts or subscriptions, different access |
| Per workload or per team | One account per workload per environment for important workloads; shared non-production accounts are acceptable for small ones |
| Shared and platform services | Dedicated accounts for networking (hub), shared services (CI runners, artifact registries), and identity |
| Security and logging | A log archive account that workloads can write to but not delete from, and a security tooling account for scanners and audit roles |
| Sandbox | Separate accounts for experimentation, with budgets and automatic cleanup, isolated from production networks |
| Grouping | AWS Organizations organizational units, or Azure management groups, by environment and purpose, so policy applies by group |

Creating accounts should be **automated and fast** (an account vending process), or teams will cram unrelated workloads into existing ones.

## Identity

| Consideration | Default |
|---|---|
| Human access | Single sign-on from the organization's identity provider (IAM Identity Center on AWS, Entra ID on Azure), mapped from groups. No long-lived user credentials in the cloud. |
| Privilege | Read-only by default; elevated roles requested just in time and time-limited (Azure PIM, AWS permission sets with approval tooling) |
| Workload access | Workload identities only: IAM roles, managed identities, Kubernetes workload identity. No stored keys. ([EKS Pod Identity](../devops/kubernetes/components/eks-pod-identity/), [AKS workload identity](../devops/kubernetes/components/aks-workload-identity/)) |
| CI/CD access | OIDC federation from the CI system, scoped per repository and environment ([AWS](../devops/terraform/aws/github-oidc/) and [Azure](../devops/terraform/azure/github-oidc/) GitHub OIDC stacks) |
| Break-glass | A small number of emergency accounts, stored securely, alerting on every use, tested regularly |
| Root and global admins | Locked down with hardware MFA, unused day to day, monitored |

## Network

| Consideration | Default |
|---|---|
| Address plan | Plan IP ranges for the whole estate up front, including on-premises and partners, with **no overlaps**. Overlapping ranges block peering and connectivity later, and fixing them means readdressing. |
| Topology | Hub and spoke: shared connectivity, egress, and inspection in a hub; workloads in spokes ([AWS VPC](../devops/terraform/aws/network-vpc/) and [Azure hub-spoke](../devops/terraform/azure/network-hub-spoke/) stacks). AWS Transit Gateway or Azure Virtual WAN at larger scale. |
| Ingress | Through managed load balancers or gateways with a WAF, in a defined layer; nothing else internet-facing |
| Egress | Through a controlled path (NAT, firewall) so outbound traffic can be logged and restricted |
| Private access to cloud services | Private endpoints or PrivateLink for data services; disable public access to databases and storage by default |
| DNS | A designed approach for private zones, resolution between cloud and on-premises, and who owns each zone |
| On-premises and partner connectivity | VPN for small or temporary needs; Direct Connect or ExpressRoute for production-grade bandwidth and reliability, redundant |
| Segmentation | Between environments and between workloads, enforced by network rules and, inside Kubernetes, by network policies ([namespace baseline](../devops/kubernetes/README.md)) |

## Guardrails

Guardrails are organization-wide rules that hold even when someone makes a mistake inside an account. Two kinds:

| Kind | Does | Examples |
|---|---|---|
| **Preventive** | Blocks the action | AWS service control policies ([SCP baseline](../devops/aws/cloudformation/organizations/scp-baseline.yaml)), Azure Policy with deny effects ([policy baseline](../devops/azure/bicep/governance/policy-baseline.bicep)): approved regions only, no disabling audit logging, encryption required |
| **Detective** | Finds and reports it | AWS Config rules and Security Hub, Azure Policy audit effects and Defender for Cloud |

Prefer preventive guardrails for the few things that must never happen, and detective ones for the rest, so teams aren't blocked by rules that don't fit their case. Every guardrail needs an owner and a documented exception process.

## Logging and audit

- **Control-plane audit logs** (CloudTrail, Azure activity log) turned on for every account, sent to the log archive account, and protected from deletion ([CloudTrail template](../devops/aws/cloudformation/security/cloudtrail.yaml), [activity log export](../devops/azure/bicep/governance/activity-log-export.bicep))
- **Read-only audit access** for security teams across all accounts ([audit role](../devops/aws/cloudformation/iam/audit-readonly-role.yaml))
- **Retention** set by the organization's requirements, not by default

## Environments

- **Same code, different parameters:** every environment built from the same infrastructure code, differing only in variables (size, counts, names). Drift between environments explains most "works in staging" failures.
- **How many:** usually development, a pre-production that mirrors production, and production. Each additional environment costs money and maintenance; ephemeral environments per pull request often serve testing better than more permanent ones.
- **Data:** production data stays in production. Test with synthetic or properly anonymized data.

## Tagging and naming

Decide early, enforce by policy, and keep it short:

- **Required tags:** owner, environment, cost center, and data classification at minimum ([cost guides](../devops/aws/guides/cost.md) show how to find untagged resources)
- **Naming:** predictable, including environment and region, within each provider's length limits. Names baked into hundreds of resources are expensive to change.

## Review questions

- Can a compromise in one workload reach another? Through what?
- How long does it take to create a new, compliant account or subscription?
- Where does every human and machine identity come from, and what are their longest-lived credentials?
- Do any planned IP ranges overlap, now or with likely future connections?
- What's the path for traffic in from the internet, and out to it? Is each logged?
- Which guardrails are preventive, and who can grant exceptions?
- Could an attacker with administrator access to a workload account delete the audit trail?
