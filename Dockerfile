FROM ghcr.io/helmfile/helmfile-ubuntu:v1.1.8

RUN groupadd argo --gid 999 && useradd argo --uid 999 --gid 999 && \
  chown -R 999:999 "${HOME}"

# Overriding helm with wrapper
# ref: https://github.com/argoproj/argo-cd/issues/5202#issuecomment-2070215745
COPY --chmod=755 components/helm-wrapper.sh /usr/local/sbin/helm

WORKDIR /home/argocd/cmp-server/config/
COPY components/plugin.yaml ./

USER 999:999
CMD [ "/var/run/argocd/argocd-cmp-server" ]
