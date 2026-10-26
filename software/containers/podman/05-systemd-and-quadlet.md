# systemd and Quadlet

[← Podman](README.md)

Docker restarts containers at boot through its daemon. Podman has no daemon, so it hands that job to systemd, which already starts, restarts, orders, and logs every other service on the host. **Quadlet** is how you describe a container for systemd: a short unit file that systemd turns into a full service (Podman 4.4 and later; RHEL 9.2 and later).

## A container as a service

`/etc/containers/systemd/items-api.container` (or `~/.config/containers/systemd/` for a rootless user):

```ini
[Unit]
Description=Items API
After=network-online.target

[Container]
# A tag, not a digest: AutoUpdate (below) follows the tag. Pin by digest instead if you don't use it.
Image=registry.example.com/team/items-api:1.0
ContainerName=items-api
PublishPort=127.0.0.1:8080:8080
User=10001
ReadOnly=true
DropCapability=ALL
NoNewPrivileges=true
Environment=LOG_LEVEL=info
Volume=items-data.volume:/data:Z
# Healthy when the port accepts connections (an HTTP check would need a URL that returns 2xx).
HealthCmd=python -c "import socket; socket.create_connection(('127.0.0.1', 8080), 2)"
# Pull a newer image for this tag automatically (with podman-auto-update.timer)
AutoUpdate=registry

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target default.target
```

And the volume it uses, `/etc/containers/systemd/items-data.volume`:

```ini
[Volume]
VolumeName=items-data
```

```sh
sudo systemctl daemon-reload                 # generates items-api.service from the .container file
sudo systemctl start items-api
systemctl status items-api
journalctl -u items-api -f                   # container logs, in the journal
sudo systemctl enable --now podman-auto-update.timer   # optional: daily image updates with rollback on failure
```

There's no `systemctl enable` for the container itself: the `[Install]` section in the Quadlet file does it when the service is generated. To check a unit before reloading, run the generator by hand: `/usr/libexec/podman/quadlet -dryrun` (or `-user -dryrun` for rootless units) prints the services it would create, and any errors.

## The unit types

| File | Creates | Typical keys |
|---|---|---|
| `.container` | A container | `Image`, `PublishPort`, `Volume`, `Network`, `Environment`, `Secret`, `User`, `ReadOnly`, `DropCapability`, `HealthCmd`, `AutoUpdate` |
| `.volume` | A named volume | `VolumeName`, `Driver` |
| `.network` | A network | `NetworkName`, `Subnet`, `Internal` |
| `.pod` | A pod; containers join it with `Pod=name.pod` | `PodName`, `PublishPort` |
| `.kube` | Everything in a Kubernetes YAML file (`podman kube play`) | `Yaml`, `PublishPort` |
| `.image` | A pulled image, so containers can depend on it | `Image` |
| `.build` | An image built from a Dockerfile | `ImageTag`, `File`, `SetWorkingDirectory` |

References between units use the file name (`Volume=items-data.volume:/data`, `Network=app.network`), and Quadlet adds the systemd dependencies so they start in the right order.

## Rootless services

For a container that runs as an ordinary user at boot:

```sh
sudo loginctl enable-linger deploy               # let deploy's services run without a login session
# as deploy, put the unit in ~/.config/containers/systemd/, then:
systemctl --user daemon-reload
systemctl --user start items-api
journalctl --user -u items-api -f
```

Without lingering, the user's services stop when they log out, and don't start at boot.

## Automatic updates

With `AutoUpdate=registry`, `podman auto-update` checks the registry for a newer image behind the container's tag, pulls it, restarts the service, and **rolls back** to the previous image if the restarted service fails to start. The `podman-auto-update.timer` runs it daily.

```sh
podman auto-update --dry-run                     # which containers would update
sudo systemctl list-timers podman-auto-update.timer
```

Use it for services where following a tag is acceptable (internal tools, a single host). For production fleets, deploy explicit digests through a pipeline instead, so every change is reviewed and recorded.

## Secrets

```sh
printf '%s' "$DB_PASSWORD" | podman secret create db-password -   # stored by Podman, not in the unit file
```

```ini
[Container]
Secret=db-password,type=mount,target=/run/secrets/db-password,mode=0400
```

The secret is mounted as a file in the container, not passed as an environment variable, so it doesn't appear in `podman inspect`.

## When to use Quadlet

On a single RHEL host, Quadlet is the supported, systemd-native replacement for `docker run --restart` and simple Compose deployments: services start at boot in dependency order, logs go to the journal, and failures restart like any other service. For several hosts, or anything that needs scheduling and self-healing across machines, use an orchestrator ([Kubernetes](../../../devops/kubernetes/README.md)).

## Next

[Hardening](06-hardening.md).
