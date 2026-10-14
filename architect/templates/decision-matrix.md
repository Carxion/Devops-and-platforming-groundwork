# Decision matrix: <decision>

**Owner:** <name> · **Decider:** <name> · **Date:** YYYY-MM-DD · **Related:** <RFC or ADR link>

A weighted comparison makes trade-offs explicit and arguable. It doesn't make the decision for you: if the result feels wrong, find out which weight or score you disagree with, and why. Agree the criteria and weights **before** scoring the options, so the scoring can't be tuned toward a favorite.

## The question

<One sentence: what are we choosing between, for what purpose?>

## Must-haves

Options that fail any of these are out, whatever their score.

- [ ] <e.g. Supports single sign-on through our identity provider>
- [ ] <e.g. Data stays in an approved region>

## Criteria and weights

Weights add up to 100. Derive them from the quality attributes and constraints, not from the options.

| Criterion | What good looks like | Weight |
|---|---|---|
| <e.g. Operational effort> | <e.g. Managed, no servers to patch> | <25> |
| <e.g. Cost at expected scale> | <e.g. Under a set amount per month at 3x load> | <20> |
| <e.g. Security and compliance fit> | | <20> |
| <e.g. Team skills and learning curve> | | <15> |
| <e.g. Reversibility and exit cost> | | <10> |
| <e.g. Ecosystem and support> | | <10> |
| **Total** | | **100** |

## Scores

Score each option 1 (poor) to 5 (excellent) per criterion, with the evidence for the score. Weighted score = weight × score; the maximum total is 500.

| Criterion | Weight | Option A: <name> | Option B: <name> | Option C: do nothing / current |
|---|---|---|---|---|
| | | score (weighted) | score (weighted) | score (weighted) |
| | | | | |
| **Total** | **100** | | | |

## Evidence and notes

<For each score, the reasoning or source: trial results, pricing calculations, documentation, reference customers. A score without evidence is an opinion.>

## Sensitivity

Would a reasonable change to the weights change the winner? Try the two or three weightings different stakeholders would favor.

| Weighting | Winner |
|---|---|
| As above | |
| <e.g. Cost doubled in weight> | |
| <e.g. Operational effort halved> | |

If the winner changes easily, the decision depends on a judgment about priorities: name it, and let the decider make it explicitly.

## Recommendation

<The recommended option, the main reasons, the main risks, and what would make us revisit the decision. Record the outcome as an ADR.>
