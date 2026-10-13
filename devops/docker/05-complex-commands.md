# Complex commands, broken down

[← Docker 101](README.md)

Docker's output is designed to be filtered and reshaped: `--filter` selects, `--format` (a Go template) chooses what to print, and `docker inspect` exposes everything as JSON for `jq`. Each command below is broken into its parts. [scripts/docker-audit.sh](scripts/docker-audit.sh) and [scripts/docker-cleanup.sh](scripts/docker-cleanup.sh) combine many of them.

## Go templates in 60 seconds

`--format` takes a Go template. The ones you'll use:

| Template | Means |
|---|---|
| `{{.Names}}` | A field (for `docker ps`, the fields are the column names: `.ID`, `.Image`, `.Status`, `.Ports`...) |
| `{{.State.Status}}` | A nested field (for `docker inspect`, the JSON structure) |
| `{{json .Mounts}}` | Print a value as JSON, to pipe into `jq` |
| `{{range .Mounts}}...{{end}}` | Loop over a list |
| `{{if .State.Running}}up{{else}}down{{end}}` | Conditional |
| `{{or .Config.User "root"}}` | The first non-empty value |
| `{{index .Config.Labels "com.docker.compose.service"}}` | A map key with special characters, and a safe lookup for keys that may be missing |
| `{{"\n"}}`, `table` | A newline; `table` prefix for aligned columns with headers |

Two gotchas from writing the audit script: `len` of a missing list fails (guard it with `if`), and `.State.Health` errors on containers without a health check, while `index .State "Health"` returns nothing. And one `docker inspect` template error fails the whole command, so a script must check its exit status rather than reading partial output.

---

## 1. A readable container list

```sh
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

| Part | Does |
|---|---|
| `--format 'table ...'` | `table` adds a header row and aligns columns |
| `{{.Names}}\t{{.Image}}...` | The columns you want, separated by tabs |

Save it as the default in `~/.docker/config.json`: `{ "psFormat": "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" }`.

## 2. Containers that keep restarting

```sh
docker ps -a --format '{{.Names}} {{.Status}}' | grep -E 'Restarting|Exited \([^0]' ;
docker inspect --format '{{.Name}} restarts={{.RestartCount}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}}' $(docker ps -aq)
```

| Part | Does |
|---|---|
| `grep -E 'Restarting\|Exited \([^0]'` | Status lines saying Restarting, or Exited with a code that doesn't start with 0 |
| `$(docker ps -aq)` | Every container ID (`-q` is IDs only), passed as arguments |
| `{{.RestartCount}}` | How many times Docker restarted it |
| `{{.State.ExitCode}}`, `{{.State.OOMKilled}}` | Why it last stopped: 137 with `OOMKilled=true` means the memory limit was hit |

## 3. Every published port on the host

```sh
docker ps --format '{{.Names}}: {{.Ports}}' | tr ',' '\n' | grep -E '0\.0\.0\.0|\[::\]'
```

| Part | Does |
|---|---|
| `{{.Ports}}` | Comma-separated bindings like `0.0.0.0:8080->80/tcp, [::]:8080->80/tcp` |
| `tr ',' '\n'` | One binding per line |
| `grep -E '0\.0\.0\.0\|\[::\]'` | Only bindings on every interface (IPv4 or IPv6), reachable from outside regardless of the host firewall |

## 4. An image's real configuration

```sh
docker image inspect --format 'user={{.Config.User}} entrypoint={{json .Config.Entrypoint}} cmd={{json .Config.Cmd}} ports={{json .Config.ExposedPorts}}' nginx:1.27
docker image inspect nginx:1.27 | jq '.[0].Config | {User, Entrypoint, Cmd, Env, Healthcheck}'
```

| Part | Does |
|---|---|
| `.Config.User` | Empty means root |
| `{{json ...}}` | Lists and maps printed as JSON instead of Go's `[a b]` form |
| `jq '.[0].Config \| {...}'` | `inspect` returns an array; take the first element's `Config` and pick fields |

## 5. Which images use the most space

```sh
docker images --format '{{.Size}}\t{{.Repository}}:{{.Tag}}' | sort -h -r | head
docker system df -v | sed -n '/Images space usage/,/Containers space usage/p'
```

| Part | Does |
|---|---|
| `sort -h -r` | Sort human-readable sizes (`1.2GB` above `900MB`), largest first |
| `docker system df -v` | Verbose disk use, including how much of each image is shared with others |
| `sed -n '/start/,/end/p'` | Print only the images section |

## 6. The environment and mounts of a running container

```sh
docker inspect web --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -v -iE 'pass|secret|token|key'
docker inspect web --format '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}} (rw={{.RW}}){{println}}{{end}}'
```

| Part | Does |
|---|---|
| `{{range .Config.Env}}{{println .}}{{end}}` | Each `KEY=value` on its own line |
| `grep -v -iE 'pass\|secret\|token\|key'` | Hide likely secrets before you paste the output anywhere (environment variables are visible to anyone who can run `docker inspect`, which is a reason to use secret files instead) |
| `{{.RW}}` | Whether the mount is writable |

## 7. Run a command in every running container

```sh
docker ps --format '{{.Names}}' | xargs -I{} sh -c 'printf "%-30s " {}; docker exec {} cat /etc/os-release 2>/dev/null | grep -m1 ^PRETTY_NAME= || echo "(no /etc/os-release: distroless?)"'
```

| Part | Does |
|---|---|
| `xargs -I{}` | One command per container name |
| `docker exec {} cat /etc/os-release` | What base each container is really running |
| `grep -m1 ^PRETTY_NAME=` | First matching line only |
| `\|\| echo ...` | Distroless and scratch images have no `cat` and no shell |

## 8. Debug a container that has no shell

```sh
docker run --rm -it --pid=container:go-hello --network=container:go-hello nicolaka/netshoot
```

| Part | Does |
|---|---|
| `--pid=container:go-hello` | Share the target's process namespace: `ps` shows its processes, `/proc/1/root` is its filesystem |
| `--network=container:go-hello` | Share its network namespace: `ss -tlnp`, `curl localhost:8080`, `tcpdump` see exactly what it sees |
| `nicolaka/netshoot` | An image full of network and debugging tools |

The target image stays minimal; the tools come from a separate container only while you need them. (`docker debug` in Docker Desktop does the same, and Kubernetes has `kubectl debug` with ephemeral containers; see [devops/kubernetes/OPERATIONS.md](../kubernetes/OPERATIONS.md).)

## 9. Copy files in and out

```sh
docker cp web:/etc/nginx/nginx.conf ./nginx.conf     # out
docker cp ./fixed.conf web:/etc/nginx/conf.d/        # in (lost when the container is recreated: fix the image or mount instead)
docker export web | tar -tv | grep etc/nginx         # list a container's whole filesystem
docker diff web                                      # what changed in its writable layer: A added, C changed, D deleted
```

`docker diff` on a container that should be read-only shows what it's writing and where; that's the list of paths that need a volume or tmpfs before you can turn on `read_only`.

## 10. Follow events while you reproduce a problem

```sh
docker events --filter type=container --filter event=die --filter event=oom --format '{{.Time}} {{.Actor.Attributes.name}} {{.Action}} exit={{.Actor.Attributes.exitCode}}'
```

| Part | Does |
|---|---|
| `docker events` | A live stream of what the daemon does |
| `--filter type=container --filter event=die --filter event=oom` | Only containers dying or hitting out-of-memory. Filters of the same key are ORed, different keys ANDed. |
| `{{.Actor.Attributes.exitCode}}` | The exit code that came with the event |

## Cleanup

```sh
docker system df                                         # what's using space: images, containers, volumes, build cache
docker container prune -f --filter 'until=168h'          # stopped containers older than a week
docker image prune -f                                    # dangling images (untagged leftovers of rebuilds)
docker image prune -a -f --filter 'until=168h'           # every image no container uses, older than a week
docker builder prune -f --filter 'until=168h'            # build cache
docker volume prune -f                                   # unused anonymous volumes (named volumes kept since Docker 23)
docker system prune -f                                   # containers, networks, dangling images, and build cache together
```

| Part | Does |
|---|---|
| `prune` | Remove unused objects of that type. "Unused" means no container references them; running containers are never touched. |
| `-f` | Don't ask for confirmation |
| `--filter 'until=168h'` | Only objects created more than 168 hours ago |
| `-a` | For images: not just dangling ones, but any not used by a container. They're pulled again when needed. |

**Volumes hold data.** `docker volume prune --all` and `docker system prune --volumes` delete named volumes nobody's container is using right now, including the database volume of a stack you stopped yesterday. [docker-cleanup.sh](scripts/docker-cleanup.sh) previews everything first, and touches volumes only with `--volumes`.

Schedule cleanup on build hosts and CI runners, where images and build cache pile up fastest, with a systemd timer ([Writing scripts](../bash/04-scripting.md#scheduling)) running `docker-cleanup.sh --apply`.
