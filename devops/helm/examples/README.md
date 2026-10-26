# Helm examples

[← Helm](../README.md)

Three charts and the values to deploy them, checked in the [lab](../lab/README.md): linted, rendered and validated for every environment, unit tested, and installed, upgraded, rolled back, and published on a kind cluster with Pod Security "restricted" and default-deny networking.

| Path | What it is |
|---|---|
| [charts/platform-lib](charts/platform-lib/) | A library chart: names and recommended labels, the digest-pinned image reference, the hardened pod and container security contexts, a token-less service account, a PDB, and the DNS egress rule ([Library charts](../04-libraries-and-dependencies.md)) |
| [charts/web-app](charts/web-app/) | An HTTP service: probes, graceful shutdown, zone and node spreading, an HPA (or fixed replicas), a PDB, a ConfigMap that rolls pods when it changes, a NetworkPolicy that opens only what ingress needs, an Ingress for any controller, a values schema, a `helm test` hook, and 24 unit tests |
| [charts/worker](charts/worker/) | A background worker: a heartbeat liveness probe, a 60-second shutdown window, no inbound traffic, and egress only where it's configured, with 5 unit tests |
| [environments/](environments/) | Values for `dev` (one replica, no ingress), `prod-eks` (ALB ingress), and `prod-aks` (app routing ingress with a Key Vault certificate, workload identity) |
| [publish-charts.sh](publish-charts.sh) | Publishes every chart in a directory to an OCI registry, skipping versions already published |

They're the Helm versions of the [Kustomize samples](../../kubernetes/README.md), with the same images, digests, security settings, and policies, so the two approaches can be compared on the same apps.

## Try them

In the lab's shell (`devops/helm/lab/lab.sh shell`):

```sh
cp -r devops/helm/examples/charts /tmp/charts
helm dependency build /tmp/charts/web-app

# What each environment gets
helm template web-app /tmp/charts/web-app -n sample-apps -f devops/helm/examples/environments/prod-eks/web-app.yaml

# Install, test, and look
kubectl apply -k devops/kubernetes/platform/namespace
helm install web-app /tmp/charts/web-app -n sample-apps -f devops/helm/examples/environments/dev/web-app.yaml --wait
helm test web-app -n sample-apps
helm unittest /tmp/charts/web-app
```

## The web-app chart's values

| Value | Default | Meaning |
|---|---|---|
| `image.repository`, `image.tag`, `image.digest` | podinfo 6.15.0, by digest | The image. The digest is required and must be `sha256:` and 64 hex characters; the tag is for readers |
| `config` | Two settings | Environment variables, as strings; a change rolls the pods |
| `autoscaling.enabled`, `.minReplicas`, `.maxReplicas`, `.targetCPUUtilizationPercentage` | `true`, 3, 10, 70 | The HPA. When off, `replicaCount` (3) sets replicas |
| `resources` | 100m CPU, 64Mi requested; 128Mi memory limit | Requests and a memory limit are required; a CPU limit is optional |
| `podDisruptionBudget.enabled`, `.maxUnavailable` | `true`, 1 | Off for single-replica environments |
| `serviceAccount.annotations`, `podLabels` | Empty | For workload identity |
| `service.port` | 80 | The ClusterIP Service's port |
| `ingress.enabled`, `.className`, `.host`, `.annotations`, `.tls` | Off | The Ingress; `className` is required when it's on |
| `ingress.allowFrom` | Empty | NetworkPolicy peers the ingress controller's traffic comes from |
| `networkPolicy.enabled`, `.extraEgress` | `true`, empty | The pod's NetworkPolicy: same-namespace and ingress traffic in, DNS out, plus `extraEgress` |
| `tests.image` | busybox 1.38.0, by digest | The `helm test` pod's image |

[values.schema.json](charts/web-app/values.schema.json) rejects anything else, so a misspelled key fails instead of being ignored.
