# Pipeline security

[← GitLab](README.md)

A pipeline is code that runs with credentials. Anyone who can change what a pipeline runs (its `.gitlab-ci.yml`, an included file, a component, an image, a dependency) can use whatever that pipeline can reach. This guide covers who can do what, a hardening checklist, GitLab's security scanners, and pinning what pipelines pull in. The [security architecture guide](../../architect/04-security-architecture.md) covers the wider picture.

## Who can run what

| Who | Can | Limited by |
|---|---|---|
| A **Developer** in the project | Push a branch with any `.gitlab-ci.yml` and run it, with every **unprotected** variable, on every runner that takes the project's jobs | Protected variables, protected runners, ID-token trust scoped to protected branches |
| A **Maintainer** | The same on protected branches, and change CI/CD settings and variables | Protected environments and approvals (Premium); audit events |
| Someone who can push to an **included project or component** | Change the jobs of every pipeline that includes it, within the pinned version range | Pinning to tags or SHAs; protecting that project's tags |
| The publisher of an **image or tool** a job uses | Run code in the job, with the job's variables | Pinning by digest; trusted registries; `allowed_images` on runners |
| A **fork contributor** | Run pipelines in their fork, with their own runners and variables | A parent-project member choosing to run their MR pipeline in the parent project |

The two controls that matter most are **protected branches** (who can change what `main` runs) and **protection on everything that deploys** (variables, runners, environments, and cloud roles that only trust protected refs).

## Hardening checklist

- [ ] The default branch and release tags are protected, nobody can push to `main` directly, and merging needs a passing pipeline (and, on Premium, an approval).
- [ ] Every credential is a **protected, masked** variable, scoped to an environment where it differs per environment. Better: no stored cloud credentials at all, only [ID tokens](06-variables-secrets-and-cloud-access.md#id-tokens-oidc).
- [ ] Cloud roles trust the project's protected branch for anything that changes infrastructure, and only read access for other branches ([gitlab-oidc](../terraform/aws/gitlab-oidc/)).
- [ ] Deployment runners are **protected** and serve only the projects that deploy through them; build runners don't run privileged, and nothing mounts the Docker socket ([Runner security](05-runners.md#runner-security)).
- [ ] Production deploys are manual or (Premium) behind a protected environment with approvals.
- [ ] The job token allowlist lists only the projects that need access ([job token](06-variables-secrets-and-cloud-access.md#the-job-token)).
- [ ] Images are pinned by digest in anything that deploys; components and project includes are pinned to versions or SHAs; remote includes have `integrity`.
- [ ] Artifacts that can contain secrets (plans, generated configs) use `artifacts:access: developer` and short `expire_in`.
- [ ] Nobody sets `CI_DEBUG_TRACE` on jobs with secrets.
- [ ] The secret detection scanner runs on every pipeline, and a leaked secret is rotated, not just deleted from history.
- [ ] Changes to `.gitlab-ci.yml`, included files, and components get the same review as application code. On Premium, a `CODEOWNERS` entry for them makes that enforceable.

## Security scanning

GitLab ships scanners as CI templates (and as components for some). Each runs as a job and writes a report.

| Scanner | Finds | Include | Tier |
|---|---|---|---|
| SAST | Insecure patterns in source code | `Jobs/SAST.gitlab-ci.yml` | Free |
| Secret detection | Credentials committed to the repository | `Jobs/Secret-Detection.gitlab-ci.yml` | Free |
| IaC scanning | Misconfigurations in Terraform, Kubernetes manifests, Dockerfiles, CloudFormation | `Jobs/SAST-IaC.gitlab-ci.yml` | Free |
| Container scanning | Vulnerable packages in an image | `Jobs/Container-Scanning.gitlab-ci.yml` | Free |
| Dependency scanning | Vulnerable dependencies, from lock files | `Jobs/Dependency-Scanning.gitlab-ci.yml` | Ultimate |
| DAST | Vulnerabilities in a running web application | `Security/DAST.gitlab-ci.yml` | Ultimate |

On Free, the scanners run and their reports are job artifacts you can download and act on. Ultimate adds the findings in the merge request, the vulnerability report, and policies that make scans mandatory across projects.

```yaml
# .gitlab-ci.yml
stages: [test]

include:
  - template: Jobs/SAST.gitlab-ci.yml
  - template: Jobs/Secret-Detection.gitlab-ci.yml
  - template: Jobs/SAST-IaC.gitlab-ci.yml

variables:
  # Without this, the stable templates skip merge request pipelines and run
  # only in branch pipelines.
  AST_ENABLE_MR_PIPELINES: "true"
```

Two details from running them:

- **The stable templates only run in merge request pipelines when `AST_ENABLE_MR_PIPELINES` is `"true"`.** With the [duplicate-avoiding workflow](03-rules-and-pipeline-types.md#merge-request-pipelines-without-duplicates), MRs only get MR pipelines, so without it the scanners silently never run on merge requests. The `.latest` templates set it, but also carry changes that aren't in the stable ones yet. The lab check caught this in the Terraform example.
- **The scanner jobs are `allow_failure: true`** and don't fail the pipeline on findings. To gate on findings on Free, add a job that reads the report (for example with `jq` on `gl-sast-report.json`) and fails above a severity. The [container-image component](examples/components/README.md) does the same for images with Trivy, failing on fixable HIGH and CRITICAL vulnerabilities before anything is pushed. It caught a real one while this guide was written: the Go image's pinned build stage had a Go release with a fixed HIGH vulnerability in `crypto/x509`, and the push was blocked until the base image was updated.

## Pin what pipelines pull in

| What | Pin to | Why |
|---|---|---|
| Job images | A version tag for checks; a digest (`image@sha256:...`) for anything that builds or deploys | A tag can be moved to a different image; a digest can't |
| Base images in Dockerfiles | A digest, with the tag alongside for readability | Reproducible builds, and a deliberate change when the base updates |
| Components | An exact version (`@1.2.0`) or a SHA for deploying pipelines | A partial version (`@1`) runs new code without a change in your project |
| `include: project` | A `ref` that's a protected tag or a SHA | Without `ref`, the other project's default branch at pipeline creation |
| `include: remote` | `integrity: sha256-...` | The URL's content can change at any time |
| Tools installed in jobs | Exact versions (`go run tool@v1.13.0`, `pip install x==1.2.3`) | The same reasons |

Pinning only helps if the pins move: let a tool like Renovate (which understands `.gitlab-ci.yml`, Dockerfiles, and lock files) open merge requests for updates, so they arrive reviewed and tested, not all at once during an incident.

## Next

[Troubleshooting](09-troubleshooting.md).
