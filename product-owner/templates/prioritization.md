# Prioritization worksheet: <product>, <date>

Score items **relative to each other**, as a group with the team and, where useful, stakeholders. Show the worksheet to anyone who asks why an item is where it is.

## WSJF (weighted shortest job first)

From the Scaled Agile Framework. Best when deadlines, risk, and size vary a lot, which is common for platform work.

Scale for every column: 1, 2, 3, 5, 8, 13, 20. Give the smallest item in each column a 1, and score the others against it.

| Item | User or business value | Time criticality | Risk reduction or opportunity enablement | Cost of delay (sum) | Job size | WSJF (cost of delay ÷ size) |
|---|---|---|---|---|---|---|
| <item> | | | | | | |
| <item> | | | | | | |

- **User or business value:** how much users or the organization gain.
- **Time criticality:** does value fall, or cost rise, if we wait? Deadlines, end of support, teams blocked.
- **Risk reduction or opportunity enablement:** does it reduce a risk (security, outage) or unlock other work?
- **Job size:** effort, relative to the other items.

## RICE

Published by Intercom. Best for feature work where the number of users affected varies a lot.

| Item | Reach (users or teams per quarter) | Impact | Confidence | Effort (person-weeks) | RICE (reach × impact × confidence ÷ effort) |
|---|---|---|---|---|---|
| <item> | | | | | |
| <item> | | | | | |

- **Impact:** 3 massive, 2 high, 1 medium, 0.5 low, 0.25 minimal.
- **Confidence:** 100% (high), 80% (medium), 50% (low). Below 50%, do discovery first.

## Capacity split

Before ordering items, agree the split for the next quarter:

| Part | Share | Items |
|---|---|---|
| Run (incidents, requests, deadline-driven upgrades) | <measured, e.g. 35%> | <not scored: handled as it comes> |
| Improve (debt, reliability, toil reduction) | <e.g. 20%> | <top items by WSJF> |
| Build (toward the product goal) | <the rest> | <top items by WSJF or RICE> |

## Decisions

| Item | Decision | Reason | Told the requester? |
|---|---|---|---|
| <item> | <now / next / later / won't do> | <reason> | <yes, date> |
