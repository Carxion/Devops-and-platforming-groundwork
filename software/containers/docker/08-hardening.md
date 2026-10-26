# Docker hardening

[← Docker](README.md)

Containers share the host's kernel, so container security is host security. The biggest risks are almost never exotic kernel exploits; they're configuration choices that hand over the host, and images full of old, vulnerable software. This guide goes from the mistakes that matter most to the finer controls, in four layers: the image, the container at run time, the daemon, and the host. [docker-audit.sh](scripts/docker-audit.sh) checks running containers for most of the runtime settings. The kernel mechanisms behind each control are in [How containers work](../01-how-containers-work.md#security-controls).

## Never do these

| Setting | Why it's dangerous |
|---|---|
| Mounting `/var/run/docker.sock` into a container | Anything that can talk to the Docker socket can start a privileged container with the host's root filesystem mounted: full root on the host. Tools that need it (CI agents, some monitoring) should be treated as root on the host, isolated, and kept to a minimum. |
| `--privileged` | Turns off almost every isolation: all capabilities, all devices, no seccomp or AppArmor. A process in a privileged container can trivially take over the host. |
| Adding users to the `docker` group | Equivalent to giving them passwordless root. Grant it like sudo, or use rootless mode. |
| `--network host` | Removes network isolation: the container can bind any host port and reach services listening only on localhost |
| `-v /:/host` and similar broad host mounts | The host's files, writable by the container |
| `--pid host`, `--ipc host` | The container sees and can signal every process on the host |
| `--security-opt seccomp=unconfined` or `apparmor=unconfined` | Removes the system call filter or the mandatory access control profile |
| Exposing the Docker daemon on TCP without TLS (`-H tcp://0.0.0.0:2375`) | Unauthenticated root on the host for anyone who can reach the port. Scanners find these quickly. |

## 1. The image

- **Small bases, and only what you run.** Every package is something to patch. Distroless and `-slim` images have far fewer components; multi-stage builds keep compilers out ([Dockerfiles](03-dockerfiles.md)).
- **A non-root `USER` in the image,** with a numeric UID (`USER 10001`), so platforms that check "runs as non-root" can verify it without resolving names.
- **No secrets in layers.** Use `RUN --mount=type=secret` for build-time secrets. A file copied in and deleted in a later layer is still in the image ([why](../01-how-containers-work.md#images-layers-and-the-root-filesystem)).
- **A `.dockerignore`** that excludes `.git`, `.env`, local credentials, and test data from the build context.
- **Rebuild regularly,** even without code changes, to pick up base image fixes, and redeploy. An image built a year ago carries a year of known vulnerabilities.
- **Pin by digest** so you know exactly what's running, and let a bot (Dependabot, Renovate) propose updates.
- **Trusted sources only:** official images, verified publishers, your own builds. Don't pull random `someuser/postgres` images.

### Scan

```sh
# Trivy: vulnerabilities, misconfigurations, and secrets
trivy image --severity HIGH,CRITICAL --ignore-unfixed myapp:1.0
trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed myapp:1.0     # fail CI on fixable criticals
trivy config software/containers/docker/examples/                           # Dockerfile and Compose misconfigurations
docker scout cves myapp:1.0                                                  # Docker's own scanner, built into Docker Desktop
hadolint Dockerfile                                                          # Dockerfile best practices
```

`--ignore-unfixed` hides vulnerabilities with no fix available yet, which you can't act on by rebuilding; track them separately. Scan in CI on every build, and scan images in your registry on a schedule (ECR and ACR can do this natively), because new vulnerabilities are published against old images every day.

### SBOMs and signing

A **software bill of materials** (SBOM) lists every package in an image, so when the next widespread vulnerability lands, you can answer "are we affected?" in minutes rather than days.

```sh
docker buildx build --sbom=true --provenance=mode=max -t registry.example.com/app:1.0 --push .   # attach an SBOM and build provenance
trivy image --format cyclonedx --output sbom.json myapp:1.0                                       # or generate one from any image
```

**Signing** proves an image came from your pipeline and wasn't swapped in the registry. With Sigstore's cosign and keyless signing from CI (the CI job's OIDC identity is the signer, so there's no key to steal):

```sh
cosign sign registry.example.com/app@sha256:...                       # in CI, with the job's OIDC token
cosign verify registry.example.com/app@sha256:... \
  --certificate-identity-regexp 'https://github.com/Carxion/Devops-and-platforming-groundwork/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Then enforce verification where images are deployed: a Kubernetes admission policy (Kyverno, Sigstore policy-controller), or the platform's own image signing support. See the guide's [DevSecOps section](../../../tech-lead/README.md#7-devsecops) for SLSA and supply-chain practices.

## 2. The container at run time

| Setting | Docker | Effect |
|---|---|---|
| Non-root user | `--user 10001:10001` (or `USER` in the image) | A process escaping the container lands as an unprivileged user |
| Read-only root filesystem | `--read-only --tmpfs /tmp` | Malware can't be written into the container; mount writable paths explicitly |
| Drop capabilities | `--cap-drop ALL` (add back only what's needed, e.g. `--cap-add NET_BIND_SERVICE`) | Root inside the container loses most of its power |
| No privilege escalation | `--security-opt no-new-privileges` | setuid binaries can't raise privileges |
| Resource limits | `--memory 256m --cpus 0.5 --pids-limit 200` | One container can't starve the host (or fork-bomb it) |
| Default seccomp and AppArmor or SELinux | On by default; never pass `unconfined` | Blocks dangerous system calls and file access |
| Published ports on loopback | `-p 127.0.0.1:8080:80` | Not reachable from the network, whatever the host firewall says ([Networking](05-networking-and-storage.md#published-ports-and-the-host-firewall)) |
| Secrets as files | Compose `secrets:`, or the orchestrator's secret store | Environment variables show up in `docker inspect`, crash dumps, and child processes |
| Health check | `HEALTHCHECK` in the image, or `--health-cmd` | The orchestrator can restart a hung container |

All together:

```sh
docker run -d --name api \
  --user 10001:10001 \
  --read-only --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --memory 256m --cpus 0.5 --pids-limit 200 \
  -p 127.0.0.1:8080:8080 \
  registry.example.com/team/api@sha256:<digest>
```

The [Compose example](examples/compose.yaml) applies every one of these through a shared settings block, and the [Kubernetes samples](../../../devops/kubernetes/README.md) do the same with a pod `securityContext`.

### Capabilities

Linux splits root's power into about 40 capabilities. Docker's default set keeps 14 that most applications might need: `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `FSETID`, `KILL`, `SETGID`, `SETUID`, `SETPCAP`, `SETFCAP`, `NET_BIND_SERVICE`, `NET_RAW`, `SYS_CHROOT`, `MKNOD`, and `AUDIT_WRITE`. Dangerous ones such as `SYS_ADMIN`, `NET_ADMIN`, `SYS_MODULE`, and `SYS_PTRACE` are already dropped.

Most applications need none of the 14. Start from `--cap-drop ALL` and add back only what fails:

```sh
docker run --rm docker.io/library/alpine:3.22 grep Cap /proc/1/status                  # the default effective set, as a hex mask
docker run --rm --cap-drop ALL docker.io/library/alpine:3.22 grep CapEff /proc/1/status # all zeros
capsh --decode=00000000a80425fb                                                          # turn a mask into names (libcap's capsh)
```

| Need | Add |
|---|---|
| Bind a port below 1024 as non-root | `NET_BIND_SERVICE` (or listen on 8080 and publish `-p 80:8080`) |
| `ping` inside the container | `NET_RAW` |
| An entrypoint that `chown`s files, then drops to a user | `CHOWN`, `SETUID`, `SETGID` (better: fix ownership at build time and start as the user) |

Never add `SYS_ADMIN`: it's close to `--privileged`.

### seccomp and AppArmor or SELinux

Docker applies a default **seccomp** profile that blocks dozens of system calls a container shouldn't need (such as `mount`, `reboot`, `kexec_load`, loading kernel modules, and changing the clock), and a Linux security module: the `docker-default` **AppArmor** profile on Ubuntu, or **SELinux** labels on RHEL-family hosts (when the daemon has `--selinux-enabled`, which RHEL's packages turn on).

```sh
docker info --format '{{json .SecurityOptions}}'          # seccomp, apparmor or selinux, userns, rootless, cgroupns
docker inspect --format '{{.HostConfig.SecurityOpt}}' api  # per-container overrides (empty means the defaults)
```

For a high-value service, a tighter seccomp profile listing only the calls the application uses is possible (`--security-opt seccomp=profile.json`), but it's brittle: a library update that uses a new system call fails at run time. Keep the default unless you have the testing to support a custom one; never use `unconfined`.

On SELinux hosts, mounted host directories need the `:Z` or `:z` relabel option ([Podman hardening](../podman/06-hardening.md#selinux-labels-and-volumes) explains them; they work the same in Docker).

## 3. The daemon

### Protect the daemon and its socket

The API socket is root on the host ([why](02-architecture.md#the-socket-is-root)). Options, best first:

| Option | How | Gives |
|---|---|---|
| **Rootless mode** | The daemon runs as an ordinary user (below) | An escape lands as that user, not root |
| **No socket in containers** | Build images in CI with BuildKit, Kaniko, or Buildah rather than mounting the socket into the CI job | Removes the most common path to the host |
| **A socket proxy** | Tools that only read (monitoring, dashboards) get a proxy that allows only `GET` on the endpoints they need | Read-only access instead of root |
| **SSH for remote access** | `docker context create remote --docker host=ssh://user@host` | Remote control over SSH's authentication, with no TCP port open |
| **TLS for TCP** | `--tlsverify` with client certificates, if the API must be on TCP at all | Only holders of a client certificate signed by your CA can connect |
| **A small `docker` group** | Only people you'd give root | Fewer people with root |

### Daemon configuration

Settings in `/etc/docker/daemon.json` that apply to every container ([what each file does](02-architecture.md#where-things-live)):

```json
{
  "icc": false,
  "no-new-privileges": true,
  "live-restore": true,
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "userns-remap": "default"
}
```

| Setting | Does |
|---|---|
| `icc: false` | Containers on the default bridge network can't talk to each other unless linked. Containers on user-defined networks still can; use separate networks per application |
| `no-new-privileges` | Applies `no-new-privileges` to every container by default |
| `live-restore` | Containers keep running across daemon restarts, so patching the daemon doesn't cause an outage |
| `userland-proxy: false` | Published ports use iptables rules only, without a `docker-proxy` process per port |
| `log-opts` | Rotates container logs, so a noisy container can't fill the disk |
| `userns-remap` | Container root maps to an unprivileged UID range on the host (below) |

`userns-remap` changes ownership of everything under the data directory, and existing images and containers aren't visible afterwards: turn it on for a new host, not a running one. Validate the file before restarting: `sudo dockerd --validate --config-file /etc/docker/daemon.json`.

### Rootless mode and user namespace remapping

In **rootless mode**, the Docker daemon itself runs as an ordinary user, so even a full container escape lands as that user, not root. Podman is rootless by default ([Podman architecture](../podman/02-architecture.md#rootless-containers-and-user-namespaces)). For Docker:

```sh
dockerd-rootless-setuptool.sh install      # as the user, after installing docker-ce-rootless-extras
systemctl --user enable --now docker
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
docker info --format '{{json .SecurityOptions}}'   # includes "name=rootless"
```

Limits: ports below 1024 need a sysctl change (`net.ipv4.ip_unprivileged_port_start`), some network modes and storage drivers aren't available, and network performance can be lower. For CI build hosts and multi-user machines, the trade is usually worth it.

**User namespace remapping** (`"userns-remap": "default"`) is the middle ground: the daemon stays root, but container root maps to an unprivileged UID range on the host, taken from `/etc/subuid` and `/etc/subgid` for a `dockremap` user that Docker creates.

## 4. The host

- **Keep the host minimal and patched;** it runs every container's kernel. Container-optimized OSes (Bottlerocket, Flatcar, Azure Linux) are built for this.
- **Restrict who can reach the Docker socket:** only root and the people you'd give root.
- **Audit the daemon:** `auditd` rules on `/usr/bin/dockerd`, `/var/lib/docker`, `/etc/docker`, and `/run/docker.sock`.
- **Keep Docker Engine, containerd, and runc patched:** container escapes have been found in all three, and the fixes ship as package updates.
- **Benchmark against the CIS Docker Benchmark.** The [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) is the standard checklist, and the open-source [docker-bench-security](https://github.com/docker/docker-bench-security) script checks a host against it:

```sh
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security && sudo sh docker-bench-security.sh
```

Treat its output as a checklist to review, not a score to maximize: some findings won't apply to your setup.

## Checklist

- [ ] Images: small base, non-root numeric `USER`, no secrets in layers, `.dockerignore`, pinned by digest, rebuilt regularly
- [ ] CI scans every image (Trivy or equivalent) and fails on fixable critical findings; registries rescan on a schedule
- [ ] Images are signed in CI, and signatures are verified at deployment
- [ ] Containers run with `--cap-drop ALL`, `no-new-privileges`, a read-only root filesystem, resource limits, and a health check
- [ ] No container has `--privileged`, the Docker socket, host namespaces, or broad host mounts, or each exception is documented and isolated
- [ ] Published ports bind to loopback unless they must be public
- [ ] The daemon isn't on TCP, or requires TLS client certificates; the `docker` group is as small as root access
- [ ] `daemon.json` sets log rotation, `live-restore`, `no-new-privileges`, and `icc: false`
- [ ] Rootless mode or user namespace remapping on multi-user and CI hosts
- [ ] Hosts are patched, audited, and checked with docker-bench-security
