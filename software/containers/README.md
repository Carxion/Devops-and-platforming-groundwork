# Containers

[← Software](../README.md)

Containers package an application with everything it needs to run, so it behaves the same on a laptop, in CI, and in production. This folder starts with how containers actually work, the kernel features and open standards every engine shares, then covers the two engines you'll meet most: **Docker** and **Podman**, each with its architecture, a command reference, and a hardening guide.

| Start here | Covers |
|---|---|
| [How containers work](01-how-containers-work.md) | A container as a process: namespaces, control groups, image layers and overlayfs, the OCI standards, the runtime stack from CLI to runc, security controls, and containers compared with VMs |

## Docker

[docker/](docker/README.md): a daemon (dockerd) with a CLI, BuildKit for builds, and containerd and runc underneath. The most common engine on developer machines and CI.

| Guide | Covers |
|---|---|
| [Basics](docker/01-basics.md) | Images, containers, layers, and registries; the first commands |
| [Architecture](docker/02-architecture.md) | dockerd, containerd, the shim, runc, BuildKit, the socket, contexts, where things live, storage and network drivers |
| [Dockerfiles](docker/03-dockerfiles.md) | Small, fast, non-root images with multi-stage builds |
| [Compose](docker/04-compose.md) | Multi-container applications |
| [Networking and storage](docker/05-networking-and-storage.md) | Networks, published ports and the host firewall, volumes |
| [Command reference](docker/06-command-reference.md) | Every everyday command, by task |
| [Complex commands](docker/07-complex-commands.md) | Format templates, filters, and cleanup, broken down |
| [Hardening](docker/08-hardening.md) | Image, runtime, daemon, and host hardening; capabilities, seccomp, rootless mode, scanning, signing, the CIS benchmark |
| [Troubleshooting](docker/09-troubleshooting.md) | Exits, connectivity, permissions, disk, builds, the daemon |

## Podman

[podman/](podman/README.md): no daemon, rootless by default, systemd for services, and pods like Kubernetes. Red Hat's supported engine on RHEL.

| Guide | Covers |
|---|---|
| [Basics](podman/01-basics.md) | Everyday commands, short names, rootless ports and storage, Docker compatibility |
| [Architecture](podman/02-architecture.md) | conmon, crun, rootless user namespaces, netavark and pasta, configuration files |
| [Command reference](podman/03-command-reference.md) | What's the same as Docker, and what Podman adds |
| [Pods and Kubernetes YAML](podman/04-pods-and-kubernetes.md) | Pods, `kube play`, and `kube generate` |
| [systemd and Quadlet](podman/05-systemd-and-quadlet.md) | Containers as systemd services, rootless services, automatic updates, secrets |
| [Hardening](podman/06-hardening.md) | Rootless operation, SELinux labels, user namespace options, signature policy, registry configuration |
| [Buildah, Skopeo, and UBI](podman/07-buildah-skopeo-and-ubi.md) | Daemonless builds, registry-to-registry copies and mirroring, Red Hat's base images |

## Docker or Podman?

| | Docker | Podman |
|---|---|---|
| Choose it when | Your team, tools, or vendor expect Docker; you use Docker Desktop, Compose, or Swarm | You run RHEL; you want rootless by default and no root daemon; containers should be systemd services |
| Runs | Linux natively; macOS and Windows through Docker Desktop's VM | Linux natively; macOS and Windows through `podman machine` |
| Images | OCI: interchangeable with Podman | OCI: interchangeable with Docker |
| Commands | `docker ...` | The same, as `podman ...` (and `podman-docker` provides a `docker` command) |

Images built by either run on the other, on containerd, CRI-O, and every Kubernetes cluster, because they all follow the OCI standards. Many teams use Docker on laptops and in CI, and Podman on RHEL servers.

## Related

- [Kubernetes](../../devops/kubernetes/README.md): running containers across a cluster
- [Python](../python/boilerplate/items-api/Dockerfile) and [Go](../go/boilerplate/items-api/Dockerfile) service images, built with the practices in [Dockerfiles](docker/03-dockerfiles.md)
- The [glossary](../../GLOSSARY.md#containers-and-kubernetes) for container terms
