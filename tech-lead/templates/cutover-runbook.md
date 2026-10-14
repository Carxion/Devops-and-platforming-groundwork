# Cutover runbook: <what is moving, from where to where>

**Change ID:** <ticket or change record> · **Window:** YYYY-MM-DD HH:MM to HH:MM UTC · **Lead:** <name> · **Status:** Draft / Approved / Done / Rolled back

## Summary

<One paragraph: what changes, why, who's affected, and what users will notice during and after.>

## Roles

| Role | Name | Reachable at |
|---|---|---|
| Cutover lead (makes the go/no-go and rollback calls) | | |
| Executor(s) | | |
| Verifier (checks each step independently) | | |
| Communications | | |
| Owners of affected systems | | |
| Escalation (manager, vendor support) | | |

## Before the window

- [ ] Change approved: <reference>
- [ ] Rehearsed end to end in a non-production environment on YYYY-MM-DD, including the rollback. Timings recorded below.
- [ ] Backups taken and a restore tested: <what, where>
- [ ] Stakeholders and users notified: <channels, dates>
- [ ] Monitoring and dashboards ready to watch: <links>
- [ ] Access confirmed for everyone executing (test it, don't assume it)
- [ ] DNS TTLs lowered ahead of time, if DNS changes (at least one old TTL before the window)
- [ ] Freeze on unrelated changes to affected systems

## Go/no-go criteria

Checked at <time>, before step 1. Any "no" means we stop and reschedule.

- [ ] All pre-window items done
- [ ] No open incidents on affected or dependent systems
- [ ] All roles present
- [ ] <system-specific checks, e.g. replication lag under N seconds>

## Steps

| # | Step (exact commands or actions) | Who | Expected result | Verify by | Rehearsal time | Actual start | Done |
|---|---|---|---|---|---|---|---|
| 1 | | | | | | | |
| 2 | | | | | | | |

**Point of no return:** after step <N>, rollback means <what it means, e.g. data written to the new system must be copied back>. Get explicit go-ahead from the cutover lead before passing it.

## Verification after cutover

- [ ] <smoke tests, e.g. the API smoke test against the new endpoint>
- [ ] <key business transactions work end to end>
- [ ] Error rates and latency normal on the dashboards for <N> minutes
- [ ] No new alerts

## Rollback

**Trigger:** roll back if <criteria, e.g. verification fails, or error rate above X% for Y minutes>, or at <time> if not complete.

| # | Rollback step | Who | Verify by |
|---|---|---|---|
| 1 | | | |

## Communications

| When | Message | Channel | Sent by |
|---|---|---|---|
| Start | | | |
| Done or rolled back | | | |

## Afterward

- [ ] Old system kept read-only until <date>, then decommissioned per <plan>
- [ ] Lessons recorded: what went to plan, what didn't, timings versus rehearsal
- [ ] Documentation, runbooks, and diagrams updated
