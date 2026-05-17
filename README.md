# kube-signal

`kube-signal` bootstraps a production-like Kubernetes platform on a local `kind` cluster.

The current repo flow is:

1. Create a local `kind` cluster with the provided config.
2. Run `bootstrap.sh`.
3. `bootstrap.sh` runs `terraform` in `terraform/stack/main`.
4. Terraform renders bootstrap artifacts and runs `ansible-playbook` locally.
5. Ansible installs `Cilium`, installs `Argo CD`, creates the Argo CD GitHub App repository secret, and applies the root Argo CD application.
6. Argo CD syncs the platform applications from `gitops/`.

This is the current automated path in the codebase. The older step-by-step manual flow in `NOTES.txt` is historical reference, not the main entrypoint anymore.

## What The Repo Manages

The repo is structured to bootstrap and GitOps-manage:

- `Cilium` as the cluster CNI and kube-proxy replacement
- `Argo CD` as the GitOps control plane
- `MetalLB` for `LoadBalancer` IPs on local `kind`
- `cert-manager` for certificate management
- `Istio` and Gateway API resources
- `Kyverno` policies
- `external-dns`

The `kind` cluster config in [`kind-kube-signal.yaml`](./kind-kube-signal.yaml) disables the default CNI and kube-proxy because `Cilium` is expected to replace both.

## Repository Layout

- `bootstrap.sh`: main bootstrap entrypoint
- `destroy.sh`: Terraform destroy helper for bootstrap-managed resources
- `terraform/stack/main`: Terraform entrypoint
- `ansible/playbooks/bootstrap.yml`: local bootstrap playbook
- `gitops/`: Argo CD applications and app manifests
- `example.env.bootstrap`: example Terraform input environment

## Prerequisites

Install or have available:

- Docker
- `kind`
- `terraform`
- `ansible-playbook` and `ansible-galaxy`

`kubectl` and `helm` do not have to be preinstalled in every case. The bootstrap playbook attempts to install them when missing on supported Debian or RedHat hosts.

You also need:

- internet access for Terraform providers, Ansible collections, and Helm charts
- a GitHub App that Argo CD can use to read the GitOps repository

## Required Inputs

Create `.env.bootstrap` from [`example.env.bootstrap`](./example.env.bootstrap):

```bash
cp example.env.bootstrap .env.bootstrap
```

Fill in:

- `TF_VAR_github_app_id`
- `TF_VAR_github_app_installation_id`
- `TF_VAR_github_app_private_key`

Example shape:

```bash
export TF_VAR_github_app_id="xxxxxx"
export TF_VAR_github_app_installation_id="xxxxxx"
export TF_VAR_github_app_private_key="$(cat /path/to/argocd-github-app.pem)"
```

These values are consumed by Terraform and passed to Ansible so Ansible can create the Argo CD GitHub App repository secret.

`.env.bootstrap` is not a Kubernetes secret file.

## How To Run

### 1. Create The Cluster

Use the repo-provided `kind` config and write kubeconfig to `kind-kubeconfig.yaml`:

```bash
kind create cluster \
  --config kind-kube-signal.yaml \
  --kubeconfig kind-kubeconfig.yaml
```

This is the expected default because Terraform currently defaults `kubeconfig_path` to `../../../kind-kubeconfig.yaml`, which resolves to the repo-root `kind-kubeconfig.yaml`.

### 2. Bootstrap The Platform

Run:

```bash
./bootstrap.sh
```

`bootstrap.sh` does the following:

1. loads `.env.bootstrap`
2. changes into `terraform/stack/main`
3. runs `terraform init`
4. runs `terraform apply --auto-approve`

Terraform then:

1. renders Argo CD values and the root app manifest
2. renders the Ansible inventory and vars file
3. runs the local bootstrap Ansible module

Ansible then:

1. validates the kubeconfig and bootstrap inputs
2. prepares local tooling
3. installs `Cilium`
4. installs `Argo CD`
5. creates the Argo CD GitHub App repository secret
6. applies the root Argo CD application

After that, Argo CD starts reconciling the child applications from `gitops/`.

## Important Configuration To Review

Some GitOps manifests are environment-specific and should be reviewed before relying on a full sync:

- [`gitops/apps/metallb/metallb-pool.yaml`](./gitops/apps/metallb/metallb-pool.yaml): the IP pool must match an unused range in your local `kind` Docker network
- [`gitops/apps/cert-manager/clusterissuer-route53.yaml`](./gitops/apps/cert-manager/clusterissuer-route53.yaml): contains Route53 zone-specific settings
- [`gitops/apps/cert-manager/certificate.yaml`](./gitops/apps/cert-manager/certificate.yaml): contains the configured DNS names

By default, the Argo CD root application points to the GitHub repo URL and revision configured in Terraform. If you want Argo CD to reconcile a different repo or branch, update the Terraform inputs in `terraform/stack/main`.

## Manual Secrets Still Required

The repo references a Route53 credentials secret for the cert-manager DNS01 solver:

- name: `route53-credentials-secret`
- namespace: `cert-manager`

That secret is not created by `.env.bootstrap` and is not bootstrapped by Terraform or Ansible. If you want cert-manager DNS validation to work, create it separately, for example:

```bash
kubectl -n cert-manager create secret generic route53-credentials-secret \
  --from-literal=access-key-id='AKIA...' \
  --from-literal=secret-access-key='YOUR_SECRET_ACCESS_KEY'
```

## Logs And Generated Files

During bootstrap:

- Terraform logs are written under `/tmp/kube-signal`
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
