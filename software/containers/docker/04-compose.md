# Compose

[← Docker](README.md)

Docker Compose describes a multi-container application in one YAML file: services, networks, volumes, and how they start. It's ideal for local development, CI test environments, and single-host deployments. For running across many hosts, use an orchestrator (Kubernetes, ECS, Azure Container Apps) instead.

Compose v2 is the `docker compose` plugin (with a space). The old `docker-compose` Python tool is retired. The file is `compose.yaml`, and the `version:` key at the top is obsolete and ignored.

## The commands

```sh
docker compose up -d                 # create and start everything, in the background
docker compose up -d --build         # rebuild images first
docker compose ps                    # services, state, health, ports
docker compose logs -f api           # follow one service's logs
docker compose exec api sh           # shell in a running service
docker compose run --rm api pytest   # one-off command in a new container of a service
docker compose restart api
docker compose pull                  # update images
docker compose config                # the fully resolved file, after variables, anchors, and overrides
docker compose down                  # stop and remove containers and networks
docker compose down -v               # also delete volumes, and their data
docker compose -f other.yaml -p myproj up -d   # a different file, and a different project name
```

The project name (the directory name by default, or `name:` in the file) prefixes everything Compose creates, so two copies of the same file don't collide.

## The example, explained

[examples/compose.yaml](examples/compose.yaml) runs the two sample services and a test. The parts worth copying:

### Shared settings with YAML anchors

```yaml
x-hardened: &hardened          # x- keys are ignored by Compose; &hardened names this block
  read_only: true
  cap_drop: [ALL]
  security_opt: ["no-new-privileges:true"]
  deploy:
    resources:
      limits: { cpus: "0.50", memory: 128M }
  logging:
    driver: json-file
    options: { max-size: "10m", max-file: "3" }

services:
  items-api:
    <<: *hardened              # merge the block in here
```

Every service gets the same hardening, defined once. `docker compose config` shows the merged result.

### Startup order that actually waits

```yaml
  smoke-test:
    depends_on:
      items-api:
        condition: service_healthy
```

Plain `depends_on: [items-api]` only waits for the container to *start*, not for the application inside to be ready. `condition: service_healthy` waits for the health check to pass. Other conditions: `service_started`, and `service_completed_successfully` (for a migration job that must finish first).

### A file that's also a test

```sh
docker compose -f software/containers/docker/examples/compose.yaml up --build --exit-code-from smoke-test
```

`--exit-code-from smoke-test` stops everything when that service exits and returns its exit code, so CI can run the whole stack and fail on the test's result. That's how to check the examples, locally or in your own pipeline.

### Ports on loopback

```yaml
    ports:
      - "127.0.0.1:8080:8080"
```

`"8080:8080"` publishes on every interface, which on a server means the internet. Docker inserts its own firewall rules for published ports, which **bypass ufw and firewalld rules** on the host ([Networking](05-networking-and-storage.md#published-ports-and-the-host-firewall)). Bind to `127.0.0.1` unless the port must be public, and put a reverse proxy in front if it must.

## Variables and environments

```yaml
services:
  api:
    image: "registry.example.com/api:${API_TAG:-latest}"   # from the shell or .env; default after :-
    env_file: [api.env]                                    # variables for the container
    environment:
      LOG_LEVEL: ${LOG_LEVEL:?set LOG_LEVEL}               # :? fails with a message if unset
```

Compose reads a `.env` file next to `compose.yaml` for **substitution in the file**. `env_file:` sets variables **inside a container**. They're different things that are easy to confuse. Keep secrets out of both in Git: use `secrets:` (mounted as files under `/run/secrets/`) or the platform's secret store.

### Overrides

`compose.override.yaml` is merged automatically on top of `compose.yaml`: put development-only settings there (bind-mounted source, debug ports). For other environments, name the files explicitly:

```sh
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

### Profiles

```yaml
  traffic:
    profiles: ["traffic"]       # only started when the profile is active
```

```sh
docker compose --profile traffic up -d
```

The [observability lab](../../../devops/observability/local-stack/compose.yaml) uses a profile for its optional traffic generator.

## Development workflow

```yaml
services:
  api:
    build: .
    develop:
      watch:
        - action: sync           # copy changed source into the running container
          path: ./src
          target: /app/src
        - action: rebuild        # rebuild the image when dependencies change
          path: requirements.txt
```

```sh
docker compose watch
```

## When Compose is enough for production

On a single host with modest needs, Compose with `restart: unless-stopped` is a legitimate deployment: simple, understandable, and easy to recover. Add log rotation (as in the example), resource limits, health checks, a reverse proxy for TLS, backups of the volumes, and a systemd unit or `restart:` policy so it comes back after a reboot. Outgrow it when you need more than one host, rolling updates without downtime, or autoscaling.
