## ~~To Do~~ Done Part 1:
1. ~~`resources-finalizer.argocd.argoproj.io` is used inconsistently: some apps have it (`external-dns`, Istio child apps), while others do not (`cert-manager`, `metallb`, `kyverno`, `openebs`). Deleting an app without the finalizer can leave orphaned live resources behind even though the `Application` object is gone. Fix by choosing one deletion model and applying finalizers consistently across all managed apps.~~

2. ~~Several apps have namespace drift between the Argo `Application`, the chart output, and extra manifests: `Certificate` is in `istio-ingress`, MetalLB CRs are in `metallb-system`, and Kiali is rendered into `kiali`, while app destinations use `cert-manager`, `metallb`, and `istio-system`. This can leave namespaces missing or place secrets/resources where workloads never read them. Fix by aligning namespaces end to end or adding explicit `Namespace` manifests for every hard-coded target namespace.~~

3. ~~The cert-manager `ClusterIssuer` depends on `route53-credentials-secret`, but no manifest in `gitops/` creates that secret. Argo can still report the app `Synced` because the `ClusterIssuer` object exists, while the issuer and certificate remain `NotReady` and no TLS secret is issued. Fix by managing the secret in GitOps with SOPS/Sealed Secrets/External Secrets or by making it an explicit prerequisite outside Argo.~~

4. ~~`gitops/apps/cert-manager/values.yaml` is invalid YAML (`crds` / `enabled:true`). This can break manifest generation or prevent cert-manager CRDs from being installed, which then makes `ClusterIssuer` and `Certificate` resources fail to apply. Fix by correcting the file to valid YAML and verifying the chart’s current CRD setting syntax.~~


5. ~~The Istio gateway deployment shape does not match the EnvoyFilter targets. `gitops/apps/istio/istio-ingress-gateway` renders one `gateway` chart release into `istio-ingress-gateway`, but `keep-alive.yaml` and `proxy-security-headers.yaml` target workloads labeled `istio-external-ingress-gw` / `istio-internal-ingress-gw` in `istio-ingress-ext` / `istio-ingress-int`. This can make the filters no-op or fail because the expected gateway workloads/namespaces do not exist. Fix by either deploying explicit ext/int gateway releases or retargeting the filters to the real gateway deployment.~~


6. ~~The Argo root app (`gitops/argo-apps`) and the `istio-main` parent app (`gitops/argo-apps/base/istio`) mostly manage child `Application` objects, not the final workloads. They can show `Synced` as soon as those child app manifests exist, even when child apps or pods are still unhealthy or missing. Fix by adding Argo `Application` health customization, checking `Health` separately from `Sync`, or flattening critical apps if you want parent status to reflect real rollout state.~~

## To check later:
- Every Argo `Application` in `gitops/argo-apps/base` tracks `targetRevision: HEAD`. This makes deployments non-reproducible and can change live desired state on every push, which makes rollbacks and debugging harder. Fix by pinning each app to a tag or commit SHA and promoting revisions intentionally.

- `gitops/apps/istio/istio-ingress-gateway/kustomization.yaml` pulls Gateway API from a remote GitHub release URL at render time. Argo repo-server must reach GitHub on every render, and the manifest is outside this repo’s review and rollback boundary. Fix by vendoring the Gateway API manifest into the repo or referencing a pinned local copy instead of a remote URL.

## To Do Part 2:

Goal: finish the two-hop CMP flow for MetalLB so Terraform passes values to the root app, the root app passes them to the MetalLB child app, and the child app renders the final manifests with `envsubst`.

1. ~~Install the CMPs in Argo CD, Add `envsubstappofapp` and `envsubst` CMPs in the Argo CD deployment.~~

2. ~~Root app wiring Update `terraform/modules/argocd/templates/argocd_root_app.tpl` to use `plugin.name: envsubstappofapp`. Pass flattened root env values: `metallb_config_mode` `metallb_config_addresses_start` `metallb_config_addresses_end`~~

3. ~~Terraform contract - Keep Terraform as the source of truth for: - `metallb_mode` - `metallb_addresses_start` -`metallb_addresses_end` - Do not build the final MetalLB range in Terraform. Pass start and end separately to Argo.~~

4. ~~MetalLB child app wiring - Update `gitops/argo-apps/base/metallb.yaml` to use `plugin.name: envsubst`. - Re-expose a smaller child contract: - `mode` - `addresses_start`- `addresses_end` ~~

5. ~~ Final MetalLB manifest - Update `gitops/apps/metallb/metallb-pool.yaml` to build the final range at render time: - `"${ARGOCD_ENV_addresses_start}-${ARGOCD_ENV_addresses_end}"` - Keep `gitops/apps/metallb/kustomization.yaml` simple. The dynamic part should come from `envsubst`, not from Kustomize overlays. ~~

6. Scope for this phase
- Keep MetalLB in `l2` mode only for now.
- Do not wire `metallb_auto_discover_kind_pool` into the CMP flow yet.
- Update `README.md` and bootstrap docs after the flow is working.


### Source References

- Argo CD CMP env prefixing and plugin execution model:
  https://argo-cd.readthedocs.io/en/stable/operator-manual/config-management-plugins/
- Argo CD note about user env vars being prefixed with `ARGOCD_ENV_`:
  https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/2.3-2.4/

### Final Decision

The correct adaptation for this repo is not:

- plain YAML placeholders without the envsubst render step
- Kustomize overlays for runtime cluster values
- host-dependent autodiscovery inside repo-server

The correct adaptation is:

- root app uses a dedicated app-of-apps envsubst CMP
- child app uses a dedicated application-layer envsubst CMP
- Terraform flattens and renders env contracts
- MetalLB final manifests consume child-layer `${ARGOCD_ENV_*}` values at runtime



## To Do Part 2:


