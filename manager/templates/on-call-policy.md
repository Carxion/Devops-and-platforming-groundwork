# On-call policy: <team name>

**Owner:** <manager> · **Last reviewed:** YYYY-MM-DD

What on-call means on this team, so expectations are written down rather than assumed. See [On-call and team health](../04-on-call-and-team-health.md).

## Scope

- **Services covered:** <list, with links to runbooks and dashboards>
- **Hours:** <24x7 / business hours plus best effort / follow-the-sun with regions>
- **Not covered:** <e.g. other teams' services; requests that can wait for working hours>

## Rotation

- **Length:** one week, handing over on <day and time, in UTC>
- **Roles:** primary and secondary. Secondary takes pages the primary can't acknowledge within <N> minutes, and helps with large incidents.
- **Frequency:** nobody on call more than one week in <four to six>. If the rotation is smaller, that's a staffing problem to raise, not a reason to rotate more often.
- **Swaps:** arranged between engineers and recorded in <the paging tool>; tell the manager.
- **Eligibility:** after <shadowing one rotation and completing onboarding>.

## Expectations

| | Expectation |
|---|---|
| Acknowledge a page | Within <5> minutes |
| Start working on it | Within <15> minutes, from wherever you can work securely |
| Availability | Reachable, sober enough to work, able to get online within <15> minutes |
| Escalate | When the fix is beyond you, after <30> minutes without progress, or for any customer-facing severity 1. Escalating early is expected, not a failure. |
| Hand over | A written handover at the end of the rotation: open issues, flaky alerts, changes in flight |

## Escalation path

1. Primary on-call
2. Secondary on-call
3. <Team manager or tech lead>
4. <Incident commander rotation or senior leadership, for major incidents>
5. <Vendor and cloud provider support: contract numbers and how to open a case>

## Compensation and recovery

- **Compensation:** <pay or time off for being on call, per organization policy>
- **After a night page:** start late or take the morning. This is the default, not something to ask for.
- **After a heavy week:** <e.g. a recovery day>

## Alert standards

Every alert that pages:

- needs a human, right now
- is about something users would notice
- links to a runbook that says what to do

Alerts that don't meet these are fixed or removed at the weekly operational review.

## Health measures

Reviewed monthly: pages per shift, pages outside working hours, time to acknowledge, and incidents with review actions still open. Target: <e.g. no more than two incidents per 12-hour shift>.
