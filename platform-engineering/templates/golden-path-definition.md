# Golden path: <the thing it does, e.g. "a new Python HTTP service, to production">

**Owner:** <platform team> | **Designed with:** <two or three product teams> | **Status:** <draft / beta / supported> | **Version:** <n> | **Reviewed:** <date>

## Who it's for

| For | Not for |
|---|---|
| <e.g. Stateless HTTP services in Python, on the shared Kubernetes clusters> | <e.g. Batch jobs, services with GPUs, anything stateful in the cluster> |

How many teams this covers today: <number, and how you know>

## The journey today, without it

| Step | Today | How long | Who's involved |
|---|---|---|---|
| <e.g. Create repository and pipeline> | <copy another team's, adapt> | <2 days> | <the team, by asking around> |
| <e.g. Get a namespace> | <ticket to the platform team> | <3 days> | <platform team> |
| **Total, idea to production** | | <e.g. 9 days> | |

## What the path gives

| Step | On the path | How long |
|---|---|---|
| <e.g. Create the service> | <`copier copy` with four questions> | <minutes> |
| <e.g. First deploy to dev> | <merge to main; the pipeline deploys> | <under an hour> |

## What it decides, and why

| Decision | Choice | Why (in the users' terms) |
|---|---|---|
| <e.g. Language and runtime> | <Python 3.14, FastAPI> | <supported, patched, and the platform's libraries work with it> |
| <e.g. Deploy method> | <the platform's web-app chart, values in deploy/> | <hardened manifests you don't maintain; rollbacks built in> |

## What the team still owns

- <e.g. The application code, tests, and dependencies>
- <e.g. Values for each environment>
- <e.g. On-call for the service>

## Escape hatches

| Step off by | Keep | Lose |
|---|---|---|
| <e.g. Your own Dockerfile> | <pipeline, scanning, deploy> | <platform image updates; you patch the base> |

Guardrails that apply on and off the path: <e.g. Pod Security restricted, image scanning, default-deny network policy>

## Keeping services current

- References (updated by version bump): <e.g. CI/CD component, web-app chart>
- Template updates: <e.g. `copier update`; the platform opens update merge requests monthly>
- Measure: <e.g. share of services on the latest template and chart versions>

## Support

| | |
|---|---|
| Where to ask | <channel> |
| Response time | <e.g. same working day> |
| When it breaks for a team | <e.g. platform on-call, severity per the platform's SLOs> |
| Docs and tutorial | <link> |

## How we'll know it works

| Measure | Baseline | Target | Source |
|---|---|---|---|
| <Time to first deploy for a new service> | <9 days> | <1 day> | <pipeline and repository events> |
| <Teams on the path> | <0> | <8 by end of quarter> | <catalog> |
| <Satisfaction with the path> | <n/a> | <4 of 5> | <survey> |
