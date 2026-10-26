# Docker command reference

[← Docker](README.md)

The commands you'll use, grouped by task. Docker's commands are organized by object (`docker container ...`, `docker image ...`); the older short forms (`docker ps`, `docker rmi`) still work, and both are shown where they differ. `docker <command> --help` lists every option. For long pipelines with format templates and filters, see [Complex commands](07-complex-commands.md).

## Containers: run and manage

| Command | Does |
|---|---|
| `docker run IMAGE [COMMAND]` | Create and start a container |
| `docker run -d --name web -p 8080:80 IMAGE` | Detached (background), named, with host port 8080 forwarded to container port 80 |
| `docker run --rm -it IMAGE sh` | Interactive shell; remove the container on exit |
| `docker run -e KEY=value --env-file .env IMAGE` | Set environment variables |
| `docker run -v data:/var/lib/app -v "$PWD/conf:/etc/app:ro" IMAGE` | A named volume, and a read-only bind mount |
| `docker run --restart unless-stopped IMAGE` | Restart on failure and after reboot, unless stopped by hand |
| `docker ps` / `docker container ls` | Running containers. `-a` includes stopped ones; `-q` prints only IDs |
| `docker stop NAME` | Send SIGTERM, then SIGKILL after 10 seconds (`-t` changes the wait) |
| `docker start NAME` / `docker restart NAME` | Start a stopped container / stop and start |
| `docker kill -s SIGHUP NAME` | Send a signal (default SIGKILL) |
| `docker rm NAME` | Remove a stopped container. `-f` stops it first; `-v` removes its anonymous volumes |
| `docker rename OLD NEW` | Rename |
| `docker update --memory 512m --cpus 1 NAME` | Change resource limits on a running container |
| `docker wait NAME` | Block until it stops, then print its exit code |
| `docker container prune` | Remove all stopped containers |

## Containers: look inside

| Command | Does |
|---|---|
| `docker logs -f --tail 100 NAME` | Follow the last 100 lines of output. `--since 10m`, `-t` for timestamps |
| `docker exec -it NAME sh` | Run a shell in a running container. `-u 0` as root |
| `docker inspect NAME` | Full configuration and state as JSON |
| `docker inspect --format '{{.State.Status}} {{.State.ExitCode}} {{.State.OOMKilled}}' NAME` | One field, with a Go template |
| `docker top NAME` | Its processes, with host PIDs |
| `docker stats --no-stream` | CPU, memory, network, and disk I/O per container, once |
| `docker port NAME` | Published ports |
| `docker diff NAME` | Files added (A), changed (C), or deleted (D) in its writable layer |
| `docker cp NAME:/path/in/container ./local` | Copy files out (or in, reversing the arguments) |
| `docker events --since 10m` | What the daemon did: starts, stops, health changes, OOM kills |
| `docker attach NAME` | Connect to its main process's input and output (detach with Ctrl-P Ctrl-Q) |

## Images

| Command | Does |
|---|---|
| `docker pull docker.io/library/nginx:1.27` | Download an image. Prefer full names |
| `docker images` / `docker image ls` | Local images. `--digests` shows digests |
| `docker build -t app:1.0 .` | Build from the Dockerfile in the current directory |
| `docker build --target test -t app:test .` | Build only up to one stage of a multi-stage Dockerfile |
| `docker build --no-cache --pull -t app:1.0 .` | Rebuild everything, with fresh base images |
| `docker tag app:1.0 registry.example.com/team/app:1.0` | Add another name to an image |
| `docker push registry.example.com/team/app:1.0` | Upload to a registry |
| `docker image history app:1.0` | Layers, their sizes, and the instructions that created them |
| `docker image inspect app:1.0` | Configuration: entrypoint, command, user, environment, labels, layers |
| `docker rmi app:1.0` / `docker image rm` | Remove an image (or just that tag, if it has others) |
| `docker image prune` | Remove dangling images (untagged leftovers). `-a` removes every image not used by a container |
| `docker save -o app.tar app:1.0` / `docker load -i app.tar` | Export and import images as files, for offline transfer |
| `docker manifest inspect docker.io/library/nginx:1.27` | The image's manifest or multi-architecture index, from the registry, without pulling |

## Builds with Buildx

| Command | Does |
|---|---|
| `docker buildx ls` | Builders, and the platforms each can build for |
| `docker buildx create --name multi --use` | A builder that can build for several architectures |
| `docker buildx build --platform linux/amd64,linux/arm64 -t REF --push .` | Build for two architectures and push one multi-architecture image |
| `docker buildx build --secret id=npmrc,src=$HOME/.npmrc .` | Pass a secret to `RUN --mount=type=secret`, without putting it in a layer |
| `docker buildx build --cache-to type=registry,ref=REF:cache --cache-from type=registry,ref=REF:cache .` | Share build cache through a registry, for CI |
| `docker buildx prune` | Remove build cache |
| `docker buildx imagetools inspect REF` | Inspect a remote multi-architecture image |

## Registries

| Command | Does |
|---|---|
| `docker login registry.example.com` | Log in; credentials go to a credential helper or `~/.docker/config.json` |
| `docker logout registry.example.com` | Remove stored credentials |
| `docker search nginx` | Search Docker Hub |

In CI, log in with short-lived tokens (`aws ecr get-login-password | docker login --username AWS --password-stdin ...`, `az acr login`), never a personal password.

## Networks

| Command | Does |
|---|---|
| `docker network ls` | Networks |
| `docker network create appnet` | A user-defined bridge network, with DNS between containers by name |
| `docker run --network appnet --name db IMAGE` | Attach a container at start |
| `docker network connect appnet NAME` / `disconnect` | Attach or detach a running container |
| `docker network inspect appnet` | Subnet, gateway, and attached containers with their IPs |
| `docker network prune` | Remove unused networks |

## Volumes

| Command | Does |
|---|---|
| `docker volume ls` | Volumes |
| `docker volume create data` | Create a named volume |
| `docker volume inspect data` | Where it lives on the host, and its driver |
| `docker volume rm data` | Remove (fails if a container uses it) |
| `docker volume prune` | Remove unused anonymous volumes. `-a` includes named ones: **this deletes data** |
| `docker run --rm -v data:/data -v "$PWD:/backup" docker.io/library/alpine:3.22 tar czf /backup/data.tgz -C /data .` | Back up a volume to a file |

## Compose

| Command | Does |
|---|---|
| `docker compose up -d` | Create and start everything in `compose.yaml`, in the background |
| `docker compose up --build --exit-code-from tests` | Rebuild, run, and exit with one service's exit code (for CI) |
| `docker compose ps` | The project's containers |
| `docker compose logs -f api` | One service's logs |
| `docker compose exec api sh` | A shell in a running service |
| `docker compose run --rm api pytest` | A one-off command in a new container for a service |
| `docker compose config` | The final configuration after variables and overrides: check before running |
| `docker compose pull` | Pull newer images for every service |
| `docker compose down` | Stop and remove containers and networks. `-v` also removes volumes |

More in [Compose](04-compose.md).

## System and daemon

| Command | Does |
|---|---|
| `docker version` / `docker info` | Versions, and the daemon's configuration and state |
| `docker system df` | Disk used by images, containers, volumes, and build cache. `-v` per item |
| `docker system prune` | Remove stopped containers, unused networks, dangling images, and build cache. `-a` all unused images; `--volumes` volumes too |
| `docker system events` | Same as `docker events` |
| `docker context ls` / `docker context use NAME` | Which daemon the CLI talks to ([Architecture](02-architecture.md#contexts-which-daemon-the-cli-talks-to)) |
| `sudo systemctl restart docker` | Restart the daemon (with `live-restore`, containers keep running) |
| `journalctl -u docker --since "1 hour ago"` | Daemon logs |

## Options worth knowing for `docker run`

| Option | Does |
|---|---|
| `--user 10001:10001` | Run as this UID and GID |
| `--read-only --tmpfs /tmp` | Read-only root filesystem, with a writable in-memory `/tmp` |
| `--cap-drop ALL --cap-add NET_BIND_SERVICE` | Drop every capability, add back one |
| `--security-opt no-new-privileges` | setuid binaries can't gain privileges |
| `--memory 256m --cpus 0.5 --pids-limit 200` | Resource limits |
| `--health-cmd 'wget -qO- localhost:8080/health' --health-interval 30s` | A health check, shown in `docker ps` |
| `--init` | Run a tiny init as PID 1, which forwards signals and reaps zombie processes |
| `--platform linux/arm64` | Run an image for another architecture (with emulation, if installed) |
| `--log-opt max-size=10m --log-opt max-file=3` | Rotate this container's logs |
| `--entrypoint sh` | Override the image's entrypoint, for debugging |

The [hardening guide](08-hardening.md) explains when to use each security option.

## Next

[Complex commands, broken down](07-complex-commands.md).
