# Networking and storage

[← Docker](README.md)

## Networks

| Driver | What it is | Use for |
|---|---|---|
| `bridge` (default) | A private network on the host; containers get internal IPs and reach out through NAT | Almost everything on one host |
| User-defined bridge | `docker network create appnet` | **Always prefer it to the default bridge**: containers on it find each other by name through Docker's DNS |
| `host` | The container uses the host's network stack directly, with no isolation | Rarely: some network tools and very high packet rates. It disables port isolation entirely. |
| `none` | No network | Batch jobs that must not reach anything |
| `overlay`, `macvlan` | Multi-host (Swarm) and containers with their own LAN addresses | Specialized cases |

```sh
docker network create appnet
docker run -d --name db --network appnet -e POSTGRES_PASSWORD=example postgres:17
docker run --rm --network appnet postgres:17 pg_isready -h db   # "db" resolves by container name
docker network ls
docker network inspect appnet --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}'
```

Compose creates a network per project automatically, which is why service names (`http://items-api:8080`) work in the [example](examples/compose.yaml).

Containers reach the host itself at `host.docker.internal` on Docker Desktop; on Linux add `--add-host=host.docker.internal:host-gateway`.

### Published ports and the host firewall

`-p 8080:80` makes Docker add NAT and filter rules so traffic to host port 8080 reaches the container. Those rules are processed **before** ufw's and firewalld's own rules, so a port Docker publishes is reachable even when the host firewall says it's closed. This surprises nearly everyone once.

- Publish on loopback (`-p 127.0.0.1:8080:80`) for anything that only a local reverse proxy or SSH tunnel should reach.
- Filter what must be public in the `DOCKER-USER` chain (Docker evaluates it first and never overwrites it), or with the cloud's security groups or NSGs in front of the host.
- Don't publish database ports at all; connect application containers to them over a user-defined network.

## Storage

| Type | Syntax | Lives in | Use for |
|---|---|---|---|
| **Named volume** | `-v pgdata:/var/lib/postgresql/data` | `/var/lib/docker/volumes/` (managed by Docker) | Databases and anything that must persist. Survives `docker rm`; deleted only by `docker volume rm` or `down -v`. |
| **Bind mount** | `-v /srv/app/conf:/etc/app:ro` | Anywhere on the host | Config files from the host, source code in development |
| **tmpfs** | `--tmpfs /tmp:size=64m` | Memory | Scratch space for read-only containers, secrets that must not touch disk |
| Anonymous volume | `-v /data` (no name) | Docker-managed, random name | Rarely what you want; easy to orphan. `docker volume prune` removes unused ones. |

```sh
docker volume create pgdata
docker volume ls
docker volume inspect pgdata --format '{{.Mountpoint}}'
docker run --rm -v pgdata:/data:ro busybox du -sh /data      # look inside a volume without its app
```

The long `--mount` syntax is clearer in scripts: `--mount type=volume,src=pgdata,dst=/var/lib/postgresql/data` or `--mount type=bind,src=/srv/conf,dst=/etc/app,readonly`.

### Permissions on mounts

A container running as UID 10001 can only write to a bind-mounted host directory that UID 10001 can write to. Either `chown 10001:10001 /srv/app/data` on the host, or use a named volume (Docker copies the image's directory ownership into a new empty volume).

On RHEL with SELinux, bind mounts also need a label, or the container gets "permission denied": add `:Z` (private to this container) or `:z` (shared between containers) to the volume flag. See [SELinux labels](../podman/06-hardening.md#selinux-labels-and-volumes).

### Backing up a volume

Volumes aren't backed up by anything automatically. Stop or quiesce the application first (or use the database's own dump tool, which is better for databases), then:

```sh
docker run --rm -v pgdata:/data:ro -v "$PWD:/backup" busybox tar -czf /backup/pgdata-$(date +%F).tar.gz -C /data .
# Restore into a new, empty volume
docker run --rm -v pgdata-restored:/data -v "$PWD:/backup" busybox tar -xzf /backup/pgdata-2026-10-13.tar.gz -C /data
```

| Part | Does |
|---|---|
| `-v pgdata:/data:ro` | Mount the volume read-only into a throwaway container |
| `-v "$PWD:/backup"` | Mount the current host directory to write the archive to |
| `busybox tar -czf ... -C /data .` | Archive the volume's contents (relative paths, from inside `/data`) |

For databases, prefer `docker exec db pg_dump -U postgres app | gzip > app-$(date +%F).sql.gz`: a consistent dump, without stopping anything.
