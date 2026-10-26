# CI/CD components

[← GitLab](../../README.md) · [Reusing pipeline code](../../04-reusing-pipeline-code.md#cicd-components)

A component project: reusable pipeline configuration that other projects include by version. Copy this folder into its own GitLab project (for example `platform/ci-components`), tag a release, and other projects use it like this:

```yaml
include:
  - component: $CI_SERVER_FQDN/platform/ci-components/container-image@1.0.0
    inputs:
      name: api
```

## Components

### container-image

Builds a container image with Buildah, scans it with Trivy, and pushes it with Skopeo. No Docker daemon and no privileged mode. The build job does need a runner that lets it create a user namespace (see `build_tags`); the scan and push jobs run anywhere.

| Job | Runs | Does |
|---|---|---|
| `<name>-build` | Every pipeline | Builds the image into an OCI layout directory, kept as an artifact for a day |
| `<name>-scan` | Every pipeline | Scans the image; fails on fixable vulnerabilities at `severity`. The JSON report is kept for 30 days |
| `<name>-push` | Default branch and tags | Pushes the scanned image, tagged with the Git tag or the short commit SHA, and exports `IMAGE_REF` (`repository@sha256:…`) as a dotenv variable for later jobs |

| Input | Default | Meaning |
|---|---|---|
| `name` | `image` | Prefix for the job names, so one pipeline can build several images |
| `context` | `.` | Build context |
| `dockerfile` | `Dockerfile` | Dockerfile path, relative to the project root |
| `image` | `$CI_REGISTRY_IMAGE` | Repository to push to |
| `build_stage`, `scan_stage`, `push_stage` | `build`, `test`, `publish` | Stages for the three jobs; the including pipeline must define them |
| `severity` | `HIGH,CRITICAL` | Severities that fail the scan, when a fix is available |

Requirements: a runner that can pull public images, and a container registry. The push uses the job's own registry credentials (`CI_REGISTRY_USER` and `CI_REGISTRY_PASSWORD`); to push to another registry, override `image` and give the job credentials for it.

## Versioning and releases

- Tag releases with semantic versions (`1.0.0`). The pipeline creates a GitLab release for each one, and, if the project is set as a CI/CD Catalog project, the version appears in the Catalog.
- Consumers pin a version: `@1.0.0` exactly, `@1.0` or `@1` for the latest matching release, or a commit SHA. Exact versions or SHAs are safest for anything that deploys; a partial version picks up changes without review.
- Breaking changes to inputs or job names get a new major version.

## Testing

The project's [.gitlab-ci.yml](.gitlab-ci.yml) includes each component at the commit being tested (`@$CI_COMMIT_SHA`) and builds the image in [tests/container-image/](tests/container-image/), so a change is exercised before it's tagged.
