# Helm lab

[← Helm](../README.md)

A disposable Kubernetes cluster to develop and test charts against, set up like a real platform namespace, and a tools image so nothing but Docker needs installing.

| Piece | Is |
|---|---|
| [Dockerfile](Dockerfile) | The tools image: Helm 4.3.1, kubectl 1.34, kubeconform 0.8.0, chart-testing 3.15.0, kind 0.33.0, yamllint, yamale, and the helm-unittest and helm-diff plugins. Every download is checked against a pinned checksum |
| [kind-config.yaml](kind-config.yaml) | A one-node kind cluster running Kubernetes 1.34.11. kind's network plugin enforces NetworkPolicy, so default-deny is real |
| A `registry:3` container | A local OCI registry at `helm-lab-registry:5000` on the lab network, and `127.0.0.1:5001` on your machine. The cluster pulls `localhost:5001/...` images from it, so images you build can be deployed by digest |
| metrics-server | Installed by `lab.sh up` from its Helm chart, so HorizontalPodAutoscalers have CPU metrics |
| [lab.sh](lab.sh) | `up`, `check`, `shell`, `down` |
| [check.sh](check.sh) | Every check on the example charts |

## Use

```sh
devops/helm/lab/lab.sh up       # build the image, start the registry and cluster (a minute or two)
devops/helm/lab/lab.sh check    # every check: about four minutes with the cluster, seconds without
devops/helm/lab/lab.sh shell    # helm and kubectl, pointed at the cluster, repository at /work
devops/helm/lab/lab.sh down     # delete the cluster and registry
```

`check` runs the static checks even without `up`, so it's quick to use while editing a chart. In `shell`, try the guides' commands against the cluster:

```sh
kubectl apply -k devops/kubernetes/platform/namespace
cp -r devops/helm/examples/charts /tmp/charts && helm dependency build /tmp/charts/web-app
helm install web-app /tmp/charts/web-app -n sample-apps -f devops/helm/examples/environments/dev/web-app.yaml --wait
helm test web-app -n sample-apps
kubectl -n sample-apps get hpa web-app
```

(Copying the charts to `/tmp` keeps `helm dependency build`'s output out of the repository.)

## What `check` does

| Part | Checks |
|---|---|
| Static | `helm lint --strict` for every chart with every environment's values; every rendering through kubeconform (strict, Kubernetes 1.34) and, after `check.sh`, checkov; helm-unittest (32 tests); `ct lint`; and three inputs that must be rejected |
| Cluster | The namespace baseline from [devops/kubernetes](../../kubernetes/platform/namespace/) (Pod Security restricted, default-deny, quota); install with `--wait`; `helm test` through the NetworkPolicy; an upgrade whose config change rolls the pods; an upgrade to a missing image that rolls itself back; `helm rollback`; `helm diff`; the worker |
| OCI | [publish-charts.sh](../examples/publish-charts.sh) publishes all three charts, a second run publishes nothing, and web-app installs from the registry by digest |

## Notes

- `kind` runs as root in the tools container, because it drives Docker through the mounted socket. Everything else runs as UID 10001.
- The cluster's kubeconfig is written to `.kubeconfig` here (git-ignored), with the address the tools container reaches on the `kind` Docker network.
- `--kubelet-insecure-tls` for metrics-server and `--plain-http` for the registry exist only because this is a local lab. Real clusters and registries use TLS.
