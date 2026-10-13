# Security

[← Docker 101](README.md)

Containers share the host's kernel, so container security is host security. The biggest risks are almost never exotic kernel exploits; they're configuration choices that hand over the host, and images full of old, vulnerable software. This page goes from the worst mistakes to the finer controls. [docker-audit.sh](scripts/docker-audit.sh) checks running containers for most of them.

## Never do these

| Setting | Why it's dangerous |
|---|---|
| Mounting `/var/run/docker.sock` into a container | Anything that can talk to the Docker socket can start a privileged container with the host's root filesystem mounted: full root on the host. Tools that need it (CI agents, some monitoring) should be treated as root on the host, isolated, and kept to a minimum. |
| `--privileged` | Turns off almost every isolation: all capabilities, all devices, no seccomp or AppArmor. A process in a privileged container can trivially take over the host. |
| Adding users to the `docker` group | Equivalent to giving them passwordless root. Grant it like sudo, or use rootless mode. |
| `--network host` | Removes network isolation: the container can bind any host port and reach services listening only on localhost |
| `-v /:/host` and similar broad host mounts | The host's files, writable by the container |
| `--pid host`, `--ipc host` | The container sees and can signal every process on the host |
| Exposing the Docker daemon on TCP without TLS (`-H tcp://0.0.0.0:2375`) | Unauthenticated root on the host for anyone who can reach the port. Scanners find these within minutes. |

## Image hygiene

- **Small bases, and only what you run.** Every package is something to patch. Distroless and `-slim` images have far fewer components; multi-stage builds keep compilers out ([Dockerfiles](02-dockerfiles.md)).
- **Rebuild regularly,** even without code changes, to pick up base image fixes, and redeploy. An image built a year ago carries a year of known vulnerabilities.
- **Pin by digest** so you know exactly what's running, and let a bot propose updates.
- **Trusted sources only:** official images, verified publishers, your own builds. Don't pull random `someuser/postgres` images.

## Scan

```sh
# Trivy: vulnerabilities, misconfigurations, and secrets
trivy image --severity HIGH,CRITICAL --ignore-unfixed myapp:1.0
trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed myapp:1.0     # fail CI on fixable criticals
trivy config docker/examples/                                                # Dockerfile and Compose misconfigurations
docker scout cves myapp:1.0                                                  # Docker's own scanner, built into Docker Desktop
```

`--ignore-unfixed` hides vulnerabilities with no fix available yet, which you can't act on by rebuilding; track them separately. Scan in CI on every build, and scan images in your registry on a schedule (ECR and ACR can do this natively), because new vulnerabilities are published against old images every day.

## SBOMs and signing

A **software bill of materials** (SBOM) lists every package in an image, so when the next widespread vulnerability lands, you can answer "are we affected?" in minutes rather than days.

```sh
docker buildx build --sbom=true --provenance=mode=max -t registry.example.com/app:1.0 --push .   # attach an SBOM and build provenance
trivy image --format cyclonedx --output sbom.json myapp:1.0                                       # or generate one from any image
```

**Signing** proves an image came from your pipeline and wasn't swapped in the registry. With Sigstore's cosign and keyless signing from CI (the CI job's OIDC identity is the signer, so there's no key to steal):

```sh
cosign sign registry.example.com/app@sha256:...                       # in CI, with the job's OIDC token
cosign verify registry.example.com/app@sha256:... \
  --certificate-identity-regexp 'https://github.com/OWNER/REPO/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Then enforce verification where images are deployed: a Kubernetes admission policy (Kyverno, Sigstore policy-controller), or the platform's own image signing support. See the guide's [DevSecOps section](../README.md#7-devsecops) for SLSA and supply-chain practices.

## Runtime hardening

Every one of these is in the [Compose example](examples/compose.yaml) and the [Kubernetes samples](../kubernetes/README.md):

| Setting | Docker | Effect |
|---|---|---|
| Non-root user | `--user 10001:10001` (or `USER` in the image) | A process escaping the container lands as an unprivileged user |
| Read-only root filesystem | `--read-only --tmpfs /tmp` | Malware can't be written into the container; mount writable paths explicitly |
| Drop capabilities | `--cap-drop ALL` (add back only what's needed, e.g. `--cap-add NET_BIND_SERVICE`) | Root inside the container loses most of its power |
| No privilege escalation | `--security-opt no-new-privileges:true` | setuid binaries can't raise privileges |
| Resource limits | `--memory 256m --cpus 0.5 --pids-limit 200` | One container can't starve the host (or fork-bomb it) |
| Default seccomp and AppArmor or SELinux | On by default; don't pass `seccomp=unconfined` or `apparmor=unconfined` | Blocks dangerous system calls |
| Published ports on loopback | `-p 127.0.0.1:8080:80` | Not reachable from the network, whatever the host firewall says ([Networking](04-networking-and-storage.md#published-ports-and-the-host-firewall)) |
| Secrets as files | Compose `secrets:`, or the orchestrator's secret store | Environment variables show up in `docker inspect`, crash dumps, and child processes |

## Rootless containers

In **rootless mode**, the Docker daemon itself runs as an ordinary user, so even a full container escape lands as that user, not root. Podman is rootless by default ([Podman and RHEL](07-podman-and-rhel.md)). For Docker:

```sh
dockerd-rootless-setuptool.sh install      # as the user, after installing docker-ce-rootless-extras
systemctl --user enable --now docker
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
```

Limits: ports below 1024 need a sysctl change, some network modes and storage drivers aren't available, and performance can be lower. For CI build hosts and multi-user machines, the trade is usually worth it.

**User namespace remapping** (`"userns-remap": "default"` in `daemon.json`) is the middle ground: the daemon stays root, but container root maps to an unprivileged UID range on the host.

## The host

- Keep the host minimal and patched; it runs every container's kernel. Container-optimized OSes (Bottlerocket, Flatcar, Azure Linux) are built for this.
- Restrict who can reach the Docker socket: only root and the people you'd give root.
- Turn on audit logging of the Docker daemon and socket (`auditd` rules on `/usr/bin/dockerd`, `/var/lib/docker`, and `/run/docker.sock`).
- The [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) is the standard checklist, and the open-source [docker-bench-security](https://github.com/docker/docker-bench-security) script checks a host against it.
