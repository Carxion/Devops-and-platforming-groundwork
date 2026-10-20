# Podman hardening

[← Podman](README.md)

Podman starts from a safer place than Docker: no root daemon, no root-owned socket, and rootless containers by default. Most of the [Docker hardening guide](../docker/08-hardening.md) still applies (image hygiene, scanning, signing, and runtime settings use the same flags), so this guide covers what's specific to Podman: rootless operation, SELinux, user namespace options, signature policy, and registry configuration.

## Run rootless

A rootless container runs inside your user's user namespace, so a process that escapes it is your user on the host, not root ([how it works](02-architecture.md#rootless-containers-and-user-namespaces)).

- **Run services as a dedicated, unprivileged user,** with lingering enabled and Quadlet units in that user's `~/.config/containers/systemd/` ([Rootless services](05-systemd-and-quadlet.md#rootless-services)).
- **Use rootful Podman only when something needs it** (ports below 1024 without a sysctl change, some network setups, CRIU checkpointing), and then still run the container's process as a non-root user.
- **Check what you're running:** `podman info --format '{{.Host.Security.Rootless}}'`.

Rootless isn't a reason to skip the runtime settings below: a compromised rootless container can still read and change everything your user can.

## Runtime settings

The flags are the same as Docker's:

```sh
podman run -d --name api \
  --user 10001:10001 \
  --read-only --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --memory 256m --cpus 0.5 --pids-limit 200 \
  -p 127.0.0.1:8080:8080 \
  registry.example.com/team/api@sha256:<digest>
```

In Quadlet, the same settings are `User=`, `ReadOnly=true`, `DropCapability=ALL`, `NoNewPrivileges=true`, and `PodmanArgs=--memory 256m --pids-limit 200` ([example](05-systemd-and-quadlet.md#a-container-as-a-service)).

Podman's default capability set is smaller than Docker's: it leaves out `NET_RAW`, `MKNOD`, and `AUDIT_WRITE`, so containers can't create raw sockets or device nodes unless you add them. The defaults are set in `containers.conf` (`default_capabilities`), where you can tighten them for every container on a host.

```sh
podman run --rm docker.io/library/alpine:3.22 grep CapEff /proc/1/status    # Podman's default effective set
podman inspect --format '{{.EffectiveCaps}}' api                             # a running container's capabilities, by name
```

## SELinux labels and volumes

On RHEL-family hosts, every container runs confined by SELinux (type `container_t`), with a unique category pair (MCS label), so containers can't read each other's files even if they escape to the host as the same user. A container can only read host files labeled for containers. Mounting a host directory without relabeling it gives "permission denied", with perfectly good Unix permissions:

```sh
podman run --rm -v /srv/app/conf:/etc/app:ro registry.example.com/app:1.0      # permission denied
podman run --rm -v /srv/app/conf:/etc/app:ro,Z registry.example.com/app:1.0    # works
```

| Option | Does |
|---|---|
| `:Z` | Relabel the content as **private** to this container (its own MCS label). Other containers can't read it. |
| `:z` | Relabel as **shared** between containers |

Never use `:Z` on system directories such as `/home` or `/etc`: it relabels them for one container and breaks the host's own services. Mount a dedicated directory instead. The same `:Z` and `:z` work with Docker on SELinux hosts. When something is still denied, `ausearch -m AVC -ts recent` shows it ([SELinux and AppArmor](../../../devops/bash/05-rhel-and-ubuntu.md#selinux-and-apparmor)).

Never turn SELinux off to make a container work: `--security-opt label=disable` removes the protection for that container, and `setenforce 0` removes it for the whole host. Fix the label instead.

For containers that need more than the default policy allows (access to a specific host directory or device), **udica** generates a custom SELinux policy from the container's actual needs, instead of disabling labeling.

## User namespace options

| Option | Does | Use for |
|---|---|---|
| (default, rootless) | Container root is your user; other container UIDs map to your subordinate range | Most rootless containers |
| `--userns keep-id` | Your UID and GID appear unchanged inside the container | Development, and mounted directories you need to own on the host |
| `--userns auto` | Each container gets its own unique UID range (rootful Podman) | Rootful hosts running several containers: an escape from one doesn't share UIDs with another |
| `--userns host` | No user namespace | Avoid: container root is host root (rootful) |

`--userns auto` is the rootful equivalent of rootless isolation: container root is a high, unused UID on the host. It needs a `containers` entry in `/etc/subuid` and `/etc/subgid` for the UID ranges it hands out.

## Trust only signed images: policy.json

`/etc/containers/policy.json` decides which images Podman (and Buildah, Skopeo, and CRI-O) will pull. The default accepts anything. A stricter policy rejects by default and requires signatures from your registry:

```json
{
  "default": [{ "type": "reject" }],
  "transports": {
    "docker": {
      "registry.example.com/team": [
        {
          "type": "sigstoreSigned",
          "keyPath": "/etc/containers/keys/team-cosign.pub",
          "signedIdentity": { "type": "matchRepository" }
        }
      ],
      "registry.access.redhat.com": [
        { "type": "signedBy", "keyType": "GPGKeys", "keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" }
      ]
    },
    "containers-storage": { "": [{ "type": "insecureAcceptAnything" }] },
    "docker-daemon": { "": [{ "type": "reject" }] }
  }
}
```

| Requirement | Means |
|---|---|
| `reject` | Never pull from here |
| `insecureAcceptAnything` | Accept without checks (keep it for local storage only) |
| `signedBy` | Require a GPG (simple signing) signature by this key |
| `sigstoreSigned` | Require a Sigstore (cosign) signature by this key, or keyless with `fulcio` and `rekorPublicKeyPath` |

Sigstore signatures are found through a `use-sigstore-attachments: true` setting for the registry in `/etc/containers/registries.d/`. Check the policy with `podman image trust show`, and test it by pulling a signed and an unsigned image.

## Registries: no surprises

In `/etc/containers/registries.conf`:

```toml
short-name-mode = "enforcing"                         # never guess a registry for a short name in scripts
unqualified-search-registries = ["registry.example.com"]   # if short names are allowed at all, only your registry

[[registry]]
location = "docker.io"
blocked = true                                        # pull only through your mirror

[[registry]]
location = "registry.example.com/mirror/docker.io"
```

Blocking public registries and pulling through an internal mirror (with images scanned and signed on the way in) is the usual setup for restricted networks ([Skopeo](07-buildah-skopeo-and-ubi.md#skopeo-images-in-registries) does the mirroring).

## The host

Most of the [Docker host guidance](../docker/08-hardening.md#4-the-host) applies: keep the host minimal and patched, keep Podman, crun, and conmon updated, and audit `/etc/containers` and the storage directories. Two Podman-specific points:

- **Keep SELinux enforcing** (`getenforce` shows `Enforcing`); it's the main thing standing between a container escape and other containers' files.
- **Protect the API socket if you turn it on:** a rootful `podman.socket` is root-equivalent like Docker's. Prefer the rootless, per-user socket.

## Checklist

- [ ] Containers run rootless, as a dedicated user, unless a documented need requires rootful
- [ ] The container process runs as a non-root UID, with `--cap-drop ALL`, `no-new-privileges`, a read-only root filesystem, and resource limits
- [ ] SELinux is enforcing; volumes use `:Z` or `:z` on dedicated directories; nothing uses `label=disable`
- [ ] Rootful hosts with several containers use `--userns auto`
- [ ] `policy.json` rejects by default and requires signatures for your registries
- [ ] `registries.conf` enforces full names and blocks registries you don't use
- [ ] Images are scanned and signed in CI, as in the [Docker checklist](../docker/08-hardening.md#checklist)
- [ ] The rootful Podman socket is off, or as protected as root access
