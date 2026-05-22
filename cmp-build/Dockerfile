FROM debian:bookworm-slim

ARG TARGETARCH

RUN apt-get update \
    && apt-get install --no-install-recommends -y gettext-base ca-certificates \
    && cp /usr/bin/envsubst /usr/local/bin/envsubst \
    && apt-get purge -y --auto-remove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY envsubst.sh /usr/local/bin/envsubst.sh
COPY envsubstappofapp.sh /usr/local/bin/envsubstappofapp.sh
COPY plugin.yaml /home/argocd/cmp-server/config/plugin.yaml

RUN chmod 0555 /usr/local/bin/envsubst \
    && chmod 0555 /usr/local/bin/envsubst.sh \
    && chmod 0555 /usr/local/bin/envsubstappofapp.sh \
    && chmod 0444 /home/argocd/cmp-server/config/plugin.yaml \
    && chown -R 999:999 /home/argocd/cmp-server

USER 999