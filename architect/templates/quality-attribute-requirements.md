# Quality attribute requirements: <system or service>

**Owner:** <name> · **Agreed with:** <business owner, security, operations> · **Date:** YYYY-MM-DD · **Tier:** <1 critical / 2 important / 3 internal>

Non-functional requirements, written so they can be designed for and tested. Each is a **scenario**: a stimulus, the conditions, and a measurable response. "Highly available" is not testable; "99.9% of requests succeed over 30 days" is. See [Thinking like an architect](../01-thinking-like-an-architect.md#start-from-quality-attributes).

## Summary targets

| Attribute | Target | Measured by | Verified how |
|---|---|---|---|
| Availability | <e.g. 99.9% of requests succeed, 30-day window> | <load balancer success ratio> | <SLO dashboard and burn-rate alerts> |
| Latency | <e.g. p95 under 300 ms, p99 under 800 ms> | <request duration histogram> | <k6 thresholds in CI; SLO alerts> |
| Throughput | <e.g. 500 requests/s sustained, 1,500 peak> | <request rate> | <load test before release> |
| RTO | <e.g. 1 hour> | <time from declared disaster to service restored> | <failover game day, twice a year> |
| RPO | <e.g. 5 minutes> | <data loss window> | <restore test, quarterly> |
| Security | <e.g. no critical vulnerabilities older than 30 days> | <scanner> | <CI gate and dashboard> |
| Operability | <e.g. every alert has a runbook; new engineer deploys in week one> | <review> | <architecture review; onboarding feedback> |
| Cost | <e.g. under X per thousand orders> | <cost allocation by tag> | <monthly unit cost report> |
| Compliance | <e.g. data stays in region; audit logs kept N years> | <policy> | <preventive guardrail; audit> |

## Scenarios

One row per important behavior. Add as many as the design needs.

| # | Attribute | Stimulus | Conditions | Expected response | Measure |
|---|---|---|---|---|---|
| Q-01 | Availability | One availability zone fails | Normal load | Service continues; no manual action needed | Error rate stays under SLO; no page needed beyond notification |
| Q-02 | Performance | Traffic triples within 5 minutes | Autoscaling enabled | Capacity scales without dropping requests | p95 stays under 500 ms; no 5xx |
| Q-03 | Recoverability | The primary database is deleted by mistake | Point-in-time recovery enabled | Data restored to before the mistake | Restored within RTO, with at most RPO of data lost |
| Q-04 | Security | An application's credentials leak | Workload identity in use | Leaked material is short-lived or useless outside the workload | No long-lived secret exists to leak; access logged |
| Q-05 | Deployability | A bad release reaches production | Canary deployment with SLO checks | Rollback happens automatically | Rolled back within 10 minutes; under 5% of users affected |
| Q-06 | | | | | |

## Out of scope

<Failures or conditions explicitly not designed for, and who accepted that: e.g. "loss of the entire cloud provider: accepted by <owner> on <date>".>

## Change log

- YYYY-MM-DD: <what changed, why, and who agreed>
