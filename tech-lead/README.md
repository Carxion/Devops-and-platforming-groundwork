# Tech lead onboarding checklist

**Cloud, CI/CD, IaC, and DevSecOps onboarding for enterprise and regulated programs.** Part of [DevOps and Platforming Groundwork](../README.md).

A checklist for engineers stepping into a technical lead role on an existing program: a platform, a delivery pipeline, and a set of stakeholders who were all there before you. It covers what to learn, who to talk to, how to evaluate the problems you inherit, and what to deliver in your first 90 days.

Last reviewed: 2026-09-25 · Maintainer: Dominick Bolanos · License: CC BY 4.0

---

## Contents

- [How to use this guide](#how-to-use-this-guide)
- [Ground rules](#ground-rules)
- [0. Access and logistics](#0-access-and-logistics)
- [1. Stakeholders and management](#1-stakeholders-and-management)
- [2. Evaluating the program's problems](#2-evaluating-the-programs-problems)
- [3. Cloud](#3-cloud)
- [4. Infrastructure as Code](#4-infrastructure-as-code)
- [5. Continuous Integration](#5-continuous-integration)
- [6. Continuous Delivery and Deployment](#6-continuous-delivery-and-deployment)
- [7. DevSecOps](#7-devsecops)
- [8. Observability and operations](#8-observability-and-operations)
- [9. 30/60/90-day deliverables](#9-306090-day-deliverables)
- [10. Best practices](#10-best-practices)
- [Appendix A: Templates](#appendix-a-templates)
- [Appendix B: Restricted-network environments](#appendix-b-restricted-network-environments)
- [References](#references)
- [Contributing, disclaimer, and license](#contributing-disclaimer-and-license)

---

## How to use this guide

Each checklist item carries a timing tag:

| Tag | Meaning |
|---|---|
| **W1** | First week. Mostly access, orientation, and first conversations. |
| **30** | By day 30. Listen, inventory, baseline. |
| **60** | By day 60. Diagnose, prioritize, present findings. |
| **90** | By day 90. Agree on a roadmap and start executing it. |

Not every item applies to every program. Skip what doesn't fit, but skip it on purpose: write down *why* it doesn't apply, because that reasoning is itself a finding.

**On evidence.** Where an item rests on a published standard or framework, it cites one (see [References](#references)). Everything else is practitioner judgment. Treat it as a strong default, not a rule.

**Other formats.** This README is the source of truth. The same items are also available as:

- [checklists/by-phase.md](checklists/by-phase.md): every item regrouped by W1 / 30 / 60 / 90, for working through one phase at a time
- [checklists/checklist.csv](checklists/checklist.csv): one row per item with Status, Owner, and Notes columns, for importing into a spreadsheet or tracker
- [templates/](templates/): copy-ready versions of the [Appendix A](#appendix-a-templates) templates

Copy these into your program's approved systems before filling them in (see ground rule 5).

**Guides for the harder parts:**

- [Assessing an inherited system](assessing-an-inherited-system.md): sections 2 and 9 as a working method: mapping the system, following a change and an incident through it, reading the commit history, interviewing, scoring risks, and presenting findings
- [Worked example](worked-example.md): a fictional program taken through all 90 days, showing each deliverable filled in
- [Design reviews and RFCs](design-reviews-and-rfcs.md): when to write a design, how to write it, and how to run a review that improves it
- [Migrations and cutovers](migrations-and-cutovers.md): planning, safe migration patterns, data, and running the cutover
- [Working with product and leadership](working-with-product-and-leadership.md): translating technical work into business terms, negotiating scope, presenting a roadmap, and disagreeing well

**Going deeper.** Most "find out" and "evaluate" items here have hands-on material elsewhere in the repository: reference Terraform stacks, Kubernetes samples, and AWS and Azure command guides in [devops/](../devops/README.md) for sections [3](#3-cloud) to [8](#8-observability-and-operations), API testing in [software/](../software/README.md), and team practices in [manager/](../manager/README.md). The [repository index](../README.md) maps all of it, and the [glossary](../GLOSSARY.md) defines the terms.

---

## Ground rules

1. **Learn before you change.** Outside of a security or availability emergency, avoid structural changes in your first ~30 days. The system you inherited is the product of constraints you can't see yet.
2. **Assume every odd decision had a reason.** Find the reason before removing the thing. Sometimes the reason is gone; often it isn't.
3. **Measure before you propose.** A baseline turns "I think the pipeline is slow" into a claim nobody can argue with, and lets you show your own impact later.
4. **Separate "can't change" from "hasn't been changed."** In regulated environments, a painful control usually can't be *removed*. It can often be *relocated* (moved earlier, moved to a platform layer) or have its evidence *automated*. Classify before you plan.
5. **Keep your notes where the program's data lives.** Onboarding notes on a program are program information. Store them on approved program systems, follow its data-handling rules, and never copy program details into personal devices, personal accounts, or public tools, including AI assistants that aren't approved for that data.
6. **Write it down.** Decisions, assumptions, and findings that exist only in conversation will be relitigated.

---

## 0. Access and logistics

- [ ] **W1** Confirm your role, title, and reporting line in writing, including who you are accountable to on the customer or business side.
- [ ] **W1** Complete required security, privacy, and acceptable-use training before requesting privileged access.
- [ ] **W1** Request access by role, not by copying a coworker's permissions. Record every access request and who approved it.
- [ ] **W1** Get read-only access to everything first: source control, CI/CD, cloud consoles, ticketing, wiki, monitoring, scan results. Request write/admin access separately, only where the role needs it.
- [ ] **W1** Set up MFA everywhere it's available. Confirm you have no shared or group credentials.
- [ ] **W1** Learn the break-glass and emergency-access procedure before you ever need it.
- [ ] **W1** Get added to the right distribution lists, chat channels, on-call rotations, and recurring meetings. Ask which meetings you can safely skip.
- [ ] **W1** Locate the canonical documentation: architecture diagrams, runbooks, security and compliance documentation (if it exists), onboarding docs. Note when each was last updated.
- [ ] **30** Walk the path a new developer takes from "account created" to "first change deployed." Time it and record every blocker.

---

## 1. Stakeholders and management

The technical work on most programs is easier than the coordination around it. Most tech leads who struggle in their first 90 days struggle here.

### 1.1 Understand what the program is obligated to deliver

- [ ] **W1** Read the governing document: the customer contract or statement of work for client engagements, or the charter, funding approval, or OKRs for internal programs.
- [ ] **W1** List the formal deliverables, due dates, and acceptance criteria, including required documents and reports.
- [ ] **30** Identify service-level commitments (availability, response times, patch timelines) and whether they are being met today.
- [ ] **30** Learn how the program is judged: contract incentives or penalties, performance reviews, customer satisfaction surveys, audit results.
- [ ] **30** Learn the contract term, renewal dates, or budget cycle. Timing drives what the program is willing to invest in.
- [ ] **30** Know what's in scope and what isn't. Scope creep usually arrives as a "quick favor" to the tech lead.

### 1.2 Build a stakeholder map

- [ ] **W1** List everyone with authority over, dependency on, or influence on your work. Use the [stakeholder map template](#a1-stakeholder-map).
- [ ] **30** Cover at least these roles (titles vary):
  - Executive sponsor or funding owner
  - Customer program manager or account owner
  - Your program manager and line manager (often different people)
  - Product owners and application team leads
  - Security: CISO org, security and compliance leads, and whoever formally accepts risk for the system
  - Operations: NOC, SOC, service desk, on-call leads
  - Enterprise architecture, network, and identity teams
  - Change advisory board (CAB) or release management
  - Other vendors or partner teams whose work touches yours
  - The actual end users
- [ ] **30** For each stakeholder, record what they need from you, what you need from them, and how they prefer to communicate.
- [ ] **60** Identify the informal influencers: the long-tenured engineer everyone asks, the security reviewer whose approval really matters.

### 1.3 Run first conversations

- [ ] **30** Meet every key stakeholder one-on-one within 30 days. Use the same core questions with each (see [A.2](#a2-first-conversation-questions)) so answers are comparable.
- [ ] **30** Listen more than you talk. Don't promise fixes in first meetings.
- [ ] **30** Ask each person: what is working well that I should protect?
- [ ] **30** Follow up in writing with what you heard and anything you committed to.
- [ ] **60** Look for disagreement between stakeholders about priorities. That disagreement is often the real problem you were hired to solve.

### 1.4 Align with your manager

- [ ] **W1** Ask what success looks like at 30, 90, and 180 days, in their words.
- [ ] **W1** Clarify your decision rights: what you can decide alone, what needs consultation, what needs approval.
- [ ] **30** Ask what they are hearing about the team from above and from the customer.
- [ ] **30** Agree on a status format and cadence (see [A.5](#a5-weekly-status)).
- [ ] **30** Agree on how you'll raise bad news. Commit to raising it early.
- [ ] **60** Share your draft findings with your manager before any wider readout. No one should be surprised in a meeting.

### 1.5 Set up communication and decision-making

- [ ] **30** Establish a written decision log. Record the decision, the alternatives considered, who decided, and the date. Use Architecture Decision Records for technical decisions [ADR].
- [ ] **30** Define a RACI (responsible, accountable, consulted, informed) for recurring decisions: production deploys, access grants, risk acceptance, architecture changes, vendor/tool selection.
- [ ] **30** Know the escalation path for technical, security, and schedule issues, and who owns each.
- [ ] **60** Stand up a regular stakeholder touchpoint (demo, review, or written update) that shows progress on the things they care about, not just the things engineers care about.
- [ ] **60** Translate technical risk into business terms: business impact, schedule, cost, audit exposure. "Unpatched base images" means little to a sponsor; "failed audit finding with a 30-day remediation clock" means a lot.

### 1.6 Understand your team

- [ ] **W1** Schedule one-on-ones with each engineer. Ask about their work, frustrations, career goals, and what they want from a lead.
- [ ] **30** Build a skills matrix. Identify single points of knowledge (the "bus factor" for each critical system).
- [ ] **30** Understand workload and on-call burden. Look at after-hours pages and unplanned work.
- [ ] **30** Learn how work enters the team: tickets, chat requests, meetings, hallway asks. Unmanaged intake is a common cause of burnout.
- [ ] **60** Agree on team working norms: code review expectations, definition of done, documentation, meeting load.
- [ ] **60** Check whether bad news reaches leadership. If engineers hide problems or learn about decisions secondhand, that's a finding (see Westrum's organizational culture typology [WESTRUM]).

---

## 2. Evaluating the program's problems

The goal of discovery is a short, evidenced, prioritized list of problems that stakeholders agree with. Not a list of tools you'd prefer.

### 2.1 Gather evidence before opinions

- [ ] **30** Read the last 6–12 months of incident reports and postmortems.
- [ ] **30** Review audit findings, open remediation plans, and risk-acceptance records.
- [ ] **30** Pull current vulnerability scan results and note the age of open findings by severity.
- [ ] **30** Review the ticket backlog: what's oldest, what keeps getting reopened, what's always deprioritized.
- [ ] **30** Pull pipeline data: build durations, failure rates, queue times.
- [ ] **30** Pull cost reports and the trend over the last several months.
- [ ] **30** Review the change or release calendar: how often, how big, how many rollbacks.

### 2.2 Establish a baseline

Measure per service or application, not as a program-wide average. Record the method with every number so you can reproduce it later.

- [ ] **30** DORA software delivery metrics [DORA]:
  - Throughput: change lead time, deployment frequency, failed deployment recovery time
  - Instability: change fail rate, deployment rework rate
- [ ] **30** CI: median and 95th-percentile pipeline duration, queue time, and flaky-test rate.
- [ ] **30** Environment provisioning time (request to usable).
- [ ] **30** Time for a new engineer to ship a first change.
- [ ] **30** Vulnerability age and count by severity; count of findings in the known-exploited catalog [KEV].
- [ ] **30** Time from "change ready" to "change approved" through any review board or approval gate.
- [ ] **30** Toil: recurring manual work, estimated in hours per week.
- [ ] **60** Note which metrics can't be moved by the team at all. In environments with formal approval gates or restricted networks, some delivery levers (for example deploy frequency to production) are set by external gates. A low number there is a constraint to document, not a performance verdict.

### 2.3 Collect the pain inventory

- [ ] **30** Ask engineers, operators, and app teams the same three questions: what slows you down, what scares you, what do you work around?
- [ ] **30** Sample beyond the loudest voices. Include new hires, who still notice friction veterans have normalized.
- [ ] **30** Log each item as an observation, not a solution: "deploys require manual approval from three teams," not "we need GitOps."

### 2.4 Classify each problem

For each item in the findings register ([A.3](#a3-findings-register)):

- [ ] **60** **Symptom or cause?** Slow pipelines are a symptom; the cause might be serial jobs, no caching, or undersized runners.
- [ ] **60** **Constraint type:**
  - *Removable*: nothing external requires it
  - *Relocatable*: required, but could move (earlier in the pipeline, into a platform layer, into a pre-approved standard change)
  - *Evidence-automatable*: required, but the manual evidence gathering around it can be generated by the pipeline
  - *Fixed*: required as-is by contract, policy, or law
- [ ] **60** **Owner:** who can actually change it? If it's not your team, the fix is a stakeholder conversation.
- [ ] **60** **Impact:** security, availability, compliance, cost, delivery speed, team health.
- [ ] **60** **Effort and risk** of fixing it.

### 2.5 Prioritize

- [ ] **60** Put active security exposure and availability risk first, regardless of effort.
- [ ] **60** Pick two or three low-effort, visible improvements to build trust early.
- [ ] **60** Rank the rest by impact relative to effort, and note dependencies between items.
- [ ] **60** State what you are deliberately *not* fixing yet, and why.

### 2.6 Present findings

- [ ] **60** Pre-brief your manager and the most affected stakeholders individually before any group readout.
- [ ] **60** Present: top problems with evidence, proposed priorities, what you need from each stakeholder, and what you are not doing.
- [ ] **60** Credit what the team did well. Findings that read as blame stop the flow of future information.
- [ ] **90** Convert agreed findings into a roadmap with owners and dates.

### 2.7 Common discovery mistakes

- Proposing solutions in week one.
- Reframing every problem around a tool you've used before.
- Treating one bad incident as a trend.
- Interviewing only leadership, or only engineers.
- Presenting a finding to a group before telling the person who owns that area.

---

## 3. Cloud

Examples use AWS terminology where a generic term would be unclear; the same questions apply on any provider.

### 3.1 Account and organization structure

- [ ] **W1** Get the list of accounts/subscriptions/projects, what each one is for, and who owns it.
- [ ] **30** Understand the organization hierarchy and which guardrails apply at each level (for example AWS Organizations service control policies).
- [ ] **30** Confirm workloads are separated by environment (prod, non-prod) and by sensitivity at the account level, not just by tags.
- [ ] **30** Identify which regions are in use and why (data residency, latency, cost, or service availability).
- [ ] **30** Check service quotas and limits that are close to being hit.

### 3.2 Identity and access

- [ ] **W1** Confirm human access is federated through single sign-on with MFA.
- [ ] **30** Inventory long-lived access keys and static credentials. Find out who owns each and when it was last rotated.
- [ ] **30** Review who holds administrator or equivalent roles. Compare against who actually needs them.
- [ ] **30** Confirm break-glass accounts exist, are monitored, and have been tested.
- [ ] **60** Check whether workloads and pipelines use short-lived, role-based credentials instead of stored keys.

### 3.3 Network

- [ ] **30** Get or draw a current network diagram: VPCs/VNets, subnets, peering, transit, VPN or dedicated links to on-premises.
- [ ] **30** Understand internet egress: is it allowed, filtered, proxied, or absent?
- [ ] **30** Identify publicly exposed endpoints and confirm each is intended.
- [ ] **30** Understand DNS: who manages it, split-horizon setups, private zones.
- [ ] **60** Check for private endpoints to cloud services versus traffic that routes over the internet.

### 3.4 Logging, encryption, and data protection

- [ ] **30** Confirm control-plane audit logging (for example CloudTrail) is on in every account and region, centralized, and protected from deletion by workload accounts.
- [ ] **30** Know the log retention requirements and whether they are met.
- [ ] **30** Understand key management: who can use, rotate, and delete encryption keys.
- [ ] **30** Identify where sensitive data lives and how it is classified.

### 3.5 Resilience and cost

- [ ] **30** Find the documented recovery point and recovery time objectives (RPO/RTO). Ask when a restore was last actually tested.
- [ ] **30** Confirm backups are isolated from the accounts they protect.
- [ ] **30** Check tagging coverage for cost allocation and ownership.
- [ ] **60** Look for idle and orphaned resources: unattached volumes, old snapshots, stopped instances, unused load balancers and IPs.
- [ ] **60** Confirm budgets and cost-anomaly alerts exist and reach someone who acts on them.

### 3.6 Shared responsibility

- [ ] **30** Understand which security controls are inherited from the cloud provider or an enterprise platform, and which your program must implement itself. Compliance programs usually document this in a shared-responsibility or control-inheritance matrix.

---

## 4. Infrastructure as Code

- [ ] **30** Inventory what is managed as code versus created by hand in consoles. Hand-built production resources are a finding.
- [ ] **30** Identify every IaC tool in use (Terraform/OpenTofu, CloudFormation, Pulumi, Ansible, Helm, etc.) and which one owns which resources.
- [ ] **30** Locate the state backend. Confirm it has locking, encryption, versioning, and restricted access. Remember state files can contain secrets in plain text.
- [ ] **30** Check how state is split. One giant state file means one mistake can reach everything.
- [ ] **30** Confirm provider and module versions are pinned.
- [ ] **30** Find out how applies happen: from a pipeline with reviewed plans, or from laptops?
- [ ] **60** Run a drift check. Note resources that differ from code and find out why.
- [ ] **60** Check whether plans are shown in merge requests and reviewed before apply.
- [ ] **60** Check for policy-as-code on IaC changes (for example OPA/Conftest, Checkov, or provider-native policy tools) and whether it blocks or only warns.
- [ ] **60** Review module structure: are shared modules versioned and released, or copied between repos?
- [ ] **60** For configuration management (for example Ansible), confirm runs are idempotent and repeatable, not one-time scripts.
- [ ] **90** Plan to import or rebuild hand-created resources into code, starting with production.

---

## 5. Continuous Integration

- [ ] **30** Inventory pipelines, shared templates, and who maintains them.
- [ ] **30** Understand the runners: ephemeral or persistent, privileged or not, what networks they can reach, and who administers them. A persistent, privileged runner with broad network access is a high-value target.
- [ ] **30** Find where pipeline credentials come from. Prefer short-lived credentials via identity federation (OIDC) over secrets stored in CI variables.
- [ ] **30** Check branch protection: required reviews, required passing checks, who can bypass.
- [ ] **30** Measure where pipeline time goes, job by job. Look for serial jobs that could run in parallel, missing caches, and oversized test suites.
- [ ] **30** Identify flaky tests and how the team handles them (retries hide them; quarantine surfaces them).
- [ ] **30** Understand the branching model and how long branches live before merge.
- [ ] **60** Confirm third-party pipeline components (actions, includes, orbs, plugins) are pinned to an immutable version (commit SHA or digest), not a mutable tag.
- [ ] **60** Confirm dependencies are pulled through an approved proxy or mirror rather than directly from public registries, where policy requires it.
- [ ] **60** Check artifact storage: where build outputs live, retention, and whether artifacts are immutable once published.
- [ ] **60** Review pipeline definitions for secrets echoed to logs, overly broad permissions, and unreviewed changes to pipeline config itself. The OWASP Top 10 CI/CD Security Risks is a useful review list [OWASP-CICD].
- [ ] **90** Build once, promote the same artifact through environments. Rebuilding per environment means you never deploy what you tested.

---

## 6. Continuous Delivery and Deployment

- [ ] **30** Map every deployment path to production, including the unofficial ones.
- [ ] **30** Document environments and the promotion path between them. Note differences between staging and production that could hide defects.
- [ ] **30** Identify who can deploy to production and how that access is granted and logged.
- [ ] **30** Find out whether rollback exists, how long it takes, and when it was last used successfully.
- [ ] **30** Understand how database and schema migrations are handled, and whether they can be rolled back.
- [ ] **30** Map the change management process: who approves what, lead time for approval, and freeze windows.
- [ ] **60** Identify changes that could qualify as pre-approved standard changes. Moving routine, low-risk, well-tested deployments out of a full review board is often the biggest delivery improvement available without weakening control.
- [ ] **60** If using GitOps (for example Argo CD or Flux), confirm Git is really the source of truth: check for manual changes, sync drift, and who can override.
- [ ] **60** Check how configuration and secrets differ per environment and where they're stored.
- [ ] **60** Confirm automated smoke tests or health checks run after every deploy.
- [ ] **90** Evaluate progressive delivery (canary, blue/green, feature flags) where the platform and risk profile support it.
- [ ] **90** Confirm every production deploy leaves an audit trail: what changed, who approved, what artifact, when.

---

## 7. DevSecOps

### 7.1 Governance and compliance

- [ ] **W1** Identify which frameworks and obligations apply: for example ISO/IEC 27001, SOC 2, PCI DSS, HIPAA, GDPR, or internal policy.
- [ ] **30** Find the compliance status: which certifications or attestations the system holds (for example a SOC 2 report or an ISO certificate), when they expire or are next audited, and what exceptions apply.
- [ ] **30** Read the security and compliance documentation (control descriptions, risk register, open remediation items) that touches your platform.
- [ ] **30** Meet the security and compliance leads. Learn what evidence they collect, how, and how often.
- [ ] **60** Identify manual compliance evidence that the pipeline could generate automatically: scan reports, SBOMs, approval records, configuration baselines.
- [ ] **60** Map existing secure development practices to the NIST Secure Software Development Framework [SSDF] to find gaps in a shared vocabulary.

### 7.2 Pipeline security controls

- [ ] **30** Inventory what scanning exists and where it runs: secrets detection, static analysis (SAST), dependency/software composition analysis (SCA), IaC scanning, container image scanning, dynamic testing (DAST).
- [ ] **30** For each scanner, find out: what blocks a build, what only warns, who triages results, and how false positives are suppressed.
- [ ] **60** Check whether scan results reach developers where they work (merge requests) or only a dashboard nobody opens.
- [ ] **60** Check whether scanner rules and suppression lists are version-controlled and reviewed.
- [ ] **60** Measure how much time security stages add to the pipeline. Controls that make builds much slower get bypassed.

### 7.3 Software supply chain

- [ ] **30** Confirm an SBOM is generated at build time for each released artifact, in a standard format (SPDX or CycloneDX), and stored alongside the artifact [SBOM].
- [ ] **60** Check whether artifacts are signed and whether signatures are *verified* at deploy time (for example by an admission controller). Signing without verification provides little protection.
- [ ] **60** Check for build provenance and assess the build platform against the SLSA Build track levels [SLSA].
- [ ] **60** Review base image policy: approved sources, update cadence, and who owns patching.
- [ ] **60** Treat security tools as supply-chain dependencies too. Pin and verify scanners and their plugins the same way you pin application dependencies.
- [ ] **90** Evaluate the health of critical open-source dependencies (for example with OpenSSF Scorecard [SCORECARD]).

### 7.4 Vulnerability management

- [ ] **30** Find the remediation SLAs by severity and check actual performance against them.
- [ ] **30** Check whether prioritization considers exploitation, not just CVSS score: CISA's Known Exploited Vulnerabilities catalog [KEV] and exploit-prediction scores such as EPSS [EPSS].
- [ ] **60** Review the exception and risk-acceptance process. Every exception should have an owner, a justification, and an expiration date.
- [ ] **60** Check whether the team can state which vulnerabilities are *not* exploitable in their context and record that (for example with VEX statements) instead of re-triaging the same findings every scan.

### 7.5 Platform and runtime hardening

- [ ] **30** Identify the hardening baselines in use (for example CIS Benchmarks [CIS]) and how compliance with them is checked.
- [ ] **30** For containers and Kubernetes: review RBAC, Pod Security Admission levels, network policies, admission control, and service account permissions. NIST SP 800-190 covers container-specific risks [800-190].
- [ ] **30** Confirm secrets are in a secrets manager, not in repos, images, or plain environment files.
- [ ] **60** Check whether runtime detection exists and whether its alerts reach the SOC.

### 7.6 Threat modeling and incident response

- [ ] **60** Threat-model the delivery platform itself, not only the applications: source control, CI runners, artifact registry, deploy credentials. The pipeline has access to production.
- [ ] **60** Confirm incident response runbooks exist for the platform, with current contacts.
- [ ] **90** Run or join a tabletop exercise that includes a CI/CD or supply-chain compromise scenario. NIST SP 800-204D covers integrating supply-chain security into CI/CD pipelines [800-204D].

---

## 8. Observability and operations

- [ ] **30** Inventory monitoring, logging, and tracing tools, and who owns each.
- [ ] **30** Review alerts: which ones page a human, and how many of those required action in the last month. Alerts that don't need action train people to ignore alerts.
- [ ] **30** Check whether service-level objectives (SLOs) exist and whether they reflect what users experience [SRE].
- [ ] **30** Review on-call: rotation size, page volume, after-hours load, and escalation.
- [ ] **60** Confirm runbooks exist for the most frequent alerts and have been used recently.
- [ ] **60** Confirm postmortems are blameless, written, and produce tracked action items that get closed.
- [ ] **60** Check capacity planning for clusters, registries, and runners.

---

## 9. 30/60/90-day deliverables

Concrete outputs make your onboarding visible and give stakeholders something to react to.

### By day 30

- [ ] Stakeholder map and summary of first conversations
- [ ] System inventory: accounts, pipelines, environments, deploy paths, tools, owners
- [ ] Baseline metrics with the method used to collect each one
- [ ] Top five risks, shared privately with your manager
- [ ] Access review completed for your own permissions

### By day 60

- [ ] Findings register, classified and prioritized
- [ ] Findings readout delivered to stakeholders after individual pre-briefs
- [ ] Two or three quick wins shipped and measured against the baseline
- [ ] Decision log and RACI in use

### By day 90

- [ ] Roadmap agreed with stakeholders, with owners, dates, and explicit non-goals
- [ ] First Architecture Decision Records written for the major roadmap choices
- [ ] Metrics dashboard or recurring report showing the baseline and trend
- [ ] Team working agreements documented
- [ ] Your own 90-day retrospective: what you got wrong, what you'd change

---

## 10. Best practices

### Leadership and stakeholders

- Earn trust before spending it. Deliver small, visible wins before proposing large changes.
- No surprises. Tell people bad news privately and early, before it appears in a meeting or report.
- Put commitments in writing and track them. A tech lead's credibility is the ratio of promises kept to promises made.
- Explain technical work in terms of business outcomes, cost, schedule, and risk when talking to non-engineers.
- Protect the team's focus. Route requests through one intake path and push back on side-channel asks.
- Give credit publicly and take responsibility for failures publicly.
- Treat security, operations, and compliance staff as partners in design, not reviewers at the end.
- Say what you're not doing and why. Explicit non-goals prevent silent scope creep.

### Discovery and decision-making

- Evidence before opinions, baselines before proposals.
- Fix causes, not symptoms, and confirm which is which before committing effort.
- Record decisions with their context and rejected alternatives (ADRs), so future engineers can tell a deliberate choice from an accident.
- Prefer reversible decisions, and make irreversible ones slowly.
- Revisit constraints periodically. Rules outlive the reasons they were created.

### Cloud

- Separate environments and sensitivity levels at the account boundary.
- Use federated, short-lived credentials for people and workloads. Treat every long-lived key as debt.
- Enforce guardrails at the organization level so individual accounts can't opt out.
- Centralize and protect audit logs from the accounts that generate them.
- Test restores, not just backups.
- Tag for ownership and cost from day one; untagged resources become orphaned resources.

### Infrastructure as Code

- If it isn't in code, assume it will drift.
- Apply only from pipelines, from reviewed plans.
- Pin tool, provider, and module versions; upgrade deliberately.
- Keep state small, encrypted, locked, and access-controlled.
- Enforce policy as code at plan time, not after deploy.
- Version shared modules and release them; don't copy-paste between repos.

### Continuous Integration

- Keep the main branch releasable; merge small changes often.
- Make pipelines fast enough that engineers don't route around them. Measure duration continuously.
- Build once, sign once, promote the same artifact everywhere.
- Use ephemeral, least-privilege runners.
- Pin third-party pipeline components to immutable references.
- Quarantine flaky tests instead of retrying them into invisibility.

### Continuous Delivery and Deployment

- Make deployment boring: automated, repeatable, and frequent enough that the process stays practiced.
- Every deploy needs a tested rollback or fix-forward path.
- Match approval rigor to risk. Pre-approve routine, well-tested change types; save human review for high-risk changes.
- Keep Git as the source of truth for what's deployed, and alert on drift.
- Verify every deployment automatically.

### Security and compliance

- Build security controls into the paved path so the secure way is also the easiest way.
- Block builds only on findings you trust; warn on the rest and tune continuously. Noisy gates get bypassed.
- Prioritize vulnerabilities by exploitation and exposure, not severity score alone.
- Give every exception an owner and an expiration date.
- Generate compliance evidence as a pipeline byproduct instead of assembling it by hand before audits.
- Sign artifacts and verify signatures at deploy time.
- Treat the delivery pipeline as production infrastructure: threat-model it, monitor it, and restrict it.
- Apply the same supply-chain scrutiny to security tools that you apply to application dependencies.

### Operations

- Every paging alert should require human action; delete or demote the rest.
- Define SLOs from the user's perspective and use them to decide between feature work and reliability work.
- Run blameless postmortems and close their action items.
- Measure toil and budget time to automate it away.

### Team and documentation

- Reduce single points of knowledge through pairing, rotation, and runbooks.
- Document the why, not just the how.
- Keep docs next to the code they describe, and review them in the same merge requests.
- Onboard the next person better than you were onboarded. Update this checklist for your program as you go.

---

## Appendix A: Templates

Copy-ready files (CSV for the tables, Markdown for the rest) are in [tech-lead/templates/](templates/).

### A.1 Stakeholder map

| Name / role | Organization | What they need from us | What we need from them | Influence (H/M/L) | Preferred channel | Last contact |
|---|---|---|---|---|---|---|
| | | | | | | |

### A.2 First-conversation questions

1. What is this program for, in your words?
2. What's working well that I should protect?
3. What's the biggest problem you'd want solved in the next six months?
4. What has been tried before, and what happened?
5. What slows you down, and what do you work around?
6. What worries you that nobody talks about?
7. Who else should I talk to?
8. How do you want to hear from me, and how often?

### A.3 Findings register

| ID | Observation (evidence, not solution) | Source | Symptom / cause | Constraint type | Owner | Impact | Effort | Priority | Status |
|---|---|---|---|---|---|---|---|---|---|
| F-01 | | | | Removable / Relocatable / Evidence-automatable / Fixed | | | | | |

### A.4 Architecture Decision Record

```markdown
# ADR-NNN: <decision title>

Date: YYYY-MM-DD
Status: Proposed | Accepted | Superseded by ADR-NNN

## Context
What problem are we solving, and what constraints apply?

## Decision
What we are doing.

## Alternatives considered
What else we looked at, and why we didn't choose it.

## Consequences
What gets easier, what gets harder, and what we'll need to watch.
```

### A.5 Weekly status

```markdown
## Week of YYYY-MM-DD

**Summary:** One or two sentences.

**Done this week:**
**Planned next week:**
**Risks and issues:** (new or changed, with owner and needed decision)
**Decisions needed from stakeholders:**
**Metrics:** (baseline → current, for the handful that matter)
```

---

## Appendix B: Restricted-network environments

Programs with no internet egress, strict data boundaries, or formal approval gates for changes add questions most DevOps guidance assumes away. If your program has any of these, add the following:

- [ ] **30** How do new tools, packages, images, and updates enter the environment? Who approves each transfer, and how long does it take?
- [ ] **30** What mirrors and registries exist inside the boundary (container images, OS packages, language packages, IaC providers and modules), and how are they kept current?
- [ ] **30** How are vulnerability databases for scanners updated inside the boundary, and how stale are they allowed to get?
- [ ] **30** What changes require a formal security review or re-approval, and what can proceed under existing approvals?
- [ ] **60** Which DORA and developer-experience metrics are bounded by external gates? Report those as constraints, with the gate owner, rather than as team performance.
- [ ] **60** Are signatures and SBOMs verified again at the boundary crossing, not just at build time?
- [ ] **60** Where can a control be relocated or its evidence automated, given that removal is usually not an option?
- [ ] **90** Is there an approved path to continuous compliance for the platform (evidence generated automatically instead of periodic re-approval), if the organization supports one?

---

## References

Links and document status were checked on the "Last reviewed" date at the top of this file. Standards in this space are revised often; confirm you are reading the current version.

| Key | Source |
|---|---|
| [ADR] | Michael Nygard, "Documenting Architecture Decisions," 2011. https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions |
| [CIS] | Center for Internet Security, CIS Benchmarks. https://www.cisecurity.org/cis-benchmarks |
| [DORA] | DORA, "DORA's software delivery performance metrics." https://dora.dev/guides/dora-metrics/ · Metric history: https://dora.dev/guides/dora-metrics/history/ |
| [EPSS] | FIRST, Exploit Prediction Scoring System. https://www.first.org/epss/ |
| [KEV] | CISA, Known Exploited Vulnerabilities Catalog. https://www.cisa.gov/known-exploited-vulnerabilities-catalog |
| [OWASP-CICD] | OWASP, Top 10 CI/CD Security Risks. https://owasp.org/www-project-top-10-ci-cd-security-risks/ |
| [800-190] | NIST SP 800-190, Application Container Security Guide. https://csrc.nist.gov/pubs/sp/800/190/final |
| [800-204D] | NIST SP 800-204D, Strategies for the Integration of Software Supply Chain Security in DevSecOps CI/CD Pipelines. https://csrc.nist.gov/pubs/sp/800/204/d/final |
| [SBOM] | CISA, Software Bill of Materials resources. https://www.cisa.gov/sbom · NTIA 2021 minimum elements; CISA published a 2025 update as a public comment draft (August 2025). Formats: SPDX https://spdx.dev · CycloneDX https://cyclonedx.org |
| [SCORECARD] | OpenSSF Scorecard. https://securityscorecards.dev |
| [SLSA] | SLSA specification (v1.2 current at time of review). https://slsa.dev/spec/ |
| [SRE] | Google, Site Reliability Engineering books (free online). https://sre.google/books/ |
| [SSDF] | NIST SP 800-218, Secure Software Development Framework v1.1 (final). https://csrc.nist.gov/pubs/sp/800/218/final · SSDF v1.2 (SP 800-218r1) released as an initial public draft December 2025: https://csrc.nist.gov/projects/ssdf |
| [WESTRUM] | Ron Westrum, "A typology of organisational cultures," *Quality and Safety in Health Care* 13, suppl. 2 (2004). https://qualitysafety.bmj.com/content/13/suppl_2/ii22 |

---

## Contributing, disclaimer, and license

**Contributing.** Corrections and additions are welcome through issues and pull requests. For factual claims, link a primary source (the standard, spec, or official documentation), not a blog summarizing it. See [CONTRIBUTING.md](../CONTRIBUTING.md) for the item format and checks. Corrections are logged in [CHANGELOG.md](../CHANGELOG.md).

**Do not contribute program-specific information.** Examples must be generic or drawn from public sources. Do not submit anything from a customer, employer, or restricted environment, even de-identified.

**Disclaimer.** This is a personal project. It reflects the author's own views and is not endorsed by, and does not describe, any employer, customer, or organization. It is not legal, compliance, or contractual advice; your program's contracts, policies, and risk owners take precedence.

**License.** Content is licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/). Full text in [LICENSE](../LICENSE).
