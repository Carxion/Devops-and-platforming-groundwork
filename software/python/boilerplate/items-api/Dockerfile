# syntax=docker/dockerfile:1
#
# Two stages: uv installs the locked dependencies into a virtual environment,
# then only that environment is copied into a clean, non-root runtime image.
#
#   docker build -t items-api-python software/python/boilerplate/items-api
#   docker run --rm -p 127.0.0.1:8080:8080 items-api-python

FROM python:3.14-slim@sha256:a2b82f3c48559aa0a8446d9af49826b6e2b2016f4cd2afabfe6013ec53729170 AS build
COPY --from=ghcr.io/astral-sh/uv:0.13.0@sha256:cdc6093146eb3ff6a40107b38f008b789e050e77ad87865e381d9917da55a168 /uv /usr/local/bin/uv

# Compile bytecode at build time for faster starts; copy instead of linking
# (the cache is a separate mount); use the image's Python, never download one.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

WORKDIR /app
# Dependencies first, from the lock file only: this layer is cached until
# pyproject.toml or uv.lock changes.
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project
# Then the application itself, installed (not editable) into the same environment.
COPY README.md ./
COPY src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable

FROM python:3.14-slim@sha256:a2b82f3c48559aa0a8446d9af49826b6e2b2016f4cd2afabfe6013ec53729170

LABEL org.opencontainers.image.title="items-api-python" \
      org.opencontainers.image.source="https://github.com/Carxion/Devops-and-platforming-groundwork" \
      org.opencontainers.image.licenses="CC-BY-4.0"

# A fixed non-root user, and no pip: nothing at run time needs it.
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app \
 && python -m pip uninstall --yes --quiet pip

COPY --from=build /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2)"]

# uvicorn handles SIGTERM itself: in-flight requests finish, then it exits.
ENTRYPOINT ["uvicorn", "items_api.main:app", "--host", "0.0.0.0", "--port", "8080", "--no-server-header"]
