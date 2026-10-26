# Podman command reference

[← Podman](README.md)

Most Podman commands match Docker's exactly; the [Docker command reference](../docker/06-command-reference.md) applies with `podman` in place of `docker`. This page lists the everyday commands, then what Podman adds. `podman <command> --help` and `man podman-<command>` cover every option.

## Same as Docker

| Task | Command |
|---|---|
| Run a container | `podman run -d --name web -p 8080:80 docker.io/library/nginx:1.27` |
| List containers | `podman ps` (`-a` all, `-q` IDs only, `--pod` with their pod) |
| Logs | `podman logs -f --tail 100 web` |
| Shell inside | `podman exec -it web sh` |
| Inspect | `podman inspect web`, `podman inspect --format '{{.State.Status}}' web` |
| Stop, start, remove | `podman stop web`, `podman start web`, `podman rm -f web` |
| Resource use | `podman stats --no-stream`, `podman top web` |
| Copy files | `podman cp web:/etc/nginx/nginx.conf ./` |
| Pull, list, remove images | `podman pull`, `podman images`, `podman rmi` |
| Build | `podman build -t app:1.0 .` (`--target`, `--platform`, `--secret` as in Docker) |
| Tag and push | `podman tag app:1.0 registry.example.com/team/app:1.0`, `podman push ...` |
| Log in | `podman login registry.example.com` (credentials in `${XDG_RUNTIME_DIR}/containers/auth.json`) |
| Networks | `podman network create appnet`, `podman network ls`, `podman network inspect appnet` |
| Volumes | `podman volume create data`, `podman volume ls`, `podman volume inspect data` |
| Clean up | `podman system prune` (`-a` all unused images, `--volumes` volumes too), `podman system df` |
| Events | `podman events --since 10m` |
| Save and load | `podman save -o app.tar app:1.0`, `podman load -i app.tar` |

## What Podman adds

### Rootless and user namespaces

| Command | Does |
|---|---|
| `podman unshare cat /proc/self/uid_map` | Run a command inside your user namespace: shows how your UIDs map |
| `podman unshare chown 1001:1001 ./data` | Change ownership as the container will see it, for a directory you'll mount |
| `podman run --userns keep-id ...` | Your own UID and GID inside the container, so files in mounted directories keep your ownership |
| `podman run --userns auto ...` | A fresh, unique UID range for this container (root Podman), isolating containers from each other |
| `podman info --format '{{.Host.Security.Rootless}}'` | Whether this Podman is rootless |

### Pods

| Command | Does |
|---|---|
| `podman pod create --name app -p 8080:80` | A pod: containers in it share a network namespace (and the published ports) |
| `podman run -d --pod app --name web IMAGE` | Start a container in the pod |
| `podman pod ps` | Pods and their status |
| `podman pod stop app`, `podman pod rm -f app` | Stop or remove the pod and every container in it |

### Kubernetes YAML

| Command | Does |
|---|---|
| `podman kube generate app > app.yaml` | Write a Kubernetes Pod manifest from a running pod or container |
| `podman kube play app.yaml` | Run Pods, Deployments, and ConfigMaps from Kubernetes YAML |
| `podman kube down app.yaml` | Stop and remove what `kube play` started |

More in [Pods and Kubernetes YAML](04-pods-and-kubernetes.md).

### systemd

| Command | Does |
|---|---|
| `podman auto-update --dry-run` | Which containers have a newer image for their tag (with `AutoUpdate=registry` in Quadlet) |
| `podman auto-update` | Pull newer images and restart those containers, rolling back if they fail to start |
| `/usr/libexec/podman/quadlet -dryrun` | Show the systemd services Quadlet would generate from the unit files, and any errors |
| `podman generate systemd --new --name web` | Older: write a systemd unit for a container. Deprecated in favor of Quadlet |

More in [systemd and Quadlet](05-systemd-and-quadlet.md).

### Images and storage

| Command | Does |
|---|---|
| `podman image tree IMAGE` | The image's layers as a tree |
| `podman image trust show` | The signature policy in effect (`policy.json`) |
| `podman image scp IMAGE root@localhost::` | Copy an image between users' stores (here, from your user to root's), or to another host |
| `podman system reset` | Delete **every** container, image, volume, and network for this user: a clean start |
| `podman system migrate` | Restart containers with a new runtime or configuration after an upgrade |

### Checkpoint and restore

| Command | Does |
|---|---|
| `sudo podman container checkpoint web` | Save a running container's memory and state to disk (with CRIU, rootful) |
| `sudo podman container restore web` | Start it again from where it was |

### The Docker-compatible API

| Command | Does |
|---|---|
| `systemctl --user enable --now podman.socket` | Start the API socket on demand, for your user |
| `podman system service --time 0` | Run the API service in the foreground (for testing) |
| `podman system connection list` | Remote Podman hosts this CLI can talk to (like Docker contexts) |
| `podman system connection add build ssh://deploy@203.0.113.10/run/user/1000/podman/podman.sock` | Add one, over SSH |
| `podman --connection build ps` | Run a command against it |

### Podman machine (macOS and Windows)

| Command | Does |
|---|---|
| `podman machine init` | Create the Linux VM containers run in |
| `podman machine start` / `stop` | Start or stop it |
| `podman machine ssh` | A shell in the VM |
| `podman machine set --rootful` | Run containers as root in the VM (for software that needs it) |

## Next

[Pods and Kubernetes YAML](04-pods-and-kubernetes.md).
