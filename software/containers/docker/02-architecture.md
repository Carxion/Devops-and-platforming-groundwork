# Docker architecture

[← Docker](README.md)

Docker is several programs, each with one job. Knowing which one does what explains where configuration lives, why the socket is so powerful, why containers survive a daemon restart, and what to look at when something breaks. The kernel features underneath all of them are in [How containers work](../01-how-containers-work.md).

## The components

```text
  you ──► docker CLI ──(REST API over /var/run/docker.sock)──► dockerd
                                                                 │  images, networks, volumes, builds (BuildKit)
                                                                 ▼
                                                             containerd ──► containerd-shim-runc-v2 ──► runc ──► container process
                                                                 │               (one per container)      (exits after start)
                                                                 └─ image content and snapshots
```

| Component | What it is | Does |
|---|---|---|
| **`docker` CLI** | The command-line client | Turns commands into API calls. It holds no state: `docker ps` asks the daemon |
| **Docker API** | A REST API on a Unix socket (`/var/run/docker.sock`), or a named pipe on Windows | Everything the CLI, Compose, SDKs, and tools such as Portainer do goes through it |
| **`dockerd`** | The Docker daemon (Docker Engine), running as root by default | Manages images, containers, networks, volumes, builds, and the API; hands container execution to containerd |
| **BuildKit** | The build engine, inside dockerd and in `buildx` builders | Runs Dockerfile builds: parallel stages, cache mounts, secrets, multi-architecture output |
| **containerd** | A CNCF container runtime daemon, also used directly by Kubernetes | Stores image content, prepares filesystem snapshots, and supervises containers |
| **containerd-shim-runc-v2** | One small process per running container | Keeps the container's standard input and output and exit status, so dockerd and containerd can restart without stopping containers |
| **runc** | The OCI reference runtime | Creates the namespaces and cgroups, applies security settings, starts the process, then exits |
| **docker-proxy** | A small helper per published port (when the userland proxy is on) | Forwards traffic to published ports in a few cases iptables rules don't cover, such as connections from the host to itself |

See them on a Linux host with a running container:

```sh
docker version                       # client and server versions, and containerd and runc versions
docker info                          # storage driver, cgroup version, runtimes, security options, rootless or not
ps -ef | grep -E 'dockerd|containerd|shim'
```

`docker info` is the first command to run on an unfamiliar host: it shows the storage driver, the cgroup driver and version, whether the daemon is rootless, which security options (seccomp, AppArmor, SELinux, user namespaces) are on, and where data lives.

## The socket is root

The Docker API has no per-command permissions: anything that can write to `/var/run/docker.sock` can do everything, including starting a privileged container with the host's root filesystem mounted. So:

- Membership of the `docker` group is equivalent to root on the host.
- Mounting the socket into a container (for CI agents, monitoring, or "Docker in Docker") gives that container root on the host.
- Exposing the API over TCP without TLS client certificates gives root to anyone who can reach the port.

[Hardening](08-hardening.md#protect-the-daemon-and-its-socket) covers the safer alternatives: rootless mode, TLS, SSH access with `DOCKER_HOST=ssh://`, and socket proxies.

## Contexts: which daemon the CLI talks to

The CLI can talk to more than one daemon. A **context** names a connection:

```sh
docker context ls                                        # contexts; * marks the active one
docker context create build-host --docker "host=ssh://deploy@203.0.113.10"
docker --context build-host ps                           # one command against another host, over SSH
docker context use build-host                            # switch for all commands
DOCKER_HOST=ssh://deploy@203.0.113.10 docker ps          # or set it per command
```

Docker Desktop runs dockerd inside a small Linux VM, and its context points the CLI there.

## Where things live

| What | Default location | Configured in |
|---|---|---|
| Daemon configuration | `/etc/docker/daemon.json` | That file; restart dockerd after changes |
| Images, containers, volumes, build cache | `/var/lib/docker/` (`docker info --format '{{.DockerRootDir}}'`) | `"data-root"` in daemon.json |
| containerd's data | `/var/lib/containerd/` | containerd's own config |
| The API socket | `/var/run/docker.sock` | `"hosts"` in daemon.json |
| Client configuration and registry logins | `~/.docker/config.json` | `docker login`, credential helpers |
| Container logs (json-file driver) | `/var/lib/docker/containers/<id>/<id>-json.log` | `"log-driver"` and `"log-opts"` |
| Daemon logs | The journal: `journalctl -u docker` | systemd |

A typical `daemon.json` for a server:

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "default-ulimits": { "nofile": { "Name": "nofile", "Soft": 65536, "Hard": 65536 } }
}
```

| Setting | Why |
|---|---|
| `log-opts` `max-size` and `max-file` | The default json-file log driver has no size limit; without these, logs fill the disk |
| `live-restore` | Containers keep running while dockerd restarts or upgrades |
| `userland-proxy: false` | Use iptables rules only for published ports, without a docker-proxy process per port |
| `no-new-privileges` | Default `--security-opt no-new-privileges` for every container |
| `default-ulimits` | Raise the open-files limit for every container |

Check the file before restarting the daemon, because a syntax error stops dockerd from starting: `sudo dockerd --validate --config-file /etc/docker/daemon.json`.

## Storage drivers

The storage driver puts image layers and the container's writable layer together. On current Docker Engine, new installations use the **containerd image store** with the `overlayfs` snapshotter; older installations use the `overlay2` storage driver. Both use the kernel's overlay filesystem ([Images, layers, and the root filesystem](../01-how-containers-work.md#images-layers-and-the-root-filesystem)). Check which one a host uses with `docker info --format '{{.Driver}}'`.

Write-heavy data (databases, caches, uploads) should go in volumes, which bypass the storage driver entirely and run at native disk speed ([Networking and storage](05-networking-and-storage.md)).

## Networking drivers

| Driver | What it does | Use for |
|---|---|---|
| `bridge` (default) | A private network on the host (`docker0`, or one per user-defined network), with NAT out and iptables rules for published ports | Single-host applications. Use a user-defined network so containers resolve each other by name |
| `host` | No network namespace: the container uses the host's network directly | Rare performance-sensitive cases; removes network isolation |
| `none` | Only a loopback interface | Batch jobs that need no network |
| `overlay` | A network spanning several hosts (Swarm) | Multi-host Swarm services |
| `macvlan`, `ipvlan` | Containers get addresses directly on the physical network | Legacy applications that must appear as hosts on the LAN |

Docker manages iptables (or nftables) rules for published ports itself, and those rules are evaluated before host firewalls such as ufw see the traffic. [Networking and storage](05-networking-and-storage.md#published-ports-and-the-host-firewall) explains the consequence and the fix.

## What happens on `docker run`

```sh
docker run -d --name web -p 8080:80 docker.io/library/nginx:1.27
```

1. The CLI sends `POST /containers/create` to dockerd over the socket.
2. dockerd checks for the image; if it's missing, it pulls it: it asks the registry for the manifest (picking the one for the host's CPU), then downloads any layers it doesn't already have.
3. dockerd prepares the container's root filesystem (image layers plus a new writable layer) and its configuration: networking, mounts, environment, security settings.
4. The CLI sends `POST /containers/{id}/start`. dockerd asks containerd to start the container.
5. containerd starts a shim, which runs runc with an OCI bundle (a root filesystem plus `config.json`).
6. runc creates the namespaces and cgroup, applies capabilities, seccomp, and AppArmor or SELinux, switches into the root filesystem, and runs the image's entrypoint as the container's PID 1. Then runc exits; the shim stays as the container's parent.
7. dockerd connects the container to its network and adds the iptables rules for port 8080.

`docker events` in another terminal shows these steps happening ([Complex commands](07-complex-commands.md)).

## Docker Desktop, Docker Engine, and the rest

| Name | What it is |
|---|---|
| **Docker Engine** | dockerd, containerd, runc, and the CLI on Linux. Open source (the Moby project) |
| **Docker Desktop** | A desktop application for macOS, Windows, and Linux: Docker Engine in a VM, plus a GUI, Kubernetes, and extensions. Commercial use in larger organizations needs a paid subscription; check Docker's current terms |
| **Docker Compose** | Runs multi-container applications from a YAML file; a CLI plugin (`docker compose`) |
| **Buildx** | The CLI plugin for BuildKit: multi-architecture builds, remote builders, build cache export |
| **Docker Hub** | Docker's public registry; anonymous and free-tier pulls are rate-limited |

## Next

[Dockerfiles](03-dockerfiles.md).
