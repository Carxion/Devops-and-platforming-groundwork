# Reusing pipeline code

[← GitLab](README.md)

Pipelines repeat themselves: the same image and cache in every job, the same lint job in every project. GitLab has several ways to share configuration, from a hidden job in one file to versioned components in a catalog. This guide covers each, and when to use which.

## Within one file

### default

Keywords under `default:` apply to every job that doesn't set them: `image`, `before_script`, `after_script`, `cache`, `artifacts`, `retry`, `timeout`, `interruptible`, `tags`, `services`, `hooks`, and `id_tokens`.

### extends and hidden jobs

A job whose name starts with a dot is **hidden**: it never runs, but other jobs can `extends` it. Extending merges hashes deeply and replaces everything else (lists included):

```yaml
# .gitlab-ci.yml
.python:
  image: python:3.14-slim
  variables:
    PIP_CACHE_DIR: $CI_PROJECT_DIR/.pip-cache
  cache:
    key: pip
    paths: [.pip-cache/]
  before_script:
    - pip install -r requirements-dev.txt

lint:
  extends: .python
  script: [ruff check .]

test:
  extends: .python
  variables:
    PYTEST_ADDOPTS: -ra            # merged with .python's variables, not replacing them
  script: [pytest]
```

`extends` can list several templates (`extends: [.terraform, .aws-oidc]`, as in the [Terraform example](examples/terraform/.gitlab-ci.yml)); later ones win where they overlap. Keep the depth to two or three levels, or nobody can tell what a job ends up as. The pipeline editor's **Full configuration** tab shows the merged result.

### !reference

`!reference` reuses one key from another job, which `extends` can't do because lists replace rather than merge:

```yaml
# .gitlab-ci.yml
.setup:
  script:
    - echo "install tools"

.cleanup:
  after_script:
    - echo "remove temporary files"

test:
  script:
    - !reference [.setup, script]  # the list from .setup, then this job's own lines
    - echo "run the tests"
  after_script:
    - !reference [.cleanup, after_script]
```

YAML anchors (`&name`, `<<: *name`) also work, but only within one file, and they're harder to read. Prefer `extends` and `!reference`.

## Across files and projects: include

| Form | Includes | Use it for |
|---|---|---|
| `include: local: ci/lint.yml` | A file in the same repository, at the same commit | Splitting a long pipeline into files |
| `include: project: group/ci-templates`, `file: /lint.yml`, `ref: v1.2.0` | A file from another project, at a ref | Shared templates before components existed; pin `ref` |
| `include: remote: https://...` | A file from any URL, fetched at pipeline creation | Rarely: it runs whatever that URL serves. Add `integrity: sha256-...` (GitLab 17.9 and later) so a change fails the pipeline instead |
| `include: template: Jobs/SAST.gitlab-ci.yml` | A template shipped with GitLab | The security scanners and a few others |
| `include: component: $CI_SERVER_FQDN/group/project/name@1.0.0` | A CI/CD component, with inputs | Anything shared across projects ([below](#cicd-components)) |

How included configuration combines with yours:

- Included files merge into one configuration. **A job you define with the same name as an included job merges with it**, and your keys win. The Python example uses this to add `needs` to the component's build job:

  ```yaml
  items-api-build:
    needs: [lint, typecheck, test]
  ```

- Includes can nest, up to 150 includes per pipeline, counting nested ones.
- `include:rules` makes an include conditional, for example `rules: [{if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH}]`.
- A project include without `ref` uses the other project's default branch at the moment the pipeline is created, so a change there changes your pipeline without review. Always pin `ref` to a tag or SHA.

## CI/CD components

A **component** is a reusable piece of pipeline configuration with declared inputs, kept in its own project, released with versions, and listed in the **CI/CD Catalog** where people can find it. Components replace most uses of `include:project` templates. The [components example](examples/components/README.md) is a complete component project, tested in the lab.

### Structure

```text
ci-components/                     a project of its own
├── README.md                      required for the Catalog
├── .gitlab-ci.yml                 tests the components and releases them on tags
└── templates/
    ├── lint.yml                   a single-file component, used as .../lint@1.0.0
    └── container-image/
        └── template.yml           a directory component, used as .../container-image@1.0.0
```

A project can hold up to 100 components (GitLab 18.5 and later).

### Inputs

A component file starts with a `spec` header, separated from the configuration by `---`. Inputs are interpolated with `$[[ inputs.name ]]`, which GitLab resolves when it creates the pipeline, before any job runs:

```yaml
spec:
  inputs:
    name:
      default: image
    severity:
      description: Fail on vulnerabilities at these severities.
      default: HIGH,CRITICAL
    build_tags:
      type: array                  # string (default), number, boolean, or array
      default: []
---
"$[[ inputs.name ]]-build":
  tags: $[[ inputs.build_tags ]]
  script:
    - echo "building $[[ inputs.name ]]"
```

An input with no `default` is required. Inputs can also have `options` (allowed values) and `regex` (a pattern the value must match), so a typo fails at pipeline creation instead of halfway through a job.

### Using one

```yaml
# .gitlab-ci.yml
stages: [build, test, publish]

include:
  - component: $CI_SERVER_FQDN/platform/ci-components/container-image@1.0.0
    inputs:
      name: api
      context: .
      build_tags: [image-build]
```

| Version | Means | Use for |
|---|---|---|
| `@1.0.0` | Exactly that release | Anything that deploys or publishes |
| `@1.0`, `@1` | The newest `1.0.x`, or the newest `1.x.x` release | Picking up fixes automatically, where a surprise is acceptable |
| `@~latest` | The newest release | Trying things out |
| `@<commit SHA>` | That commit | The most exact pin, and testing unreleased changes |
| `@main` | A branch, as it is now | Avoid outside the component's own tests |

Partial versions never pick pre-releases. Whatever you choose, someone who can push to the component project can change what your pipeline runs within that range, so treat component maintainers as trusted for every project that uses them.

### Releasing and testing

- **Test in the component project's own pipeline,** including each component at the commit under test (`@$CI_COMMIT_SHA`), as the [example's pipeline](examples/components/.gitlab-ci.yml) does with a small test image.
- **Release with semantic version tags.** A `release:` job on tag pipelines creates the GitLab release; with the project set as a Catalog project (Settings > General > Visibility, CI/CD Catalog project), the version appears in the Catalog.
- **Document the inputs and jobs** in the README: it's the Catalog page.
- **Change major versions for breaking changes:** renamed inputs, renamed jobs (consumers may extend or `needs` them), or new requirements on runners.

## Choosing

| Need | Use |
|---|---|
| Settings every job in one pipeline shares | `default:` |
| A fragment several jobs in one file share | A hidden job and `extends`, or `!reference` for a single list |
| A long pipeline split into readable parts | `include: local` |
| The same jobs in many projects | A component, pinned to a version |
| GitLab's security scanners | `include: template`, or their components where available |
| A generated pipeline | A [dynamic child pipeline](03-rules-and-pipeline-types.md#parent-child-and-multi-project-pipelines) |

## Next

[Runners](05-runners.md).
