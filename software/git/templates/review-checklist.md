# Code review checklist

A checklist for reviewers, to copy into a team's contribution guidelines and adapt. Not every item applies to every change; the first sections matter most.

## Design

- [ ] The change solves the problem stated in the description (and the problem is worth solving)
- [ ] It's the simplest approach that works; nothing is built for needs we don't have yet
- [ ] It fits the existing architecture, or the description explains why it departs from it (an ADR for big departures)

## Correctness

- [ ] Edge cases are handled: empty, missing, very large, duplicate, and out-of-order input
- [ ] Errors are handled where they can be, and reported with enough context where they can't
- [ ] Concurrent use is safe: shared state, retries, and duplicate requests
- [ ] Time zones, character encodings, and units are explicit

## Security

- [ ] Input from users, files, and other services is validated
- [ ] Every new endpoint or action checks authorization, not just authentication
- [ ] No secrets in code, config, tests, or logs; no customer data in logs
- [ ] No injection: queries are parameterized, and shell commands and templates don't take raw input
- [ ] New dependencies are needed, maintained, and licensed acceptably

## Operability

- [ ] Failures will be visible: logs with context, metrics, and alerts where needed
- [ ] The change can be rolled back, or the rollout plan says how to recover
- [ ] Migrations are backward compatible with the running version (expand, then contract)
- [ ] Timeouts, retries, and limits are set for every call to another system
- [ ] Runbooks and dashboards are updated if behavior changed

## Tests

- [ ] Tests cover the new behavior and the bug being fixed
- [ ] The tests would fail if the code were wrong
- [ ] Tests are reliable: no sleeps, no dependence on order, time, or the network

## Readability

- [ ] Names say what things are and do
- [ ] Comments explain why, where the code can't
- [ ] A new team member could follow it

## Comment labels

| Label | Meaning |
|---|---|
| `issue:` | Must be fixed before merging |
| `suggestion:` | Worth considering; the author decides |
| `question:` | Asking to understand, not asking for a change |
| `nit:` | Trivial and optional |
| `praise:` | Something done well |
