# Spacelift runner image. mise installs the toolchain from mise.toml.
# Spacelift's launcher mounts the tofu binary and the workspace; the
# image provides the environment and the spacelift user.
FROM debian:13-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl git jq openssh-client procps unzip xz-utils python3 \
    && rm -rf /var/lib/apt/lists/* \
    # Spacelift runner contract: unprivileged user "spacelift", UID 1983
    && useradd --uid 1983 --create-home --shell /bin/bash spacelift

# renovate: datasource=github-releases depName=jdx/mise extractVersion=^v(?<version>.+)$
ARG MISE_VERSION=2026.8.15

ENV MISE_DATA_DIR=/usr/local/share/mise \
    MISE_CONFIG_DIR=/etc/mise \
    MISE_CACHE_DIR=/tmp/mise-cache \
    MISE_INSTALL_PATH=/usr/local/bin/mise \
    PATH=/usr/local/share/mise/shims:/usr/local/bin:/usr/bin:/bin

COPY mise.toml /etc/mise/config.toml

RUN curl -fsSL https://mise.run | MISE_VERSION="v${MISE_VERSION}" sh \
    && mise trust /etc/mise/config.toml \
    && mise install \
    && chmod -R a+rX "${MISE_DATA_DIR}" \
    # smoke-test the tools the stacks depend on
    && op --version && tailscale --version \
    && ansible-playbook --version && omnictl --version \
    # The build and the smoke tests ran as root and left a root-owned
    # cache. Drop it last so the runtime user can create a writable one.
    && rm -rf "${MISE_CACHE_DIR}"

USER spacelift
