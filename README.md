# kube-signal

`kube-signal` bootstraps a production-like Kubernetes platform on a local `kind` cluster, then hands steady-state management to Argo CD.

The current automated flow is:

1. Create a local `kind` cluster with the provided config.
2. Run `bootstrap.sh`.
3. Terraform renders Argo CD bootstrap artifacts.
4. Terraform runs the local Ansible bootstrap.
5. Ansible installs `Cilium`, installs `Argo CD`, creates the required bootstrap secrets, and applies the root Argo CD application.
6. Argo CD reconciles the platform from `gitops/`.
7. Argo CD Config Management Plugins render environment-specific values and chart versions during sync.

This is the main path in the codebase. Older manual notes are historical reference only.

## What The Repo Manages

The repo bootstraps and GitOps-manages:

- `Cilium` as CNI and kube-proxy replacement
- `Argo CD` as the GitOps control plane
- `MetalLB` for local `LoadBalancer` IPs
- `cert-manager`
- `Istio`
- `Gateway API` resources used by the ingress gateway layer
- `Kiali`
- `Kyverno`
- `external-dns`
- `OpenEBS`

The `kind` config in [`kind-kube-signal.yaml`](./kind-kube-signal.yaml) disables the default CNI and kube-proxy because `Cilium` replaces both.

## Big Improvements In The Current Design

Compared to the older bootstrap shape, the current system now has a cleaner separation between bootstrap and steady-state GitOps.

- Terraform owns the bootstrap inputs and renders the exact Argo CD artifacts that Ansible applies.
- Ansible creates both the Argo CD GitHub App repository secret and the Route53 secret needed by `cert-manager`.
- Argo CD uses dedicated CMP sidecars for `envsubst` rendering instead of downloading tools and mounting scripts at runtime.
- The CMP runtime is packaged as a versioned image, built from [`cmp-build/`](./cmp-build/) and published by [`.github/workflows/build-cmp-envsubst.yml`](./.github/workflows/build-cmp-envsubst.yml).
- The root Argo CD application injects environment-specific values into child applications through CMP env vars.
- GitOps child applications now consume variables for:
  - Git source repo URL and revision
  - MetalLB address pool
  - cert-manager DNS / ACME settings
  - per-application Helm chart versions

This means most environment changes now happen through Terraform inputs rather than manual edits to GitOps manifests.

## Repository Layout

- `bootstrap.sh`: main bootstrap entrypoint
- `destroy.sh`: Terraform destroy helper for bootstrap-managed resources
- `cmp-build/`: source for the custom Argo CD CMP image
- `terraform/stack/main`: Terraform entrypoint
- `ansible/playbooks/bootstrap.yml`: local bootstrap playbook
- `gitops/`: Argo CD applications and application content
- `example.env.bootstrap`: example bootstrap environment file

## Prerequisites

Install or have available:

- Docker
- `kind`
- `terraform`
- `ansible-playbook`
- `ansible-galaxy`

`kubectl` and `helm` do not have to be preinstalled in every case. The bootstrap tooling role attempts to install them when missing on supported Debian or RedHat hosts.

You also need:

- internet access for Terraform providers, Ansible collections, image pulls, and Helm charts
- a GitHub App Argo CD can use to read the GitOps repository
- AWS credentials with access to the Route53 zone used by `cert-manager`

## Required Inputs

Create `.env.bootstrap` from [`example.env.bootstrap`](./example.env.bootstrap):

```bash
cp example.env.bootstrap .env.bootstrap
```

At minimum, provide:

- `TF_VAR_github_app_id`
- `TF_VAR_github_app_installation_id`
- `TF_VAR_github_app_private_key`
- `TF_VAR_aws_access_key_id`
- `TF_VAR_aws_secret_access_key`

Example:

```bash
export TF_VAR_github_app_id="xxxxxx"
export TF_VAR_github_app_installation_id="xxxxxx"
export TF_VAR_github_app_private_key="$(cat /path/to/argocd-github-app.pem)"
export TF_VAR_aws_access_key_id="AKIA..."
export TF_VAR_aws_secret_access_key="..."
```

These are consumed by Terraform, rendered into the bootstrap artifacts, and then used by Ansible to create:

- the Argo CD GitHub App repository secret
- the `route53-credentials-secret` in `cert-manager`

`.env.bootstrap` is local bootstrap input, not a Kubernetes secret manifest.

## Useful Terraform Inputs

The defaults are intentionally usable, but these inputs are the main ones worth overriding per environment:

- `TF_VAR_gitops_root_app_repo_url`
- `TF_VAR_gitops_root_app_target_revision`
- `TF_VAR_kubeconfig_path`
- `TF_VAR_argocd_chart_version`
- `TF_VAR_argocd_cmp_image`
- `TF_VAR_metallb_addresses_start`
- `TF_VAR_metallb_addresses_end`
- `TF_VAR_cert_manager_acme_email`
- `TF_VAR_cert_manager_route53_region`
- `TF_VAR_cert_manager_route53_hosted_zone_id`
- `TF_VAR_base_domain`

The platform application chart versions are also variableized through Terraform:

- `TF_VAR_cert_manager_version`
- `TF_VAR_external_dns_version`
- `TF_VAR_istio_main_version`
- `TF_VAR_istio_ingress_gateway_version`
- `TF_VAR_kiali_version`
- `TF_VAR_kyverno_version`
- `TF_VAR_metallb_version`
- `TF_VAR_openebs_version`

## How The System Works

### Bootstrap Phase

`bootstrap.sh`:

1. loads `.env.bootstrap`
2. changes into `terraform/stack/main`
3. runs `terraform init`
4. runs `terraform apply --auto-approve`

Terraform then:

1. renders Argo CD Helm values
2. renders the Argo CD root application manifest
3. renders the local Ansible inventory and vars file
4. runs the local bootstrap Ansible workflow

Ansible then:

1. prepares local tooling
2. installs `Cilium`
3. installs `Argo CD`
4. creates the Argo CD GitHub App repository secret
5. creates the Route53 credentials secret for `cert-manager`
6. applies the root Argo CD application

### GitOps Phase

After bootstrap, Argo CD reconciles the child applications from `gitops/`.

The root app uses the `envsubstappofapp` CMP plugin to render child `Application` manifests with environment-specific values such as:

- repo URL
- target revision
- MetalLB IP range
- cert-manager email / Route53 settings
- base domain
- per-application chart versions

Child applications that need variable substitution use the `envsubst` CMP plugin. This is how the repo now injects Helm chart versions into `gitops/apps/**/kustomization.yaml` without hardcoding them.

## Argo CD CMP Model

Argo CD is configured with two CMP plugins:

- `envsubstappofapp`
  Used for the root app-of-apps layer.
- `envsubst`
  Used by child applications that need environment substitution before `kustomize build --enable-helm`.

The CMP sidecars run from the custom image referenced by `argocd_cmp_image`. The image is built from [`cmp-build/`](./cmp-build/) and published by [`.github/workflows/build-cmp-envsubst.yml`](./.github/workflows/build-cmp-envsubst.yml).

This avoids runtime package installation inside repo-server and keeps the CMP runtime versioned and reproducible.

## How To Run

### 1. Create The Cluster

Use the repo-provided `kind` config and write kubeconfig to `kind-kubeconfig.yaml`:

```bash
kind create cluster \
  --config kind-kube-signal.yaml \
  --kubeconfig kind-kubeconfig.yaml
```

This matches the default Terraform `kubeconfig_path`.

### 2. Bootstrap The Platform

Run:

```bash
./bootstrap.sh
```

### 3. Verify

Typical checks:

```bash
kubectl --kubeconfig kind-kubeconfig.yaml get nodes
kubectl --kubeconfig kind-kubeconfig.yaml -n argocd get applications
kubectl --kubeconfig kind-kubeconfig.yaml -n argocd get pods
```

## What To Review Before A Real Sync

Most environment-specific values now come from Terraform variables, not direct manifest edits. The main ones to review are:

- MetalLB address range
- GitOps repo URL and target revision
- base domain
- cert-manager ACME email
- Route53 region
- Route53 hosted zone ID
- Argo CD chart version
- CMP image tag
- per-application chart versions

## Logs And Generated Files

During bootstrap:

- Terraform apply logs are written under `/tmp/kube-signal`
- rendered artifacts are written under `terraform/stack/main/artifacts`
- local Ansible cache content is written under `.ansible/`

## Destroy

To destroy Terraform-managed bootstrap resources:

```bash
./destroy.sh
```

To delete the `kind` cluster itself, run that separately:

```bash
kind delete cluster --name kube-signal
```

`destroy.sh` does not delete the `kind` cluster for you.
