#!/usr/bin/env bash
# Runs inside a uv container (check.sh starts it): generate a service from the
# template, run the service's own checks, then release a template change and
# apply it to the service with `copier update`, keeping a local edit.
#
# Usage: generate-and-update.sh <template-dir> <output-dir>
set -Eeuo pipefail

TEMPLATE_SRC="$1"
OUT="$2"
COPIER="copier==9.19.1"
SERVICE=orders-api
failures=0

ok() { printf 'ok    %s\n' "$*"; }
fail() {
  printf 'FAIL  %s\n' "$*"
  failures=$((failures + 1))
}
check() {
  local description="$1" output
  shift
  if output="$("$@" 2>&1)"; then
    ok "$description"
  else
    fail "$description"
    printf '%s\n' "$output" | tail -20 | sed 's/^/      | /'
  fi
}
git_quiet() { git -c user.name=platform -c user.email=platform@example.com -c init.defaultBranch=main "$@" >/dev/null; }

# The template as its own Git repository, released as v1.0.0: Copier records
# the version a service came from, and updates between versions.
tpl="$(mktemp -d)/python-service"
cp -r "$TEMPLATE_SRC" "$tpl"
rm -rf "$tpl/test"
git_quiet -C "$tpl" init
git_quiet -C "$tpl" add -A
git_quiet -C "$tpl" commit -m "Python service golden path"
git_quiet -C "$tpl" tag v1.0.0

rm -rf "${OUT:?}/$SERVICE"
check "copier copy: generate $SERVICE from v1.0.0" \
  uvx --quiet "$COPIER" copy --trust --defaults --vcs-ref v1.0.0 \
  --data service_name="$SERVICE" --data owner=team-orders --data description="Takes and tracks orders." \
  "$tpl" "$OUT/$SERVICE"

if uvx --quiet "$COPIER" copy --trust --defaults --data service_name=Bad_Name "$tpl" "$(mktemp -d)/bad" >/dev/null 2>&1; then
  fail "copier rejects an invalid service name"
else
  ok "copier rejects an invalid service name"
fi

cd "$OUT/$SERVICE"
missing=0
for f in src/orders_api/main.py tests/test_main.py uv.lock Dockerfile .gitlab-ci.yml deploy/dev.yaml deploy/production.yaml catalog-info.yaml mkdocs.yml docs/index.md CODEOWNERS .copier-answers.yml; do
  if [[ ! -f "$f" ]]; then
    fail "generated file missing: $f"
    missing=1
  fi
done
if [[ $missing == 0 ]]; then ok "every golden path file is present"; fi
check "answers file records template v1.0.0" grep -q '_commit: v1.0.0' .copier-answers.yml

# The generated service passes its own pipeline's checks.
export UV_LINK_MODE=copy
check "uv sync --locked (the lock the template's task wrote matches pyproject.toml)" uv sync --locked
check "ruff format --check" uv run ruff format --check .
check "ruff check" uv run ruff check .
check "mypy (strict)" uv run mypy
check "pytest" uv run pytest -q

check "catalog-info.yaml is a valid Backstage Component" uv run --with pyyaml python - <<'EOF'
import re, yaml
doc = yaml.safe_load(open("catalog-info.yaml"))
assert doc["apiVersion"] == "backstage.io/v1alpha1" and doc["kind"] == "Component", doc
assert re.fullmatch(r"[a-z0-9A-Z]([-_.a-z0-9A-Z]{0,61}[a-z0-9A-Z])?", doc["metadata"]["name"]), doc["metadata"]
spec = doc["spec"]
for field in ("type", "lifecycle", "owner"):
    assert spec.get(field), f"spec.{field} is required"
assert spec["owner"] == "group:team-orders", spec
EOF

# Day 2: the service team edits the code; the platform team improves the template.
git_quiet init
git_quiet add -A
git_quiet commit -m "Generated from the golden path"
printf '\n\n# Added by the service team.\nTEAM_NOTE = "kept across template updates"\n' >>src/orders_api/main.py
git_quiet commit -am "Team change"

cat >"$tpl/template/.editorconfig" <<'EOF'
# Added in template v1.1.0: consistent editor settings for every service.
root = true

[*]
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 4

[*.{yml,yaml,toml,json}]
indent_size = 2
EOF
git_quiet -C "$tpl" add -A
git_quiet -C "$tpl" commit -m "Add .editorconfig"
git_quiet -C "$tpl" tag v1.1.0

check "copier update: v1.0.0 to v1.1.0" uvx --quiet "$COPIER" update --trust --defaults --vcs-ref v1.1.0
check "the template's new file arrived in the service" test -f .editorconfig
check "the team's own edit survived the update" grep -q 'TEAM_NOTE' src/orders_api/main.py
check "answers file now records template v1.1.0" grep -q '_commit: v1.1.0' .copier-answers.yml
check "the updated service still passes its tests" uv run pytest -q

if ((failures > 0)); then
  printf '%s failure(s) generating and updating\n' "$failures"
  exit 1
fi
