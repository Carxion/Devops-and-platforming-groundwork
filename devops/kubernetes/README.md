# Kubernetes reference manifests

Sample applications for the three workload shapes most programs run, plus the namespace baseline they run inside. They're written to the standards the [onboarding checklist](../../tech-lead/README.md) asks you to look for ([section 7.5](../../tech-lead/README.md#75-platform-and-runtime-hardening)), and they target the clusters built by the [EKS](../terraform/aws/eks-cluster/) and [AKS](../terraform/azure/aks-cluster/) stacks.

They're plain YAML managed with [Kustomize](https://kustomize.io), which is built into `kubectl`, so there's no templating language to learn and what you review is what gets applied. The same apps are packaged as Helm charts in [devops/helm](../helm/README.md), for comparison and for teams that deploy with Helm.

> **Status.** Every overlay rendered, passed strict schema validation against Kubernetes 1.34 (kubeconform), and passed checkov's Kubernetes policies when last checked. CI doesn't run these; run them with the commands in [Checks and tested versions](#checks-and-tested-versions). They haven't been applied to a live cluster by this project. Deploy to a dev cluster first.

## Contents

- [What's here](#whats-here)
- [Setup](#setup)
- [Deploying](#deploying)
- [Adapting a sample to your app](#adapting-a-sample-to-your-app)
- [Making it operational](#making-it-operational)
- [Best practices](#best-practices)
- [Checks and tested versions](#checks-and-tested-versions)

For day-to-day administration and troubleshooting commands, see [OPERATIONS.md](OPERATIONS.md).

---

## What's here

```text
devops/kubernetes/
├── platform/namespace/          applied once by the platform team
├── components/                  reusable add-ons for any app
│   ├── aks-workload-identity/   Entra ID identity for pods
│   └── eks-pod-identity/        IAM role credentials for pods
└── apps/
    ├── web-app/                 HTTP service behind an ingress
    │   ├── base/
    │   ├── components/          ingress-aws-alb, ingress-aks-app-routing
    │   └── overlays/            dev, prod-eks, prod-aks
    ├── worker/                  background consumer, no inbound traffic
    │   ├── base/
    │   └── overlays/            dev, prod-eks, prod-aks
    └── scheduled-job/           CronJob for batch work
        ├── base/
        └── overlays/            dev, prod
```

| Piece | What it gives you |
|---|---|
| **platform/namespace** | A namespace that enforces the Pod Security "restricted" profile; a default-deny NetworkPolicy plus DNS egress; a ResourceQuota (which also blocks per-service load balancers and NodePorts); a LimitRange with defaults for containers that forget to set resources |
| **web-app** | Deployment (podinfo as a stand-in) with startup, liveness, and readiness probes, graceful shutdown, zone and node spreading, an HPA, a PDB, a ConfigMap that rolls pods when it changes, and a NetworkPolicy. The ingress component adds an ALB or AKS app routing Ingress and opens the matching network path. |
| **worker** | Deployment with no Service, a heartbeat-file liveness probe (no port to probe), a 60-second shutdown window, and HTTPS-only egress |
| **scheduled-job** | CronJob with no overlapping runs, a deadline per run, retry limits, history limits, and automatic cleanup of finished Jobs |
| **aks-workload-identity** | Service account annotation, pod label, and HTTPS egress for AKS workload identity |
| **eks-pod-identity** | Pod label plus egress to the Pod Identity agent and AWS APIs. The role mapping itself is Terraform (see [Cloud identity](#cloud-identity)). |

Every workload runs as a non-root user (UID 10001) with a read-only root filesystem, all Linux capabilities dropped, no privilege escalation, the runtime-default seccomp profile, no service account token, and an image pinned by digest.

### Base, overlays, components

- **Base:** the app as it should run in production, minus anything environment- or cloud-specific.
- **Overlay:** one per deployment target. It sets the namespace, picks components, and patches size (replicas, schedules) and the image digest being promoted.
- **Component:** an optional feature that several overlays can include, such as an ingress type or a cloud identity.

---

## Setup

### Tools

| Tool | Used for | Install |
|---|---|---|
| kubectl 1.33 or later | everything, including `kubectl kustomize` and `kubectl apply -k` | `az aks install-cli`, `brew install kubectl`, or `winget install Kubernetes.kubectl` |
| kubelogin | signing in to AKS with Entra ID | installed by `az aks install-cli` |
| kubeconform | schema validation | [releases](https://github.com/yannh/kubeconform/releases) |
| checkov | policy checks | `pipx install checkov` |

### Connect to the cluster

```sh
# EKS (from the eks-cluster stack output)
aws eks update-kubeconfig --region <region> --name <cluster>

# AKS (from the aks-cluster stack output); local accounts are disabled
az aks get-credentials --resource-group <rg> --name <cluster>
kubelogin convert-kubeconfig -l azurecli

kubectl config current-context   # confirm before every apply
```

### Cluster prerequisites

The manifests assume these exist in the cluster. The Terraform stacks provide some of them; install the rest with your platform tooling.

| Needed by | Requirement | EKS stack | AKS stack |
|---|---|---|---|
| NetworkPolicies | A CNI that enforces them | VPC CNI with `enableNetworkPolicy` (set by the stack) | Cilium (set by the stack) |
| HPA | metrics-server | Install the metrics-server add-on | Built in |
| web-app ingress | An ingress controller | Install the AWS Load Balancer Controller | Enable application routing (`az aks approuting enable`) |
| ingress TLS | A certificate | ACM certificate ARN in the Ingress annotation | Key Vault certificate URI in the Ingress annotation |
| Cloud identity | Identity plumbing | Pod Identity agent (installed by the stack) | Workload identity and OIDC issuer (enabled by the stack) |

---

## Deploying

Preview, diff, then apply. The namespace goes first, because every app overlay deploys into it.

```sh
# 1. Namespace baseline (platform team, once per cluster)
kubectl apply -k devops/kubernetes/platform/namespace

# 2. See exactly what an overlay will create
kubectl kustomize devops/kubernetes/apps/web-app/overlays/dev

# 3. See what would change in the cluster
kubectl diff -k devops/kubernetes/apps/web-app/overlays/dev

# 4. Apply and wait for the rollout
kubectl apply -k devops/kubernetes/apps/web-app/overlays/dev
kubectl -n sample-apps rollout status deployment/web-app

# 5. Try it (dev has no ingress)
kubectl -n sample-apps port-forward svc/web-app 8080:80
curl http://localhost:8080
```

For production, pick the overlay that matches your cloud, such as `overlays/prod-eks` or `overlays/prod-aks`, after replacing the placeholders below.

### Placeholders to replace

| File | Placeholder |
|---|---|
| `platform/namespace/*` and every overlay | namespace `sample-apps` |
| `web-app/components/ingress-aws-alb/ingress.yaml` | host, ACM certificate ARN, optional WAF ACL ARN |
| `web-app/components/ingress-aws-alb/networkpolicy.yaml` | VPC CIDR `10.0.0.0/16` (network-vpc output `vpc_cidr`) |
| `web-app/components/ingress-aks-app-routing/ingress.yaml` | host, Key Vault certificate URI |
| `components/aks-workload-identity/kustomization.yaml` | managed identity client ID |
| `*/base/kustomization.yaml` and prod overlays | image name and digest |

### Cloud identity

Pods get cloud credentials without secrets.

**AKS workload identity.** Create a user-assigned managed identity, then add a federated credential that trusts this service account. Put the identity's client ID in the component.

```sh
az identity federated-credential create \
  --name worker \
  --identity-name <managed identity> --resource-group <rg> \
  --issuer "$(terraform -chdir=devops/terraform/azure/aks-cluster output -raw oidc_issuer_url)" \
  --subject system:serviceaccount:sample-apps:worker \
  --audiences api://AzureADTokenExchange
```

**EKS Pod Identity.** Map the service account to an IAM role in Terraform; no annotation is needed in the manifests.

```hcl
resource "aws_eks_pod_identity_association" "worker" {
  cluster_name    = "<cluster>"
  namespace       = "sample-apps"
  service_account = "worker"
  role_arn        = aws_iam_role.worker.arn # trust policy principal: pods.eks.amazonaws.com
}
```

Grant each identity only what that app needs, such as one queue or one bucket, never a shared broad role.

---

## Adapting a sample to your app

1. **Copy** the app folder you need into your repository and rename it everywhere: folder, resource names, labels, and the NetworkPolicy `podSelector`.
2. **Image:** set `newName` and `digest` in the base `images:` block. Build images as non-root; if yours needs a writable path, mount an `emptyDir` there rather than relaxing `readOnlyRootFilesystem`.
3. **Ports and probes:** point probes at real endpoints. Readiness should fail when a dependency the app can't work without is down; liveness should fail only when the process itself is stuck.
4. **Resources:** start from measured usage. Set the memory request equal to typical usage and the memory limit with headroom above it; set a CPU request and no CPU limit (see [Best practices](#resources-and-scaling)).
5. **Network:** list every destination the app talks to and add it to the app's NetworkPolicy egress. Anything not listed is blocked, which is the point.
6. **Config and secrets:** non-secret settings go in the `configMapGenerator`. Secrets come from a secrets manager (see [Security](#security)), never from a file in the repository.

---

## Making it operational

### Deliver with GitOps

Applying from a laptop doesn't scale and leaves no audit trail. In production, a GitOps controller ([Argo CD](https://argo-cd.readthedocs.io) or [Flux](https://fluxcd.io)) running in the cluster applies the overlays from Git. That makes Git the source of truth the guide's section [6](../../tech-lead/README.md#6-continuous-delivery-and-deployment) asks about:

- Each cluster's controller watches that cluster's overlays (`overlays/prod-aks` for the AKS prod cluster, and so on).
- Changes reach production only by merging a pull request. Drift is detected, and corrected or alerted on, automatically.
- The controller holds the cluster credentials, so CI never needs them.

### Promote by digest

Build an image once, then promote **the same digest** through environments ([section 5](../../tech-lead/README.md#5-continuous-integration): build once, deploy what you tested):

1. CI builds, scans, signs, and pushes the image, then opens a pull request that updates the `digest` in `overlays/dev`.
2. After it's verified in dev, a pull request copies that digest to the prod overlay. Reviewers see exactly which image is moving.

`kustomize edit set image web-app=ghcr.io/org/web-app@sha256:<digest>` makes that change from a script.

### Verify in CI

The commands in [Checks and tested versions](#checks-and-tested-versions) are what a pipeline should run: render every overlay, validate it against the target Kubernetes version's schemas, and run checkov on the rendered output. Add `kubectl diff` against a dev cluster if your CI can reach one.

### Enforce in the cluster, too

CI checks can be bypassed by anyone with cluster access. Back them with admission control in the cluster: Pod Security Admission (already on via the namespace labels), plus a policy engine such as Kyverno or Gatekeeper on AKS (Azure Policy uses Gatekeeper and is enabled by the stack). Useful rules include requiring image digests from approved registries, requiring resource requests, and verifying image signatures.

---

## Best practices

### Security

- **Pod Security "restricted" on every app namespace.** It rejects privileged and root pods at admission, so mistakes fail fast instead of shipping.
- **Run as non-root with a read-only root filesystem, drop all capabilities, and disallow privilege escalation.** Writable paths are explicit `emptyDir` mounts. NIST SP 800-190 covers why ([guide reference](../../tech-lead/README.md#references)).
- **No service account token unless the app calls the Kubernetes API.** Set `automountServiceAccountToken: false`; when an app does need the API, give it a Role scoped to its namespace and verbs.
- **Default-deny NetworkPolicy, then allow what's needed.** Without a policy, any compromised pod can reach every other pod in the cluster. Confirm your CNI enforces policies; an unenforced policy looks like protection and isn't.
- **Pin images by digest, from registries you control.** A tag can be repointed; a digest can't. Mirror third-party images into your registry and scan them there.
- **No secrets in manifests or ConfigMaps.** Use the [External Secrets Operator](https://external-secrets.io) or the Secrets Store CSI driver to pull from Secrets Manager or Key Vault, with workload identity for access. Kubernetes Secrets are only base64-encoded; the EKS and AKS stacks encrypt them at rest, but anyone with read access to the namespace can still read them.
- **Workload identity per app, not node identity.** Pods get their own short-lived credentials. The EKS stack's IMDSv2 hop limit of 1 stops pods from borrowing the node's role.

### Reliability

- **Three probes, three jobs.** Startup protects slow starts; liveness restarts a wedged process; readiness takes a pod out of traffic. Never make liveness depend on a downstream service, or one outage restarts every pod at once.
- **Graceful shutdown.** Handle SIGTERM, finish in-flight work, and fit inside `terminationGracePeriodSeconds`. A short `preStop` sleep lets load balancers stop routing to a pod before it stops listening.
- **At least two replicas, spread across zones**, with a PodDisruptionBudget, so node drains and zone failures don't take the service down.
- **Rolling updates with `maxUnavailable: 0`** for services that must stay at full capacity during deploys.
- **Jobs need bounds:** `concurrencyPolicy: Forbid` unless overlapping runs are safe, an `activeDeadlineSeconds`, a `backoffLimit`, and `ttlSecondsAfterFinished` so finished Jobs don't pile up.

### Resources and scaling

- **Always set requests.** The scheduler places pods by requests; without them, nodes overcommit and pods get evicted unpredictably.
- **Set a memory limit; usually skip the CPU limit.** Exceeding memory gets the container killed, so a limit prevents one pod from starving a node. CPU is compressible: a CPU limit throttles the app even when the node has idle CPU, which shows up as latency. Set a CPU request instead, which guarantees a share. If your program requires CPU limits (some policies do), set them well above the request.
- **Scale on the right signal.** The HPA scales the web app on CPU. For workers, scale on queue length with [KEDA](https://keda.sh).
- **Right-size from data.** Compare requests to actual usage monthly; the Vertical Pod Autoscaler in recommendation mode gives you the numbers without changing anything.
- **Quotas per namespace** so one team's mistake can't consume the cluster.

### Configuration and delivery

- **Same base, small overlays.** If an overlay patches most of the base, the environments are diverging. Find out why.
- **Config changes roll pods automatically.** `configMapGenerator` adds a content hash to the ConfigMap name, so a config change creates a new rollout, and rolling back the manifest rolls back the config too.
- **Keep the HPA in charge of replicas.** Don't set `spec.replicas` on Deployments with an HPA; every apply would reset the count.
- **Changes go through Git.** `kubectl edit` in production creates drift the GitOps controller will either revert or fight.

### Observability

- **Log structured JSON to stdout.** The node's agent ships it; the app doesn't manage files or rotation.
- **Use the standard labels** (`app.kubernetes.io/name`, `part-of`, `version`, `component`) consistently, so dashboards, cost reports, and policies can select on them.
- **Expose metrics** on a separate port (the web app uses 9797) and allow your monitoring namespace in the NetworkPolicy when you add scraping.
- **Alert on symptoms users feel:** error rate and latency against SLOs ([section 8](../../tech-lead/README.md#8-observability-and-operations)), not pod restarts.

### Multi-tenancy

- **One namespace per team or app group**, each with the baseline: Pod Security labels, default-deny, quota, and limits.
- **RBAC by namespace.** Teams get edit rights in their namespaces through Entra ID or IAM groups, not cluster-admin.
- **Separate clusters for separate trust levels.** Namespaces are a soft boundary. Production and non-production, or different classification levels, belong in different clusters, and usually different accounts.

---

## Checks and tested versions

None of these need a cluster:

```sh
# render one overlay
kubectl kustomize devops/kubernetes/apps/web-app/overlays/prod-aks

# render all, then validate and policy-check them
mkdir -p rendered
for d in $(find devops/kubernetes -name kustomization.yaml -path "*overlays/*" -exec dirname {} \;) devops/kubernetes/platform/namespace; do
  kubectl kustomize "$d" > "rendered/$(echo "$d" | tr '/' '_').yaml"
done
kubeconform -strict -summary -kubernetes-version 1.34.0 rendered/*.yaml
checkov -d rendered --framework kubernetes
```

Checkov exceptions are `checkov.io/skipN` annotations on the resource, each with its reason. List them with `grep -rn "checkov.io/skip" devops/kubernetes/`.

Tested with kubectl 1.34 (built-in Kustomize), kubeconform 0.8.0 against Kubernetes 1.34 schemas, and checkov 3.3, in October 2026. Images: podinfo 6.15.0 and busybox 1.38.0, pinned by multi-architecture index digest.
