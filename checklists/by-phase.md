# Checklist by phase

<!-- Generated from README.md by scripts/build_checklists.py. Do not edit by hand. -->

Every item from the [onboarding checklist](../README.md), regrouped by when it is due. Section context and the reasoning behind each item live in the README; this view is for working through a phase.

## W1: First week

17 items.

### 0. Access and logistics

- [ ] `0-01` Confirm your role, title, and reporting line in writing, including who you are accountable to on the customer or business side.
- [ ] `0-02` Complete required security, privacy, and acceptable-use training before requesting privileged access.
- [ ] `0-03` Request access by role, not by copying a coworker's permissions. Record every access request and who approved it.
- [ ] `0-04` Get read-only access to everything first: source control, CI/CD, cloud consoles, ticketing, wiki, monitoring, scan results. Request write/admin access separately, only where the role needs it.
- [ ] `0-05` Set up MFA everywhere it's available. Confirm you have no shared or group credentials.
- [ ] `0-06` Learn the break-glass and emergency-access procedure before you ever need it.
- [ ] `0-07` Get added to the right distribution lists, chat channels, on-call rotations, and recurring meetings. Ask which meetings you can safely skip.
- [ ] `0-08` Locate the canonical documentation: architecture diagrams, runbooks, security and compliance documentation (if it exists), onboarding docs. Note when each was last updated.

### 1. Stakeholders and management › 1.1 Understand what the program is obligated to deliver

- [ ] `1.1-01` Read the governing document: the customer contract or statement of work for client engagements, or the charter, funding approval, or OKRs for internal programs.
- [ ] `1.1-02` List the formal deliverables, due dates, and acceptance criteria, including required documents and reports.

### 1. Stakeholders and management › 1.2 Build a stakeholder map

- [ ] `1.2-01` List everyone with authority over, dependency on, or influence on your work. Use the [stakeholder map template](../README.md#a1-stakeholder-map).

### 1. Stakeholders and management › 1.4 Align with your manager

- [ ] `1.4-01` Ask what success looks like at 30, 90, and 180 days, in their words.
- [ ] `1.4-02` Clarify your decision rights: what you can decide alone, what needs consultation, what needs approval.

### 1. Stakeholders and management › 1.6 Understand your team

- [ ] `1.6-01` Schedule one-on-ones with each engineer. Ask about their work, frustrations, career goals, and what they want from a lead.

### 3. Cloud › 3.1 Account and organization structure

- [ ] `3.1-01` Get the list of accounts/subscriptions/projects, what each one is for, and who owns it.

### 3. Cloud › 3.2 Identity and access

- [ ] `3.2-01` Confirm human access is federated through single sign-on with MFA.

### 7. DevSecOps › 7.1 Governance and compliance

- [ ] `7.1-01` Identify which frameworks and obligations apply: for example ISO/IEC 27001, SOC 2, PCI DSS, HIPAA, GDPR, or internal policy.

## 30: By day 30

99 items.

### 0. Access and logistics

- [ ] `0-09` Walk the path a new developer takes from "account created" to "first change deployed." Time it and record every blocker.

### 1. Stakeholders and management › 1.1 Understand what the program is obligated to deliver

- [ ] `1.1-03` Identify service-level commitments (availability, response times, patch timelines) and whether they are being met today.
- [ ] `1.1-04` Learn how the program is judged: contract incentives or penalties, performance reviews, customer satisfaction surveys, audit results.
- [ ] `1.1-05` Learn the contract term, renewal dates, or budget cycle. Timing drives what the program is willing to invest in.
- [ ] `1.1-06` Know what's in scope and what isn't. Scope creep usually arrives as a "quick favor" to the tech lead.

### 1. Stakeholders and management › 1.2 Build a stakeholder map

- [ ] `1.2-02` Cover at least these roles (titles vary):
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
- [ ] `1.2-03` For each stakeholder, record what they need from you, what you need from them, and how they prefer to communicate.

### 1. Stakeholders and management › 1.3 Run first conversations

- [ ] `1.3-01` Meet every key stakeholder one-on-one within 30 days. Use the same core questions with each (see [A.2](../README.md#a2-first-conversation-questions)) so answers are comparable.
- [ ] `1.3-02` Listen more than you talk. Don't promise fixes in first meetings.
- [ ] `1.3-03` Ask each person: what is working well that I should protect?
- [ ] `1.3-04` Follow up in writing with what you heard and anything you committed to.

### 1. Stakeholders and management › 1.4 Align with your manager

- [ ] `1.4-03` Ask what they are hearing about the team from above and from the customer.
- [ ] `1.4-04` Agree on a status format and cadence (see [A.5](../README.md#a5-weekly-status)).
- [ ] `1.4-05` Agree on how you'll raise bad news. Commit to raising it early.

### 1. Stakeholders and management › 1.5 Set up communication and decision-making

- [ ] `1.5-01` Establish a written decision log. Record the decision, the alternatives considered, who decided, and the date. Use Architecture Decision Records for technical decisions [ADR].
- [ ] `1.5-02` Define a RACI (responsible, accountable, consulted, informed) for recurring decisions: production deploys, access grants, risk acceptance, architecture changes, vendor/tool selection.
- [ ] `1.5-03` Know the escalation path for technical, security, and schedule issues, and who owns each.

### 1. Stakeholders and management › 1.6 Understand your team

- [ ] `1.6-02` Build a skills matrix. Identify single points of knowledge (the "bus factor" for each critical system).
- [ ] `1.6-03` Understand workload and on-call burden. Look at after-hours pages and unplanned work.
- [ ] `1.6-04` Learn how work enters the team: tickets, chat requests, meetings, hallway asks. Unmanaged intake is a common cause of burnout.

### 2. Evaluating the program's problems › 2.1 Gather evidence before opinions

- [ ] `2.1-01` Read the last 6–12 months of incident reports and postmortems.
- [ ] `2.1-02` Review audit findings, open remediation plans, and risk-acceptance records.
- [ ] `2.1-03` Pull current vulnerability scan results and note the age of open findings by severity.
- [ ] `2.1-04` Review the ticket backlog: what's oldest, what keeps getting reopened, what's always deprioritized.
- [ ] `2.1-05` Pull pipeline data: build durations, failure rates, queue times.
- [ ] `2.1-06` Pull cost reports and the trend over the last several months.
- [ ] `2.1-07` Review the change or release calendar: how often, how big, how many rollbacks.

### 2. Evaluating the program's problems › 2.2 Establish a baseline

- [ ] `2.2-01` DORA software delivery metrics [DORA]:
  - Throughput: change lead time, deployment frequency, failed deployment recovery time
  - Instability: change fail rate, deployment rework rate
- [ ] `2.2-02` CI: median and 95th-percentile pipeline duration, queue time, and flaky-test rate.
- [ ] `2.2-03` Environment provisioning time (request to usable).
- [ ] `2.2-04` Time for a new engineer to ship a first change.
- [ ] `2.2-05` Vulnerability age and count by severity; count of findings in the known-exploited catalog [KEV].
- [ ] `2.2-06` Time from "change ready" to "change approved" through any review board or approval gate.
- [ ] `2.2-07` Toil: recurring manual work, estimated in hours per week.

### 2. Evaluating the program's problems › 2.3 Collect the pain inventory

- [ ] `2.3-01` Ask engineers, operators, and app teams the same three questions: what slows you down, what scares you, what do you work around?
- [ ] `2.3-02` Sample beyond the loudest voices. Include new hires, who still notice friction veterans have normalized.
- [ ] `2.3-03` Log each item as an observation, not a solution: "deploys require manual approval from three teams," not "we need GitOps."

### 3. Cloud › 3.1 Account and organization structure

- [ ] `3.1-02` Understand the organization hierarchy and which guardrails apply at each level (for example AWS Organizations service control policies).
- [ ] `3.1-03` Confirm workloads are separated by environment (prod, non-prod) and by sensitivity at the account level, not just by tags.
- [ ] `3.1-04` Identify which regions are in use and why (data residency, latency, cost, or service availability).
- [ ] `3.1-05` Check service quotas and limits that are close to being hit.

### 3. Cloud › 3.2 Identity and access

- [ ] `3.2-02` Inventory long-lived access keys and static credentials. Find out who owns each and when it was last rotated.
- [ ] `3.2-03` Review who holds administrator or equivalent roles. Compare against who actually needs them.
- [ ] `3.2-04` Confirm break-glass accounts exist, are monitored, and have been tested.

### 3. Cloud › 3.3 Network

- [ ] `3.3-01` Get or draw a current network diagram: VPCs/VNets, subnets, peering, transit, VPN or dedicated links to on-premises.
- [ ] `3.3-02` Understand internet egress: is it allowed, filtered, proxied, or absent?
- [ ] `3.3-03` Identify publicly exposed endpoints and confirm each is intended.
- [ ] `3.3-04` Understand DNS: who manages it, split-horizon setups, private zones.

### 3. Cloud › 3.4 Logging, encryption, and data protection

- [ ] `3.4-01` Confirm control-plane audit logging (for example CloudTrail) is on in every account and region, centralized, and protected from deletion by workload accounts.
- [ ] `3.4-02` Know the log retention requirements and whether they are met.
- [ ] `3.4-03` Understand key management: who can use, rotate, and delete encryption keys.
- [ ] `3.4-04` Identify where sensitive data lives and how it is classified.

### 3. Cloud › 3.5 Resilience and cost

- [ ] `3.5-01` Find the documented recovery point and recovery time objectives (RPO/RTO). Ask when a restore was last actually tested.
- [ ] `3.5-02` Confirm backups are isolated from the accounts they protect.
- [ ] `3.5-03` Check tagging coverage for cost allocation and ownership.

### 3. Cloud › 3.6 Shared responsibility

- [ ] `3.6-01` Understand which security controls are inherited from the cloud provider or an enterprise platform, and which your program must implement itself. Compliance programs usually document this in a shared-responsibility or control-inheritance matrix.

### 4. Infrastructure as Code

- [ ] `4-01` Inventory what is managed as code versus created by hand in consoles. Hand-built production resources are a finding.
- [ ] `4-02` Identify every IaC tool in use (Terraform/OpenTofu, CloudFormation, Pulumi, Ansible, Helm, etc.) and which one owns which resources.
- [ ] `4-03` Locate the state backend. Confirm it has locking, encryption, versioning, and restricted access. Remember state files can contain secrets in plain text.
- [ ] `4-04` Check how state is split. One giant state file means one mistake can reach everything.
- [ ] `4-05` Confirm provider and module versions are pinned.
- [ ] `4-06` Find out how applies happen: from a pipeline with reviewed plans, or from laptops?

### 5. Continuous Integration

- [ ] `5-01` Inventory pipelines, shared templates, and who maintains them.
- [ ] `5-02` Understand the runners: ephemeral or persistent, privileged or not, what networks they can reach, and who administers them. A persistent, privileged runner with broad network access is a high-value target.
- [ ] `5-03` Find where pipeline credentials come from. Prefer short-lived credentials via identity federation (OIDC) over secrets stored in CI variables.
- [ ] `5-04` Check branch protection: required reviews, required passing checks, who can bypass.
- [ ] `5-05` Measure where pipeline time goes, job by job. Look for serial jobs that could run in parallel, missing caches, and oversized test suites.
- [ ] `5-06` Identify flaky tests and how the team handles them (retries hide them; quarantine surfaces them).
- [ ] `5-07` Understand the branching model and how long branches live before merge.

### 6. Continuous Delivery and Deployment

- [ ] `6-01` Map every deployment path to production, including the unofficial ones.
- [ ] `6-02` Document environments and the promotion path between them. Note differences between staging and production that could hide defects.
- [ ] `6-03` Identify who can deploy to production and how that access is granted and logged.
- [ ] `6-04` Find out whether rollback exists, how long it takes, and when it was last used successfully.
- [ ] `6-05` Understand how database and schema migrations are handled, and whether they can be rolled back.
- [ ] `6-06` Map the change management process: who approves what, lead time for approval, and freeze windows.

### 7. DevSecOps › 7.1 Governance and compliance

- [ ] `7.1-02` Find the compliance status: which certifications or attestations the system holds (for example a SOC 2 report or an ISO certificate), when they expire or are next audited, and what exceptions apply.
- [ ] `7.1-03` Read the security and compliance documentation (control descriptions, risk register, open remediation items) that touches your platform.
- [ ] `7.1-04` Meet the security and compliance leads. Learn what evidence they collect, how, and how often.

### 7. DevSecOps › 7.2 Pipeline security controls

- [ ] `7.2-01` Inventory what scanning exists and where it runs: secrets detection, static analysis (SAST), dependency/software composition analysis (SCA), IaC scanning, container image scanning, dynamic testing (DAST).
- [ ] `7.2-02` For each scanner, find out: what blocks a build, what only warns, who triages results, and how false positives are suppressed.

### 7. DevSecOps › 7.3 Software supply chain

- [ ] `7.3-01` Confirm an SBOM is generated at build time for each released artifact, in a standard format (SPDX or CycloneDX), and stored alongside the artifact [SBOM].

### 7. DevSecOps › 7.4 Vulnerability management

- [ ] `7.4-01` Find the remediation SLAs by severity and check actual performance against them.
- [ ] `7.4-02` Check whether prioritization considers exploitation, not just CVSS score: CISA's Known Exploited Vulnerabilities catalog [KEV] and exploit-prediction scores such as EPSS [EPSS].

### 7. DevSecOps › 7.5 Platform and runtime hardening

- [ ] `7.5-01` Identify the hardening baselines in use (for example CIS Benchmarks [CIS]) and how compliance with them is checked.
- [ ] `7.5-02` For containers and Kubernetes: review RBAC, Pod Security Admission levels, network policies, admission control, and service account permissions. NIST SP 800-190 covers container-specific risks [800-190].
- [ ] `7.5-03` Confirm secrets are in a secrets manager, not in repos, images, or plain environment files.

### 8. Observability and operations

- [ ] `8-01` Inventory monitoring, logging, and tracing tools, and who owns each.
- [ ] `8-02` Review alerts: which ones page a human, and how many of those required action in the last month. Alerts that don't need action train people to ignore alerts.
- [ ] `8-03` Check whether service-level objectives (SLOs) exist and whether they reflect what users experience [SRE].
- [ ] `8-04` Review on-call: rotation size, page volume, after-hours load, and escalation.

### 9. 30/60/90-day deliverables

- [ ] `9-01` Stakeholder map and summary of first conversations
- [ ] `9-02` System inventory: accounts, pipelines, environments, deploy paths, tools, owners
- [ ] `9-03` Baseline metrics with the method used to collect each one
- [ ] `9-04` Top five risks, shared privately with your manager
- [ ] `9-05` Access review completed for your own permissions

### Appendix B: Restricted-network environments

- [ ] `B-01` How do new tools, packages, images, and updates enter the environment? Who approves each transfer, and how long does it take?
- [ ] `B-02` What mirrors and registries exist inside the boundary (container images, OS packages, language packages, IaC providers and modules), and how are they kept current?
- [ ] `B-03` How are vulnerability databases for scanners updated inside the boundary, and how stale are they allowed to get?
- [ ] `B-04` What changes require a formal security review or re-approval, and what can proceed under existing approvals?

## 60: By day 60

61 items.

### 1. Stakeholders and management › 1.2 Build a stakeholder map

- [ ] `1.2-04` Identify the informal influencers: the long-tenured engineer everyone asks, the security reviewer whose approval really matters.

### 1. Stakeholders and management › 1.3 Run first conversations

- [ ] `1.3-05` Look for disagreement between stakeholders about priorities. That disagreement is often the real problem you were hired to solve.

### 1. Stakeholders and management › 1.4 Align with your manager

- [ ] `1.4-06` Share your draft findings with your manager before any wider readout. No one should be surprised in a meeting.

### 1. Stakeholders and management › 1.5 Set up communication and decision-making

- [ ] `1.5-04` Stand up a regular stakeholder touchpoint (demo, review, or written update) that shows progress on the things they care about, not just the things engineers care about.
- [ ] `1.5-05` Translate technical risk into business terms: business impact, schedule, cost, audit exposure. "Unpatched base images" means little to a sponsor; "failed audit finding with a 30-day remediation clock" means a lot.

### 1. Stakeholders and management › 1.6 Understand your team

- [ ] `1.6-05` Agree on team working norms: code review expectations, definition of done, documentation, meeting load.
- [ ] `1.6-06` Check whether bad news reaches leadership. If engineers hide problems or learn about decisions secondhand, that's a finding (see Westrum's organizational culture typology [WESTRUM]).

### 2. Evaluating the program's problems › 2.2 Establish a baseline

- [ ] `2.2-08` Note which metrics can't be moved by the team at all. In environments with formal approval gates or restricted networks, some delivery levers (for example deploy frequency to production) are set by external gates. A low number there is a constraint to document, not a performance verdict.

### 2. Evaluating the program's problems › 2.4 Classify each problem

- [ ] `2.4-01` **Symptom or cause?** Slow pipelines are a symptom; the cause might be serial jobs, no caching, or undersized runners.
- [ ] `2.4-02` **Constraint type:**
  - *Removable*: nothing external requires it
  - *Relocatable*: required, but could move (earlier in the pipeline, into a platform layer, into a pre-approved standard change)
  - *Evidence-automatable*: required, but the manual evidence gathering around it can be generated by the pipeline
  - *Fixed*: required as-is by contract, policy, or law
- [ ] `2.4-03` **Owner:** who can actually change it? If it's not your team, the fix is a stakeholder conversation.
- [ ] `2.4-04` **Impact:** security, availability, compliance, cost, delivery speed, team health.
- [ ] `2.4-05` **Effort and risk** of fixing it.

### 2. Evaluating the program's problems › 2.5 Prioritize

- [ ] `2.5-01` Put active security exposure and availability risk first, regardless of effort.
- [ ] `2.5-02` Pick two or three low-effort, visible improvements to build trust early.
- [ ] `2.5-03` Rank the rest by impact relative to effort, and note dependencies between items.
- [ ] `2.5-04` State what you are deliberately *not* fixing yet, and why.

### 2. Evaluating the program's problems › 2.6 Present findings

- [ ] `2.6-01` Pre-brief your manager and the most affected stakeholders individually before any group readout.
- [ ] `2.6-02` Present: top problems with evidence, proposed priorities, what you need from each stakeholder, and what you are not doing.
- [ ] `2.6-03` Credit what the team did well. Findings that read as blame stop the flow of future information.

### 3. Cloud › 3.2 Identity and access

- [ ] `3.2-05` Check whether workloads and pipelines use short-lived, role-based credentials instead of stored keys.

### 3. Cloud › 3.3 Network

- [ ] `3.3-05` Check for private endpoints to cloud services versus traffic that routes over the internet.

### 3. Cloud › 3.5 Resilience and cost

- [ ] `3.5-04` Look for idle and orphaned resources: unattached volumes, old snapshots, stopped instances, unused load balancers and IPs.
- [ ] `3.5-05` Confirm budgets and cost-anomaly alerts exist and reach someone who acts on them.

### 4. Infrastructure as Code

- [ ] `4-07` Run a drift check. Note resources that differ from code and find out why.
- [ ] `4-08` Check whether plans are shown in merge requests and reviewed before apply.
- [ ] `4-09` Check for policy-as-code on IaC changes (for example OPA/Conftest, Checkov, or provider-native policy tools) and whether it blocks or only warns.
- [ ] `4-10` Review module structure: are shared modules versioned and released, or copied between repos?
- [ ] `4-11` For configuration management (for example Ansible), confirm runs are idempotent and repeatable, not one-time scripts.

### 5. Continuous Integration

- [ ] `5-08` Confirm third-party pipeline components (actions, includes, orbs, plugins) are pinned to an immutable version (commit SHA or digest), not a mutable tag.
- [ ] `5-09` Confirm dependencies are pulled through an approved proxy or mirror rather than directly from public registries, where policy requires it.
- [ ] `5-10` Check artifact storage: where build outputs live, retention, and whether artifacts are immutable once published.
- [ ] `5-11` Review pipeline definitions for secrets echoed to logs, overly broad permissions, and unreviewed changes to pipeline config itself. The OWASP Top 10 CI/CD Security Risks is a useful review list [OWASP-CICD].

### 6. Continuous Delivery and Deployment

- [ ] `6-07` Identify changes that could qualify as pre-approved standard changes. Moving routine, low-risk, well-tested deployments out of a full review board is often the biggest delivery improvement available without weakening control.
- [ ] `6-08` If using GitOps (for example Argo CD or Flux), confirm Git is really the source of truth: check for manual changes, sync drift, and who can override.
- [ ] `6-09` Check how configuration and secrets differ per environment and where they're stored.
- [ ] `6-10` Confirm automated smoke tests or health checks run after every deploy.

### 7. DevSecOps › 7.1 Governance and compliance

- [ ] `7.1-05` Identify manual compliance evidence that the pipeline could generate automatically: scan reports, SBOMs, approval records, configuration baselines.
- [ ] `7.1-06` Map existing secure development practices to the NIST Secure Software Development Framework [SSDF] to find gaps in a shared vocabulary.

### 7. DevSecOps › 7.2 Pipeline security controls

- [ ] `7.2-03` Check whether scan results reach developers where they work (merge requests) or only a dashboard nobody opens.
- [ ] `7.2-04` Check whether scanner rules and suppression lists are version-controlled and reviewed.
- [ ] `7.2-05` Measure how much time security stages add to the pipeline. Controls that make builds much slower get bypassed.

### 7. DevSecOps › 7.3 Software supply chain

- [ ] `7.3-02` Check whether artifacts are signed and whether signatures are *verified* at deploy time (for example by an admission controller). Signing without verification provides little protection.
- [ ] `7.3-03` Check for build provenance and assess the build platform against the SLSA Build track levels [SLSA].
- [ ] `7.3-04` Review base image policy: approved sources, update cadence, and who owns patching.
- [ ] `7.3-05` Treat security tools as supply-chain dependencies too. Pin and verify scanners and their plugins the same way you pin application dependencies.

### 7. DevSecOps › 7.4 Vulnerability management

- [ ] `7.4-03` Review the exception and risk-acceptance process. Every exception should have an owner, a justification, and an expiration date.
- [ ] `7.4-04` Check whether the team can state which vulnerabilities are *not* exploitable in their context and record that (for example with VEX statements) instead of re-triaging the same findings every scan.

### 7. DevSecOps › 7.5 Platform and runtime hardening

- [ ] `7.5-04` Check whether runtime detection exists and whether its alerts reach the SOC.

### 7. DevSecOps › 7.6 Threat modeling and incident response

- [ ] `7.6-01` Threat-model the delivery platform itself, not only the applications: source control, CI runners, artifact registry, deploy credentials. The pipeline has access to production.
- [ ] `7.6-02` Confirm incident response runbooks exist for the platform, with current contacts.

### 8. Observability and operations

- [ ] `8-05` Confirm runbooks exist for the most frequent alerts and have been used recently.
- [ ] `8-06` Confirm postmortems are blameless, written, and produce tracked action items that get closed.
- [ ] `8-07` Check capacity planning for clusters, registries, and runners.

### 9. 30/60/90-day deliverables

- [ ] `9-06` Findings register, classified and prioritized
- [ ] `9-07` Findings readout delivered to stakeholders after individual pre-briefs
- [ ] `9-08` Two or three quick wins shipped and measured against the baseline
- [ ] `9-09` Decision log and RACI in use

### Appendix B: Restricted-network environments

- [ ] `B-05` Which DORA and developer-experience metrics are bounded by external gates? Report those as constraints, with the gate owner, rather than as team performance.
- [ ] `B-06` Are signatures and SBOMs verified again at the boundary crossing, not just at build time?
- [ ] `B-07` Where can a control be relocated or its evidence automated, given that removal is usually not an option?

## 90: By day 90

13 items.

### 2. Evaluating the program's problems › 2.6 Present findings

- [ ] `2.6-04` Convert agreed findings into a roadmap with owners and dates.

### 4. Infrastructure as Code

- [ ] `4-12` Plan to import or rebuild hand-created resources into code, starting with production.

### 5. Continuous Integration

- [ ] `5-12` Build once, promote the same artifact through environments. Rebuilding per environment means you never deploy what you tested.

### 6. Continuous Delivery and Deployment

- [ ] `6-11` Evaluate progressive delivery (canary, blue/green, feature flags) where the platform and risk profile support it.
- [ ] `6-12` Confirm every production deploy leaves an audit trail: what changed, who approved, what artifact, when.

### 7. DevSecOps › 7.3 Software supply chain

- [ ] `7.3-06` Evaluate the health of critical open-source dependencies (for example with OpenSSF Scorecard [SCORECARD]).

### 7. DevSecOps › 7.6 Threat modeling and incident response

- [ ] `7.6-03` Run or join a tabletop exercise that includes a CI/CD or supply-chain compromise scenario. NIST SP 800-204D covers integrating supply-chain security into CI/CD pipelines [800-204D].

### 9. 30/60/90-day deliverables

- [ ] `9-10` Roadmap agreed with stakeholders, with owners, dates, and explicit non-goals
- [ ] `9-11` First Architecture Decision Records written for the major roadmap choices
- [ ] `9-12` Metrics dashboard or recurring report showing the baseline and trend
- [ ] `9-13` Team working agreements documented
- [ ] `9-14` Your own 90-day retrospective: what you got wrong, what you'd change

### Appendix B: Restricted-network environments

- [ ] `B-08` Is there an approved path to continuous compliance for the platform (evidence generated automatically instead of periodic re-approval), if the organization supports one?
