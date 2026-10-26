# Proof of concept: <the question in a few words>

**Owner:** <solutions architect> | **Customer contact:** <role> | **Start:** <date> | **End (time box):** <date> | **Status:** <planned / running / complete>

A proof of concept answers one specific question that can't be answered on paper. It isn't a pilot, and it isn't a free first phase. Agree this page with the customer before any work starts.

## The question

One sentence: what we're trying to find out.

> <e.g. Can orders be replicated from the current database to the new one with under 5 minutes' lag at the nightly peak?>

## Why it matters

Which decision depends on the answer, and what happens if we're wrong.

- <e.g. Option B depends on running both databases side by side during migration. If replication can't keep up, Option B needs a weekend outage for cutover, which the business has ruled out.>

## Success criteria

Agreed with the customer before starting. Measurable, with the conditions under which they're measured.

| Criterion | Target | Measured how | Result |
|---|---|---|---|
| <e.g. Replication lag at peak> | <under 5 minutes, 95th percentile> | <replication metrics over 3 nightly runs> | |
| <e.g. Data consistency after cutover> | <row counts and checksums match> | <comparison script> | |

## Scope

- **In:** <the minimum needed to answer the question>
- **Out:** <everything else, especially production hardening, full data volumes if not needed, other features>

## Environment and data

- **Where:** <sandbox account or subscription, owned by whom>
- **Data:** <synthetic or masked; never real personal data without the customer's written approval and controls>
- **Access needed:** <from whom, by when>

## People and time

| Who | Role | Time |
|---|---|---|
| <…> | <builds it> | <days> |
| <customer role> | <provides access, reviews results> | <hours> |

## At the end

What happens with each outcome, agreed in advance:

- **Criteria met:** <e.g. proceed with Option B in the proposal>
- **Partly met:** <e.g. review with the customer; adjust the design or the cutover plan>
- **Not met:** <e.g. recommend Option A>

And what happens to the POC itself: <torn down by <date> / kept as a reference, not promoted to production>.

## Result

Filled in at the end.

- **Outcome:** <met / partly met / not met>
- **What we learned:** <…>
- **Effect on the design:** <…>
- **Evidence:** <link to measurements, scripts, screenshots>
