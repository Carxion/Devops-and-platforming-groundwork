# Platform service: <capability, e.g. "the web-app Helm chart" or "managed Postgres">

**Owner:** <platform team> | **Status:** <beta / supported / deprecated> | **Current version:** <x.y.z> | **Updated:** <date>

## What it gives you

<Two or three sentences, as a user would describe it: "A production-ready deployment for an HTTP service: probes, autoscaling, a disruption budget, network policy, and ingress, from about ten lines of values.">

## How to use it

| | |
|---|---|
| Interface | <e.g. Helm chart at oci://registry.example.com/platform/charts/web-app> |
| Getting started | <link to the tutorial or golden path> |
| Reference | <link to the values table, inputs, or API docs> |
| Example | <link to a real service using it> |

## Versions and compatibility

- Versions follow semver. Within a major version, changes are backward compatible: new options get safe defaults, nothing is renamed or removed.
- Supported versions: <e.g. the latest two minor versions of the current major>
- How you hear about changes: <release notes link, channel, automated update merge requests>

## Service levels

| Objective | Target | Measured by |
|---|---|---|
| <e.g. Pipeline component success rate, excluding user errors> | <99.5% per month> | <pipeline events> |
| <e.g. Time to provision a database> | <95% under 15 minutes> | <provisioning events> |

Status and incidents: <link>

## Support

| Need | Where | Response |
|---|---|---|
| Question | <channel> | <same working day> |
| It's broken for my team | <platform on-call route> | <per severity> |
| Feature request | <issue tracker> | <triaged weekly> |

## What it doesn't do

- <e.g. Stateful workloads; use the managed database service>
- <e.g. Custom sidecars; open a request, or use the escape hatch below>

## Escape hatch

<How to step off for what this doesn't cover, and what support you keep.>

## Deprecation policy

<e.g. Deprecated versions keep working for at least six months after the announcement. Every team using one gets an update merge request before support ends.>
