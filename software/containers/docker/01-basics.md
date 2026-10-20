# Basics

[← Docker](README.md)

## The ideas

| Term | Means |
|---|---|
| **Image** | A read-only template: a filesystem (an operating system's userland, libraries, and your app) plus metadata (the command to run, environment, user, ports). Built from a Dockerfile. |
| **Layer** | Images are stacks of layers, one per filesystem-changing Dockerfile instruction. Layers are shared between images and cached, so rebuilding and pulling only moves what changed. |
| **Container** | A running (or stopped) instance of an image: the image's layers plus a thin writable layer on top, running as isolated processes on the host's kernel. |
| **Registry** | Where images are stored and shared: Docker Hub, GitHub Container Registry (`ghcr.io`), Amazon ECR, Azure Container Registry, Quay, or your own. |
| **Tag** | A movable name for an image version: `nginx:1.27`. Tags can be re-pointed, so the same tag can mean different images on different days. |
| **Digest** | The image's content hash: `nginx@sha256:...`. It can't change. Pin production images by digest. |
| **Engine** | The daemon (`dockerd`) that builds and runs containers, and the `docker` command-line client that talks to it. Containers are run underneath by containerd and runc, which follow the OCI (Open Container Initiative) standards. |

**A container is not a virtual machine.** It shares the host's kernel and is isolated by Linux namespaces (its own view of processes, network, mounts, and users) and cgroups (limits on CPU, memory, and I/O). It starts in milliseconds and has no kernel of its own, which is also why a container breakout is a host compromise.

## First commands

```sh
docker version                           # client and server versions; fails if the daemon isn't reachable
docker run --rm hello-world              # pull an image and run it; --rm removes the container when it exits
docker run --rm -it ubuntu:24.04 bash    # an interactive shell (-i keep stdin open, -t allocate a terminal)
docker run -d --name web -p 127.0.0.1:8080:80 nginx:1.27   # detached (-d), named, port 8080 on loopback -> 80 inside
curl -s localhost:8080 | head -5
```

## The container lifecycle

```sh
docker ps                      # running containers
docker ps -a                   # including stopped ones
docker logs web                # its stdout and stderr; -f to follow, --since 10m, --tail 100
docker exec -it web sh         # a shell inside a running container (bash if the image has it)
docker exec web nginx -t       # run one command inside
docker stats --no-stream       # CPU, memory, network, and I/O per container
docker top web                 # its processes, as seen from the host
docker inspect web             # everything Docker knows about it, as JSON
docker stop web                # SIGTERM, then SIGKILL after 10 seconds (-t to change)
docker start web               # start it again, with the same writable layer
docker restart web
docker rm web                  # delete it (it must be stopped, or use -f)
```

The writable layer is deleted with the container. **Anything a container writes that must survive goes in a volume** ([Networking and storage](05-networking-and-storage.md)).

## Images

```sh
docker pull nginx:1.27                     # download
docker images                              # local images (docker image ls)
docker image inspect nginx:1.27            # config: entrypoint, user, env, exposed ports, layers
docker history nginx:1.27                  # the layers and the instruction that made each one
docker build -t myapp:1.0 .                # build from ./Dockerfile
docker tag myapp:1.0 registry.example.com/team/myapp:1.0
docker login registry.example.com
docker push registry.example.com/team/myapp:1.0
docker rmi myapp:1.0                       # remove a local image
```

An image name is `[registry/][namespace/]repository[:tag][@digest]`. With no registry, Docker Hub is assumed; with no tag, `latest`, which is just a tag like any other and doesn't mean newest. **Don't deploy `latest`.**

## Useful `docker run` options

| Option | Does |
|---|---|
| `--rm` | Remove the container when it exits |
| `-d` | Run in the background |
| `--name web` | A fixed name instead of a random one |
| `-p 127.0.0.1:8080:80` | Publish container port 80 on host port 8080, loopback only. `-p 8080:80` listens on every interface. |
| `-e KEY=value`, `--env-file .env` | Environment variables |
| `-v data:/var/lib/app` | Mount a named volume |
| `-v "$PWD/conf:/etc/app:ro"` | Bind-mount a host directory, read-only |
| `--restart unless-stopped` | Restart on failure and after reboots, unless you stopped it |
| `--memory 512m --cpus 1.5` | Resource limits |
| `--user 10001:10001` | Run as this UID and GID |
| `--read-only --tmpfs /tmp` | Read-only root filesystem, with a writable in-memory `/tmp` |
| `--cap-drop ALL` | Drop every Linux capability |
| `--network appnet` | Attach to a user-defined network |
| `--entrypoint sh` | Override the image's entrypoint, to debug an image whose command fails |
| `--init` | Run a tiny init as PID 1 that forwards signals and reaps zombies |

## Where things live

| | Path or command |
|---|---|
| Docker's data (images, containers, volumes) | `/var/lib/docker` (move it with `data-root` in `/etc/docker/daemon.json`) |
| Daemon configuration | `/etc/docker/daemon.json` |
| Daemon logs | `journalctl -u docker` |
| Disk use | `docker system df` |
| Client configuration and registry credentials | `~/.docker/config.json` |

A sensible `/etc/docker/daemon.json` for servers caps container log files, which otherwise grow without limit:

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true
}
```

`live-restore` keeps containers running while the daemon restarts (for example during a Docker upgrade). Restart the daemon after editing: `sudo systemctl restart docker`.
