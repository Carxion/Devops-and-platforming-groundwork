# Troubleshooting

[← Docker](README.md)

## Container exits immediately or keeps restarting

```sh
docker ps -a --filter name=app                     # STATUS shows "Exited (1) 3 seconds ago" or "Restarting"
docker logs app --tail 50                          # the application's own error, almost always
docker inspect app --format 'exit={{.State.ExitCode}} oom={{.State.OOMKilled}} error={{.State.Error}}'
docker run --rm -it --entrypoint sh app-image      # start the image with a shell instead of its command
```

| Exit code | Usually means |
|---|---|
| 0 | The command finished. Containers run one process; when it exits, the container stops. A "service" that daemonizes into the background exits at once: run it in the foreground (`nginx -g 'daemon off;'`). |
| 1, 2 | The application failed: read its logs |
| 125 | Docker itself couldn't create the container: bad option, name in use |
| 126 | The command isn't executable: permissions, or a script with Windows line endings (`\r`) |
| 127 | Command not found: wrong path, or a binary for another architecture or libc |
| 137 | Killed with SIGKILL: out of memory (`OOMKilled=true`, raise the limit or fix the leak), or it ignored SIGTERM during `docker stop` ([PID 1 and signals](03-dockerfiles.md#exec-form-and-signals)) |
| 139 | Segmentation fault |
| 143 | Stopped by SIGTERM: a normal `docker stop` |

`exec format error` means the image was built for another CPU architecture (an arm64 image on an amd64 host, or the reverse): build a multi-arch image, or pass `--platform`.

## Can't reach the container

Work from the inside out:

```sh
docker exec app ss -tlnp 2>/dev/null || docker exec app netstat -tlnp   # listening inside? on which address?
docker port app                                                        # what's published
curl -v http://127.0.0.1:8080/                                         # from the host
```

| Symptom | Cause |
|---|---|
| Works from inside the container, not from the host | The app listens on `127.0.0.1` inside the container. It must listen on `0.0.0.0` (the [items-api](examples/items-api/Dockerfile) passes `--host 0.0.0.0` for this reason). |
| Works from the host, not from other machines | Published on `127.0.0.1` (intended?), the cloud security group or NSG, or the host firewall for traffic Docker doesn't manage |
| Reachable from the internet when it shouldn't be | Published on all interfaces; Docker's rules bypass ufw and firewalld ([Networking](05-networking-and-storage.md#published-ports-and-the-host-firewall)) |
| One container can't reach another by name | They're on the default bridge, which has no DNS. Put both on a user-defined network (Compose does this automatically). |
| No DNS or no internet from containers | Check `docker run --rm busybox nslookup example.com`. Corporate DNS or proxies: set `dns` and the proxy in `daemon.json`, or `--dns`. |
| `address already in use` on start | Another process or container has the host port: `ss -tlnp \| grep :8080` |

## Permission denied

| Where | Cause and fix |
|---|---|
| `docker` commands: "permission denied ... docker.sock" | You're not root or in the `docker` group. Use `sudo`, or rootless Docker or Podman. (Adding yourself to the group grants root-equivalent access.) |
| Writing to a bind mount | The container's UID can't write the host directory: `chown` it to that UID, or use a named volume |
| Reading a bind mount on RHEL | SELinux label: add `:Z` or `:z` ([SELinux labels](../podman/06-hardening.md#selinux-labels-and-volumes)) |
| Writing anywhere, with `read_only: true` | Expected. `docker diff` on a writable copy shows which paths it writes; mount a volume or tmpfs there. |
| Binding port 80 as non-root | Ports below 1024 need `NET_BIND_SERVICE`. Listen on 8080 inside and publish `-p 80:8080`. |

## Disk full

```sh
docker system df                  # images, containers, volumes, build cache
docker system df -v | less        # per item
sudo du -sh /var/lib/docker/*     # from the host's side
```

The usual causes: build cache on CI hosts, old images, stopped containers, and container logs without rotation (`/var/lib/docker/containers/*/*-json.log`). [docker-cleanup.sh](scripts/docker-cleanup.sh) previews and removes the first three; set `log-opts` in `daemon.json` ([Basics](01-basics.md#where-things-live)) for the fourth. To move Docker's data to a bigger disk, set `data-root` in `daemon.json` and move `/var/lib/docker` while the daemon is stopped.

## Build problems

| Symptom | Fix |
|---|---|
| Every build reinstalls all dependencies | Layer order: copy the dependency manifest and install before `COPY . .` ([Dockerfiles](03-dockerfiles.md#order-layers-from-least-to-most-frequently-changed)) |
| Build is slow to start, "sending build context" is huge | Add a `.dockerignore` (allowlist), and don't build from your home directory |
| `COPY failed: file not found` | The path is outside the build context, or excluded by `.dockerignore`. Paths are relative to the context, not the Dockerfile. |
| Changes don't show up | A cached layer: `docker build --no-cache`, or check you're running the new tag |
| Works on your machine, not in CI | Different architecture, an unpinned base image that changed, or a file only you have locally. Pin by digest, and build from a clean checkout. |
| `apt-get update` or `dnf` fails in the build | Network or proxy: pass `--build-arg HTTPS_PROXY=...`, or the base image is too old and its repositories moved |

## The daemon

```sh
sudo systemctl status docker
journalctl -u docker --since "1 hour ago"
docker info                       # storage driver, data root, cgroup version, warnings at the bottom
sudo dockerd --validate --config-file /etc/docker/daemon.json   # check daemon.json before restarting
```

A typo in `/etc/docker/daemon.json` stops the daemon from starting at all, and every container with it. Validate first.
