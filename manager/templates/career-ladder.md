# Career ladder: platform, DevOps, and SRE engineers

A starting point for writing your own. Adapt the levels, titles, and examples to your organization, and agree them with your peers and HR before using them in reviews. See [Running the team](../01-running-the-team.md#expectations).

Each level includes everything in the levels below it. People are assessed on sustained behavior over several months, not single moments, and nobody needs to show every example at a level.

## Summary

| Level | Scope | Independence | Typical title |
|---|---|---|---|
| L1 | Well-defined tasks | Needs guidance on approach and review of most work | Engineer I / Associate |
| L2 | Features and components | Works independently on defined problems; asks for help at the right time | Engineer II |
| L3 | Systems and services owned by the team | Defines how to solve ambiguous problems; trusted to lead projects | Senior engineer |
| L4 | Several teams or a platform area | Sets technical direction for an area; multiplies others' work | Staff engineer |
| L5 | The organization's platform and practices | Shapes direction across the organization | Principal engineer |

## Dimensions

### Technical skill

| Level | Looks like |
|---|---|
| L1 | Writes and changes infrastructure code, scripts, and pipelines with review. Follows runbooks. Uses the [shell](../../devops/bash/README.md) and [containers](../../software/containers/docker/README.md) confidently for daily tasks. |
| L2 | Builds components end to end: a Terraform module, a pipeline, a service's monitoring. Debugs across layers (network, OS, container, application) to find causes, not just symptoms. |
| L3 | Designs systems that are secure, observable, and operable by default. Anticipates failure modes, capacity, and cost. Their reviews make others' designs better. |
| L4 | Solves problems that span teams: platform architecture, migrations, standards. Chooses when not to build. Their designs are adopted beyond their team. |
| L5 | Sets the technical strategy for the platform. Makes the few big decisions that shape years of work, with sound reasoning others can follow. |

### Operations and reliability

| Level | Looks like |
|---|---|
| L1 | Joins on-call with backup. Escalates appropriately. Keeps runbooks current as they use them. |
| L2 | Handles most incidents alone. Writes clear incident timelines. Fixes the alerts and runbooks that let the team down. |
| L3 | Leads incident response and blameless reviews. Defines SLOs for services. Removes classes of incidents, not just instances. |
| L4 | Shapes reliability practice across teams: alerting standards, incident process, capacity planning. |
| L5 | Sets reliability strategy and the trade-offs between reliability, speed, and cost at the organization level. |

### Delivery and ownership

| Level | Looks like |
|---|---|
| L1 | Finishes tasks reliably, with tests and documentation. Raises blockers early. |
| L2 | Owns features from design through operation. Breaks work into small, shippable pieces. Estimates their own work well. |
| L3 | Leads projects of several people to completion. Manages scope, risk, and stakeholders. Says no with reasons. |
| L4 | Leads multi-team initiatives and migrations. Aligns teams on a plan and sees it through. |
| L5 | Drives organization-wide change programs. |

### Collaboration and leadership

| Level | Looks like |
|---|---|
| L1 | Asks good questions, takes feedback well, helps teammates. |
| L2 | Gives useful code and design reviews. Helps onboard new hires. Communicates clearly in writing. |
| L3 | Mentors others. Builds consensus on technical decisions. Represents the team to other teams and stakeholders. |
| L4 | Grows senior engineers. Influences without authority across teams. Writes the documents others refer to. |
| L5 | Develops technical leaders. Represents engineering to leadership and external parties. |

## Using it

- Share it with the team. Expectations that only the manager knows aren't expectations.
- In reviews and promotion cases, cite specific examples against these behaviors, from the whole period.
- Recognize operational and maintenance work (upgrades, alert cleanup, documentation) as real contributions at every level. On platform teams it's most of the job.
