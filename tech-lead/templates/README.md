# Templates

Copy-ready templates for the checklist's deliverables: the ones in [Appendix A](../README.md#appendix-a-templates), plus templates for the day-30, day-60, and day-90 outputs and for design and change work. Copy them into your program's approved systems before filling them in. Don't fill them in here.

| File | Use | README section |
|---|---|---|
| [stakeholder-map.csv](stakeholder-map.csv) | Everyone with authority over, dependency on, or influence on your work | [1.2](../README.md#12-build-a-stakeholder-map) |
| [first-conversation-questions.md](first-conversation-questions.md) | One copy per stakeholder one-on-one | [1.3](../README.md#13-run-first-conversations) |
| [findings-register.csv](findings-register.csv) | Classified, prioritized problem list | [2.4](../README.md#24-classify-each-problem)–[2.6](../README.md#26-present-findings) |
| [adr-template.md](adr-template.md) | One file per architecture decision (`adr/NNNN-title.md`) | [1.5](../README.md#15-set-up-communication-and-decision-making) |
| [weekly-status.md](weekly-status.md) | Status update to your manager and stakeholders | [1.4](../README.md#14-align-with-your-manager) |
| [system-inventory.csv](system-inventory.csv) | Every service, data store, pipeline, environment, and dependency, with an owner | [9, day 30](../README.md#by-day-30) |
| [metrics-baseline.csv](metrics-baseline.csv) | Baseline metrics with the method for each, and whether the team can move them | [2.2](../README.md#22-establish-a-baseline) |
| [risk-register.csv](risk-register.csv) | Risks as "if..., then...", scored likelihood × impact ([scoring scale](../assessing-an-inherited-system.md#7-score-the-risks)) | [9, day 30](../README.md#by-day-30) |
| [raci.csv](raci.csv) | Who's responsible, accountable, consulted, and informed for key decisions | [1.5](../README.md#15-set-up-communication-and-decision-making) |
| [findings-report.md](findings-report.md) | The day-60 readout: summary, what's working, top findings with evidence, priorities, asks | [2.6](../README.md#26-present-findings) |
| [roadmap.md](roadmap.md) | The day-90 roadmap: goals against the baseline, plan, capacity split, non-goals | [9, day 90](../README.md#by-day-90) |
| [rfc-design-doc.md](rfc-design-doc.md) | A design proposal for review before building: problem, proposal, security, operations, alternatives | [10](../README.md#10-best-practices) |
| [cutover-runbook.md](cutover-runbook.md) | A migration or cutover: roles, go/no-go, steps with verification, point of no return, rollback | [6](../README.md#6-continuous-delivery-and-deployment) |

Incident reviews use the [manager template](../../manager/templates/incident-review.md); the [manager templates](../../manager/templates/README.md) also include a team charter and an on-call policy.

## Findings register values

The CSV can't carry dropdowns, so use these values when you set up validation in a spreadsheet or tracker.

| Column | Allowed values |
|---|---|
| Symptom / cause | Symptom, Cause, Unknown |
| Constraint type | Removable, Relocatable, Evidence-automatable, Fixed |
| Impact | Security, Availability, Compliance, Cost, Delivery speed, Team health (more than one allowed) |
| Effort | S, M, L |
| Priority | P1 (active security or availability exposure), P2, P3, Not now |
| Status | Open, Agreed, In progress, Done, Won't fix |

The constraint types are defined in [2.4](../README.md#24-classify-each-problem). For "Won't fix", record why: deliberate non-goals are part of the findings.
