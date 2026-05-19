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

### Goal

Move the environment-specific MetalLB configuration to a pure GitOps CMP flow, using the same two-hop envsubst pattern that worked in the older project:

1. Terraform renders high-level config into the root bootstrap `Application`.
2. The root app uses a CMP dedicated to the app-of-apps layer.
3. That root CMP resolves child `Application` YAMLs and passes a smaller env contract to each child app.
4. The child app uses a second CMP dedicated to the application layer.
5. The final application manifests consume `${ARGOCD_ENV_*}` variables at render time inside the repo-server sidecar.

### Verified Behavior We Must Preserve

- Argo CD prefixes user-supplied `spec.source.plugin.env` variables with `ARGOCD_ENV_` before they reach the plugin command.
- Plugin env values are visible only to the CMP process; plain YAML files do not interpolate arbitrary variables by themselves.
- The old project pattern works because the CMP command itself runs `envsubst` at the correct layer.
- The current repo does not have those envsubst CMPs yet.

### Current Repo Reality

- The root bootstrap app is rendered from Terraform in `terraform/modules/argocd/templates/argocd_root_app.tpl`.
- The root app currently points to `gitops/argo-apps`.
- Child apps under `gitops/argo-apps/base/*.yaml` currently rely on a plugin-based render path.
- MetalLB currently keeps its environment-specific pool directly in `gitops/apps/metallb/metallb-pool.yaml`.
- That hardcoded pool is the problem we are solving.

### Constraint We Must Accept

`metallb_auto_discover_kind_pool` cannot be implemented inside the Argo repo-server CMP path in the current architecture.

Reason:

- CMP sidecars run inside the cluster, in the Argo CD repo-server pod.
- They do not run on the bootstrap host that created the kind cluster.
- They do not have safe, built-in access to the host Docker network where kind IP ranges live.

Therefore:

- Phase 1 of this plan will require explicit `metallb_addresses`.
- If we want `metallb_auto_discover_kind_pool` later, it must be resolved before Argo render time, for example in Terraform, and then passed into the root app as concrete addresses.

### Target Flow In This Repo

The target flow should be:

1. Terraform accepts `metallb_addresses` as `list(string)`.
2. Terraform derives a YAML-safe multiline fragment, for example `metallb_addresses_yaml`.
3. Terraform renders the root app with plugin `envsubstappofapp`.
4. The root app exposes flattened env names such as `metallb_config_addresses_yaml`.
5. The root CMP runs `kustomize build` on `gitops/argo-apps`, then runs `envsubst`.
6. The MetalLB child `Application` YAML receives concrete values from `${ARGOCD_ENV_metallb_config_addresses_yaml}`.
7. The MetalLB child app uses plugin `envsubst`.
8. The child app re-emits a smaller env contract such as `addresses_yaml`.
9. The child CMP runs `envsubst` on the MetalLB app source, then runs `kustomize build --enable-helm`.
10. `gitops/apps/metallb/metallb-pool.yaml` consumes `${ARGOCD_ENV_addresses_yaml}` and renders the final `IPAddressPool`.

That is the exact two-hop contract we want:

- root layer:
  `Terraform -> child Application YAML`
- application layer:
  `child Application env -> final Kubernetes manifests`

### Required Changes

#### 1. Introduce dedicated envsubst CMPs in Argo CD

Add two CMP sidecars and their plugin definitions through `terraform/modules/argocd/templates/argocd_values.tpl`:

- `envsubstappofapp`
- `envsubst`

Expected behavior:

- `envsubstappofapp`:
  run `kustomize build` first, then `envsubst`
- `envsubst`:
  run `envsubst` over the app source first, then `kustomize build --enable-helm`

Implementation note:

- Prefer shipping the commands as small scripts in a dedicated image or mounted script files, instead of embedding long shell one-liners directly in `plugin.yaml`.
- The sidecar image must contain the tools it uses:
  - shell
  - `envsubst`
  - `kustomize`
  - `helm`

#### 2. Switch the root bootstrap app to the root envsubst CMP

Change `terraform/modules/argocd/templates/argocd_root_app.tpl` so the root bootstrap app uses:

- `plugin.name: envsubstappofapp`

Add root env values for the MetalLB contract, but use flattened names, not nested object names. Example:

- `metallb_config_mode`
- `metallb_config_addresses_yaml`

Do not pass raw Terraform lists directly into plugin env.

Instead, Terraform should render a YAML-safe multiline string. Example shape:

```text
    - "172.18.255.200-172.18.255.230"
```

The rendered string must already contain the correct indentation for insertion under:

```yaml
spec:
  addresses:
```

#### 3. Keep `metallb_addresses` typed as a list

The source of truth type must be:

- `terraform/stack/main/variables.tf`: `list(string)`
- `terraform/modules/argocd/variables.tf`: `list(string)`

Do not downgrade it to `string`.

Terraform should derive helper strings from the list, not replace the canonical type.

Recommended helper locals or template inputs:

- `metallb_addresses_yaml`
- optionally `metallb_addresses_csv` if later needed for a shell consumer

#### 4. Rework the MetalLB child `Application` to be a second-hop env bridge

Change `gitops/argo-apps/base/metallb.yaml` so it uses:

- `plugin.name: envsubst`

Inside that child app, define the smaller app-scoped env contract. Example:

- `name: addresses_yaml`
- `value: |`
  `${ARGOCD_ENV_metallb_config_addresses_yaml}`

Optional additional values:

- `mode`
- future chart values if needed

Important rule:

- The child app should reference the root contract using `${ARGOCD_ENV_<flattened_root_name>}`.
- The child app should expose a simpler contract to the application layer using short app-specific names.

#### 5. Rework the MetalLB application manifests to consume child-layer env vars

Change `gitops/apps/metallb/metallb-pool.yaml` so it does not contain a hardcoded range and does not attempt to rely on plain YAML interpolation without envsubst.

Use the final application-layer env name directly. Example structure:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: metallb-pool
  namespace: metallb-system
spec:
  addresses:
${ARGOCD_ENV_addresses_yaml}
```

This file only works after step 1 and step 4 are in place, because the `envsubst` child CMP is what performs the substitution before Kustomize renders the app.

#### 6. Keep `gitops/apps/metallb/kustomization.yaml` simple

For this envsubst pattern, we do not need Kustomize overlays or Kustomize patches just to set the pool addresses.

The MetalLB app can remain a simple Kustomization that:

- installs the Helm chart
- includes `metallb-pool.yaml`

The dynamic part comes from `envsubst`, not from Kustomize overlays.

#### 7. Decide how to handle `metallb_mode`

For phase 1, keep the repo explicitly `l2` only unless we also introduce the BGP resources and contract.

Recommended phase 1 approach:

- keep `metallb_mode` in Terraform and root env for forward compatibility
- do not branch behavior on it yet unless we add separate manifest templates for BGP

This avoids pretending mode is dynamic when only the L2 resource set exists today.

#### 8. Postpone `metallb_auto_discover_kind_pool`

Do not wire `metallb_auto_discover_kind_pool` through the CMP chain yet.

Phase 1 rule:

- require `metallb_addresses`

Phase 2 option:

- Terraform may derive `effective_metallb_addresses` for kind and pass only the resolved addresses into Argo

That keeps the GitOps layer deterministic while still allowing a convenience path later.

### File-Level Implementation Order

1. `terraform/stack/main/variables.tf`
   Keep `metallb_addresses` as `list(string)` and document that it is required for phase 1.

2. `terraform/modules/argocd/variables.tf`
   Keep `metallb_addresses` as `list(string)`.

3. `terraform/modules/argocd/main.tf`
   Derive template inputs for:
   - `metallb_addresses_yaml`
   - optional `metallb_mode`

4. `terraform/modules/argocd/templates/argocd_values.tpl`
   Install the two new CMP sidecars and plugin definitions:
   - `envsubstappofapp`
   - `envsubst`

5. `terraform/modules/argocd/templates/argocd_root_app.tpl`
   Switch root plugin to `envsubstappofapp` and emit flattened env names.

6. `gitops/argo-apps/base/metallb.yaml`
   Switch child plugin to `envsubst` and re-emit child-scoped env names.

7. `gitops/apps/metallb/metallb-pool.yaml`
   Replace the hardcoded address block with `${ARGOCD_ENV_addresses_yaml}`.

8. `README.md` and `example.env.bootstrap`
   Document the phase 1 contract:
   - explicit `metallb_addresses`
   - no automatic kind discovery yet in the GitOps path

### Validation Criteria

The implementation is correct only when all of the following are true:

1. The root bootstrap app manifest generated by Terraform contains the flattened MetalLB env contract.
2. The root CMP resolves the MetalLB child `Application` YAML to concrete values.
3. The live MetalLB child `Application` object shows the smaller app-scoped env contract.
4. The child CMP resolves `gitops/apps/metallb/metallb-pool.yaml` so the final manifest contains a real YAML list under `spec.addresses`.
5. The final `IPAddressPool` in the cluster contains the configured addresses and no literal `${ARGOCD_ENV_*}` placeholders.

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




