# Podman architecture

[← Podman](README.md)

Podman does the same job as Docker with a different shape: there's no central daemon, every container's parent is a small monitor process, and unprivileged users get their own containers through user namespaces. The kernel features underneath are the same as Docker's ([How containers work](../01-how-containers-work.md)).

## The components

```text
  podman run ──► (fork and exec) ──► conmon ──► crun (or runc) ──► container process
     │                                 │          (exits after start)
     │                                 └─ holds stdio, writes logs, records the exit code
     ├─ containers/image:   pulls and verifies images
     ├─ containers/storage: layers and container filesystems (overlay)
     └─ netavark + aardvark-dns: networks and container DNS (pasta for rootless)
```

| Component | Does |
|---|---|
| **`podman`** | The CLI, and a library: it does the work itself (pull, prepare storage, set up the network, create the container), then exits. There's no daemon to ask |
| **conmon** | One small monitor per container. It starts the OCI runtime, keeps the container's standard input and output, writes the logs, and records the exit code, so `podman` can exit while the container runs |
| **crun** | The OCI runtime Podman uses by default on RHEL and Fedora: written in C, smaller and faster to start than runc. runc also works |
| **containers/image** | The library that talks to registries, applies `registries.conf`, and checks signatures (`policy.json`) |
| **containers/storage** | Stores image layers and container filesystems, usually with the overlay driver |
| **netavark** | Creates networks, interfaces, and firewall rules for containers |
| **aardvark-dns** | DNS for container networks, so containers on a user-defined network reach each other by name |
| **pasta** (or slirp4netns) | Networking for rootless containers, which can't create host network interfaces: a user-mode network stack that connects the container's namespace to the host |

Check what a host uses:

```sh
podman info --format '{{.Host.OCIRuntime.Name}} {{.Host.NetworkBackend}} {{.Store.GraphDriverName}} cgroups-{{.Host.CgroupsVersion}} rootless={{.Host.Security.Rootless}}'
```

## No daemon

Because each `podman` command does its own work and exits:

- **Nothing runs as root in the background,** so there's no root-owned socket to protect, and no single process whose crash or upgrade affects every container.
- **Containers are ordinary processes of the user who started them,** visible in `ps` under that user, and in the user's systemd session.
- **State is on disk,** in a database under the storage directory, which every `podman` command reads. Two users' containers never mix.
- **Restarting at boot is systemd's job,** not a daemon's ([systemd and Quadlet](05-systemd-and-quadlet.md)).

When a tool needs an API (Compose, the Docker SDKs, Podman Desktop), `podman system service` provides a Docker-compatible REST API, usually started on demand by a systemd socket unit ([Docker compatibility](01-basics.md#docker-compatibility)).

## Rootless containers and user namespaces

A rootless container runs inside a **user namespace**: inside it, the process is root (UID 0); outside, it's your user. Other container UIDs map to a range of host UIDs your user owns, listed in `/etc/subuid` and `/etc/subgid`:

```sh
grep "$USER" /etc/subuid                  # e.g. deploy:100000:65536 — your 65,536 extra UIDs start at 100000
podman unshare cat /proc/self/uid_map     # the mapping Podman uses
#          0       1000          1        container root (0) is you (UID 1000)
#          1     100000      65536        container UIDs 1 and up are 100000 and up
```

So a process that's root in the container, and escapes it, is your user on the host, with no more power than you have. A container process running as UID 1001 is host UID 101000, which owns nothing outside the container.

Two consequences:

- **File ownership in mounted directories looks odd** on the host: files a container's UID 1001 creates are owned by 101000. `podman unshare chown 1001:1001 dir` changes ownership from inside your user namespace, and `--userns keep-id` maps your own UID into the container unchanged ([Hardening](06-hardening.md#user-namespace-options)).
- **Some things need real privilege,** and rootless can't do them: binding ports below 1024 (by default), some network modes, and anything that needs a capability your user doesn't have on the host.

`useradd` adds `/etc/subuid` and `/etc/subgid` entries for new users automatically on current RHEL and Ubuntu; for older accounts, add them with `sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 <user>`.

## Networking

| Mode | Rootful | Rootless |
|---|---|---|
| Default | A bridge network (`podman`), with NAT and firewall rules from netavark | **pasta**: the container gets a copy of the host's addresses and routes; published ports are forwarded by pasta |
| User-defined networks | `podman network create appnet`: a bridge with DNS by name (aardvark-dns) | The same, inside your user's network namespace |
| `--network host` | The host's network | The host's network as your user sees it |
| `--network none` | Loopback only | Loopback only |

Containers in the same **pod** share one network namespace, and reach each other on `localhost` ([Pods](04-pods-and-kubernetes.md)).

## Configuration files

| File | Configures | System-wide | Per user |
|---|---|---|---|
| `containers.conf` | Defaults for every container: runtime, capabilities, logging, network backend | `/etc/containers/containers.conf` | `~/.config/containers/containers.conf` |
| `registries.conf` | Search registries, short-name aliases, mirrors, blocked registries | `/etc/containers/registries.conf` | `~/.config/containers/registries.conf` |
| `policy.json` | Which images are trusted: require signatures, reject registries | `/etc/containers/policy.json` | `~/.config/containers/policy.json` |
| `storage.conf` | Storage driver and locations | `/etc/containers/storage.conf` | `~/.config/containers/storage.conf` |
| Quadlet units | Containers as systemd services | `/etc/containers/systemd/` | `~/.config/containers/systemd/` |

Defaults ship in `/usr/share/containers/`; files in `/etc/containers/` override them, and per-user files override those. `podman info` shows the files in effect.

## What happens on `podman run`

```sh
podman run -d --name web -p 8080:80 docker.io/library/nginx:1.27
```

1. `podman` resolves the image name through `registries.conf`, and pulls it if missing: it fetches the manifest for the host's CPU, checks it against `policy.json`, and stores new layers in containers/storage.
2. It creates the container's filesystem (image layers plus a writable layer) and records the container in its database.
3. It sets up networking: for rootless, pasta; for rootful, netavark creates a veth pair on the bridge and the firewall rules for port 8080.
4. It starts `conmon`, which runs `crun` with an OCI bundle. crun creates the namespaces (including the user namespace, if rootless) and cgroup, applies capabilities, seccomp, and SELinux labels, and starts nginx as PID 1. Then crun exits.
5. `podman` exits. conmon stays, as the container's parent, until the container stops.

## Next

[Command reference](03-command-reference.md).
