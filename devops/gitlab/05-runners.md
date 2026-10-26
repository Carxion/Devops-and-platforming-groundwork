# Runners

[← GitLab](README.md)

A runner is the program that runs jobs. It polls GitLab for work, runs each job with an **executor** (a container, a VM, a Kubernetes pod, or a shell), and sends back the log and artifacts. This guide covers where runners come from, registering one, the settings that matter, building container images, and keeping runners safe.

## Hosted or self-managed

| | Hosted runners (GitLab.com) | Self-managed runners |
|---|---|---|
| **Who runs them** | GitLab | You, on your machines, VMs, or cluster |
| **Isolation** | A fresh VM per job | Whatever you configure |
| **Cost** | Compute minutes (400 a month on Free, more on paid tiers) | Your infrastructure; no compute minutes |
| **Network** | The internet only | Can reach your private networks |
| **Use when** | You're on GitLab.com and jobs don't need private network access | Self-managed GitLab, private networks, special hardware, or high volume |

On GitLab.com you can use both: hosted runners for most jobs, and a self-managed runner (selected by [tag](#tags)) for jobs that need to reach something private.

## Scopes

| Scope | Available to | Who manages it |
|---|---|---|
| **Instance** | Every project on the instance | Administrators (self-managed only) |
| **Group** | Every project in the group and its subgroups | Group Owners and Maintainers |
| **Project** | One project (or a few, if assigned) | Project Maintainers |

Put runners at the narrowest scope that serves their users. A runner that deploys to production, or that can reach a sensitive network, belongs to one group or project, and should be [protected](#runner-security).

## Executors

| Executor | Runs each job | Use for |
|---|---|---|
| **Docker** | In a new container, on one host | The default choice: clean, isolated, any image |
| **Kubernetes** | In a new pod, in a cluster | Teams already on Kubernetes; scales with the cluster |
| **Docker Autoscaler**, **Instance** | In VMs created on demand from a cloud autoscaling group (AWS, Azure, Google Cloud) | Elastic capacity with VM isolation per job; replaces the deprecated Docker Machine executor |
| **Shell** | Directly on the runner's host, as the runner's user | Rarely: jobs share the host and can leave state behind. Only for trusted jobs on a dedicated host |
| **SSH**, **VirtualBox**, **Parallels**, **Custom** | On a remote host, a local VM, or your own driver | Special cases |

## Registering a runner

Runners register with a **runner authentication token** (it starts with `glrt-`). The older **registration tokens** are deprecated; since GitLab 17.0 an administrator can turn them off, after which registering with one fails with `410 Gone - runner registration disallowed`.

1. **Create the runner in GitLab:** Settings > CI/CD > Runners > New project runner (or the group or Admin equivalent). Choose its tags, whether it runs untagged jobs, and whether it's protected. GitLab shows the authentication token once.
2. **Register it on the machine** with that token:

   ```sh
   gitlab-runner register --non-interactive \
     --url https://gitlab.example.com \
     --token glrt-REDACTED \
     --executor docker \
     --docker-image alpine:3.24
   ```

   Tags, description, and the untagged and protected settings now live in GitLab, not in the `register` command.

3. **Check it's online** in the runners list. A runner shows a green dot once it has polled GitLab.

To automate step 1, create runners with the API (`POST /user/runners`, with a token that has the `create_runner` or `api` scope): the response contains the `glrt-` token. The lab's [lab.sh](lab/lab.sh) registers its two runners this way.

The [GitLab Runner Helm chart](https://docs.gitlab.com/runner/install/kubernetes/) installs a runner with the Kubernetes executor into a cluster; pass it the authentication token as a Kubernetes secret.

## config.toml

Each runner host has a `/etc/gitlab-runner/config.toml` (one file for all the runners registered on it). The settings worth knowing, for the Docker executor:

```toml
concurrent = 4                     # jobs at once across all runners in this file

[[runners]]
  name = "docker"
  url = "https://gitlab.example.com"
  token = "glrt-REDACTED"          # written by register; keep the file readable by root only
  executor = "docker"
  limit = 4                        # jobs at once for this runner
  [runners.docker]
    image = "alpine:3.24"          # the default when a job sets no image
    privileged = false             # keep it false; see "Building container images"
    pull_policy = ["always"]       # the default; with if-not-present, one project could run an image another pulled with its own credentials
    allowed_images = ["registry.example.com/*", "docker.io/library/*", "ghcr.io/astral-sh/*"]
    volumes = ["/cache"]
  [runners.cache]
    Type = "s3"                    # a cache shared by every runner host, instead of one per host
    Shared = true
    [runners.cache.s3]
      ServerAddress = "s3.amazonaws.com"
      BucketName = "example-runner-cache"
      BucketLocation = "us-east-1"
```

Changes are picked up without a restart. `allowed_images` and `allowed_services` restrict what jobs can run, which matters on runners shared between teams.

## Tags

Tags route jobs to runners. A job with `tags: [image-build]` runs only on a runner that has the `image-build` tag; a job without tags runs only on runners set to **run untagged jobs**. A job stays **pending** forever if no online runner matches all its tags ([Troubleshooting](09-troubleshooting.md#a-job-stays-pending)).

Name tags for what a runner can do (`image-build`, `gpu`, `prod-network`), not for the machine it's on, so you can replace machines without editing pipelines.

## Building container images

Building an image inside a job is where runner security is most often given away. The options, from the safest default:

| Approach | Needs on the runner | Trade-off |
|---|---|---|
| **Buildah** (or Podman), as in the [container-image component](examples/components/README.md) | Permission to create a user namespace: on the Docker executor, `security_opt = ["seccomp=unconfined"]` | No daemon and no privileged mode, but a relaxed seccomp profile. Give it its own runner and tag |
| **Hosted runners on GitLab.com** | Nothing | Each job is in its own VM, so Buildah and Docker-in-Docker both work |
| **Docker-in-Docker** (`services: [docker:dind]`) | `privileged = true` | The job is effectively root on the host. Only on dedicated, disposable runners |
| **Mounting the host's Docker socket** | `volumes = ["/var/run/docker.sock:/var/run/docker.sock"]` | Every job controls the host's daemon and can see every other job's containers. Avoid on shared runners |
| Kaniko | — | No longer maintained; GitLab's docs now point to Buildah, Podman, or Docker instead |

Buildah needs a user namespace for each `RUN` step, which Docker's default seccomp profile blocks: without the relaxed profile, the build fails with `Error during unshare(CLONE_NEWUSER): Operation not permitted`. The lab registers a second runner, tagged `image-build`, that only takes tagged jobs and has that one setting:

```sh
gitlab-runner register --non-interactive --url https://gitlab.example.com --token glrt-REDACTED \
  --executor docker --docker-image alpine:3.24 \
  --docker-security-opt seccomp=unconfined
```

Hosts that restrict unprivileged user namespaces themselves (through a sysctl or the distribution's AppArmor policy) can still block it; if the same error remains, check the host's user namespace policy.

## Runner security

- **A job can do anything the runner can.** Assume any code in any branch of any project the runner serves can use the runner's network position, its cloud identity (an instance profile or workload identity), and anything left on the host.
- **Protect deployment runners.** A protected runner only takes jobs from protected branches and tags, so a feature-branch pipeline can't reach it. Combine with protected variables ([Variables](06-variables-secrets-and-cloud-access.md#variable-settings)).
- **Don't give runner hosts standing cloud credentials** beyond what every job on them may use. Prefer per-job [ID tokens](06-variables-secrets-and-cloud-access.md#id-tokens-oidc) and roles that check the project and branch.
- **Separate by trust:** runners for open-source or fork contributions never share hosts with runners that deploy.
- **Keep `privileged = false`** except on dedicated, disposable build runners, and never mount the Docker socket on shared runners.
- **Restrict images** with `allowed_images` on shared runners, and keep the default `pull_policy = ["always"]`: with `if-not-present`, one project can run a private image that another project pulled with its own credentials.
- **Keep runners current:** run a GitLab Runner version that matches your GitLab's major and minor version.
- **Clean up:** containers and volumes from finished jobs, and the build cache, on long-lived hosts (`docker system prune` on a schedule, or ephemeral VMs).

## Next

[Variables, secrets, and cloud access](06-variables-secrets-and-cloud-access.md).
