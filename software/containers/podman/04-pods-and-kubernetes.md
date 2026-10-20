# Pods and Kubernetes YAML

[← Podman](README.md)

A **pod** is a group of containers that share a network namespace, so they reach each other on `localhost`, and are started, stopped, and removed together. It's the same idea as a Kubernetes pod, and Podman can run Kubernetes YAML directly, which makes it a quick way to try a manifest without a cluster.

## How a pod works

Every pod has an **infra container**: a tiny container whose only job is to hold the pod's namespaces open (Kubernetes calls it the pause container). The other containers join its network namespace (and, by default, its IPC and UTS namespaces). Ports are published on the pod, not on individual containers.

```sh
podman pod create --name app -p 8080:80
podman run -d --pod app --name web docker.io/library/nginx:1.27
podman run -d --pod app --name sidecar docker.io/library/alpine:3.22 \
  sh -c 'while true; do wget -qO- http://localhost:80/ >/dev/null && echo ok; sleep 5; done'
podman pod ps                        # one pod, three containers (with the infra container)
podman ps --pod                      # the containers, with their pod
podman logs sidecar                  # "ok": the sidecar reaches nginx on localhost
curl -s localhost:8080 | head -4     # nginx, through the pod's published port
podman pod rm -f app                 # stop and remove the pod and everything in it
```

The sidecar reaches nginx at `localhost:80` because they share one network namespace: there's one `lo` and one `eth0` for the whole pod. Two containers in a pod can't both listen on the same port.

Use a pod for containers that belong together and always run together: an application and a log shipper, a proxy, or a metrics exporter. Use a network (`podman network create`) for separate services that only need to talk to each other.

## From a pod to Kubernetes YAML

`podman kube generate` writes a Kubernetes manifest from what's running:

```sh
podman pod create --name app -p 8080:80
podman run -d --pod app --name web docker.io/library/nginx:1.27
podman kube generate app > app.yaml
podman pod rm -f app
```

The output is a Pod manifest with the image, the port, and the security settings, a starting point to adapt (add resources, probes, and labels) for a real cluster. Add `--service` to also write a Service.

## From Kubernetes YAML to running containers

`podman kube play` runs Pods, Deployments, and ConfigMaps (and creates volumes for PersistentVolumeClaims) from Kubernetes YAML:

```yaml
# web.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
spec:
  containers:
    - name: nginx
      image: docker.io/library/nginx:1.27
      ports:
        - containerPort: 80
          hostPort: 8080
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: [ALL]
          add: [CHOWN, SETUID, SETGID, NET_BIND_SERVICE]
```

```sh
podman kube play web.yaml       # creates the pod and its containers
podman pod ps
curl -s localhost:8080 | head -4
podman kube down web.yaml       # removes everything kube play created
```

(The stock nginx image starts as root and switches to the `nginx` user, which is why it needs `CHOWN`, `SETUID`, and `SETGID`; an image that starts as a non-root user needs none of them.)

It isn't a Kubernetes cluster: there's no scheduler, no controllers, and no Services between hosts. A Deployment runs its pod once, without keeping replicas. But it's enough to check that a manifest's images, ports, environment, and security settings work, and with Quadlet's `.kube` units, to run the same YAML as a systemd service on a single host ([systemd and Quadlet](05-systemd-and-quadlet.md)).

## Next

[systemd and Quadlet](05-systemd-and-quadlet.md).
