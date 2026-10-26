# How containers work

[← Containers](README.md)

A container isn't a small virtual machine. It's an ordinary Linux process that the kernel shows a different view of the system, limits in what it can use, and restricts in what it can do. Docker, Podman, containerd, and Kubernetes all build on the same few kernel features and open standards. Knowing them explains most container behavior: why a container sees only its own processes, why it's killed when it uses too much memory, why "root in a container" isn't always root, and what a container escape actually means.

## A container is a process

Start a container and look for it from the host:

```sh
docker run -d --name demo docker.io/library/alpine:3.22 sleep 600
docker top demo                                  # the container's processes, as the host sees them
docker inspect --format '{{.State.Pid}}' demo    # its process ID on the host
docker exec demo ps                              # the same process, as the container sees it: PID 1
```

On a Linux host, `ps -ef | grep 'sleep 600'` shows the same `sleep` process in the host's own process list. There's no guest operating system and no separate kernel: the container's processes run on the host's kernel, like any other program. What makes them a container is four things the kernel applies to them.

| Feature | What it does | Gives the container |
|---|---|---|
| **Namespaces** | Change what a process can *see* | Its own process tree, network, hostname, mounts, and users |
| **Control groups (cgroups)** | Limit what a process can *use* | CPU, memory, and process-count limits, and accounting |
| **A root filesystem** | Change the process's `/` | The image's files instead of the host's |
| **Security controls** | Restrict what a process can *do* | Dropped capabilities, blocked system calls (seccomp), and SELinux or AppArmor confinement |

## Namespaces: what a process can see

A namespace wraps a global resource so processes inside it get their own isolated instance.

| Namespace | Isolates | In a container |
|---|---|---|
| `pid` | Process IDs | The app is PID 1 and sees only its own processes |
| `net` | Network interfaces, IP addresses, routes, ports, firewall rules | Its own `eth0` and IP; port 80 inside doesn't clash with the host |
| `mnt` | Mount points | Its own filesystem tree, built from the image |
| `uts` | Hostname and domain name | Its own hostname (by default, the container ID) |
| `ipc` | Shared memory and message queues | No access to other processes' shared memory |
| `user` | User and group IDs | Root inside can map to an unprivileged user outside (rootless containers, user namespace remapping) |
| `cgroup` | The view of the cgroup tree | Sees its own cgroup as the root |
| `time` | The boot and monotonic clocks | Rarely used by container engines |

Every process's namespaces are listed in `/proc/<pid>/ns`. Two processes share a namespace when the links point to the same inode:

```sh
docker exec demo ls -l /proc/1/ns     # the container's namespaces
ls -l /proc/self/ns                   # yours, on a Linux host: different inodes, except where shared
lsns                                  # every namespace on a Linux host, and the process that created it
```

You can build the core of a container yourself with `unshare`, which starts a program in new namespaces:

```sh
sudo unshare --pid --fork --mount-proc --uts --net sh   # a shell in new pid, mount, uts, and net namespaces
ps                                                       # only this shell and ps: PID 1 is sh
hostname container-by-hand && hostname                   # changes the hostname only inside
ip link                                                  # only a loopback interface, and it's down
exit
```

Container engines do the same thing, plus cgroups, a root filesystem, security controls, and networking set up for you.

Sharing namespaces is how some features work: `--network container:other` puts a container in another's network namespace, which is exactly what a Kubernetes or Podman **pod** is (containers sharing one network namespace, so they reach each other on `localhost`). And `--pid host` or `--network host` simply skips creating that namespace, which is why those flags remove isolation.

## Control groups: what a process can use

A cgroup is a group of processes the kernel accounts for and limits together. Modern distributions use **cgroup v2**, a single tree mounted at `/sys/fs/cgroup`. Container limits become values in the container's cgroup:

```sh
docker run --rm --memory 256m --cpus 0.5 --pids-limit 100 docker.io/library/alpine:3.22 \
  sh -c 'cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/cpu.max /sys/fs/cgroup/pids.max'
# 268435456          256 MiB
# 50000 100000       50,000 µs of CPU per 100,000 µs period: half a CPU
# 100                at most 100 processes or threads
```

| Limit | cgroup v2 file | When it's exceeded |
|---|---|---|
| `--memory` | `memory.max` | The kernel's out-of-memory killer kills a process in the container (exit code 137, `OOMKilled: true` in `docker inspect`) |
| `--cpus` | `cpu.max` | The container is throttled: it waits, it isn't killed |
| `--pids-limit` | `pids.max` | `fork()` fails, so a fork bomb can't take down the host |

The same files hold usage: `memory.current`, `cpu.stat`, and `pids.current` are what `docker stats` and Kubernetes' metrics read. Kubernetes requests and limits become these same values.

## Images, layers, and the root filesystem

An image is a stack of **layers** (each a tarball of filesystem changes) plus a **config** (the default command, environment, user, and working directory). Each Dockerfile instruction that changes files adds a layer. Layers are identified by the SHA-256 hash of their content, so identical layers are stored once and shared by every image that uses them.

When a container starts, the engine stacks the image's read-only layers and adds one thin writable layer on top, using the kernel's **overlay filesystem** (overlayfs):

```text
  merged view (the container's /)
  ┌──────────────────────────────┐
  │ upperdir: writable layer     │  per container; deleted with the container
  ├──────────────────────────────┤
  │ lowerdir: image layer 3      │  read-only, shared by every container
  │ lowerdir: image layer 2      │  from this image
  │ lowerdir: image layer 1      │
  └──────────────────────────────┘
```

Reading a file finds the topmost layer that has it. Writing a file from a lower layer first **copies it up** to the writable layer (copy-on-write); deleting one writes a "whiteout" marker that hides it. Consequences:

- **Starting a container is fast,** because nothing is copied: the image layers are shared.
- **Writes to the container's filesystem are lost** when the container is removed. Data that matters goes in a volume, which is a plain directory mounted in, outside the overlay.
- **Deleting a file in a later Dockerfile layer doesn't shrink the image.** The file is still in the earlier layer; the whiteout only hides it. That's why secrets copied in and then deleted are still in the image, and why cleanup must happen in the same `RUN` as the install.

```sh
docker image history docker.io/library/alpine:3.22            # the layers and the instructions that made them
docker inspect --format '{{json .GraphDriver.Data}}' demo      # the container's overlay directories
docker diff demo                                               # files the container added (A), changed (C), or deleted (D)
```

## The standards: OCI

The [Open Container Initiative](https://opencontainers.org/) (OCI) publishes three specifications, which is why images and tools are interchangeable:

| Specification | Defines | Means |
|---|---|---|
| **Image spec** | The image format: layers, config, and the manifest that lists them | An image built by Docker runs on Podman, containerd, or CRI-O |
| **Runtime spec** | A "bundle": a root filesystem plus a `config.json` describing the process, namespaces, cgroups, mounts, and security settings | Any OCI runtime (runc, crun) can run any engine's containers |
| **Distribution spec** | The HTTP API for pushing and pulling images | Any registry (Docker Hub, GHCR, ECR, ACR, Harbor, Quay) works with any client |

An image is referenced by **tag** (`nginx:1.27`, which can be moved to a different image) or by **digest** (`nginx@sha256:...`, the hash of the manifest, which can never change). A multi-architecture image is an **index** that points to one manifest per platform; the client picks the one for its CPU.

## The runtime stack

Running a container is split between layers of software, each with one job:

```text
  docker CLI ──► dockerd ──► containerd ──► containerd-shim ──► runc ──► your process
  podman CLI ──────────────────────────────► conmon ──────────► crun ──► your process
  kubelet ─(CRI)─► containerd or CRI-O ────► shim or conmon ───► runc ──► your process
```

| Layer | Examples | Job |
|---|---|---|
| **Client** | `docker`, `podman`, `nerdctl`, `crictl` | Takes your commands |
| **Engine or high-level runtime** | dockerd, containerd, CRI-O, Podman (as a library, no daemon) | Pulls and stores images, sets up networking and storage, manages container lifecycle |
| **Shim or monitor** | containerd-shim, conmon | Stays with each container: holds its standard input and output, reports its exit code, lets the engine restart without killing containers |
| **Low-level (OCI) runtime** | runc, crun | Creates the namespaces and cgroups, applies security settings, starts the process from an OCI bundle, then exits |

Kubernetes talks to a high-level runtime through the **Container Runtime Interface** (CRI). Since Kubernetes 1.24 it no longer talks to Docker Engine directly; clusters use containerd or CRI-O. Images built with Docker run unchanged, because they're OCI images.

The engine-specific details are in [Docker architecture](docker/02-architecture.md) and [Podman architecture](podman/02-architecture.md).

## Security controls

Namespaces hide things; they don't stop a process that has power over the kernel. These controls limit what a container's processes can do:

| Control | What it does | Default in Docker and Podman |
|---|---|---|
| **Capabilities** | Split root's power into about 40 separate privileges (`CAP_NET_ADMIN`, `CAP_SYS_ADMIN`, ...) | A reduced set: `CAP_SYS_ADMIN`, `CAP_NET_ADMIN`, module loading, and other dangerous ones are dropped |
| **seccomp** | Filters system calls | A default profile blocks dozens of risky calls (loading kernel modules, `reboot`, changing the system clock) |
| **SELinux or AppArmor** | Mandatory access control: what files and resources a process may touch, whatever its user | SELinux `container_t` on RHEL-family hosts; the `docker-default` AppArmor profile on Ubuntu |
| **User namespaces** | Map container root to an unprivileged host UID | On for rootless Podman and rootless Docker; opt-in otherwise |
| **no-new-privileges** | Stops setuid binaries from gaining privileges | Opt-in |

`--privileged` turns most of this off. The hardening guides for [Docker](docker/08-hardening.md) and [Podman](podman/06-hardening.md) cover each control in practice.

## Containers and virtual machines

| | Container | Virtual machine |
|---|---|---|
| Kernel | Shares the host's kernel | Its own kernel, on a hypervisor |
| Isolation boundary | The kernel's namespaces, cgroups, and security controls | Hardware virtualization |
| Start time | Milliseconds to seconds | Seconds to minutes |
| Overhead | A process | A whole operating system |
| Runs | Linux containers on a Linux kernel | Any operating system |

Because containers share the kernel, a kernel vulnerability can let a process escape every container on the host. Where workloads don't trust each other (multi-tenant platforms, running customer code), add a stronger boundary: a VM per tenant, or a sandboxed runtime such as gVisor or Kata Containers, which Kubernetes selects through a RuntimeClass.

On macOS and Windows, Docker Desktop and Podman Desktop run a small Linux VM, and the containers run inside it. That's why file sharing between the host and containers is slower there, and why host paths look different.

## Clean up

```sh
docker rm -f demo
```

## Next

Pick an engine: [Docker](docker/README.md) or [Podman](podman/README.md).
