# ============================================================================
# Emakola Production Dockerfile
# Multi-stage build for Elixir/Phoenix on Fly.io
# ============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Builder
# ---------------------------------------------------------------------------
ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bookworm-20260518-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y \
      build-essential \
      git \
      curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 for asset compilation
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set build environment
ENV MIX_ENV=prod \
    LANG=en_US.UTF-8 \
    ERL_FLAGS="+JPperf true"

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# ---------------------------------------------------------------------------
# Install dependencies
# ---------------------------------------------------------------------------
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# Copy compile-time config
RUN mkdir config
COPY config/config.exs config/branding.exs config/plans.exs config/${MIX_ENV}.exs config/

# Compile dependencies (cached layer)
RUN mix deps.compile

# ---------------------------------------------------------------------------
# Build assets
# ---------------------------------------------------------------------------
COPY priv priv
COPY lib lib
COPY assets assets

# Install Node.js dependencies for assets (if applicable)
RUN if [ -f assets/package.json ]; then \
      cd assets && npm ci --no-audit --no-fund; \
    fi

# Build Tailwind CSS, esbuild JS, and digest assets
RUN mix assets.setup && \
    mix assets.deploy

# ---------------------------------------------------------------------------
# Compile application and build release
# ---------------------------------------------------------------------------
COPY rel rel

# Copy runtime config
COPY config/runtime.exs config/

# Compile the application
RUN mix compile

# Build the release
RUN mix release

# ---------------------------------------------------------------------------
# Stage 2: Runner
# ---------------------------------------------------------------------------
FROM ${RUNNER_IMAGE} AS runner

# Install runtime dependencies
RUN apt-get update -y && \
    apt-get install -y \
      libstdc++6 \
      openssl \
      libncurses5 \
      locales \
      ca-certificates \
      curl \
      tini \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod \
    ERL_AFLAGS="-proto_dist inet6_tcp" \
    PHX_SERVER=true

WORKDIR /app

# Create non-root user
RUN groupadd --system emakola && \
    useradd --system --gid emakola --home /app --shell /bin/sh emakola

# Copy the release from the builder
COPY --from=builder --chown=emakola:emakola /app/_build/prod/rel/emakola ./

# Copy migration runner script
RUN mkdir -p /app/bin
COPY --from=builder --chown=emakola:emakola /app/rel/overlays/bin/ /app/bin/

# Ensure scripts are executable
RUN chmod +x /app/bin/*

USER emakola

# Expose the Phoenix port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:4000/api/health || exit 1

# Use tini as init system for proper signal handling (SIGTERM, etc.)
ENTRYPOINT ["/usr/bin/tini", "--"]

# Start the Phoenix server
CMD ["/app/bin/server"]
