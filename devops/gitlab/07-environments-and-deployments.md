# Environments and deployments

[← GitLab](README.md)

A job that declares an `environment` is a **deployment**: GitLab records what was deployed where, when, and by whom, shows it on the environment's page, and lets you deploy an earlier version again. This guide covers environments, the gates you can put in front of them in each tier, keeping deployments from overlapping, review apps, rollback, and the [Terraform example](examples/terraform/.gitlab-ci.yml) walked through.

## Environments

```yaml
# .gitlab-ci.yml
stages: [build, deploy]

build:
  stage: build
  script: [echo "build $CI_COMMIT_SHORT_SHA"]

deploy-staging:
  stage: deploy
  script: [echo "deploy to staging"]
  environment:
    name: staging
    url: https://staging.example.com
    deployment_tier: staging
  resource_group: staging          # one deployment to staging at a time
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy-production:
  stage: deploy
  needs: [deploy-staging]
  script: [echo "deploy to production"]
  environment:
    name: production
    url: https://www.example.com
    deployment_tier: production
  resource_group: production
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual                 # the pipeline waits here until someone deploys
```

| Key | Does |
|---|---|
| `name` | The environment. Created on the first deployment. Can use variables: `review/$CI_COMMIT_REF_SLUG` |
| `url` | A link from the MR and the environments page to the running deployment |
| `deployment_tier` | `production`, `staging`, `testing`, `development`, or `other`. Used by protected environments, DORA metrics, and the `deployment_tier` claim in ID tokens. GitLab guesses from the name if not set; set it |
| `action` | `start` (default), `prepare`, `verify`, `access`, or `stop`: what the job does to the environment. Only `start` records a deployment |
| `on_stop`, `auto_stop_in` | The job that tears the environment down, and when to run it automatically |

Deploy the same artifact everywhere. Build once, then promote that exact build (an image by digest, a saved plan) from environment to environment, as the component's `IMAGE_REF` and the Terraform example's saved plan do. Rebuilding per environment means production runs something that was never tested.

## Deployment gates

What can stand between a merged change and production, by tier:

| Gate | Tier | Stops |
|---|---|---|
| **Protected branch:** deploy jobs only run from `main` or release tags | Free | Deploys from unreviewed branches |
| **Protected variables:** production credentials only exist in protected-branch pipelines | Free | Feature-branch pipelines reaching production at all |
| **Manual job** (`when: manual` in `rules`) | Free | Deploys nobody chose to start. Anyone who can merge into the branch can start it |
| **Protected environment:** only named users, groups, or roles can deploy to it | Premium | Deploys by people who aren't authorized for that environment, even from `main` |
| **Deployment approvals:** a deployment waits for a number of approvals from named people | Premium | Unreviewed deploys; separates "who wrote it" from "who approved releasing it" |
| **Protected runners** that only take protected-branch jobs and are the only ones on the deployment network | Free | Any other pipeline reaching the environment's network |

A sensible default on Free: deploy jobs that run only from the protected default branch, with credentials in protected variables (or, better, roles that only trust that branch's ID token), and a manual job for production. On Premium, add a protected production environment with one required approval.

## One deployment at a time

Two pipelines deploying to the same environment at once can interleave and leave it in a state neither intended. `resource_group: <name>` makes jobs with the same resource group run one at a time, across all pipelines in the project. Give each environment its own (`resource_group: production`). The Terraform example uses one for both `plan` and `apply`, so a plan can't read state while an apply is writing it.

By default, waiting jobs run in no particular order; a resource group's process mode, set through the API, can make them run oldest first or newest first.

## Review apps

A **review app** is a short-lived environment per merge request, so reviewers can see the change running:

```yaml
# .gitlab-ci.yml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH

stages: [deploy]

review:
  stage: deploy
  script: [echo "deploy review app for !$CI_MERGE_REQUEST_IID"]
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_COMMIT_REF_SLUG.review.example.com
    deployment_tier: development
    on_stop: stop-review
    auto_stop_in: 3 days           # torn down even if nobody stops it
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

stop-review:
  stage: deploy
  script: [echo "delete review app"]
  variables:
    GIT_STRATEGY: none             # the branch may already be deleted
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      when: manual
      allow_failure: true          # don't block the pipeline on this
```

The stop job runs when someone stops the environment, when the branch is deleted or the MR is merged or closed, or after `auto_stop_in`. Give review environments lower-privilege credentials than staging, scoped with an environment scope of `review/*`.

## Rollback

Each deployment is a job in a past pipeline. The environment's page (Operate > Environments) lists its deployments, and can run an earlier one's deployment job again to roll back. For that to work:

- The **deployment job must do the whole deployment** from its own inputs: an image digest, a saved artifact, a commit. A job that relies on an artifact that has since expired, or on a build step in the same pipeline being rerun, can't roll back.
- **Data changes don't roll back** by redeploying code. Make schema changes backward compatible (expand, then migrate, then contract), so the previous version still runs against the new schema. The tech lead's [migrations guide](../../tech-lead/migrations-and-cutovers.md) covers the pattern.
- For Terraform, "rollback" is a new plan from the previous commit, reviewed like any change: revert the commit in an MR and apply that.

## The Terraform pipeline, walked through

The [Terraform example](examples/terraform/.gitlab-ci.yml) deploys one root module, such as [network-vpc](../terraform/aws/network-vpc/), with the roles from [gitlab-oidc](../terraform/aws/gitlab-oidc/). In the lab it runs against moto: a merge request plans, and on `main` the plan runs, then the apply is played and creates 29 resources.

| Job | Runs | Uses | Does |
|---|---|---|---|
| `fmt`, `validate`, `test` | Every pipeline | No credentials | Formatting, validation, and the module's offline tests with mocked providers |
| `kics-iac-sast` | Every pipeline | No credentials | GitLab's IaC scanner, from the `Jobs/SAST-IaC` template |
| `plan` | MRs and `main` | The **plan** role (read-only), through an ID token | Plans against the real state, saves `plan.cache`, and reports creates, updates, and deletes to the MR |
| `apply` | `main` only, manual | The **apply** role, in a variable protected to `main` | Applies the saved plan from `plan` in the `production` environment |

Decisions worth copying:

- **Apply the saved plan, not a new one.** What runs is exactly what was reviewed; if anything changed since, Terraform refuses the stale plan and you plan again.
- **Two roles.** Every branch can plan with read access; only `main` can change anything. The apply role's ARN is a protected variable, and the role itself only trusts `main`'s ID token, so a feature branch has neither.
- **Inputs from a file variable** (`TF_VARS_FILE`), passed to `plan` only. `TF_VAR_<name>` CI/CD variables would reach every job, including `terraform test`, and override the values the tests set: the lab caught exactly that.
- **The plan artifact is restricted** (`artifacts:access: developer`), because a saved plan can contain secrets in clear text.
- **`resource_group`** serializes plans and applies per environment.
- **The pipeline waits, blocked,** until someone runs `apply`. Leaving a blocked pipeline unattended is fine; a newer pipeline's plan supersedes it.

## Next

[Pipeline security](08-pipeline-security.md).
