# RFC-NNNN: <Title>

**Author:** <name> · **Reviewers:** <names, including someone from each affected team> · **Created:** YYYY-MM-DD · **Review closes:** YYYY-MM-DD · **Status:** Draft / In review / Accepted / Rejected / Superseded

Use an RFC for a change that crosses team boundaries, is expensive to reverse, or needs agreement before work starts. For a decision already made, an [ADR](adr-template.md) records it more briefly.

## Problem

<What's wrong or missing, for whom, with evidence. Link the findings it addresses. Someone who reads only this section should understand why it matters.>

## Goals and non-goals

**Goals:**

-

**Non-goals** (explicitly out of scope):

-

## Proposal

<The design: components, data flow, interfaces, and how it fits the existing system. A diagram helps. Enough detail that a reviewer can find the flaws.>

### Security and compliance

<Identities and permissions, data handled and its classification, new network paths, secrets, logging and audit, and any approvals or reviews required.>

### Operations

<How it's deployed, monitored, alerted on, backed up, and supported; who's on call for it; what the runbook needs.>

### Cost

<Expected cost and how it scales, including people's time to run it.>

### Migration and rollout

<How existing users or systems move to it, in what stages, and how to roll back each stage. For a cutover, attach a [cutover runbook](cutover-runbook.md).>

## Alternatives considered

| Option | Pros | Cons | Why not chosen |
|---|---|---|---|
| Do nothing | | | |
| | | | |

## Risks and open questions

| Risk or question | Likelihood and impact | How we'll find out or mitigate |
|---|---|---|
| | | |

## Success measures

<How we'll know it worked, against which baseline, and when we'll check.>

## Decision

<Filled in when review closes: accepted, rejected, or changed, by whom, and the reasons. Record the decision as an ADR.>
