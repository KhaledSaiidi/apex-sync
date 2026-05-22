FROM quay.io/argoproj/argocd:v2.12.6

USER 0

RUN apt-get update \
    && apt-get install --no-install-recommends -y gettext-base ca-certificates \
    && cp /usr/bin/envsubst /usr/local/bin/envsubst \
    && mkdir -p /home/argocd/cmp-server/config /home/argocd/cmp-server/scripts \
    && apt-get purge -y --auto-remove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY envsubst.sh /home/argocd/cmp-server/scripts/envsubst.sh
COPY envsubstappofapp.sh /home/argocd/cmp-server/scripts/envsubstappofapp.sh

RUN chmod 0555 /usr/local/bin/envsubst \
    && chmod 0555 /home/argocd/cmp-server/scripts/envsubst.sh \
    && chmod 0555 /home/argocd/cmp-server/scripts/envsubstappofapp.sh \
    && chown -R 999:999 /home/argocd/cmp-server

USER 999
