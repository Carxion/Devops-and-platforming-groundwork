# How Kubernetes works: concepts and components

[← Kubernetes](README.md)

What Kubernetes is, the ideas everything else builds on, and the components that make a cluster work: what each one does, how they talk to each other, and how to see them on a real cluster. Read this first if you're new; [RESOURCES.md](RESOURCES.md) then covers the resource types you'll write, and [OPERATIONS.md](OPERATIONS.md) the day-to-day commands.

The output shown is real, from kubectl 1.34 against the [Helm lab's](../helm/lab/README.md) one-node kind cluster, and [tests/concepts-guide.sh](tests/concepts-guide.sh) checks every claim on this page that the lab can show. The component descriptions follow the Kubernetes documentation's [cluster components](https://kubernetes.io/docs/concepts/overview/components/) and [architecture](https://kubernetes.io/docs/concepts/architecture/) pages.

## Contents

- [What Kubernetes is](#what-kubernetes-is)
- [Core ideas](#core-ideas)
- [The architecture](#the-architecture)
- [Control plane components](#control-plane-components)
- [Node components](#node-components)
- [Add-ons](#add-ons)
- [Following a deployment through the cluster](#following-a-deployment-through-the-cluster)
- [The networking model](#the-networking-model)
- [Managed clusters: what you run and what you don't](#managed-clusters-what-you-run-and-what-you-dont)
- [Seeing it for yourself](#seeing-it-for-yourself)
- [Checking this page](#checking-this-page)

---

## What Kubernetes is

Kubernetes runs containers across a group of machines and keeps them running. You tell it what should exist ("three copies of this image, reachable at this name, with this much memory each"), and it works out where to put them, starts them, restarts them when they crash, replaces them when a machine dies, and routes traffic to the healthy ones.

What it gives you, compared with running containers on servers yourself:

| Need | Without Kubernetes | With Kubernetes |
|---|---|---|
| Placing containers | You pick a server for each one | The scheduler picks, based on the resources each one requests |
| Recovering from failure | Monitoring pages someone, who restarts things | Controllers notice and replace the failed pod, usually within seconds |
| Finding other services | Hard-coded addresses, or a separate service registry | A stable DNS name and virtual IP per Service |
| Deploying a new version | A script that stops and starts containers | A rolling update you can pause, watch, and undo |
| Scaling | Add servers and edit the load balancer | Change a number, or let an autoscaler change it |

What it doesn't give you: a build system, a CI/CD pipeline, a secrets vault, a database you don't have to look after, or an application that tolerates being restarted. Those are still yours.

## Core ideas

Five ideas explain most of how Kubernetes behaves.

**1. You declare desired state; controllers make it real.** Every object has a `spec` (what you want) and a `status` (what is). You write the spec, usually as YAML in Git; the cluster writes the status. You never tell Kubernetes "start a container": you say "there should be three", and something in the cluster makes it so.

**2. Everything goes through the API.** The cluster is a database of objects behind a REST API. `kubectl`, the scheduler, the controllers, the kubelet on every node, Helm, and Argo CD are all API clients: they read objects, watch for changes, and write updates. No component talks to another directly; they coordinate through the objects they read and write. `-v=6` shows the requests behind any kubectl command:

```text
$ kubectl -n kube-system get pods -v=6 2>&1 >/dev/null | grep Response
I1028 18:35:45.970749       7 round_trippers.go:632] "Response" verb="GET" url="https://helm-lab-control-plane:6443/api?timeout=32s" status="200 OK" milliseconds=3
I1028 18:35:45.972613       7 round_trippers.go:632] "Response" verb="GET" url="https://helm-lab-control-plane:6443/apis?timeout=32s" status="200 OK" milliseconds=0
I1028 18:35:45.980321       7 round_trippers.go:632] "Response" verb="GET" url="https://helm-lab-control-plane:6443/api/v1/namespaces/kube-system/pods?limit=500" status="200 OK" milliseconds=2
```

The first two ask the server which resource types it serves; the third is the list of pods.

**3. Controllers run reconcile loops.** A controller watches one kind of object, compares the spec to the real world, and acts to close the gap. Then it does it again, forever. This is why Kubernetes heals itself: delete a pod a Deployment owns and a controller notices there are now too few and creates one. It's also why a manual change to a managed object gets undone. See [following a deployment](#following-a-deployment-through-the-cluster) for the loop in action.

**4. The pod is the unit of scheduling.** Kubernetes doesn't run containers directly; it runs pods: one or more containers that share a network address and can share volumes, always placed on the same node. Pods are disposable. They get a new name and IP address every time they're replaced, which is why you reach them through a Service and manage them through a controller (a Deployment, StatefulSet, Job, and so on) rather than creating them by hand.

**5. Labels and selectors connect things.** Objects find each other by labels, not by name. A Deployment owns the pods that match its selector; a Service sends traffic to the pods that match its selector; a NetworkPolicy applies to the pods that match its selector. If a label is wrong, things silently don't connect, and that's the cause of a large share of "my Service has no endpoints" problems.

A few more terms you'll meet straight away:

| Term | Meaning |
|---|---|
| **Cluster** | A control plane plus the nodes it manages |
| **Node** | A machine (VM or physical) that runs pods |
| **Namespace** | A named group of objects inside a cluster: the boundary for names, access control, quotas, and policy |
| **Object / resource** | One record in the API, such as a Deployment named `web`. "Resource" also means the type (`deployments`) |
| **Manifest** | A YAML or JSON file describing one or more objects |
| **Controller** | A loop that makes the real world match one kind of object's spec |
| **Owner reference** | The link from an object to the object that created it (pod → ReplicaSet → Deployment). Deleting the owner deletes what it owns |

## The architecture

A cluster has two halves: the **control plane**, which decides what should happen, and the **nodes**, which run the workloads.

```text
                         kubectl, CI, GitOps controllers
                                      │ HTTPS (6443)
┌─────────────────────────── Control plane ───────────────────────────┐
│                                                                     │
│   kube-scheduler ──┐                          ┌── kube-controller-  │
│                    │  watch / write objects   │   manager           │
│                    ▼                          ▼                     │
│               ┌──────────────────────────────────┐                  │
│               │          kube-apiserver          │◄── cloud-        │
│               └─────────────────┬────────────────┘    controller-   │
│                                 │ the only client      manager      │
│                            ┌────▼────┐                              │
│                            │  etcd   │  every object, stored        │
│                            └─────────┘                              │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │ watch pods for this node, report status
          ┌───────────────────────┼───────────────────────┐
┌─────────▼──────── Node ─────────┐   ┌─────────▼──────── Node ─────────┐
│ kubelet ──CRI──► containerd     │   │ kubelet ──CRI──► containerd     │
│                  └─► pods       │   │                  └─► pods       │
│ kube-proxy (Service routing)    │   │ kube-proxy (Service routing)    │
│ CNI plugin (pod networking)     │   │ CNI plugin (pod networking)     │
└─────────────────────────────────┘   └─────────────────────────────────┘
```

Two things to notice. Only the API server talks to etcd: every other component, including the ones on the control plane, goes through the API. And the arrows from the nodes point up: the kubelet asks the API server which pods it should run, rather than the control plane pushing work to it.

## Control plane components

| Component | What it does | If it's down |
|---|---|---|
| **kube-apiserver** | The front door. Serves the REST API, authenticates and authorizes every request, runs admission (Pod Security, quotas, webhooks), validates objects, and stores them in etcd. Scales horizontally: run several behind a load balancer. | You can't change anything, and controllers can't act. Running pods keep running. |
| **etcd** | A consistent, distributed key-value store holding every object in the cluster. The cluster's only source of truth, so it's what you back up. | The API server can't read or write; effectively the same as the API server being down. Lose its data without a backup and you've lost the cluster's state. |
| **kube-scheduler** | Watches for pods with no node assigned and picks one: filters out nodes that can't take the pod (not enough requested CPU or memory, taints, affinity rules, volume zones), scores the rest, and writes the choice to the pod. | New pods stay `Pending`. Existing pods are unaffected. |
| **kube-controller-manager** | One process running the built-in controllers: Deployment, ReplicaSet, StatefulSet, DaemonSet, Job, CronJob, node lifecycle, namespace cleanup, service accounts, garbage collection, EndpointSlice, and more. | Nothing reconciles: a crashed pod isn't replaced, a scale-up doesn't happen, a deleted namespace sticks in `Terminating`. |
| **cloud-controller-manager** | The cloud-specific controllers: creates load balancers for `type: LoadBalancer` Services, labels nodes with their zone, removes nodes whose VMs are gone. Only on clusters running in a cloud; kind doesn't have one. | Load balancers aren't created or updated; deleted VMs linger as nodes. |

In a production control plane each component runs on three or more machines. etcd needs a majority of its members (two of three, three of five) to accept writes. The scheduler and controller manager run as several copies, but only one is active at a time: they elect a leader through a [Lease](https://kubernetes.io/docs/concepts/architecture/leases/) object, and a standby takes over if the leader stops renewing it.

```text
$ kubectl -n kube-system get lease
NAME                                   HOLDER                                                                      AGE
apiserver-u7r6yufo7t6rqely33l2wgchim   apiserver-u7r6yufo7t6rqely33l2wgchim_4565dc7f-c819-4d40-82ba-d875f0e91b6d   6m18s
kube-controller-manager                helm-lab-control-plane_1ccb2e4b-e504-4e96-8a30-b3d4b47bda3c                 6m16s
kube-scheduler                         helm-lab-control-plane_566bf3e3-384a-4d88-a390-d923607cf346                 6m15s
```

On a cluster built with kubeadm (kind uses it), the control plane components are themselves pods in `kube-system`. They're **static pods**: the kubelet on the control plane node starts them from files in `/etc/kubernetes/manifests`, without the API server, which is how the API server can run as a pod at all.

```text
$ kubectl -n kube-system get pods
NAME                                             READY   STATUS    RESTARTS   AGE
coredns-66bc5c9577-d5qk9                         1/1     Running   0          5m52s
coredns-66bc5c9577-wkfhg                         1/1     Running   0          5m52s
etcd-helm-lab-control-plane                      1/1     Running   0          5m58s
kindnet-dtbcx                                    1/1     Running   0          5m53s
kube-apiserver-helm-lab-control-plane            1/1     Running   0          5m58s
kube-controller-manager-helm-lab-control-plane   1/1     Running   0          5m58s
kube-proxy-4fttz                                 1/1     Running   0          5m52s
kube-scheduler-helm-lab-control-plane            1/1     Running   0          5m58s
metrics-server-7f6b8b4497-qwndz                  1/1     Running   0          5m25s

$ docker exec helm-lab-control-plane ls /etc/kubernetes/manifests
etcd.yaml
kube-apiserver.yaml
kube-controller-manager.yaml
kube-scheduler.yaml
```

The pods named after the node (`etcd-helm-lab-control-plane`) are the static ones; the API server shows them as "mirror pods" so you can see them, but deleting one there doesn't stop it. On EKS and AKS you won't see any of these: the provider runs the control plane for you (see [managed clusters](#managed-clusters-what-you-run-and-what-you-dont)).

### What's in etcd

Every object is a key under `/registry/<resource>/<namespace>/<name>`. You'd never read or write etcd directly in normal work, but looking once makes "the cluster is a database of objects" concrete. After applying the [demo](#seeing-it-for-yourself) below:

```text
$ kubectl -n kube-system exec etcd-helm-lab-control-plane -- etcdctl \
    --cacert /etc/kubernetes/pki/etcd/ca.crt \
    --cert /etc/kubernetes/pki/etcd/server.crt \
    --key /etc/kubernetes/pki/etcd/server.key \
    get /registry --prefix --keys-only | grep concepts | grep -v events
/registry/configmaps/concepts/kube-root-ca.crt
/registry/deployments/concepts/hello
/registry/endpointslices/concepts/hello-9vsfp
/registry/namespaces/concepts
/registry/pods/concepts/hello-77b57f65d6-bc5k9
/registry/pods/concepts/hello-77b57f65d6-ngtws
/registry/replicasets/concepts/hello-77b57f65d6
/registry/serviceaccounts/concepts/default
/registry/services/endpoints/concepts/hello
/registry/services/specs/concepts/hello
```

One Deployment and one Service produced all of that: the ReplicaSet and pods from the controllers, the EndpointSlice from the EndpointSlice controller, and the ServiceAccount and root CA ConfigMap that every namespace gets. The values are stored in a binary encoding, and Secrets are only base64 in it unless the API server is configured to [encrypt them at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/), which is why etcd access and backups need the same protection as the secrets themselves.

## Node components

| Component | What it does |
|---|---|
| **kubelet** | The agent on every node, running as a system service (not a pod). Watches the API for pods assigned to its node, tells the container runtime to start them, runs their probes, mounts their volumes, and reports their status and the node's health back. It also starts static pods from local files. |
| **Container runtime** | Pulls images and runs containers. The kubelet talks to it through the Container Runtime Interface (CRI). containerd and CRI-O are the common ones. Docker Engine stopped being supported directly (the "dockershim") in Kubernetes 1.24; images built with Docker run unchanged. |
| **kube-proxy** | Makes Service virtual IPs work. Watches Services and EndpointSlices and programs the node's packet filtering (iptables or nftables rules) so traffic to a Service IP lands on one of its pods. Runs as a DaemonSet. Some network plugins, such as Cilium, replace it. |
| **CNI plugin** | Gives each pod its network interface and IP address and connects pods across nodes. Not part of Kubernetes itself; the kubelet calls whichever plugin the cluster installed (kindnet here, the VPC CNI on EKS, Azure CNI or Cilium on AKS). Whether NetworkPolicy is enforced depends on the plugin. |

```text
$ docker exec helm-lab-control-plane systemctl is-active kubelet containerd
active
active

$ kubectl get nodes -o wide
NAME                     STATUS   ROLES           AGE     VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                      CONTAINER-RUNTIME
helm-lab-control-plane   Ready    control-plane   6m17s   v1.34.11   172.19.0.3    <none>        Debian GNU/Linux 13 (trixie)   6.18.54.1-microsoft-standard-WSL2   containerd://2.3.4
```

`crictl` talks to the runtime through the same CRI the kubelet uses, so it shows what's really running on a node, including when the API server is down:

```text
$ docker exec helm-lab-control-plane crictl ps
CONTAINER           IMAGE               CREATED             STATE               NAME                      ATTEMPT             POD ID              POD                                              NAMESPACE
c3903ddac3e8d       d7b01abacd67f       2 minutes ago       Running             metrics-server            0                   70c6b88bff09a       metrics-server-7f6b8b4497-qwndz                  kube-system
ab05f76419402       52546a367cc9e       5 minutes ago       Running             coredns                   0                   69f0febfba2ec       coredns-66bc5c9577-wkfhg                         kube-system
32f0ba3403aa8       4626fe10df5b9       6 minutes ago       Running             kindnet-cni               0                   027ae735d9cb0       kindnet-dtbcx                                    kube-system
76d32828f7ebb       09f56957dedd9       6 minutes ago       Running             kube-proxy                0                   625b0476ce741       kube-proxy-4fttz                                 kube-system
b1b82639a993f       a3e246e9556e9       6 minutes ago       Running             etcd                      0                   28e031b943cdc       etcd-helm-lab-control-plane                      kube-system
3a028b1f43d94       0209ad1d5728b       6 minutes ago       Running             kube-apiserver            0                   a6c761200f61d       kube-apiserver-helm-lab-control-plane            kube-system
...
```

On a managed cluster you'd reach a node with `kubectl debug node/<name>` instead (see [OPERATIONS.md](OPERATIONS.md#nodes)).

### How the control plane knows a node is alive

Each kubelet renews a Lease in the `kube-node-lease` namespace every few seconds, and periodically updates the node's status conditions. If the lease stops being renewed, the node lifecycle controller marks the node `NotReady` and, after a grace period, the pods on it are evicted and recreated elsewhere by their controllers.

```text
$ kubectl -n kube-node-lease get lease
NAME                     HOLDER                   AGE
helm-lab-control-plane   helm-lab-control-plane   11m

$ kubectl get node helm-lab-control-plane -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
MemoryPressure=False
DiskPressure=False
PIDPressure=False
Ready=True
```

The pressure conditions are the kubelet's own view: when a node runs short of memory or disk, the kubelet evicts pods itself, starting with pods using more than they requested, then by priority. That's another reason to set requests to what the app really uses.

## Add-ons

Add-ons are ordinary workloads (Deployments and DaemonSets, usually in `kube-system`) that clusters need in practice but Kubernetes doesn't build in.

| Add-on | What it does | In the lab | On EKS / AKS |
|---|---|---|---|
| **Cluster DNS** (CoreDNS) | Gives every Service a DNS name, `<service>.<namespace>.svc.cluster.local`, and is the nameserver in every pod's `/etc/resolv.conf` | `coredns` | Managed add-on on both |
| **Network plugin** (CNI) | Pod IPs and pod-to-pod networking, and NetworkPolicy enforcement if the plugin supports it | `kindnet` | VPC CNI / Azure CNI or Cilium |
| **metrics-server** | CPU and memory usage per pod and node, for `kubectl top` and the HorizontalPodAutoscaler | installed by `lab.sh up` | Add-on on EKS, built in on AKS |
| **Ingress or Gateway controller** | Implements Ingress or Gateway API objects with a real proxy or cloud load balancer | not installed | AWS Load Balancer Controller / application routing |
| **Storage (CSI) driver** | Creates and attaches volumes for PersistentVolumeClaims | `local-path-provisioner` | EBS CSI / Azure Disk CSI |

Kubernetes defines the API for an Ingress, a NetworkPolicy, or a volume claim, but something has to implement it. An Ingress with no controller, or a NetworkPolicy on a plugin that doesn't enforce policies, is accepted by the API server and then does nothing. When a feature "doesn't work", check that its controller is installed.

## Following a deployment through the cluster

Here's what happens when you apply the [demo](#seeing-it-for-yourself) Deployment with two replicas. Each step is a different component reacting to an object another one wrote:

1. **kubectl** sends the Deployment to the **API server**, which authenticates you, checks RBAC, runs admission (the namespace's Pod Security level, quotas), validates it, and stores it in **etcd**.
2. The **Deployment controller** (in kube-controller-manager) sees a Deployment with no ReplicaSet for its pod template, and creates one with `replicas: 2`.
3. The **ReplicaSet controller** sees a ReplicaSet wanting 2 pods with 0 existing, and creates 2 Pod objects. They have no node yet, and admission checks each pod against Pod Security.
4. The **scheduler** sees 2 unscheduled pods, picks a node for each, and writes it to `spec.nodeName`.
5. The **kubelet** on that node sees pods assigned to it, has the **container runtime** pull the image and start the containers, with the **CNI plugin** giving each pod an IP address, then starts running the readiness probe.
6. When the probe passes, the kubelet marks the pod Ready. The **EndpointSlice controller** adds its IP to the Service's EndpointSlice, and **kube-proxy** on every node adds it to the Service's routing rules. Only now does traffic reach it.

Events record each step, and the component that reported it. Trimmed to one pod of a scale-up from 2 to 3, in the order they happened:

```text
$ kubectl -n concepts scale deployment hello --replicas=3
$ kubectl -n concepts get events -o custom-columns=COMPONENT:.source.component,REASON:.reason,OBJECT:.involvedObject.name
COMPONENT               REASON              OBJECT
deployment-controller   ScalingReplicaSet   hello
replicaset-controller   SuccessfulCreate    hello-77b57f65d6
default-scheduler       Scheduled           hello-77b57f65d6-bxv92
kubelet                 Pulled              hello-77b57f65d6-bxv92
kubelet                 Created             hello-77b57f65d6-bxv92
kubelet                 Started             hello-77b57f65d6-bxv92
```

Events are kept for an hour by default, so they're the first place to look when something didn't happen ([OPERATIONS.md](OPERATIONS.md#troubleshooting-by-symptom) works through the common cases). The owner references record the chain:

```text
$ kubectl -n concepts get pod hello-77b57f65d6-ngtws -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}'
ReplicaSet/hello-77b57f65d6
$ kubectl -n concepts get replicaset hello-77b57f65d6 -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}'
Deployment/hello
```

### Self-healing is the same loop

Delete a pod and the ReplicaSet controller sees one too few and creates a replacement, with a new name, before the old one has even finished shutting down:

```text
$ kubectl -n concepts delete pod hello-77b57f65d6-552nd --wait=false
pod "hello-77b57f65d6-552nd" deleted from concepts namespace

$ kubectl -n concepts get pods
NAME                     READY   STATUS        RESTARTS   AGE
hello-77b57f65d6-552nd   1/1     Terminating   0          4m11s
hello-77b57f65d6-bc5k9   0/1     Pending       0          0s
hello-77b57f65d6-ngtws   1/1     Running       0          4m11s
```

The same loop is why `kubectl delete pod` is a common way to restart a misbehaving pod, and why it doesn't work for a pod nothing owns: a bare pod is just gone.

## The networking model

Kubernetes defines a [network model](https://kubernetes.io/docs/concepts/services-networking/) and leaves most of the implementation to the network plugin:

- Every pod gets its own IP address, shared by its containers (which reach each other on `localhost`).
- Pods can reach every other pod's IP directly, on any node, without NAT, unless a NetworkPolicy says otherwise.
- Node agents, such as the kubelet, can reach every pod on their node.
- A Service gets a stable virtual IP and DNS name in front of a changing set of pods.

Following one request from a pod to the demo Service, `hello`:

```text
$ kubectl -n concepts exec deploy/hello -- cat /etc/resolv.conf
search concepts.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

$ kubectl -n concepts exec deploy/hello -- nslookup hello.concepts.svc.cluster.local
Server:   10.96.0.10
Address:  10.96.0.10:53

Name:     hello.concepts.svc.cluster.local
Address:  10.96.47.221

$ kubectl -n concepts get service,endpointslices
NAME            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/hello   ClusterIP   10.96.47.221   <none>        80/TCP    4m11s

NAME                                         ADDRESSTYPE   PORTS   ENDPOINTS               AGE
endpointslice.discovery.k8s.io/hello-9vsfp   IPv4          9898    10.244.0.6,10.244.0.7   4m11s
```

1. The app looks up `hello`. The search list in `resolv.conf` expands it to `hello.concepts.svc.cluster.local`, and CoreDNS (the `kube-dns` Service at `10.96.0.10`) answers with the Service's ClusterIP.
2. The app connects to `10.96.47.221:80`. No process listens on that address: it's virtual.
3. kube-proxy's rules on the node rewrite the destination to one ready pod, chosen at random, on its real port (`9898`):

```text
$ docker exec helm-lab-control-plane iptables-save -t nat | grep 'concepts/hello' | grep -v MASQ
-A KUBE-SEP-A7FOXJSWZZZPGL35 -p tcp -m comment --comment "concepts/hello:http" -m tcp -j DNAT --to-destination 10.244.0.7:9898
-A KUBE-SEP-KCAHWCYU4NRM4KRM -p tcp -m comment --comment "concepts/hello:http" -m tcp -j DNAT --to-destination 10.244.0.8:9898
-A KUBE-SERVICES -d 10.96.47.221/32 -p tcp -m comment --comment "concepts/hello:http cluster IP" -m tcp --dport 80 -j KUBE-SVC-BNKYOUUKRMLTEHB6
-A KUBE-SVC-BNKYOUUKRMLTEHB6 -m comment --comment "concepts/hello:http -> 10.244.0.7:9898" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-A7FOXJSWZZZPGL35
-A KUBE-SVC-BNKYOUUKRMLTEHB6 -m comment --comment "concepts/hello:http -> 10.244.0.8:9898" -j KUBE-SEP-KCAHWCYU4NRM4KRM
```

Read them from `KUBE-SERVICES`: traffic to the ClusterIP on port 80 jumps to the Service's chain, which picks one endpoint chain at random (50% the first, otherwise the second), which rewrites the destination to that pod's IP and port.

So a Service only routes to pods that are Ready and match its selector, and it balances per connection, not per request: a client that holds one long-lived connection (gRPC, HTTP/2, database pools) keeps talking to the same pod.

Getting traffic in from **outside** the cluster is a separate layer on top: a `NodePort` Service opens a port on every node, a `LoadBalancer` Service asks the cloud-controller-manager for a cloud load balancer, and an Ingress or Gateway sends HTTP to Services through a controller. [RESOURCES.md](RESOURCES.md#networking) has each one.

## Managed clusters: what you run and what you don't

On EKS and AKS (the clusters the [Terraform stacks](../terraform/) build), the provider runs the control plane: you get an API endpoint, not machines.

| Part | EKS | AKS | You still own |
|---|---|---|---|
| API server, etcd, scheduler, controller manager | AWS, across availability zones | Azure | Choosing the Kubernetes version and upgrading on time; API endpoint access (public, private, or both) |
| etcd backups | AWS | Azure | Backing up what etcd doesn't know about: volumes, and your manifests in Git |
| Nodes | Managed node groups, Fargate, or Auto Mode | Node pools | Node OS images and upgrades (managed for you to varying degrees), sizing, and how many |
| kube-proxy, CoreDNS, CNI | Add-ons you choose versions of | Managed by AKS | Keeping add-on versions in step with the cluster |
| Ingress, CSI drivers, metrics-server | Add-ons and controllers you install | Some built in, some enabled | Installing, configuring, and upgrading them |
| Everything in your namespaces | | | All of it |

You can't `kubectl exec` into the control plane or read etcd on a managed cluster, and you don't need to. Its health shows up through `kubectl get --raw='/readyz?verbose'` and the provider's own console and logs.

## Seeing it for yourself

Start the lab, apply this Deployment and Service, and run the commands on this page against them. It meets Pod Security "restricted", which the namespace enforces:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: concepts
  labels:
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
  namespace: concepts
  labels:
    app: hello
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: hello
          image: ghcr.io/stefanprodan/podinfo:6.15.0@sha256:ec73780a8425f59ea49f5bc8cdff0d598805a224fbaa1f86c67a244f250fa9da
          ports:
            - name: http
              containerPort: 9898
          readinessProbe:
            httpGet:
              path: /readyz
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
---
apiVersion: v1
kind: Service
metadata:
  name: hello
  namespace: concepts
spec:
  selector:
    app: hello
  ports:
    - name: http
      port: 80
      targetPort: http
```

```sh
devops/helm/lab/lab.sh up
devops/helm/lab/lab.sh shell          # kubectl, pointed at the lab cluster
kubectl apply -f concepts.yaml        # the manifest above
kubectl -n concepts rollout status deployment/hello
```

The `docker exec helm-lab-control-plane ...` commands run on your machine, not in the lab shell: the kind node is a Docker container, so that's how you get onto it.

Things to try, and what to watch for:

| Try | Watch | What it shows |
|---|---|---|
| `kubectl -n concepts delete pod <name>` | `kubectl -n concepts get pods -w` | The ReplicaSet controller replacing a pod |
| `kubectl -n concepts scale deployment hello --replicas=5` | `kubectl -n concepts get events -w` | Controller, scheduler, and kubelet events in turn |
| Change the readiness probe path to `/nope` and apply | `kubectl -n concepts get endpointslices -w` | A rollout that stalls: new pods never become Ready, so they never get traffic, and the old ones stay |
| `kubectl -n concepts rollout undo deployment/hello` | `kubectl -n concepts get replicaset` | Rollback is switching back to the previous ReplicaSet |
| Set the memory request to `100Gi` and apply | `kubectl -n concepts describe pod <pending pod>` | The scheduler finding no node with room: `Insufficient memory` |
| Remove `runAsNonRoot` and apply | `kubectl -n concepts get events` | Admission rejecting the pod before it exists |
| `kubectl get --raw /api/v1/namespaces/concepts/pods` | | It's all a REST API; kubectl is a client |
| `kubectl -n concepts get pods -v=6` | | The HTTP requests kubectl makes |

Clean up with `kubectl delete namespace concepts`.

Where to go next: [RESOURCES.md](RESOURCES.md) for every common resource type, [README.md](README.md) for the hardened sample apps and how they're deployed, [OPERATIONS.md](OPERATIONS.md) for troubleshooting, and [Helm](../helm/README.md) for packaging.

---

## Checking this page

[tests/concepts-guide.sh](tests/concepts-guide.sh) checks this page against the Helm lab's kind cluster. On the node, it checks the static pod manifests, that the kubelet and containerd are system services, and that kube-proxy has programmed Service rules. Through the API, it validates and applies the demo, then checks the control plane pods, leader-election and node leases, the owner chain, the events and which component reports each, pod replacement, DNS, the Service's endpoints and routing, and the etcd keys. Everything it creates is removed at the end.

```sh
devops/helm/lab/lab.sh up
devops/kubernetes/tests/concepts-guide.sh
```

Names, IP addresses, and ages in the output above differ on every run.
