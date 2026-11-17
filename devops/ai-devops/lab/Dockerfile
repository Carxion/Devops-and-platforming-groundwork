# syntax=docker/dockerfile:1
#
# The tools the AI DevOps lab's checks run with: uv (and Python 3.14) for the
# example projects, git because DVC needs a repository, and modelscan in its
# own Python 3.12 environment (it doesn't support newer Pythons yet).
# lab.sh builds and runs it; nothing is installed on your machine.
#
#   docker build -t ai-devops-lab-tools devops/ai-devops/lab

FROM ghcr.io/astral-sh/uv:0.13.5-python3.14-trixie-slim@sha256:d8e732839dfc4225a1ff698803b478b2223c05636c055d3add41ab9dbec0f315

ARG MODELSCAN_VERSION=0.8.8

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# git comes from the Debian archive at the base image's snapshot; it isn't
# version-pinned because the checks need only basic commands.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_CACHE_DIR=/tmp/uv-cache \
    UV_LINK_MODE=copy \
    GIT_PYTHON_REFRESH=quiet

RUN uv venv -q -p 3.12 /opt/modelscan \
    && VIRTUAL_ENV=/opt/modelscan uv pip install -q --no-cache "modelscan==${MODELSCAN_VERSION}" \
    && ln -s /opt/modelscan/bin/modelscan /usr/local/bin/modelscan \
    && chmod -R a+rX /opt

RUN useradd --uid 10001 --create-home --shell /bin/bash lab \
    && git config --system --add safe.directory '*' \
    && git config --system user.name lab \
    && git config --system user.email lab@example.com \
    && rm -rf /tmp/uv-cache && mkdir -p /tmp/uv-cache && chown 10001 /tmp/uv-cache
USER 10001
WORKDIR /home/lab
ENTRYPOINT ["/bin/bash"]
