# Creating resources and the resource types

[← Kubernetes](README.md)

How to create, change, and delete Kubernetes resources with `kubectl`, and a tour of the resource types you'll use most, each with a working manifest. Every manifest here meets the Pod Security "restricted" profile that the [namespace baseline](platform/namespace/) enforces. The output shown is real, from kubectl 1.34 against the [Helm lab's](../helm/lab/README.md) kind cluster, and [tests/resources-guide.sh](tests/resources-guide.sh) applies every manifest on this page and checks the result. [OPERATIONS.md](OPERATIONS.md) covers inspecting, debugging, and day-to-day administration.

## Contents

- [Imperative or declarative](#imperative-or-declarative)
- [Imperative commands](#imperative-commands)
- [Generating and exploring YAML](#generating-and-exploring-yaml)
- [kubectl apply](#kubectl-apply)
- [Changing and deleting](#changing-and-deleting)
- [Anatomy of a manifest](#anatomy-of-a-manifest)
- [The resource types](#the-resource-types)
  - [Workloads](#workloads): Pod, Deployment, StatefulSet, DaemonSet, Job, CronJob
  - [Networking](#networking): Service, EndpointSlice, Ingress, Gateway API, NetworkPolicy
  - [Configuration](#configuration): ConfigMap, Secret
  - [Storage](#storage): PersistentVolumeClaim, PersistentVolume, StorageClass
  - [Identity and access](#identity-and-access): ServiceAccount, Role, RoleBinding, ClusterRole, ClusterRoleBinding
  - [Namespaces and policy](#namespaces-and-policy): Namespace, ResourceQuota, LimitRange, PodDisruptionBudget, PriorityClass
  - [Scaling](#scaling): HorizontalPodAutoscaler
  - [Extending the API](#extending-the-api): CustomResourceDefinition
- [Checking these examples](#checking-these-examples)

---

## Imperative or declarative

| Style | Commands | Use for |
|---|---|---|
| **Imperative:** tell the cluster what to do | `kubectl create`, `run`, `expose`, `scale`, `set image`, `delete` | Learning, one-off debugging, generating a starting manifest |
| **Declarative:** tell the cluster what should exist | `kubectl apply -f`, `kubectl apply -k`, Helm, Argo CD, Flux | Everything that matters: the manifest in Git is the record, reviewed and repeatable |

Use declarative for anything another person will depend on. An imperative change exists only in the cluster: nobody reviewed it, the next deploy may undo it, and nobody can recreate it.

## Imperative commands

```sh
kubectl create namespace demo
kubectl -n demo create deployment web --image=ghcr.io/stefanprodan/podinfo:6.15.0 --replicas=2 --port=9898
kubectl -n demo expose deployment web --port=80 --target-port=9898
kubectl -n demo run debug --image=busybox:1.38.0 --restart=Never -- sleep 60
kubectl -n demo create configmap web-config --from-literal=GREETING=hello
kubectl -n demo create secret generic web-db --from-literal=password=change-me
kubectl -n demo create job migrate --image=busybox:1.38.0 -- echo done
kubectl -n demo create cronjob nightly --image=busybox:1.38.0 --schedule="0 2 * * *" -- echo hi
kubectl -n demo create serviceaccount reader
kubectl -n demo create role pod-reader --verb=get,list,watch --resource=pods
kubectl -n demo create rolebinding reader-pods --role=pod-reader --serviceaccount=demo:reader
kubectl -n demo create quota compute --hard=requests.cpu=2,requests.memory=4Gi,pods=20
kubectl -n demo create poddisruptionbudget web --selector=app=web --max-unavailable=1
kubectl -n demo create ingress web --class=nginx --rule="web.example.com/*=web:80"
kubectl -n demo autoscale deployment web --min=2 --max=5 --cpu=70%
```

They're quick, and in a namespace that enforces Pod Security "restricted" (as every namespace on the [baseline](platform/namespace/) does) most of them don't produce running pods. `kubectl create deployment` succeeds, but the Deployment stays at 0 ready, because every pod it tries to create is rejected:

```text
$ kubectl -n demo create deployment web --image=ghcr.io/stefanprodan/podinfo:6.15.0 --replicas=2 --port=9898
Warning: would violate PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "podinfo" must set
securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "podinfo" must set
securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "podinfo" must set
securityContext.runAsNonRoot=true), seccompProfile (pod or container "podinfo" must set securityContext.seccompProfile.type
to "RuntimeDefault" or "Localhost")
deployment.apps/web created

$ kubectl -n demo get deployment web
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
web    0/2     0            0           5s

$ kubectl -n demo get events --field-selector reason=FailedCreate -o custom-columns=MESSAGE:.message
Error creating: pods "web-756fcf4786-zhwdw" is forbidden: violates PodSecurity "restricted:latest": ...
```

`kubectl run` is rejected outright, with the same reasons. The imperative commands can't set a security context, so treat them as a way to **generate** a manifest, not to create workloads.

## Generating and exploring YAML

Add `--dry-run=client -o yaml` to any `create`, `run`, or `expose` to print the manifest instead of creating it:

```sh
kubectl create deployment web --image=ghcr.io/stefanprodan/podinfo:6.15.0 --port=9898 --dry-run=client -o yaml > deployment.yaml
```

```yaml
# Generated: a starting point, not something to apply as is
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: web
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  strategy: {}
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - image: ghcr.io/stefanprodan/podinfo:6.15.0
        name: podinfo
        ports:
        - containerPort: 9898
        resources: {}
status: {}
```

Then finish it: remove `status`, `strategy: {}`, and empty `resources`; add the security context, resources, probes, and a digest-pinned image. The [Deployment](#deployment) below is what it should end up as.

To find out what fields exist without leaving the terminal:

| Command | Shows |
|---|---|
| `kubectl explain deployment.spec.strategy` | One field's documentation and its sub-fields |
| `kubectl explain pod.spec --recursive` | Every field below a path |
| `kubectl api-resources` | Every resource type the cluster serves, with short names, API version, and whether it's namespaced |
| `kubectl api-resources --namespaced=false` | Cluster-scoped types only |
| `kubectl api-resources --api-group=apps` | One API group |

```text
$ kubectl api-resources --namespaced=true --api-group=apps
NAME                  SHORTNAMES   APIVERSION   NAMESPACED   KIND
controllerrevisions                apps/v1      true         ControllerRevision
daemonsets            ds           apps/v1      true         DaemonSet
deployments           deploy       apps/v1      true         Deployment
replicasets           rs           apps/v1      true         ReplicaSet
statefulsets          sts          apps/v1      true         StatefulSet
```

## kubectl apply

`kubectl apply` makes the cluster match a manifest: it creates what doesn't exist, and changes what differs. Run it again and nothing changes.

```sh
kubectl apply -f web.yaml                      # one file (several resources, separated by ---)
kubectl apply -f manifests/                    # every .yaml, .yml, and .json in a directory
kubectl apply -f manifests/ -R                 # and its subdirectories
kubectl apply -k apps/web-app/overlays/dev     # a Kustomize directory (this repository's samples)
cat web.yaml | kubectl apply -f -              # from stdin
kubectl apply -f https://example.com/x.yaml    # from a URL: read it first
```

### Client-side and server-side apply

By default, `kubectl apply` works out the change on your machine, comparing your manifest, the live object, and the last version you applied (kept in the `kubectl.kubernetes.io/last-applied-configuration` annotation). **Server-side apply** (`--server-side`) has the API server do the merge instead, and records which **field manager** owns each field:

```sh
kubectl apply --server-side -f web.yaml
kubectl apply --server-side --field-manager=team-shop -f web.yaml   # name the manager (pipelines should)
```

Prefer server-side apply: it handles large objects and CRDs better, and it tells you when you'd overwrite a field someone else owns. In the lab, after `kubectl scale` changed the replica count of a Deployment whose manifest also set `replicas`, the next apply refused:

```text
$ kubectl apply --server-side -f web.yaml
error: Apply failed with 1 conflict: conflict with "kubectl" with subresource "scale" using apps/v1: .spec.replicas
Please review the fields above--they currently have other managers. Here
are the ways you can resolve this warning:
* If you intend to manage all of these fields, please re-run the apply
  command with the `--force-conflicts` flag.
* If you do not intend to manage all of the fields, please edit your
  manifest to remove references to the fields that should keep their
  current managers.
...
```

An HorizontalPodAutoscaler scales the same way, so this is why a Deployment with an HPA should leave `replicas` out of its manifest: the HPA owns that field. `--force-conflicts` takes ownership anyway; use it when you mean to, not to get past the error. `kubectl get deployment web --show-managed-fields -o yaml` shows who owns what.

### Check before you apply

```sh
kubectl apply --dry-run=server -f web.yaml   # the API server validates and runs admission, but saves nothing
kubectl diff -f web.yaml                     # what would change, against the live objects
```

`kubectl diff` exits 0 when there's nothing to change and 1 when there is, so pipelines can use it as a check. A server dry run runs admission (Pod Security, quotas, webhooks), which client-side validation can't.

### Order matters

A file can only be applied in one pass if everything it refers to already exists, or is created earlier in the same pass:

- **Namespaces first.** `kubectl apply` creates resources in file order, so put the Namespace first. A server dry run can't create it at all, so every namespaced resource in a dry run against a missing namespace fails with `namespaces "shop" not found`. Apply the Namespace, then dry-run the rest.
- **CRDs before their custom resources.** The API server doesn't know a custom kind until its CRD is established:

  ```text
  error: resource mapping not found for name: "orders-db" namespace: "shop" from "resources.yaml":
  no matches for kind "Backup" in version "example.com/v1"
  ensure CRDs are installed first
  ```

  Apply CRDs separately, then `kubectl wait --for=condition=Established crd/backups.example.com`, then the resources.
- **References can arrive late.** A Deployment that reads a ConfigMap is accepted before the ConfigMap exists; its pods wait in `CreateContainerConfigError` until it does, then start.

### Wait for the result

`apply` returns when the API server has accepted the objects, not when they work:

```sh
kubectl -n shop wait --for=condition=Available deployment/web --timeout=2m
kubectl -n shop rollout status statefulset/queue --timeout=2m
kubectl -n shop wait --for=condition=Complete job/migrate --timeout=2m
kubectl -n shop wait --for=jsonpath='{.status.phase}'=Running pod/hello --timeout=1m
```

## Changing and deleting

| Command | Does | Use |
|---|---|---|
| Edit the manifest, then `kubectl apply` | Changes what's in Git and in the cluster together | The default for every change |
| `kubectl patch deployment web --type=merge -p '{"spec":{"revisionHistoryLimit":5}}'` | Changes specific fields | Automation, emergencies; then update the manifest |
| `kubectl label deployment web tier=frontend`, `kubectl annotate deployment web example.com/owner=team-shop` | Adds or changes a label or annotation (`key-` removes one) | Quick metadata changes |
| `kubectl scale deployment web --replicas=4`, `kubectl set image deployment/web web=<image>` | Imperative changes to common fields | Emergencies; the next apply may undo them |
| `kubectl edit deployment web` | Opens the live object in an editor | Avoid: unreviewed, unrecorded, and overwritten by the next deploy |
| `kubectl replace -f web.yaml` | Replaces the whole object | Rarely; `--force` deletes and recreates it, with downtime |

```sh
kubectl delete -f web.yaml                          # what a manifest created
kubectl -n shop delete deployment web               # one object
kubectl -n shop delete pods -l app=web              # by label (a Deployment recreates them)
kubectl delete namespace shop                       # a namespace and everything in it
```

Deleting an owner deletes what it owns (a Deployment's ReplicaSets and pods) in the background by default. Deleting a namespace deletes everything in it; if it hangs in `Terminating`, see [OPERATIONS.md](OPERATIONS.md#stuck-in-terminating).

## Anatomy of a manifest

```yaml
# Not applied: annotated anatomy.
apiVersion: apps/v1          # group/version (core resources have no group: "v1")
kind: Deployment             # the resource type
metadata:
  name: web                  # unique per kind in its namespace
  namespace: shop            # omitted for cluster-scoped kinds (Namespace, ClusterRole, PersistentVolume)
  labels:                    # identifying key-values: selectors match on these
    app: web
  annotations:               # non-identifying metadata: tools, owners, descriptions
    example.com/owner: team-shop
spec:                        # what you want (you write this)
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: ghcr.io/stefanprodan/podinfo:6.15.0@sha256:ec73780a8425f59ea49f5bc8cdff0d598805a224fbaa1f86c67a244f250fa9da
# status:                    # what is (the cluster writes this; never put it in a manifest)
```

- **Labels and selectors** connect resources: a Service finds pods, a Deployment finds its pods, a NetworkPolicy chooses what it applies to, all by matching labels. The [recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/) (`app.kubernetes.io/name`, `instance`, `version`, `part-of`, `managed-by`) are what this repository's samples use.
- **Owner references** link created objects to their creators: a Deployment owns ReplicaSets, which own pods. That's how deleting the Deployment cleans up, and what `kubectl get pods -o jsonpath='{.items[*].metadata.ownerReferences[*].kind}'` shows.
- **Namespaced or cluster-scoped:** most workload and configuration kinds live in a namespace; nodes, namespaces, PersistentVolumes, StorageClasses, ClusterRoles, PriorityClasses, and CRDs don't. `kubectl api-resources --namespaced=false` lists the cluster-scoped kinds.

---

## The resource types

| Kind | Short name | Scope | What it's for |
|---|---|---|---|
| [Pod](#pod) | `po` | Namespace | One or more containers that run together; created by the controllers below, rarely by hand |
| [Deployment](#deployment) | `deploy` | Namespace | Stateless apps: keeps N identical pods running, rolls out changes |
| ReplicaSet | `rs` | Namespace | Keeps N pods running; managed by a Deployment, not by you |
| [StatefulSet](#statefulset) | `sts` | Namespace | Apps that need stable names and their own storage: databases, queues |
| [DaemonSet](#daemonset) | `ds` | Namespace | One pod per node: log shippers, node agents |
| [Job](#job) | | Namespace | Run to completion: a migration, a batch task |
| [CronJob](#cronjob) | `cj` | Namespace | A Job on a schedule |
| [Service](#service) | `svc` | Namespace | A stable name and address for a set of pods |
| [EndpointSlice](#endpointslice) | | Namespace | The pod addresses behind a Service; maintained for you |
| [Ingress](#ingress) | `ing` | Namespace | HTTP routing from outside the cluster to Services |
| [NetworkPolicy](#networkpolicy) | `netpol` | Namespace | Which traffic may reach or leave pods |
| [ConfigMap](#configmap) | `cm` | Namespace | Non-secret configuration |
| [Secret](#secret) | | Namespace | Sensitive configuration |
| [PersistentVolumeClaim](#persistentvolumeclaim) | `pvc` | Namespace | A request for storage |
| [PersistentVolume, StorageClass](#persistentvolume-and-storageclass) | `pv`, `sc` | Cluster | The storage itself, and how it's provisioned |
| [ServiceAccount](#serviceaccount) | `sa` | Namespace | An identity for pods |
| [Role, RoleBinding](#role-and-rolebinding) | | Namespace | Permissions in one namespace, and who has them |
| [ClusterRole, ClusterRoleBinding](#clusterrole-and-clusterrolebinding) | | Cluster | Permissions across the cluster |
| [Namespace](#namespace) | `ns` | Cluster | A boundary for names, policy, quotas, and access |
| [ResourceQuota](#resourcequota) | `quota` | Namespace | Limits on what a namespace can use |
| [LimitRange](#limitrange) | `limits` | Namespace | Default and maximum resources per container |
| [PodDisruptionBudget](#poddisruptionbudget) | `pdb` | Namespace | How many pods voluntary disruptions may take down |
| [PriorityClass](#priorityclass) | `pc` | Cluster | Which pods are scheduled first, and evicted last |
| [HorizontalPodAutoscaler](#horizontalpodautoscaler) | `hpa` | Namespace | Scale replicas on metrics |
| [CustomResourceDefinition](#customresourcedefinition) | `crd` | Cluster | Add your own resource types |

The examples build one namespace, `shop`, in the order the test applies them. Every pod in them runs as a non-root user with a read-only root filesystem, no capabilities, and the runtime's default seccomp profile, with requests and a memory limit set. Without those, the namespace rejects them.

## Workloads

### Namespace

Start with the namespace, labeled to enforce Pod Security "restricted" (the [baseline](platform/namespace/namespace.yaml) adds quotas, limits, and network policies too):

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shop
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
```

```sh
kubectl get namespaces --show-labels
kubectl config set-context --current --namespace=shop   # make it your default
```

### Pod

The smallest unit: one or more containers sharing a network and volumes. Pods are disposable: if one dies, nothing recreates it, which is why you run them through a controller. A bare pod is still useful for a one-off task or a debugging session:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello
  namespace: shop
  labels:
    app: hello
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: hello
      image: docker.io/library/busybox:1.38.0@sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e
      command: ["sh", "-c", "echo hello from a pod; sleep 3600"]
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          memory: 32Mi
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
```

```sh
kubectl -n shop get pods -o wide
kubectl -n shop logs hello                    # hello from a pod
kubectl -n shop exec -it hello -- sh
kubectl -n shop delete pod hello
```

### Deployment

The default for stateless services. A Deployment owns a ReplicaSet, which keeps the pods running; changing the pod template creates a new ReplicaSet and rolls pods over to it. This one reads its configuration from the [ConfigMap](#configmap) and [Secret](#secret) below, runs as the `web` [ServiceAccount](#serviceaccount), and leaves `replicas` to the [HPA](#horizontalpodautoscaler):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: shop
  labels:
    app: web
spec:
  # No replicas: the HorizontalPodAutoscaler owns it.
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      serviceAccountName: web
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: web
          image: ghcr.io/stefanprodan/podinfo:6.15.0@sha256:ec73780a8425f59ea49f5bc8cdff0d598805a224fbaa1f86c67a244f250fa9da
          ports:
            - name: http
              containerPort: 9898
          envFrom:
            - configMapRef:
                name: web-config
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: web-db
                  key: password
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              memory: 128Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

```sh
kubectl -n shop rollout status deployment/web
kubectl -n shop get deployment,replicaset,pods -l app=web
kubectl -n shop rollout history deployment/web
kubectl -n shop rollout undo deployment/web     # back to the previous ReplicaSet
kubectl -n shop rollout restart deployment/web  # new pods, same spec (for example after a Secret changes)
```

The [web-app sample](apps/web-app/base/deployment.yaml) adds startup probes, graceful shutdown, and zone spreading.

### StatefulSet

For workloads whose pods aren't interchangeable: each gets a stable name (`queue-0`, `queue-1`), a stable DNS name through a headless Service, and its own PersistentVolumeClaim from `volumeClaimTemplates`. Pods start in order and stop in reverse.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: queue
  namespace: shop
spec:
  clusterIP: None              # headless: DNS returns each pod's address (queue-0.queue.shop.svc)
  selector:
    app: queue
  ports:
    - name: data
      port: 8080
```

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: queue
  namespace: shop
spec:
  serviceName: queue
  replicas: 2
  selector:
    matchLabels:
      app: queue
  template:
    metadata:
      labels:
        app: queue
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: queue
          image: docker.io/library/busybox:1.38.0@sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e
          command: ["sh", "-c", "echo \"I am $HOSTNAME\" >> /data/log; while true; do sleep 3600; done"]
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              memory: 32Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: data
              mountPath: /data
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

```text
$ kubectl -n shop get pvc
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-queue-0   Bound    pvc-66723976-8ecb-41aa-906a-359e499091e5   1Gi        RWO            standard       14s
data-queue-1   Bound    pvc-5588cd47-3bf4-4cf1-ba91-61e4851f7775   1Gi        RWO            standard       8s

$ kubectl -n shop exec queue-0 -- cat /data/log
I am queue-0
```

Deleting or scaling down a StatefulSet keeps its PVCs (and the data) unless `persistentVolumeClaimRetentionPolicy` says otherwise. For production databases, a managed service or an operator built for that database is usually a better choice than a StatefulSet you maintain.

### DaemonSet

One pod on every node (or every node matching a selector), added automatically as nodes join: log shippers, monitoring agents, node-local proxies.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-agent
  namespace: shop
spec:
  selector:
    matchLabels:
      app: node-agent
  template:
    metadata:
      labels:
        app: node-agent
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: agent
          image: docker.io/library/busybox:1.38.0@sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e
          command: ["sh", "-c", "while true; do echo \"agent on $NODE_NAME\"; sleep 60; done"]
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              memory: 32Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
```

```sh
kubectl -n shop rollout status daemonset/node-agent
kubectl -n shop get pods -l app=node-agent -o wide     # one per node
```

Real agents often need host access (host paths, host network) that "restricted" forbids; they belong in a system namespace with a less strict profile, managed by the platform team.

### Job

Runs pods until a set number succeed, then stops. For migrations, backfills, and one-off tasks:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate
  namespace: shop
spec:
  backoffLimit: 2                 # retries before the Job fails
  activeDeadlineSeconds: 300      # give up after five minutes
  ttlSecondsAfterFinished: 3600   # delete the finished Job an hour later
  template:
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: migrate
          image: docker.io/library/busybox:1.38.0@sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e
          command: ["sh", "-c", "echo running migrations; sleep 2; echo done"]
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              memory: 32Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
```

```sh
kubectl -n shop wait --for=condition=Complete job/migrate --timeout=2m
kubectl -n shop logs job/migrate                 # running migrations / done
```

A Job's pod template can't be changed after creation: to run it again with changes, delete it and apply again.

### CronJob

Creates a Job on a schedule:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nightly-report
  namespace: shop
spec:
  schedule: "0 2 * * *"
  timeZone: Etc/UTC
  concurrencyPolicy: Forbid       # never two at once
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 1
      activeDeadlineSeconds: 600
      template:
        spec:
          restartPolicy: Never
          automountServiceAccountToken: false
          securityContext:
            runAsNonRoot: true
            runAsUser: 10001
            runAsGroup: 10001
            seccompProfile:
              type: RuntimeDefault
          containers:
            - name: report
              image: docker.io/library/busybox:1.38.0@sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e
              command: ["sh", "-c", "echo building the nightly report"]
              resources:
                requests:
                  cpu: 10m
                  memory: 16Mi
                limits:
                  memory: 32Mi
              securityContext:
                allowPrivilegeEscalation: false
                readOnlyRootFilesystem: true
                capabilities:
                  drop: ["ALL"]
```

```sh
kubectl -n shop get cronjob nightly-report
kubectl -n shop create job --from=cronjob/nightly-report report-now   # run it now
kubectl -n shop patch cronjob nightly-report -p '{"spec":{"suspend":true}}'   # pause it
```

## Networking

### Service

A stable name and virtual IP in front of a changing set of pods, chosen by label. Other pods reach this one at `web.shop.svc.cluster.local` (or just `web` from the same namespace):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: shop
spec:
  selector:
    app: web
  ports:
    - name: http
      port: 80            # what clients connect to
      targetPort: http    # the container port, by name
```

| Type | Reachable from | Use |
|---|---|---|
| `ClusterIP` (default) | Inside the cluster | Almost everything |
| Headless (`clusterIP: None`) | Inside; DNS returns pod addresses | StatefulSets, clients that pick pods themselves |
| `NodePort` | Every node's IP, on a port in 30000 to 32767 | Rarely; behind your own load balancer |
| `LoadBalancer` | A cloud load balancer the cluster creates | One per Service, each with its own cost and address. Prefer an [Ingress](#ingress) or Gateway for HTTP |
| `ExternalName` | A DNS alias to a name outside the cluster | Pointing in-cluster clients at an external service |

The baseline's quota allows no `LoadBalancer` Services, to keep exposure going through ingress. In the lab:

```text
$ kubectl -n shop create service loadbalancer public --tcp=80:9898
error: failed to create LoadBalancer service: services "public" is forbidden: exceeded quota: compute,
requested: services.loadbalancers=1, used: services.loadbalancers=0, limited: services.loadbalancers=0
```

```sh
kubectl -n shop get svc web
kubectl -n shop port-forward svc/web 8080:80     # reach it from your machine
```

### EndpointSlice

The list of ready pod addresses behind a Service, kept up to date by the control plane. You don't create them for Services with selectors, but they're where to look when a Service doesn't answer: an empty slice means no ready pods match the selector.

```text
$ kubectl -n shop get endpointslices
NAME          ADDRESSTYPE   PORTS   ENDPOINTS                 AGE
queue-f7n8m   IPv4          8080    10.244.0.12,10.244.0.14   14s
web-rjx8w     IPv4          9898    10.244.0.7,10.244.0.9     14s
```

### Ingress

HTTP and HTTPS routing from outside the cluster to Services, by host and path. It does nothing without an **ingress controller** in the cluster (the AWS Load Balancer Controller, AKS application routing, ingress-nginx, and so on), chosen by `ingressClassName`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: shop
spec:
  ingressClassName: nginx
  rules:
    - host: shop.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  name: http
```

```sh
kubectl -n shop get ingress web    # ADDRESS stays empty until a controller for the class picks it up
```

The [web-app sample's components](apps/web-app/components/) have real ALB and AKS app routing Ingresses.

### Gateway API

The successor to Ingress, with separate resources for the infrastructure (`GatewayClass`, `Gateway`, owned by the platform team) and the routes (`HTTPRoute`, owned by app teams). The Ingress API is stable but no longer gets new features; they go into the Gateway API. It's installed as CRDs and implemented by a controller, so check your cluster has one:

```yaml
# Not applied: needs the Gateway API CRDs and a controller.
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web
  namespace: shop
spec:
  parentRefs:
    - name: public            # a Gateway the platform team runs
      namespace: gateways
  hostnames: ["shop.example.com"]
  rules:
    - backendRefs:
        - name: web
          port: 80
```

### NetworkPolicy

Which traffic may reach and leave selected pods. Once any policy selects a pod for a direction, only what policies allow gets through. The usual pattern: deny everything in the namespace, then allow each flow:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: shop
spec:
  podSelector: {}               # every pod in the namespace
  policyTypes: ["Ingress", "Egress"]
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - port: http
```

With default-deny on egress, pods also need a policy allowing DNS, as the [baseline's](platform/namespace/network-policies.yaml) does. NetworkPolicies are enforced by the network plugin; one that doesn't support them accepts the objects and enforces nothing. [OPERATIONS.md](OPERATIONS.md#networkpolicy-is-blocking-traffic) covers debugging them.

## Configuration

### ConfigMap

Non-secret configuration, as key-values or files, read by pods as environment variables (`envFrom`, `valueFrom`) or mounted files:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
  namespace: shop
data:
  PODINFO_UI_MESSAGE: Hello from a ConfigMap
```

```sh
kubectl -n shop create configmap app-files --from-file=config/ --dry-run=client -o yaml   # from files
kubectl -n shop rollout restart deployment/web   # pods only read env vars at start
```

Pods don't restart when a ConfigMap changes. Kustomize's `configMapGenerator` (used by the [samples](apps/web-app/base/kustomization.yaml)) and Helm's checksum annotation ([Helm](../helm/03-writing-charts.md#roll-pods-when-config-changes)) roll them automatically.

### Secret

Like a ConfigMap, for sensitive values. **Base64 is encoding, not encryption:**

```text
$ kubectl -n shop get secret web-db -o jsonpath='{.data.password}'
Y2hhbmdlLW1l
$ kubectl -n shop get secret web-db -o jsonpath='{.data.password}' | base64 -d
change-me
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: web-db
  namespace: shop
type: Opaque
stringData:                     # plain text here; the API server stores it base64-encoded
  password: change-me
```

That manifest is fine for a lab and wrong for anything else: a Secret in Git is a leaked secret. In real environments, let the External Secrets Operator or the Secrets Store CSI driver create Secrets from AWS Secrets Manager or Azure Key Vault, restrict who can read Secrets with RBAC, and turn on encryption at rest ([Helm: secrets](../helm/07-deploying-and-operating.md#secrets)).

## Storage

### PersistentVolumeClaim

A request for storage of a size and access mode. The cluster's StorageClass provisions a volume to match, and pods mount the claim. A StatefulSet's `volumeClaimTemplates` create one per pod ([above](#statefulset)); a single claim looks like this:

```yaml
# Not applied: a standalone claim, for a single-replica workload.
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: uploads
  namespace: shop
spec:
  accessModes: ["ReadWriteOnce"]   # one node at a time; ReadWriteMany needs a shared filesystem (EFS, Azure Files)
  storageClassName: standard       # omit for the cluster's default class
  resources:
    requests:
      storage: 5Gi
```

### PersistentVolume and StorageClass

A **PersistentVolume** is the storage itself, cluster-scoped. With dynamic provisioning you never write one: the **StorageClass** creates them on demand, through a CSI driver. Platform teams define the classes; `kubectl get storageclass` shows which exist and which is the default.

```yaml
# Not applied: an EKS class for the EBS CSI driver.
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-encrypted
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
reclaimPolicy: Retain                    # keep the disk if the claim is deleted
volumeBindingMode: WaitForFirstConsumer  # create it in the zone where the pod lands
allowVolumeExpansion: true
```

`reclaimPolicy: Delete` (the usual default) deletes the disk with the claim; use `Retain` for data you can't lose. AKS ships classes such as `managed-csi` for Azure Disk.

## Identity and access

### ServiceAccount

The identity pods run as, for the Kubernetes API (through RBAC) and, with workload identity, for the cloud ([Cloud identity](README.md#cloud-identity)). Give each workload its own, and don't mount an API token unless it calls the API:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web
  namespace: shop
automountServiceAccountToken: false
```

```sh
kubectl -n shop create token web --duration=10m   # a short-lived token, for testing access
```

### Role and RoleBinding

A **Role** lists allowed verbs on resources in one namespace; a **RoleBinding** grants it to users, groups, or service accounts:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: shop
rules:
  - apiGroups: [""]                 # "" is the core group (pods, services, configmaps, secrets)
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: reader
  namespace: shop
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: reader-pods
  namespace: shop
subjects:
  - kind: ServiceAccount
    name: reader
    namespace: shop
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
```

Check what an identity can do before relying on it:

```text
$ kubectl auth can-i list pods -n shop --as=system:serviceaccount:shop:reader
yes
$ kubectl auth can-i delete pods -n shop --as=system:serviceaccount:shop:reader
no
$ kubectl auth can-i list secrets -n shop --as=system:serviceaccount:shop:reader
no
```

`kubectl auth can-i --list -n shop --as=...` lists everything an identity may do.

### ClusterRole and ClusterRoleBinding

The same, cluster-wide. A ClusterRole can also be granted in a single namespace through a RoleBinding, which is how the built-in `view`, `edit`, and `admin` roles are usually used:

```yaml
# Not applied: grants the built-in "view" role in one namespace to a group from the identity provider.
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: shop-viewers
  namespace: shop
subjects:
  - kind: Group
    name: shop-developers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
```

Grant to groups from the identity provider, not to individual users, and keep ClusterRoleBindings rare: one grants its permissions in every namespace, including future ones.

## Namespaces and policy

### ResourceQuota

Caps what a namespace can consume. Once a quota limits CPU or memory, every pod must declare those requests and limits, or have them filled in by a [LimitRange](#limitrange):

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute
  namespace: shop
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.memory: 16Gi
    pods: "40"
    services.loadbalancers: "0"
```

```text
$ kubectl -n shop describe quota compute
Resource                Used   Hard
--------                ----   ----
limits.memory           384Mi  16Gi
pods                    6      40
requests.cpu            140m   4
requests.memory         192Mi  8Gi
services.loadbalancers  0      0
```

### LimitRange

Default requests and limits for containers that don't set them, and minimums and maximums for those that do:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
  namespace: shop
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 50m
        memory: 64Mi
      default:
        memory: 128Mi
```

### PodDisruptionBudget

How many of an app's pods voluntary disruptions (node drains, cluster upgrades) may take down at once. Without one, a drain can remove every replica together:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web
  namespace: shop
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: web
```

A PDB that allows zero disruptions (`maxUnavailable: 0`, or `minAvailable` equal to the replica count) blocks drains entirely; [OPERATIONS.md](OPERATIONS.md#drain-is-stuck) covers the symptom.

### PriorityClass

Which pods the scheduler places first when the cluster is full, and which it evicts last. Cluster-scoped, and usually defined by the platform team:

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: shop-critical
value: 100000
globalDefault: false
description: Customer-facing shop services, scheduled before batch work.
```

Pods opt in with `priorityClassName: shop-critical`. Higher priority can preempt (evict) lower-priority pods, so keep the number of classes small and agreed.

## Scaling

### HorizontalPodAutoscaler

Changes a Deployment's or StatefulSet's replica count from metrics. It needs metrics-server (built into AKS; an add-on on EKS; installed in the lab) and CPU requests on the pods, since utilization is measured against requests:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web
  namespace: shop
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

```sh
kubectl -n shop get hpa web            # TARGETS shows <unknown> until metrics arrive, about a minute
kubectl -n shop describe hpa web       # why it scaled, or didn't
```

## Extending the API

### CustomResourceDefinition

Adds a resource type of your own, with a schema the API server enforces. Operators and controllers (cert-manager, Argo CD, External Secrets, Crossplane) are built on CRDs: you create custom resources, and a controller acts on them.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backups.example.com
spec:
  group: example.com
  scope: Namespaced
  names:
    plural: backups
    singular: backup
    kind: Backup
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: ["schedule", "retentionDays"]
              properties:
                schedule:
                  type: string
                retentionDays:
                  type: integer
                  minimum: 1
```

Once it's established, the new kind works like any other:

```yaml
apiVersion: example.com/v1
kind: Backup
metadata:
  name: orders-db
  namespace: shop
spec:
  schedule: "0 3 * * *"
  retentionDays: 14
```

```text
$ kubectl -n shop get backups
NAME        AGE
orders-db   13s

$ kubectl apply -f bad-backup.yaml       # retentionDays: 0
The Backup "bad" is invalid: spec.retentionDays: Invalid value: 0: spec.retentionDays in body should be greater than or equal to 1
```

Without a controller watching it, a custom resource is just stored data; the controller is what makes a `Backup` take backups. Deleting a CRD deletes every resource of that kind in the cluster.

---

## Checking these examples

[tests/resources-guide.sh](tests/resources-guide.sh) checks this page against a real cluster: it extracts every YAML block, validates them with kubeconform (strict, Kubernetes 1.34), and applies every block that starts with `apiVersion:` to the Helm lab's kind cluster, CRDs first. Then it checks what the page claims: the workloads become ready, the StatefulSet's claims bind, the Job completes, RBAC allows and denies what it says, the quota refuses a LoadBalancer, the CRD rejects an invalid resource, `kubectl diff` exits 0 then 1, and imperative creation fails under "restricted". Blocks that start with a comment (`# Not applied`, `# Generated`) are validated but not applied.

```sh
devops/helm/lab/lab.sh up
devops/kubernetes/tests/resources-guide.sh
```
