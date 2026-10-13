# Templates

Copy-ready versions of the templates in [Appendix A](../README.md#appendix-a-templates). Copy them into your program's approved systems before filling them in. Don't fill them in here.

| File | Use | README section |
|---|---|---|
| [stakeholder-map.csv](stakeholder-map.csv) | Everyone with authority over, dependency on, or influence on your work | [1.2](../README.md#12-build-a-stakeholder-map) |
| [first-conversation-questions.md](first-conversation-questions.md) | One copy per stakeholder one-on-one | [1.3](../README.md#13-run-first-conversations) |
| [findings-register.csv](findings-register.csv) | Classified, prioritized problem list | [2.4](../README.md#24-classify-each-problem)–[2.6](../README.md#26-present-findings) |
| [adr-template.md](adr-template.md) | One file per architecture decision (`adr/NNNN-title.md`) | [1.5](../README.md#15-set-up-communication-and-decision-making) |
| [weekly-status.md](weekly-status.md) | Status update to your manager and stakeholders | [1.4](../README.md#14-align-with-your-manager) |

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
