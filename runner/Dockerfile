# Spacelift runner with op (1Password CLI) and Tailscale baked in.
# The 1Password tofu provider shells out to op; the run hooks start tailscaled.
FROM ghcr.io/spacelift-io/runner-terraform:latest@sha256:2b363c9f75f5e0f2aa9d4454d0cd6a6064aadaf4866c3e2fe7ceccb19f6916b1

USER root

# op has no GitHub releases; the 1password/op Docker image tags mirror the
# CLI versions, so Renovate tracks those.
# renovate: datasource=docker depName=1password/op
ARG OP_VERSION=2.32.0
# renovate: datasource=github-releases depName=tailscale/tailscale extractVersion=^v(?<version>.+)$
ARG TAILSCALE_VERSION=1.102.3

# gcompat: glibc loader shim. The 1Password provider v3 binary is
# glibc-linked and cannot start on musl without it.
RUN apk add --no-cache unzip gcompat \
    && curl -sSfo /tmp/op.zip "https://cache.agilebits.com/dist/1P/op2/pkg/v${OP_VERSION}/op_linux_amd64_v${OP_VERSION}.zip" \
    && unzip -o /tmp/op.zip op -d /usr/local/bin \
    && curl -sSf "https://pkgs.tailscale.com/stable/tailscale_${TAILSCALE_VERSION}_amd64.tgz" \
       | tar xz -C /usr/local/bin --strip-components=1 \
         "tailscale_${TAILSCALE_VERSION}_amd64/tailscale" \
         "tailscale_${TAILSCALE_VERSION}_amd64/tailscaled" \
    && rm -f /tmp/op.zip \
    && op --version && tailscale --version

USER spacelift
