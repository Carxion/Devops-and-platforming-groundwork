# Capability map: <platform or organization>

**Owner:** <platform product owner> | **As of:** <date>

The capabilities are the CNCF platforms white paper's. For each, record how teams get it today, from the users' side. "By ticket" and "each team builds its own" are the platform's opportunities.

| Capability | How teams get it today | Self-service? | On a golden path? | Wait or effort today | Priority |
|---|---|---|---|---|---|
| Web portals for provisioning and observing | <e.g. none> | <yes / partly / no> | <which> | <e.g. n/a> | <H / M / L> |
| APIs for provisioning | <e.g. Terraform modules, by merge request> | | | | |
| Golden path templates and documentation | <e.g. one template, outdated> | | | | |
| Building and testing automation | <e.g. each team's own pipeline> | | | | |
| Delivering and verifying services | <e.g. manual helm upgrades> | | | | |
| Development environments | <e.g. laptops; shared staging> | | | | |
| Application observability | <e.g. logs yes; metrics by request> | | | | |
| Infrastructure services | <e.g. namespaces by ticket> | | | | |
| Data services | <e.g. managed Postgres by ticket, 3 days> | | | | |
| Messaging and event services | <e.g. none supported> | | | | |
| Identity and secret services | <e.g. long-lived keys in CI variables> | | | | |
| Security services | <e.g. scans in some pipelines> | | | | |
| Artifact storage | <e.g. container registry, self-service> | | | | |

## Requests to the platform team, last <n> weeks

| Kind of request | Count | Median wait | Routine? | Self-service candidate? |
|---|---|---|---|---|
| <e.g. New namespace> | <23> | <2 days> | <yes: same answer each time> | <yes> |

## Fragmentation

| Thing | Ways teams do it today | Target |
|---|---|---|
| <e.g. CI pipelines for services> | <e.g. 12 distinct styles> | <one component> |
| <e.g. Kubernetes deploy> | <e.g. Helm (3 charts), Kustomize, raw kubectl> | <the platform chart> |
