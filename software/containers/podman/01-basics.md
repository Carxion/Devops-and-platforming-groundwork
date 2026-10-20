# Podman basics

[← Podman](README.md)

Podman's commands mirror Docker's, so most of what you know carries over. This guide covers the everyday commands and the differences that matter.

## How Podman differs from Docker

| | Docker | Podman |
|---|---|---|
| Architecture | A long-running root daemon (`dockerd`); the CLI talks to it | **No daemon.** Each container is a child of `conmon`, a small monitor started by the command ([Architecture](02-architecture.md)) |
| Default privilege | The daemon runs as root | **Rootless by default**: containers run under your own user, mapped through user namespaces |
| Starting at boot | `--restart` policies, handled by the daemon | **systemd**, through Quadlet unit files ([systemd and Quadlet](05-systemd-and-quadlet.md)) |
| Pods | No | Yes: groups of containers sharing a network namespace, like Kubernetes pods ([Pods](04-pods-and-kubernetes.md)) |
| Kubernetes YAML | No | `podman kube play` runs Kubernetes manifests; `podman kube generate` writes them |
| Compose | `docker compose` | `podman compose`, which runs a Compose provider (`docker-compose` or `podman-compose`) against Podman |
| Short image names | Docker Hub is assumed | Resolved through `/etc/containers/registries.conf`. **Use full names** (`docker.io/library/nginx:1.27`) |
| Image and container storage | One store, owned by root | One store per user: `~/.local/share/containers/` for rootless, `/var/lib/containers/` for root |

The last row surprises people: images pulled with `sudo podman` aren't visible to `podman` as your user, and the reverse. They're separate stores.

## First commands

```sh
podman run --rm docker.io/library/alpine:3.22 cat /etc/os-release   # run once, remove on exit
podman run -d --name web -p 8080:80 docker.io/library/nginx:1.27   # in the background, as your own user, no sudo
podman ps                                                          # running containers (-a includes stopped)
podman logs -f web                                                 # follow its output
podman exec -it web sh                                             # a shell inside it
podman inspect --format '{{.State.Status}}' web                    # one field from its configuration
podman stop web && podman rm web
```

These are the same as `docker` with `podman` in front, and the options mean the same: `-d`, `--name`, `-p`, `-v`, `-e`, `--rm`, `-it`, `--user`, `--read-only`, `--cap-drop`, `--memory`. The [command reference](03-command-reference.md) lists the rest, and where Podman adds something Docker doesn't have.

## Images and short names

```sh
podman pull docker.io/library/nginx:1.27      # full name: registry, namespace, repository, tag
podman images                                 # local images, for this user
podman image tree docker.io/library/nginx:1.27   # the image's layers
podman rmi docker.io/library/nginx:1.27
```

Given a short name such as `nginx`, Podman looks it up in `/etc/containers/registries.conf`: first in short-name aliases, then by asking which of the `unqualified-search-registries` to use (in a terminal), or failing (in a script, with the default `short-name-mode = "enforcing"`). That's deliberate: a short name that resolves to whichever registry answers first is a way to be tricked into running someone else's image. Use full names in scripts, Dockerfiles, Compose files, and Quadlet units.

## Rootless ports and storage

Rootless containers run as your user, so they inherit your user's limits:

- **Ports below 1024** can't be published by default. Publish on 8080 and put a load balancer or a firewall redirect in front, or lower `net.ipv4.ip_unprivileged_port_start` for the host.
- **Storage** lives in `~/.local/share/containers/storage/`. On a server, make sure that home directory is on a filesystem with enough space.
- **Containers stop when you log out,** unless lingering is enabled for the user: `sudo loginctl enable-linger <user>` (needed for rootless systemd services that run at boot).

## Docker compatibility

```sh
sudo dnf install podman-docker                        # a `docker` command that runs Podman
systemctl --user enable --now podman.socket           # a Docker-compatible API socket, for tools that need one
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock
docker-compose up -d                                  # Compose, the Docker SDKs, and other tools now use Podman
```

Podman's API service is started on demand by systemd socket activation and exits when idle, so there's still no long-running daemon.

## Next

[Architecture](02-architecture.md).
