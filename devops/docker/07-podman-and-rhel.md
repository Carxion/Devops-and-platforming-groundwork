# Podman and RHEL

[← Docker 101](README.md)

RHEL doesn't ship Docker. Its supported container tools are **Podman** (run containers), **Buildah** (build images), and **Skopeo** (copy and inspect images in registries). Podman runs the same OCI images, accepts nearly the same commands, and is supported by Red Hat on RHEL. It's also available on Ubuntu (`apt install podman`), Fedora, and macOS and Windows (Podman Desktop).

If a vendor requires Docker Engine on RHEL, [install-docker.sh](../bash/scripts/install-docker.sh) installs it from Docker's repository; otherwise, prefer Podman on RHEL: `sudo bash devops/bash/scripts/install-docker.sh --podman`, or `sudo dnf install podman podman-docker buildah skopeo`.

## How Podman differs

| | Docker | Podman |
|---|---|---|
| Architecture | A long-running root daemon (`dockerd`); the CLI talks to it | **No daemon.** Each container is a child process of the command that started it (and of `conmon`, a small monitor) |
| Default privilege | The daemon runs as root | **Rootless by default**: containers run under your own user, mapped through user namespaces |
| Starting at boot | `--restart` policies, handled by the daemon | **systemd**, through Quadlet unit files (below) |
| Pods | No | Yes: groups of containers sharing a network namespace, like Kubernetes pods |
| Kubernetes YAML | No | `podman kube play pod.yaml` runs Kubernetes manifests; `podman kube generate` writes them |
| Compose | `docker compose` | `podman compose` (runs `docker-compose` or `podman-compose` against Podman's Docker-compatible socket) |
| Short image names | Docker Hub is assumed | Asks which registry, per `/etc/containers/registries.conf`. **Use full names** (`docker.io/library/nginx:1.27`) to avoid ambiguity. |

Most commands translate one for one: `podman run`, `podman ps`, `podman build`, `podman exec`, `podman logs`, `podman images`. With the `podman-docker` package, a `docker` command runs Podman, so scripts and habits keep working.

```sh
podman run --rm -d --name web -p 8080:80 docker.io/library/nginx:1.27   # as your own user, no sudo
podman ps
podman logs -f web
podman unshare cat /proc/self/uid_map    # how your UID maps to container UIDs
```

Rootless containers can't bind ports below 1024 by default (publish on 8080 and put a load balancer or firewall redirect in front, or lower `net.ipv4.ip_unprivileged_port_start`), and their storage lives in `~/.local/share/containers/`.

## SELinux and volumes

On RHEL, containers run confined by SELinux (type `container_t`), and they can only read files labeled for containers. Mounting a host directory without relabeling it gives "permission denied", with perfectly good Unix permissions:

```sh
podman run --rm -v /srv/app/conf:/etc/app:ro registry.example.com/app:1.0      # permission denied
podman run --rm -v /srv/app/conf:/etc/app:ro,Z registry.example.com/app:1.0    # works
```

| Option | Does |
|---|---|
| `:Z` | Relabel the content as **private** to this container (a unique MCS label). Other containers can't read it. |
| `:z` | Relabel as **shared** between containers |

Never use `:Z` on system directories such as `/home` or `/etc`: it relabels them for one container and breaks the host's own services. Mount a dedicated directory instead. The same `:Z` and `:z` work with Docker on SELinux hosts. When something is still denied, `ausearch -m AVC -ts recent` shows it ([SELinux and AppArmor](../bash/05-rhel-and-ubuntu.md#selinux-and-apparmor)).

## Running containers as services: Quadlet

Instead of a daemon with restart policies, Podman uses systemd. A **Quadlet** file describes a container in a systemd-style unit, and systemd generates and runs the service from it (Podman 4.4 and later; RHEL 9.2 and later).

`/etc/containers/systemd/items-api.container` (or `~/.config/containers/systemd/` for a rootless user):

```ini
[Unit]
Description=Items API
After=network-online.target

[Container]
# A tag, not a digest: AutoUpdate (below) follows the tag. Pin by digest instead if you don't use it.
Image=registry.example.com/team/items-api:1.0
ContainerName=items-api
PublishPort=127.0.0.1:8080:8080
User=10001
ReadOnly=true
DropCapability=ALL
NoNewPrivileges=true
Environment=LOG_LEVEL=info
Volume=items-data:/data:Z
# Healthy when the port accepts connections (an HTTP check would need a URL that returns 2xx).
HealthCmd=python -c "import socket; socket.create_connection(('127.0.0.1', 8080), 2)"
# Pull a newer image for this tag automatically (with podman-auto-update.timer)
AutoUpdate=registry

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target default.target
```

```sh
sudo systemctl daemon-reload                 # generates items-api.service from the .container file
sudo systemctl start items-api
systemctl status items-api
journalctl -u items-api -f                   # container logs, in the journal
sudo systemctl enable --now podman-auto-update.timer   # optional: daily image updates with rollback on failure
```

Quadlet also has `.volume`, `.network`, `.pod`, `.kube` (run Kubernetes YAML), and `.build` files. On a single RHEL host, this is the supported, systemd-native replacement for `docker run --restart` and simple Compose deployments.

## Buildah and Skopeo

```sh
buildah bud -t app:1.0 .                         # build from a Dockerfile (podman build does the same)
skopeo inspect docker://docker.io/library/nginx:1.27            # inspect a remote image without pulling it
skopeo copy docker://docker.io/library/nginx:1.27 docker://registry.example.com/mirror/nginx:1.27   # registry to registry, for mirroring
skopeo list-tags docker://registry.access.redhat.com/ubi9/ubi
```

Skopeo is the tool for mirroring images into a registry that a restricted network can reach, without needing a daemon or pulling layers to local disk.

## Red Hat images

**UBI** (Universal Base Image) is freely redistributable, so you can build and publish images on it without a subscription. Variants: `ubi9/ubi` (full dnf), `ubi9/ubi-minimal` (microdnf), `ubi9/ubi-micro` (no package manager), and language images such as `ubi9/python-312` and `ubi9/nodejs-20`. Images built on UBI are supported by Red Hat when run on RHEL or OpenShift.
