# Definition of done: <team>

**Agreed:** <date> | **Applies to:** every item in an increment, unless noted

The Scrum Guide makes the definition of done the commitment for the increment: an item that doesn't meet it isn't done, and isn't shown in the sprint review as done. For platform and infrastructure work, "done" has to include running it, not only building it.

## Code and configuration

- [ ] Changes are in version control and reviewed by at least one other person
- [ ] The pipeline passes: formatting, linting, tests, and security scans
- [ ] Infrastructure changes were planned and the plan was reviewed (`terraform plan`, `--check --diff`, `what-if`)
- [ ] No secrets in code, configuration, or logs
- [ ] Tests cover the change, including the failure path where it matters

## Deployed and running

- [ ] Deployed to production (or to every environment it's meant for), through the pipeline, not by hand
- [ ] Rolled out safely: canary, a batch at a time, or behind a feature flag, as fits the risk
- [ ] Rollback was tested, or the rollback plan is written down

## Operable

- [ ] Monitored: metrics and logs exist, and there's an alert for user-facing failure (tied to an SLO where one exists)
- [ ] A runbook exists or was updated for anything the on-call engineer might need to do
- [ ] Dashboards updated if behavior changed
- [ ] Capacity and cost checked for anything that scales or costs money

## Usable

- [ ] Documentation for the people who use it: how to use it, its limits, and where to get help
- [ ] Users were told: release notes, a message in their channel, or the sprint review
- [ ] Old ways of doing the same thing are deprecated, with a date, or a reason to keep them

## Exceptions

Items that can't meet a line (a spike, a document-only change) say so in the item, with the reason. If the team often can't meet a line, change the definition in a retrospective rather than skipping it quietly.
