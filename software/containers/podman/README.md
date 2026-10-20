# Podman

[← Containers](../README.md)

Podman runs the same OCI images as Docker, with nearly the same commands, but works differently underneath: there's no daemon, containers run rootless by default, and systemd starts them at boot. It's the container engine Red Hat supports on RHEL, where Docker isn't shipped, and it's available on Ubuntu, Fedora, macOS, and Windows too. Its companions are **Buildah** (build images) and **Skopeo** (copy and inspect images in registries).

> **Status.** Written from Podman's documentation and not yet run end to end in this repository. Test commands in a container (below) or a VM before relying on them, especially Quadlet and systemd services, which need a host running systemd.

## Learning path

| # | Guide | You'll be able to |
|---|---|---|
| 1 | [Basics](01-basics.md) | Run, inspect, and manage containers with Podman, and translate Docker habits |
| 2 | [Architecture](02-architecture.md) | Explain how Podman works without a daemon: conmon, crun, rootless user namespaces, networking, storage, and its configuration files |
| 3 | [Command reference](03-command-reference.md) | Find the command for any task, grouped like the Docker reference |
| 4 | [Pods and Kubernetes YAML](04-pods-and-kubernetes.md) | Group containers into pods, and run or generate Kubernetes manifests locally |
| 5 | [systemd and Quadlet](05-systemd-and-quadlet.md) | Run containers as systemd services that start at boot and update themselves |
| 6 | [Hardening](06-hardening.md) | Use rootless containers, SELinux labels, user namespace options, capabilities, and signature verification |
| 7 | [Buildah, Skopeo, and UBI](07-buildah-skopeo-and-ubi.md) | Build images without a daemon, mirror images between registries, and use Red Hat's redistributable base images |

New to containers? Read [How containers work](../01-how-containers-work.md) first; coming from Docker, start at [Basics](01-basics.md).

## Install

```sh
sudo dnf install -y podman podman-docker buildah skopeo     # RHEL, Rocky, AlmaLinux, Fedora
sudo apt-get install -y podman buildah skopeo               # Ubuntu
podman version
podman info                                                 # rootless or not, storage driver, network backend, cgroup version
```

`podman-docker` adds a `docker` command that runs Podman, so scripts and habits keep working. On macOS and Windows, install Podman Desktop or the `podman` CLI, then `podman machine init && podman machine start` creates the Linux VM the containers run in.

If a vendor requires Docker Engine on RHEL, [install-docker.sh](../../../devops/bash/scripts/install-docker.sh) installs it from Docker's repository; otherwise, prefer Podman on RHEL: `sudo bash devops/bash/scripts/install-docker.sh --podman`.

## Try it without installing

Podman runs inside a container, which is how the commands in these guides were checked:

```sh
docker run --rm -it --privileged quay.io/podman/stable podman run --rm docker.io/library/alpine:3.22 echo hello
```
