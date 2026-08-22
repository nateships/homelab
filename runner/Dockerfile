# Spacelift runner with op (1Password CLI) and Tailscale baked in.
# The 1Password tofu provider shells out to op; the run hooks start tailscaled.
FROM ghcr.io/spacelift-io/runner-terraform:latest

USER root

# 1Password CLI has no GitHub releases; bump manually with mise.toml's pin.
ARG OP_VERSION=2.32.0
# renovate: datasource=github-releases depName=tailscale/tailscale extractVersion=^v(?<version>.+)$
ARG TAILSCALE_VERSION=1.88.1

RUN apk add --no-cache unzip \
    && curl -sSfo /tmp/op.zip "https://cache.agilebits.com/dist/1P/op2/pkg/v${OP_VERSION}/op_linux_amd64_v${OP_VERSION}.zip" \
    && unzip -o /tmp/op.zip op -d /usr/local/bin \
    && curl -sSf "https://pkgs.tailscale.com/stable/tailscale_${TAILSCALE_VERSION}_amd64.tgz" \
       | tar xz -C /usr/local/bin --strip-components=1 \
         "tailscale_${TAILSCALE_VERSION}_amd64/tailscale" \
         "tailscale_${TAILSCALE_VERSION}_amd64/tailscaled" \
    && rm -f /tmp/op.zip \
    && op --version && tailscale --version

USER spacelift
