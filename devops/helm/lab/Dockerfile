# syntax=docker/dockerfile:1
#
# Every tool the Helm lab and its checks use, at pinned versions, each
# download verified by checksum. lab.sh builds and runs it; nothing is
# installed on your machine.
#
#   docker build -t helm-lab-tools devops/helm/lab

FROM debian:trixie-slim@sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad

ARG HELM_VERSION=4.3.1
ARG HELM_SHA256=0403a88ae20913d11b10a2467b50087721fea7581736da6b9d3992f5357fe54b
ARG KUBECTL_VERSION=1.34.12
ARG KUBECTL_SHA256=90b7b9058ffeb5c10710bb1c73f541eaf426fb1b4e87df435db669de9a2564a2
ARG KUBECONFORM_VERSION=0.8.0
ARG KUBECONFORM_SHA256=9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883
ARG CT_VERSION=3.15.0
ARG CT_SHA256=467561730f25fe09d5e6cd09a3e1f6aa759871c657a57602947c716d9be2c583
ARG KIND_VERSION=0.33.0
ARG KIND_SHA256=aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d
ARG UNITTEST_VERSION=1.2.1
ARG UNITTEST_SHA256=48e86ecc1467b009630e5954375e5d8494139f73b466df5fe8c04fa45b634939
ARG DIFF_VERSION=3.15.15
ARG DIFF_SHA256=504e99410611daa70702362e1b10dc74929df8a912cb3f6b5d21d1ee9d0cb7d9

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# git: chart-testing reads the repository; yamllint and yamale: chart-testing
# lints YAML and checks Chart.yaml with them; docker-cli: kind drives the
# Docker daemon through it. They aren't version-pinned: they come from the
# pinned base image's release, and old versions leave the archive as security
# fixes land. Every tool the checks depend on is pinned by checksum below.
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git jq yamllint python3-yamale docker-cli \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/dl
RUN curl -fsSLo helm.tgz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
 && echo "${HELM_SHA256}  helm.tgz" | sha256sum -c - \
 && tar -xzf helm.tgz && install linux-amd64/helm /usr/local/bin/helm \
 && curl -fsSLo kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && echo "${KUBECTL_SHA256}  kubectl" | sha256sum -c - \
 && install kubectl /usr/local/bin/kubectl \
 && curl -fsSLo kubeconform.tgz "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
 && echo "${KUBECONFORM_SHA256}  kubeconform.tgz" | sha256sum -c - \
 && tar -xzf kubeconform.tgz && install kubeconform /usr/local/bin/kubeconform \
 && curl -fsSLo ct.tgz "https://github.com/helm/chart-testing/releases/download/v${CT_VERSION}/chart-testing_${CT_VERSION}_linux_amd64.tar.gz" \
 && echo "${CT_SHA256}  ct.tgz" | sha256sum -c - \
 && mkdir ct && tar -xzf ct.tgz -C ct && install ct/ct /usr/local/bin/ct && mkdir -p /etc/ct && cp ct/etc/* /etc/ct/ \
 && curl -fsSLo kind "https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-amd64" \
 && echo "${KIND_SHA256}  kind" | sha256sum -c - \
 && install kind /usr/local/bin/kind \
 && curl -fsSLo unittest.tgz "https://github.com/helm-unittest/helm-unittest/releases/download/v${UNITTEST_VERSION}/helm-unittest-linux-amd64-${UNITTEST_VERSION}.tgz" \
 && echo "${UNITTEST_SHA256}  unittest.tgz" | sha256sum -c - \
 && curl -fsSLo diff.tgz "https://github.com/databus23/helm-diff/releases/download/v${DIFF_VERSION}/diff-${DIFF_VERSION}-linux-amd64.tgz" \
 && echo "${DIFF_SHA256}  diff.tgz" | sha256sum -c -

# Plugins go in a fixed directory, so they work for any user the container runs as.
ENV HELM_PLUGINS=/opt/helm-plugins
RUN mkdir -p "$HELM_PLUGINS/unittest" "$HELM_PLUGINS/diff" \
 && tar -xzf unittest.tgz -C "$HELM_PLUGINS/unittest" \
 && tar -xzf diff.tgz -C "$HELM_PLUGINS/diff" --strip-components=1 \
 && rm -rf /tmp/dl

RUN useradd --uid 10001 --create-home --shell /bin/bash lab
USER 10001
WORKDIR /work
ENTRYPOINT ["/bin/bash"]
