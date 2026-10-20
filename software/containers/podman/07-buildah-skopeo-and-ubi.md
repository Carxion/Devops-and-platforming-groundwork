# Buildah, Skopeo, and UBI

[← Podman](README.md)

Podman's companion tools split the work Docker does in one daemon into separate, daemonless programs: **Buildah** builds images, and **Skopeo** inspects, copies, and signs images in registries. On RHEL, Red Hat's **UBI** images are the base to build on.

## Buildah: building images

`podman build` uses Buildah's code, so for Dockerfiles the two are the same:

```sh
podman build -t app:1.0 .                 # from a Dockerfile (or a Containerfile)
buildah build -t app:1.0 .                # the same build, with Buildah
```

Buildah can also build an image step by step from a script, without a Dockerfile. That's useful when the build logic is easier to express in shell, or when you want to install packages from the host into an image that has no package manager:

```sh
ctr=$(buildah from registry.access.redhat.com/ubi9/ubi-minimal)   # a working container from a base image
buildah run "$ctr" -- microdnf install -y python3                    # run a command in it
buildah copy "$ctr" app.py /opt/app/app.py                           # copy files in
buildah config --user 10001 --cmd '["python3", "/opt/app/app.py"]' "$ctr"   # set image metadata
buildah commit "$ctr" app:1.0                                        # save it as an image
buildah rm "$ctr"
```

Neither needs a daemon or root, so they're the usual way to build images in CI without mounting a Docker socket: run Buildah (or `podman build`) rootless in the CI job's own container.

## Skopeo: images in registries

Skopeo works on images where they are, without pulling them to local storage:

```sh
skopeo inspect docker://docker.io/library/nginx:1.27                       # the image's metadata and digest
skopeo inspect --raw docker://docker.io/library/nginx:1.27 | jq .          # the raw manifest or multi-architecture index
skopeo list-tags docker://registry.access.redhat.com/ubi9/ubi              # every tag in a repository
skopeo copy docker://docker.io/library/nginx:1.27 docker://registry.example.com/mirror/nginx:1.27   # registry to registry
skopeo copy --all docker://docker.io/library/nginx:1.27 dir:./nginx        # every architecture, to a directory
skopeo sync --src docker --dest dir docker.io/library/nginx:1.27 ./mirror  # mirror tags in bulk
```

| Transport | Means |
|---|---|
| `docker://` | A registry |
| `containers-storage:` | Podman's or Buildah's local storage |
| `docker-daemon:` | A Docker daemon's local images |
| `dir:` | Files in a directory |
| `oci:` / `oci-archive:` | An OCI layout directory, or a tarball of one |
| `docker-archive:` | A `docker save` tarball |

Skopeo is the tool for **mirroring images into a restricted network**: copy from the internet to files on one side, carry them across, and copy from files into the internal registry on the other, with digests preserved so signatures still verify.

## UBI: Red Hat's base images

**UBI** (Universal Base Image) is freely redistributable, so you can build and publish images on it without a Red Hat subscription. Images built on UBI are supported by Red Hat when run on RHEL or OpenShift.

| Image | Contains | Package manager |
|---|---|---|
| `registry.access.redhat.com/ubi9/ubi` | A standard RHEL userspace | `dnf` |
| `ubi9/ubi-minimal` | A minimal userspace | `microdnf` |
| `ubi9/ubi-micro` | The bare minimum: no package manager, no shell utilities | None (add packages at build time from the host, with Buildah) |
| `ubi9/ubi-init` | systemd as PID 1, for containers that run several services | `dnf` |
| `ubi9/python-312`, `ubi9/nodejs-20`, `ubi9/openjdk-21` | A language runtime, ready to build on | `dnf` |

Pick the smallest that works: `ubi-micro` or `ubi-minimal` for the final stage of a multi-stage build, and a full or language image for the build stage. UBI images only include the subset of RHEL packages that's freely redistributable; on a subscribed RHEL host, builds can use the full RHEL repositories.

## Next

Back to the [Podman overview](README.md), or compare with [Docker](../docker/README.md).
