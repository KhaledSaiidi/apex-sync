These are enhancements to work on:

~~- `external-dns` secret wiring first: extend `ansible/roles/gitops_root_app/tasks/main.yml` so `route53-credentials-secret` is created in `external-dns` as well as `cert-manager`; do not rely on the `cert-manager` namespace secret because pods cannot read secrets across namespaces.~~

~~- `external-dns` values file: add `gitops/apps/external-dns/values.yaml` and wire it from `gitops/apps/external-dns/kustomization.yaml`; set `provider: aws`, `sources: [istio-virtualservice]`, `domainFilters: ["${ARGOCD_ENV_base_domain}"]`, `policy: sync`, `registry: txt`, `txtOwnerId: "${ARGOCD_ENV_external_dns_txt_owner_id}"`, `interval: 1m`, `triggerLoopOnEvent: true`, `logLevel: info`, and expose `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` from `route53-credentials-secret`.~~

~~- `external-dns` workload hardening: in the same values file set `serviceAccount.create: true`, `resources.requests` to `cpu: 100m` and `memory: 128Mi`, `resources.limits` to `cpu: 300m` and `memory: 256Mi`, `podDisruptionBudget.maxUnavailable: 1`, `securityContext.runAsNonRoot: true`, `securityContext.allowPrivilegeEscalation: false`, and add anti-affinity or topology spread so DNS updates do not depend on one node.~~

- `istio-ingress-gateway` values file: replace the inline labels in `gitops/apps/istio/istio-ingress-gateway/kustomization.yaml` with `gitops/apps/istio/istio-ingress-gateway/values.yaml`; set `labels.app: istio-ingress-gateway`, `labels.istio: ingressgateway`, `service.type: LoadBalancer`, `service.externalTrafficPolicy: Local`, `resources.requests` to `cpu: 100m` and `memory: 128Mi`, `resources.limits` to `cpu: 1000m` and `memory: 512Mi`, `autoscaling.enabled: true`, `autoscaling.minReplicas: 2`, `autoscaling.maxReplicas: 5`, and `podDisruptionBudget.minAvailable: 1`.

- `istio-ingress-gateway` traffic ownership: if you want deterministic ingress addressing, add a new env var such as `ARGOCD_ENV_istio_ingress_gateway_load_balancer_ip` and set `service.loadBalancerIP` from it; otherwise leave IP assignment to MetalLB but keep the `LoadBalancer` service explicit in values.

- `cert-manager` values expansion: extend `gitops/apps/cert-manager/values.yaml` with `prometheus.enabled: true`, controller/webhook/cainjector `resources.requests` of `cpu: 100m` and `memory: 128Mi`, `resources.limits` of `cpu: 200m` and `memory: 256Mi`, `podDisruptionBudget.enabled: true`, `securityContext.runAsNonRoot: true`, `securityContext.allowPrivilegeEscalation: false`, and `webhook.timeoutSeconds: 10`.

- `cert-manager` secret ownership: keep the Route53 credentials bootstrap-owned for now, but document that `route53-credentials-secret` is the single source of truth and only duplicate it into another namespace when a workload really needs it; if you want GitOps ownership later, move it to `ExternalSecret`, SOPS, or SealedSecret instead of leaving secret creation split across ad hoc manifests.

- `cert-manager` certificate wiring: either add the future Istio `Gateway` TLS reference that will consume `wildcard-domain-secret-tls`, or remove `gitops/apps/cert-manager/certificate.yaml` until a real consumer exists; a production repo should not keep an orphaned wildcard certificate with no workload proving it is used.

- `metallb` values file: add `gitops/apps/metallb/values.yaml` and wire it from `gitops/apps/metallb/kustomization.yaml`; set controller and speaker `resources`, enable metrics, add `serviceMonitor.enabled: true` only when a Prometheus operator exists, and make pool behavior explicit by adding `autoAssign: true` and `avoidBuggyIPs: true` in `gitops/apps/metallb/metallb-pool.yaml`.

- `istio-main` values file: add `gitops/apps/istio/istio-main/values-istiod.yaml` and wire it to the `istiod` chart; set `pilot.replicaCount: 2`, `pilot.resources.requests` to `cpu: 200m` and `memory: 256Mi`, `pilot.resources.limits` to `cpu: 500m` and `memory: 512Mi`, `meshConfig.accessLogFile: /dev/stdout`, and `defaultConfig.holdApplicationUntilProxyStarts: true`.

- `kyverno` values file: add `gitops/apps/kyverno/values.yaml` and wire it from `gitops/apps/kyverno/kustomization.yaml`; set admission, background, and reports controller replicas/resources explicitly, enable metrics, and keep the current policies but plan a later pass to replace the hardcoded `default` namespace behavior with label-based namespace onboarding.

- `kiali` and `openebs` last: for `kiali`, either add values for `auth.strategy` and `external_services.prometheus.url` or disable the app until observability exists; for `openebs`, add provisioner resources, pin `bitnami/kubectl` to a fixed tag, add `ttlSecondsAfterFinished` and `backoffLimit` to the host-path job, and make the storage class reclaim policy an explicit choice instead of leaving it as an unreviewed default.
