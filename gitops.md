## To Do:
1. ~~`resources-finalizer.argocd.argoproj.io` is used inconsistently: some apps have it (`external-dns`, Istio child apps), while others do not (`cert-manager`, `metallb`, `kyverno`, `openebs`). Deleting an app without the finalizer can leave orphaned live resources behind even though the `Application` object is gone. Fix by choosing one deletion model and applying finalizers consistently across all managed apps.~~

2. ~~Several apps have namespace drift between the Argo `Application`, the chart output, and extra manifests: `Certificate` is in `istio-ingress`, MetalLB CRs are in `metallb-system`, and Kiali is rendered into `kiali`, while app destinations use `cert-manager`, `metallb`, and `istio-system`. This can leave namespaces missing or place secrets/resources where workloads never read them. Fix by aligning namespaces end to end or adding explicit `Namespace` manifests for every hard-coded target namespace.~~

3. ~~The cert-manager `ClusterIssuer` depends on `route53-credentials-secret`, but no manifest in `gitops/` creates that secret. Argo can still report the app `Synced` because the `ClusterIssuer` object exists, while the issuer and certificate remain `NotReady` and no TLS secret is issued. Fix by managing the secret in GitOps with SOPS/Sealed Secrets/External Secrets or by making it an explicit prerequisite outside Argo.~~

4. ~~`gitops/apps/cert-manager/values.yaml` is invalid YAML (`crds` / `enabled:true`). This can break manifest generation or prevent cert-manager CRDs from being installed, which then makes `ClusterIssuer` and `Certificate` resources fail to apply. Fix by correcting the file to valid YAML and verifying the chart’s current CRD setting syntax.~~


5. ~~The Istio gateway deployment shape does not match the EnvoyFilter targets. `gitops/apps/istio/istio-ingress-gateway` renders one `gateway` chart release into `istio-ingress-gateway`, but `keep-alive.yaml` and `proxy-security-headers.yaml` target workloads labeled `istio-external-ingress-gw` / `istio-internal-ingress-gw` in `istio-ingress-ext` / `istio-ingress-int`. This can make the filters no-op or fail because the expected gateway workloads/namespaces do not exist. Fix by either deploying explicit ext/int gateway releases or retargeting the filters to the real gateway deployment.~~


6. ~~The Argo root app (`gitops/argo-apps`) and the `istio-main` parent app (`gitops/argo-apps/base/istio`) mostly manage child `Application` objects, not the final workloads. They can show `Synced` as soon as those child app manifests exist, even when child apps or pods are still unhealthy or missing. Fix by adding Argo `Application` health customization, checking `Health` separately from `Sync`, or flattening critical apps if you want parent status to reflect real rollout state.~~

## To check later:
- Every Argo `Application` in `gitops/argo-apps/base` tracks `targetRevision: HEAD`. This makes deployments non-reproducible and can change live desired state on every push, which makes rollbacks and debugging harder. Fix by pinning each app to a tag or commit SHA and promoting revisions intentionally.

- `gitops/apps/istio/istio-ingress-gateway/kustomization.yaml` pulls Gateway API from a remote GitHub release URL at render time. Argo repo-server must reach GitHub on every render, and the manifest is outside this repo’s review and rollback boundary. Fix by vendoring the Gateway API manifest into the repo or referencing a pinned local copy instead of a remote URL.
