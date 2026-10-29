# Kubernetes administration and troubleshooting

Everyday commands for running the [sample apps](README.md) on the EKS and AKS clusters from the [Terraform stacks](../terraform/), and a symptom-by-symptom guide for when something breaks.

Creating resources and the resource types themselves are in [RESOURCES.md](RESOURCES.md).

Examples use the `sample-apps` namespace and the `web-app`, `worker`, and `scheduled-job` apps. Substitute your own names.

> **Production is read-mostly.** If a GitOps controller manages the cluster, use these commands to *look*. Make changes through Git, or the controller will revert them (or fight you). The exceptions are emergencies, and those get a follow-up pull request.

## Contents

- [Setup and habits](#setup-and-habits)
- [Cluster and access](#cluster-and-access)
- [Inspecting workloads](#inspecting-workloads)
- [Logs](#logs)
- [Getting inside a pod](#getting-inside-a-pod)
- [Managing workloads](#managing-workloads)
- [Nodes](#nodes)
- [Troubleshooting by symptom](#troubleshooting-by-symptom)
- [EKS-specific](#eks-specific)
- [AKS-specific](#aks-specific)

---

## Setup and habits

```sh
# Confirm where you are before every change
kubectl config current-context
kubectl config get-contexts

# Switch cluster, and set a default namespace for this context
kubectl config use-context <context>
kubectl config set-context --current --namespace=sample-apps
```

Habits that prevent incidents:

- **Read the context in your prompt.** Most "I deleted prod" stories start with the wrong context. Shell prompt tools (kube-ps1, starship) show it all the time.
- **Preview first:** `kubectl diff -k <overlay>` before `apply`, and `--dry-run=server` before anything that changes state. Server-side dry run runs admission, so it catches Pod Security and quota rejections.
- **Use selectors, not names.** `-l app.kubernetes.io/name=web-app` keeps working when pod names change.

---

## Cluster and access

```sh
kubectl version                                   # client and server versions
kubectl cluster-info
kubectl get --raw='/readyz?verbose'               # API server health checks
kubectl get nodes -o wide
kubectl get pods -n kube-system                   # system components (CoreDNS, CNI, kube-proxy)

kubectl auth whoami                               # who the cluster thinks you are
kubectl auth can-i --list -n sample-apps          # everything you may do here
kubectl auth can-i delete pods -n sample-apps
kubectl auth can-i get secrets -n sample-apps --as=system:serviceaccount:sample-apps:worker
```

Warnings across the whole cluster, newest last:

```sh
kubectl events -A --types=Warning
```

Find a resource type or field without leaving the terminal:

```sh
kubectl api-resources | grep -i policy
kubectl explain deployment.spec.strategy.rollingUpdate
```

---

## Inspecting workloads

```sh
kubectl get all -n sample-apps                    # common types only; not ConfigMaps, Ingress, NetworkPolicy, etc.
kubectl get deploy,rs,pods,svc,ingress,hpa,pdb,networkpolicy,cronjob,job -n sample-apps

kubectl get pods -n sample-apps -o wide           # node, pod IP, restarts
kubectl get pods -n sample-apps -l app.kubernetes.io/name=web-app --show-labels
kubectl get pods -A --field-selector=status.phase!=Running   # anything not running, cluster-wide

kubectl describe pod <pod> -n sample-apps         # spec, state, last termination, events
kubectl get pod <pod> -n sample-apps -o yaml      # everything the API server knows

kubectl events -n sample-apps                     # namespace events, in time order
kubectl events -n sample-apps --for=deployment/web-app
```

Resource usage (needs metrics-server):

```sh
kubectl top pods -n sample-apps --containers
kubectl top nodes
```

Useful one-liners:

```sh
# Why did each container last terminate? (OOMKilled, Error, Completed)
kubectl get pods -n sample-apps -o custom-columns='POD:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount,LAST:.status.containerStatuses[*].lastState.terminated.reason'

# Which image digest is actually running?
kubectl get pods -n sample-apps -o custom-columns='POD:.metadata.name,IMAGE:.status.containerStatuses[*].imageID'

# Requests and limits per pod
kubectl get pods -n sample-apps -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory,MEM_LIM:.spec.containers[*].resources.limits.memory'

# Quota used versus allowed
kubectl describe resourcequota -n sample-apps
```

---

## Logs

```sh
kubectl logs deploy/web-app -n sample-apps                 # one pod of the Deployment
kubectl logs -n sample-apps -l app.kubernetes.io/name=web-app --prefix --tail=50   # all replicas
kubectl logs <pod> -n sample-apps -f --since=10m           # follow the last 10 minutes
kubectl logs <pod> -n sample-apps --previous               # the crashed container before the restart
kubectl logs <pod> -n sample-apps -c <container>           # a specific container
kubectl logs job/<job> -n sample-apps                      # a Job's pod
```

The apps log JSON to stdout, so filter with `jq`:

```sh
kubectl logs -n sample-apps -l app.kubernetes.io/name=worker --tail=200 | jq -c 'select(.level != "info")'
```

`kubectl logs` only shows what the node still holds. For history, query your log platform: CloudWatch Logs Insights or Container Insights on EKS, Log Analytics (`ContainerLogV2`) on AKS.

---

## Getting inside a pod

The sample apps run with a read-only root filesystem, as a non-root user, and some images have no shell. `kubectl exec` may not get you far. Use an **ephemeral debug container** instead. It shares the pod's network namespace, so it sees exactly what the app sees, including its NetworkPolicies.

```sh
kubectl exec -it <pod> -n sample-apps -- sh                # if the image has a shell
```

The namespace enforces Pod Security "restricted", so debug containers must comply too. Save this profile once:

```sh
cat > debug-restricted.json <<'EOF'
{
  "securityContext": {
    "runAsNonRoot": true,
    "runAsUser": 10001,
    "allowPrivilegeEscalation": false,
    "capabilities": { "drop": ["ALL"] },
    "seccompProfile": { "type": "RuntimeDefault" }
  }
}
EOF
```

Then attach a debug container to a running pod:

```sh
kubectl debug -it <pod> -n sample-apps \
  --image=busybox:1.38 --target=web-app \
  --profile=restricted --custom=debug-restricted.json -- sh
```

Inside it:

```sh
wget -qO- http://localhost:9898/readyz        # the app, from inside its own pod
nslookup web-app.sample-apps.svc.cluster.local
wget -qO- -T 3 http://web-app.sample-apps     # through the Service (subject to NetworkPolicy)
ps                                            # with --target, you see the app's processes
```

Other options:

```sh
# Copy of the pod with a different command, to poke at a crashing app without restarts
kubectl debug <pod> -n sample-apps -it --copy-to=<pod>-debug --container=web-app -- sh

# Reach a pod or Service from your machine
kubectl port-forward -n sample-apps svc/web-app 8080:80
kubectl port-forward -n sample-apps <pod> 9797:9797           # metrics port
```

Remove copied debug pods afterwards (`kubectl delete pod <pod>-debug -n sample-apps`). Ephemeral containers go away when the pod does.

---

## Managing workloads

### Deploy and roll back

```sh
kubectl diff -k devops/kubernetes/apps/web-app/overlays/dev
kubectl apply -k devops/kubernetes/apps/web-app/overlays/dev --dry-run=server
kubectl apply -k devops/kubernetes/apps/web-app/overlays/dev

kubectl rollout status deployment/web-app -n sample-apps --timeout=5m
kubectl rollout history deployment/web-app -n sample-apps
kubectl rollout undo deployment/web-app -n sample-apps                  # previous revision
kubectl rollout undo deployment/web-app -n sample-apps --to-revision=3
kubectl rollout restart deployment/web-app -n sample-apps               # new pods, same spec
kubectl wait --for=condition=Available deployment/web-app -n sample-apps --timeout=2m
```

Under GitOps, `rollout undo` is an emergency brake: revert the commit right afterwards, or the controller will roll forward again.

### Scale

```sh
kubectl get hpa -n sample-apps                       # web-app's replicas are owned by its HPA
kubectl describe hpa web-app -n sample-apps          # current metrics and recent decisions
kubectl patch hpa web-app -n sample-apps -p '{"spec":{"minReplicas":5}}'   # temporary floor

kubectl scale deployment/worker -n sample-apps --replicas=0   # stop a worker (no HPA)
kubectl scale deployment/worker -n sample-apps --replicas=2
```

Don't `kubectl scale` a Deployment that has an HPA. The HPA overrides you within seconds.

### CronJobs

```sh
kubectl get cronjob scheduled-job -n sample-apps                 # schedule, suspended?, last run
kubectl get jobs -n sample-apps --sort-by=.metadata.creationTimestamp
kubectl create job --from=cronjob/scheduled-job manual-$(date +%s) -n sample-apps   # run now
kubectl patch cronjob scheduled-job -n sample-apps -p '{"spec":{"suspend":true}}'   # pause
kubectl patch cronjob scheduled-job -n sample-apps -p '{"spec":{"suspend":false}}'  # resume
kubectl delete job <job> -n sample-apps                            # stop a running run
```

### Config changes

ConfigMaps come from `configMapGenerator`, so changing a value creates a new ConfigMap and rolls the pods. Change config in the overlay and apply. Don't `kubectl edit` the ConfigMap: the pods won't restart, and the next apply undoes your edit.

### Namespace baseline

```sh
kubectl get ns sample-apps --show-labels             # Pod Security labels
kubectl get networkpolicy -n sample-apps
kubectl describe limitrange,resourcequota -n sample-apps

# What would break if a namespace started enforcing "restricted"?
# Server dry run lists every existing pod that would violate it.
kubectl label ns <namespace> pod-security.kubernetes.io/enforce=restricted --overwrite --dry-run=server
```

---

## Nodes

```sh
kubectl get nodes -L topology.kubernetes.io/zone,node.kubernetes.io/instance-type
kubectl describe node <node>                         # conditions, capacity, allocated requests, pods
kubectl top nodes
kubectl get pods -A -o wide --field-selector spec.nodeName=<node>
```

Taking a node out for maintenance:

```sh
kubectl cordon <node>                                # no new pods
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --timeout=10m
# ... maintenance ...
kubectl uncordon <node>
```

`--delete-emptydir-data` is needed because the sample apps use `emptyDir` for `/tmp`; that data is scratch space by design. Drains respect PodDisruptionBudgets, so if a drain hangs, see [Drain is stuck](#drain-is-stuck).

On managed node pools, prefer the cloud's own operations (node group updates on EKS, `az aks nodepool upgrade` on AKS). They cordon, drain, and replace nodes for you.

Shell on a node, for kubelet and container runtime problems:

```sh
# Run in a namespace without the restricted Pod Security profile (for example default).
kubectl debug node/<node> -n default -it --image=busybox:1.38 --profile=sysadmin
# The node's filesystem is mounted at /host
```

---

## Troubleshooting by symptom

Start every investigation the same way:

```sh
kubectl get pods -n sample-apps -o wide
kubectl describe pod <pod> -n sample-apps        # read Events at the bottom first
kubectl events -n sample-apps
```

### Pods aren't created at all

The Deployment shows `0/3` and there are no pods to describe. Pod creation failed at admission, and the error is on the **ReplicaSet** (or the Job, for CronJobs), not on a pod:

```sh
kubectl describe rs -n sample-apps -l app.kubernetes.io/name=web-app
```

| Event message contains | Cause | Fix |
|---|---|---|
| `violates PodSecurity "restricted:latest"` | The pod spec runs as root, allows privilege escalation, keeps capabilities, or lacks seccomp | Fix the pod spec. Don't relax the namespace label. |
| `exceeded quota` | The namespace ResourceQuota is full | `kubectl describe resourcequota -n sample-apps`; reduce requests or raise the quota deliberately |
| `must specify requests` / `limits` | Quota requires resources the pod doesn't declare | Set requests and a memory limit |

### Pending

The pod exists but isn't scheduled. `describe pod` events say why:

| Event message contains | Cause | Fix |
|---|---|---|
| `Insufficient cpu` / `Insufficient memory` | No node has room for the requests | Lower requests to measured usage, or let the cluster autoscaler add nodes (check its logs) |
| `didn't match pod topology spread constraints` | Can't spread as required | The samples use `ScheduleAnyway`; if you changed it to `DoNotSchedule`, add capacity in the other zones |
| `untolerated taint` | All suitable nodes are tainted (for example the AKS system pool, which only runs critical add-ons) | Run on the user pool, or add a toleration if the pod really belongs there |
| `unbound PersistentVolumeClaim` | Storage not provisioned | `kubectl describe pvc`; check the StorageClass and the zone |

### ImagePullBackOff / ErrImagePull

```sh
kubectl describe pod <pod> -n sample-apps | grep -A5 -i "failed to pull"
```

- **`not found` / `manifest unknown`:** a wrong name or digest. Compare with `images:` in the overlay.
- **`unauthorized` / `403`:** the node can't pull from the registry. On EKS, the node role needs ECR pull access (the stack attaches `AmazonEC2ContainerRegistryPullOnly`). On AKS, the kubelet identity needs `AcrPull` on the registry; check with `az aks check-acr` (see [AKS-specific](#aks-specific)).
- **`i/o timeout` / `connection refused`:** nodes can't reach the registry. Check NAT, firewall egress rules, or private endpoints for the registry.

### CrashLoopBackOff

The container starts, exits, and is restarted with growing delays.

```sh
kubectl logs <pod> -n sample-apps --previous
kubectl get pod <pod> -n sample-apps -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'
```

| Exit code / reason | Meaning | Look at |
|---|---|---|
| `OOMKilled` (137) | Exceeded its memory limit | `kubectl top pod`; raise the limit or fix the leak |
| 137 without OOMKilled | Killed after the grace period, often by a failing liveness probe | Liveness probe events, and whether `terminationGracePeriodSeconds` is long enough |
| 143 | Exited on SIGTERM | Normal during shutdown; unexpected otherwise |
| 1 or another app code | The app failed | `logs --previous` |
| 126 / 127 | Command not executable / not found | `command` and `args`, and whether the image has that binary |

Two failures specific to hardened pods:

- **`Read-only file system`** in the logs: the app writes somewhere other than the mounted `emptyDir`. Mount an `emptyDir` at that path; don't turn off `readOnlyRootFilesystem`.
- **`Permission denied`**: the image expects to run as a specific user, or its files aren't readable by UID 10001. Rebuild the image to work as any non-root user, or match `runAsUser` to the image's user.

### Running but not Ready

The pod runs, but `READY` shows `0/1`, so it gets no traffic.

```sh
kubectl describe pod <pod> -n sample-apps | grep -i -A3 "readiness probe failed"
```

Check the probe from inside the pod with a [debug container](#getting-inside-a-pod): `wget -qO- http://localhost:9898/readyz`. Common causes are a wrong path or port, a dependency the readiness check needs being unavailable, or a probe timeout shorter than the app's real response time.

### The Service doesn't answer

Work from the Service toward the pod:

```sh
kubectl get svc web-app -n sample-apps -o wide                        # selector and ports
kubectl get endpointslices -n sample-apps -l kubernetes.io/service-name=web-app
```

- **No endpoints:** the Service selector doesn't match any Ready pods. Compare it with `kubectl get pods --show-labels`, and check readiness.
- **Endpoints exist but connections fail:** check that `targetPort` matches the container port name or number. Then suspect a NetworkPolicy (next section).

### NetworkPolicy is blocking traffic

Every pod starts with **default-deny** in both directions, plus DNS. If traffic doesn't flow, the first question is which policy should allow it:

```sh
kubectl get networkpolicy -n sample-apps
kubectl describe networkpolicy -n sample-apps
kubectl get pod <pod> -n sample-apps --show-labels       # policies select by label
```

Test from the source pod's own network namespace, using a [debug container](#getting-inside-a-pod) attached to the **client** pod:

```sh
nslookup web-app.sample-apps.svc.cluster.local   # fails: DNS egress is blocked or CoreDNS is down
wget -qO- -T 3 http://web-app.sample-apps        # times out: a policy blocks it (blocked traffic is dropped, not refused)
```

Checklist:

- Traffic needs **egress allowed on the client** *and* **ingress allowed on the server**.
- Policies select pods by label. A pod missing the expected label is covered only by default-deny.
- Named ports (`port: http`) must exist on the destination pod.
- Load balancer traffic: an EKS ALB with `target-type: ip` comes from VPC addresses (the ipBlock rule); AKS app routing comes from the `app-routing-system` namespace.
- **On EKS, confirm policies are enforced at all:** the VPC CNI add-on needs `enableNetworkPolicy` (set by the stack). If policies seem to have no effect, check the add-on configuration (see [EKS-specific](#eks-specific)).
- **On AKS with Cilium**, the agent can show dropped packets: `kubectl -n kube-system exec ds/cilium -- cilium-dbg monitor --type drop` (the binary is `cilium` on Cilium releases before 1.15). If Advanced Container Networking Services observability is enabled, `hubble observe --verdict DROPPED` gives the same view.

### Ingress has no address, or returns errors

```sh
kubectl get ingress -n sample-apps                     # ADDRESS empty = the controller hasn't reconciled it
kubectl describe ingress web-app -n sample-apps        # controller events, such as certificate or subnet errors
```

Controller logs:

```sh
# EKS: AWS Load Balancer Controller
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=100

# AKS: application routing (managed NGINX)
kubectl get deploy,pods -n app-routing-system
kubectl logs -n app-routing-system deploy/nginx --tail=100   # use the deployment name from the line above
```

- **ALB never created:** check the public subnets carry the `kubernetes.io/role/elb` tag (the network-vpc stack sets it), that the certificate ARN is right, and that the controller's IAM permissions are in place.
- **502/503 from the load balancer:** the targets are unhealthy. The health check path must return 2xx or 3xx (the sample uses `/readyz`), and the NetworkPolicy must allow the load balancer's traffic.
- **AKS TLS errors:** the add-on syncs the Key Vault certificate into the `keyvault-web-app` secret. Check that secret exists, and that the add-on's identity has access to the Key Vault.

### HPA doesn't scale

```sh
kubectl get hpa web-app -n sample-apps          # TARGETS showing <unknown> means no metrics
kubectl describe hpa web-app -n sample-apps
```

- **`<unknown>` targets:** metrics-server isn't installed or running (`kubectl get deploy -n kube-system metrics-server`), or the pods have no CPU request. Utilization is measured against requests.
- **Stuck at `maxReplicas`:** demand is beyond the ceiling, or CPU is high for another reason, such as a retry storm.
- **Slow to scale down:** expected. The sample waits 300 seconds before scaling down, to avoid flapping.

### Cloud identity doesn't work

The app gets `401`, `403`, or "no credentials" from cloud SDKs.

**AKS workload identity:**

```sh
kubectl get sa worker -n sample-apps -o jsonpath='{.metadata.annotations}'   # azure.workload.identity/client-id
kubectl get pod <pod> -n sample-apps --show-labels                           # azure.workload.identity/use=true
kubectl get pod <pod> -n sample-apps -o yaml | grep -E "AZURE_(CLIENT_ID|TENANT_ID|FEDERATED_TOKEN_FILE)"
```

If the environment variables are missing, the webhook didn't mutate the pod. The label must be on the **pod template**, and the pod must be created after the label was added (`rollout restart`). If they're present but the token exchange fails, check that the federated credential's subject is exactly `system:serviceaccount:sample-apps:<service account>` and its issuer matches `oidc_issuer_url`. Also check that HTTPS egress is allowed (the component adds this).

**EKS Pod Identity:**

```sh
aws eks list-pod-identity-associations --cluster-name <cluster> --namespace sample-apps
kubectl get pod <pod> -n sample-apps -o yaml | grep -E "AWS_CONTAINER_(CREDENTIALS_FULL_URI|AUTHORIZATION_TOKEN_FILE)"
kubectl get daemonset eks-pod-identity-agent -n kube-system
```

The association must name the exact namespace and service account, and pods created before it existed need a restart. Egress to `169.254.170.23:80` must be allowed (the component adds this). Finally, the IAM role's trust policy must allow `pods.eks.amazonaws.com`.

### CronJob didn't run

```sh
kubectl get cronjob scheduled-job -n sample-apps -o wide      # SUSPEND, LAST SCHEDULE
kubectl describe cronjob scheduled-job -n sample-apps         # events, such as missed schedules
kubectl get jobs -n sample-apps
```

- **`SUSPEND` is `True`:** someone paused it.
- **Missed start:** with `startingDeadlineSeconds: 600`, a run that couldn't start within 10 minutes (for example, the controller was down or the cluster was full) is skipped.
- **Previous run still going:** `concurrencyPolicy: Forbid` skips new runs while one is active. Check for a hung Job; `activeDeadlineSeconds` kills it after an hour.
- **Job created but failed:** inspect the Job's pods like any other pod. `ttlSecondsAfterFinished` deletes finished Jobs after a day, so look before then.

### Drain is stuck

```sh
kubectl get pdb -A          # ALLOWED DISRUPTIONS = 0 blocks eviction
```

A PodDisruptionBudget with zero allowed disruptions blocks the drain. That usually means the app is already degraded (a replica isn't Ready) or has only one replica. Fix the app's health, or scale it up, rather than deleting the PDB.

### Stuck in Terminating

```sh
kubectl get pod <pod> -n sample-apps -o jsonpath='{.metadata.finalizers}'
kubectl get ns <namespace> -o jsonpath='{.status.conditions}'    # for a namespace: what's blocking deletion
```

Pods usually stick because their node is unreachable. Once you've confirmed the node is gone, `kubectl delete pod <pod> --grace-period=0 --force` removes the record. **Don't** force-delete pods on a healthy node, or for StatefulSets, without understanding the consequences: two copies may end up running. Namespaces stick on finalizers of resources inside them. Fix or remove the controller that owns the finalizer rather than editing finalizers by hand.

### Node NotReady

```sh
kubectl describe node <node>     # Conditions: MemoryPressure, DiskPressure, PIDPressure, Ready
kubectl get pods -A -o wide --field-selector spec.nodeName=<node>
```

On managed node pools, the usual fix is to cordon, drain, and let the cloud replace the node. Investigate with a [node debug shell](#nodes) only if it keeps happening.

---

## EKS-specific

```sh
aws eks update-kubeconfig --region <region> --name <cluster>
aws eks describe-cluster --name <cluster> --query 'cluster.{version:version,status:status,endpointPublic:resourcesVpcConfig.endpointPublicAccess}'

# Who has access (access entries, not the aws-auth ConfigMap)
aws eks list-access-entries --cluster-name <cluster>
aws eks list-associated-access-policies --cluster-name <cluster> --principal-arn <role arn>

# Add-ons, and whether NetworkPolicy enforcement is on
aws eks list-addons --cluster-name <cluster>
aws eks describe-addon --cluster-name <cluster> --addon-name vpc-cni --query 'addon.{version:addonVersion,config:configurationValues,health:health}'

# Node groups and upgrades
aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name default --query 'nodegroup.{status:status,version:version,health:health}'
aws eks describe-cluster-versions --query 'clusterVersions[].{version:clusterVersion,status:versionStatus}'
```

- **Control plane logs** (API, audit, authenticator) are in CloudWatch Logs under `/aws/eks/<cluster>/cluster`. Authenticator logs explain "You must be logged in to the server" errors.
- **"Unauthorized" for a valid AWS identity** means no access entry maps that IAM principal. Check `list-access-entries`, and that your CLI is using the role you think (`aws sts get-caller-identity`).
- **Private endpoint:** commands must run from inside the VPC or a connected network (VPN, bastion, or SSM Session Manager to an instance in the VPC).

## AKS-specific

```sh
az aks get-credentials --resource-group <rg> --name <cluster>
kubelogin convert-kubeconfig -l azurecli
az aks show --resource-group <rg> --name <cluster> --query '{version:kubernetesVersion,state:provisioningState,power:powerState.code}'

# Node pools and upgrades
az aks nodepool list --resource-group <rg> --cluster-name <cluster> -o table
az aks get-upgrades --resource-group <rg> --name <cluster> -o table

# Can the cluster pull from your registry?
az aks check-acr --resource-group <rg> --name <cluster> --acr <registry>.azurecr.io

# Private cluster: run kubectl through the Azure control plane, no VPN needed
az aks command invoke --resource-group <rg> --name <cluster> --command "kubectl get pods -n sample-apps"
```

- **Sign-in errors:** local accounts are disabled, so access is through Entra ID only. Make sure kubelogin converted the kubeconfig, and that you're in an admin group or hold an Azure RBAC role on the cluster (Azure Kubernetes Service RBAC Reader, Writer, or Admin, scoped to the namespace where possible).
- **Control plane logs** (`kube-apiserver`, `kube-audit-admin`, `guard`) go to the Log Analytics workspace through the stack's diagnostic setting. `guard` logs explain Entra ID authorization failures.
- **Container logs history:** query `ContainerLogV2` in Log Analytics, for example `ContainerLogV2 | where PodNamespace == "sample-apps" | order by TimeGenerated desc | take 100`.
- **Upgrades** happen automatically for patch versions (the `patch` channel) inside the maintenance windows in the stack. Minor version upgrades go through Terraform's `kubernetes_version`.
