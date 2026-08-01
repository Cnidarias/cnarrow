# syntax=docker/dockerfile:1

FROM emscripten/emsdk:6.0.4 AS toolchain

ARG ODIN_VERSION=dev-2026-07a
ARG TARGETARCH

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in \
      amd64) odin_arch=amd64 ;; \
      arm64) odin_arch=arm64 ;; \
      *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && mkdir -p /opt/odin \
    && curl -fsSL "https://github.com/odin-lang/Odin/releases/download/${ODIN_VERSION}/odin-linux-${odin_arch}-${ODIN_VERSION}.tar.gz" \
       | tar -xz -C /opt/odin --strip-components=1

ENV PATH="/opt/odin:${PATH}"

FROM toolchain AS builder

ARG BUILD_COMMIT=local
ENV BUILD_COMMIT=${BUILD_COMMIT}

WORKDIR /src

COPY source/ source/
COPY scripts/build-web.sh scripts/build-web.sh
COPY web/ web/

RUN chmod +x scripts/build-web.sh \
    && ./scripts/build-web.sh

FROM nginxinc/nginx-unprivileged:alpine AS runtime

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /src/build/ /usr/share/nginx/html/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
