# GitLab 101

[← GitLab](README.md)

GitLab is one application for the whole delivery path: Git repositories, merge requests and code review, CI/CD, a container and package registry, environments, issues, and security scanning. This guide covers how it's organized, who can do what, how people and machines authenticate, and the settings to get right on a new project. [Git basics](../../software/git/01-basics.md) covers Git itself.

## Offerings and tiers

| Offering | Is | Choose it when |
|---|---|---|
| **GitLab.com** | GitLab's multi-tenant SaaS | You don't want to run GitLab, and your data can live in GitLab's cloud |
| **GitLab Self-Managed** | You install and run it (Linux package, Helm chart, or container) | You need it on your own network, in a restricted environment, or under your own upgrade schedule |
| **GitLab Dedicated** | A single-tenant instance that GitLab runs for you | You need isolation and data residency without running it yourself |

Each comes in **Free**, **Premium**, or **Ultimate**. Free covers repositories, merge requests, CI/CD, runners, the registry, environments, and most scanners. Premium adds controls most organizations want for production: required approvals, code owner approval, protected environments with deployment approvals, external secrets integrations, and merge trains. Ultimate adds the security dashboards, vulnerability management, and policies. The guides note when something needs a paid tier.

## Groups, subgroups, and projects

```text
example-org/                      group: members, settings, runners, CI/CD variables
├── platform/                     subgroup: inherits from example-org, can add its own
│   ├── ci-components             project: a repository, its pipelines, registry, issues
│   └── infra-network
└── apps/
    ├── items-api
    └── web
```

- A **project** holds one repository and everything around it: pipelines, the container registry, environments, issues, and settings.
- A **group** holds projects and subgroups. Members, CI/CD variables, runners, and many settings defined on a group apply to everything below it. Put shared things as high as they apply and no higher.
- The **path** (`example-org/platform/ci-components`) is the project's address in URLs, `include:` and `component:` references, and the `sub` claim of [ID tokens](06-variables-secrets-and-cloud-access.md#id-tokens-oidc). Renaming or moving a project changes it, which breaks anything that matched the old path.

## Roles

Each member gets one role per group or project. The roles that matter most for CI/CD:

| Role | Can, for CI/CD purposes |
|---|---|
| Guest | View some project information; private repositories are hidden |
| Planner | Plan work (issues, epics, boards), with no code access |
| Reporter | Read the code, see pipelines and job logs, download artifacts |
| **Developer** | Push to unprotected branches, open merge requests, run pipelines, retry and cancel jobs, use the project's non-protected CI/CD variables in their jobs |
| **Maintainer** | Everything a Developer can, plus push to protected branches by default, change CI/CD settings and variables, manage runners and protected branches |
| Owner | Everything, including deleting the project and managing members at the top |

Two points are worth stating plainly:

- **A Developer can run any code on your runners** by pushing a branch with a changed `.gitlab-ci.yml`, and that code sees every unprotected variable. Treat Developer as trusted with the pipeline's unprotected credentials, and keep production credentials protected ([Pipeline security](08-pipeline-security.md)).
- Give the least role that works, at the lowest level that works. Most engineers need Developer on their own projects and Reporter elsewhere.

## Tokens and keys

| Credential | For | Notes |
|---|---|---|
| **SSH key** | A person's Git over SSH | Add to your user profile. Prefer ed25519. |
| **Personal access token** | A person's API and Git over HTTPS, and `glab` | Pick the narrowest scopes (`read_api` before `api`), and always set an expiry |
| **Project or group access token** | Automation that needs API access to one project or group | A bot user with its own role; doesn't depend on any one person staying |
| **Deploy token** | Read-only (or registry-push) access to one project's repository, registry, or packages | For servers and clusters that pull code or images |
| **Deploy key** | Read-only (optionally write) SSH access to one repository | For a server that clones one repository |
| **Job token** (`CI_JOB_TOKEN`) | A running job's own access: clone, registry, packages, some API calls | Created per job, gone when the job ends. Prefer it to any stored token ([details](06-variables-secrets-and-cloud-access.md#the-job-token)) |

Don't use personal access tokens for automation: they act as you, with your whole role everywhere, and break when you leave.

## Merge requests

A merge request (MR) proposes merging one branch into another, usually a short-lived feature branch into the default branch. It's where review, discussion, and pipeline results meet.

- **Open it early, as a draft,** so the pipeline runs and reviewers can see direction before the work is finished. Mark it ready when it is.
- **The MR pipeline** runs on each push to the source branch ([merge request pipelines](03-rules-and-pipeline-types.md#merge-request-pipelines-without-duplicates)). Its test results, coverage, code quality, and security findings appear in the MR.
- **Approvals:** in Free, any Developer can approve, but approvals are optional: they don't prevent merging. Premium adds required approval rules (number and who) and code owner approval through a `CODEOWNERS` file.
- **Merge checks** under Settings > Merge requests: require a passing pipeline, and all threads resolved. Both work in Free.
- **Squash or not** is a team choice; whatever you pick, make the commit that lands on the default branch describe the change. [Code review](../../software/git/05-code-review.md) covers review practice.

## Protected branches and tags

The default branch is **fully protected** by default: Developers can't push to it, Maintainers can, and nobody can force push. For a branch that deploys, tighten that:

| Setting | Recommended for the default branch |
|---|---|
| Allowed to merge | Maintainers (or Developers + Maintainers, if approvals are required and enforced) |
| Allowed to push and merge | **No one**: every change arrives through a merge request |
| Allowed to force push | Off |
| Code owner approval | On, if you're on Premium and have a `CODEOWNERS` file |

Protect release tags too (Settings > Repository > Protected tags, for example `v*`), so only Maintainers can create the tags that publish releases.

Protection does more than stop pushes. **Protected CI/CD variables and protected runners are only available to pipelines on protected branches and tags**, which is how production credentials stay out of feature-branch pipelines ([Variables](06-variables-secrets-and-cloud-access.md#variable-settings)).

## Day-one settings for a project

- [ ] Default branch `main`, protected with nobody allowed to push directly.
- [ ] Settings > Merge requests: pipelines must succeed, all threads must be resolved, and (Premium) at least one required approval.
- [ ] Settings > CI/CD > General pipelines: a sensible job timeout (the default is 60 minutes), and pipelines visible only to project members on private projects.
- [ ] Settings > CI/CD > Job token permissions: only the projects that need to call into this one are on the allowlist.
- [ ] Settings > CI/CD > Variables: none yet. Add them when a job needs one, protected and masked unless there's a reason not to.
- [ ] Settings > Repository > Protected tags: release tags protected.
- [ ] Settings > Packages and registries > Cleanup policies: a container registry cleanup policy, so untagged and old images don't accumulate forever.
- [ ] A `.gitlab-ci.yml` with at least lint and test jobs, from the [examples](examples/README.md).

## The glab CLI

`glab` is GitLab's command-line tool. Authenticate once with `glab auth login` (it can store a token, or use the OAuth flow on GitLab.com), then from inside a clone:

| Command | Does |
|---|---|
| `glab mr create --fill --draft` | Open a draft merge request from the current branch, with the commit messages as the description |
| `glab mr list`, `glab mr view`, `glab mr checkout 42` | Find, read, and check out merge requests |
| `glab ci status` | The current branch's latest pipeline, job by job |
| `glab ci view` | An interactive pipeline view: watch, retry, cancel, and trace jobs |
| `glab ci trace <job>` | Follow a job's log as it runs |
| `glab ci lint` | Validate `.gitlab-ci.yml` with the GitLab instance's own linter; add `--dry-run --ref main` to simulate a pipeline |
| `glab ci run --branch main` | Start a pipeline |
| `glab api projects/:id/pipelines` | Any REST API call, authenticated as you |

## Coming from GitHub

| GitHub | GitLab |
|---|---|
| Organization | Group (with subgroups) |
| Repository | Project |
| Pull request | Merge request |
| Actions workflow (`.github/workflows/*.yml`) | Pipeline (one `.gitlab-ci.yml`, which can include others) |
| Job, step | Job, script line |
| Reusable workflow, composite action | `include`, CI/CD component |
| Marketplace | CI/CD Catalog |
| Secrets and variables | CI/CD variables (masked, protected) |
| `GITHUB_TOKEN` | `CI_JOB_TOKEN` |
| OIDC (`id-token: write`) | `id_tokens:` on the job |
| Environment protection rules | Protected environments and deployment approvals (Premium) |
| Branch protection rules, rulesets | Protected branches, push rules (Premium) |
| Self-hosted runner | Self-managed runner |
| `CODEOWNERS` | `CODEOWNERS` (enforced approval needs Premium) |

## Next

[CI/CD basics](02-ci-cd-basics.md).
