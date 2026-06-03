# Apex-Sync

`apex-sync` bootstraps a Kubernetes platform and hands steady-state management
to Argo CD.

The repo is organized around a short bootstrap phase and a longer GitOps phase:

1. Provide a kubeconfig for an existing Kubernetes cluster.
2. Review the tracked baseline values in `override-config/`.
3. Create `.env.bootstrap` for sensitive bootstrap inputs.
4. Run `scripts/bootstrap.sh`.
5. Terraform renders Argo CD and Ansible artifacts.
6. Ansible installs Cilium, installs Argo CD, creates bootstrap secrets, and
   applies the root Argo CD application.
7. Argo CD reconciles the platform from `gitops/`.
8. Argo CD Config Management Plugins render environment-specific values and
   Helm chart versions during sync.

Cluster provisioning is currently outside this repo's active bootstrap path. A
future Terraform module can own infrastructure and cluster creation before this
GitOps bootstrap runs.

## What This Repo Manages

Bootstrap installs:

- Cilium as CNI and kube-proxy replacement
- Argo CD as the GitOps control plane
- Argo CD CMP sidecars for environment substitution
- Argo CD repository credentials backed by a GitHub App
- Route53 credentials used by cert-manager and reflected to external-dns

GitOps then manages:

- cert-manager with a Route53 ACME `ClusterIssuer`
- Reflector for controlled secret reflection
- MetalLB with a configurable address pool
- OpenEBS LocalPV hostpath storage and storage class
- Istio base, Istiod, Gateway API, public gateway, and Kiali
- Kyverno and baseline policies
- external-dns for Route53 DNS records
- Garage object storage with S3 routing and bootstrap jobs
- Percona XtraDB Cluster Operator
- Percona XtraDB Cluster resources, HAProxy, and S3 backup settings
- Argo CD HTTPRoute through the Istio public gateway
- Observability foundation and backends:
  - Prometheus Operator CRDs
  - Grafana Operator
  - OpenTelemetry Operator
  - Mimir, Loki, and Tempo
  - Grafana Alloy gateway and daemonset collectors
  - Grafana instance and datasources

## Repository Layout

- `scripts/bootstrap.sh`: main bootstrap entrypoint; runs Terraform apply.
- `scripts/destroy.sh`: Terraform destroy helper and generated-file cleanup.
- `override-config/`: tracked baseline configuration values used by bootstrap.
- `terraform/stack/main`: Terraform entrypoint.
- `terraform/modules/argocd`: renders Argo CD Helm values and root app.
- `terraform/modules/bootstrap_ansible`: renders Ansible inventory/vars and runs Ansible.
- `ansible/playbooks/bootstrap.yml`: local bootstrap playbook.
- `ansible/roles/`: Cilium, Argo CD, tooling, and root-app bootstrap roles.
- `gitops/argo-apps`: Argo CD app-of-apps definitions.
- `gitops/apps`: rendered application content.
- `cmp-build/`: custom Argo CD CMP image source.
- `.github/workflows/build-cmp-envsubst.yml`: GHCR image publish workflow.
- `example.env.bootstrap`: example secret bootstrap env file.
- `demo-app-ui.yaml`: standalone demo manifest, not part of the app-of-apps tree.
- `plan.md`: current observability implementation plan and follow-up list.

## Prerequisites

Install or have available:

- Terraform `>= 1.5.0`
- `yq`
- `ansible-playbook`
- `ansible-galaxy`
- Access to a Kubernetes cluster through `kubeconfig_path`

The Ansible bootstrap can install `kubectl` and Helm when they are missing on
supported Debian or RedHat hosts. On other OS families, install them manually.

You also need:

- Internet access for Terraform providers, Ansible collections, images, Helm charts, and remote manifests.
- A GitHub App that Argo CD can use to read this repository.
- AWS credentials with Route53 access for the hosted zone used by cert-manager and external-dns.

## Configuration Inputs

The scripts load two sources of configuration:

- `.env.bootstrap` for sensitive Terraform variables.
- `override-config/*.yaml` for non-secret platform settings.

Review and edit:

- `override-config/ansible.yaml`
- `override-config/argocd.yaml`
- `override-config/gitops.yaml`
- `override-config/observability.yaml`
- `override-config/replication.yaml`
- `override-config/resources.yaml`

Create `.env.bootstrap` from the example:

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

`.env.bootstrap` is local bootstrap input. It is ignored by Git and should not
be committed.

## Important Config Values

The main values to review before bootstrapping are:

- `kubeconfig_path`
- `gitops_root_app_repo_url`
- `gitops_root_app_target_revision`
- `gitops_root_app_path`
- `argocd_chart_version`
- `argocd_cmp_image`
- `argocd_server_service_type`
- `metallb_addresses_start`
- `metallb_addresses_end`
- `base_domain`
- `cert_manager_acme_email`
- `cert_manager_route53_region`
- `cert_manager_route53_hosted_zone_id`
- `external_dns_txt_owner_id`

Application chart versions are externalized in `override-config/gitops.yaml`,
including:

- `cert_manager_version`
- `external_dns_version`
- `gateway_api_version`
- `garage_version`
- `grafana_operator_version`
- `istio_main_version`
- `kiali_version`
- `kyverno_version`
- `loki_version`
- `metallb_version`
- `mimir_version`
- `openebs_version`
- `opentelemetry_operator_version`
- `percona_version`
- `prometheus_operator_crds_version`
- `alloy_version`
- `grafana_exploretraces_plugin_version`
- `reflector_version`
- `tempo_version`

Replication and sizing values live in `override-config/replication.yaml`.
Resource requests and limits live in `override-config/resources.yaml` and are
passed through Terraform as `resource_*` environment values.
Observability runtime tuning, such as datasource refresh periods, scrape
intervals, retention windows, and collector batch settings, lives in
`override-config/observability.yaml` and is passed through Terraform as
`observability_*` environment values.

## Bootstrap Flow

`scripts/bootstrap.sh` does the following:

1. Checks for Terraform and `yq`.
2. Requires `.env.bootstrap`.
3. Requires at least one YAML file in `override-config/`.
4. Exports each YAML key as a `TF_VAR_*` variable.
5. Runs `terraform init` in `terraform/stack/main`.
6. Runs `terraform apply --auto-approve`.
7. Writes Terraform logs under the runtime temp log directory.

Terraform then:

1. Reads and merges `override-config/*.yaml`.
2. Renders Argo CD Helm values into `terraform/stack/main/artifacts/`.
3. Renders the root Argo CD application manifest.
4. Renders the local Ansible inventory and vars file.
5. Installs Ansible collections into `.ansible/collections`.
6. Runs `ansible/playbooks/bootstrap.yml`.

Ansible then:

1. Validates the kubeconfig path.
2. Ensures `kubectl` and Helm are available.
3. Installs Cilium via Helm.
4. Installs Argo CD via Helm using Terraform-rendered values.
5. Creates the Argo CD GitHub App repository secret.
6. Creates the `route53-credentials-secret` in `cert-manager`.
7. Applies the Terraform-rendered root Argo CD application.

## GitOps Flow

The root Argo CD application points at `gitops/argo-apps` and uses the
`envsubstappofapp` CMP plugin. It renders the app-of-apps layer with values from
Terraform, including repo URL, Git revision, domain, chart versions, replica
counts, and resource settings.

The main app-of-apps overlay is:

```text
gitops/argo-apps
`-- overlays/default/root
    |-- platform-project.yaml
    `-- ../../../base
```

The base applications are synced in waves:

| Wave | Application |
| ---: | --- |
| -20 | `cert-manager`, `reflector` |
| -10 | `metallb`, `openebs` |
| 0 | `istio-main` |
| 5 | `kyverno` |
| 8 | `external-dns` |
| 10 | `garage`, `argocd-server-route`, `stateful-operator` |
| 20 | `stateful-resources` |
| 23 | `observability` |

`istio-main` is itself a small app-of-apps layer that deploys:

- `istio-main-app`: Gateway API CRDs, Istio base, and Istiod.
- `public-gateway`: Istio Gateway API infrastructure, wildcard certificate, Gateway, and Envoy filters.
- `kiali`: Kiali in `istio-system`.

`observability` is also an app-of-apps layer:

- `obs-foundation` at wave 23:
  - `prometheus-operator-crds`
  - `grafana-operator`
  - `opentelemetry-operator`
- `obs-backends` at wave 25:
  - Mimir
  - Loki
  - Tempo
  - Grafana Alloy gateway and daemonset collectors
  - Grafana instance and datasources

Most child applications use the `envsubst` CMP plugin, then run
`kustomize build --enable-helm`.

## Observability Model

The observability stack uses two layers:

```text
obs-foundation
  CRDs and operators only

obs-backends
  real observability systems, collectors, Grafana, and datasource config
```

Data flow:

- Applications send OTLP metrics, logs, and traces to the OpenTelemetry gateway.
- The OpenTelemetry daemonset collects host metrics, kubelet stats, and container logs.
- The daemonset forwards telemetry to the gateway.
- The gateway exports metrics to Mimir, logs to Loki, and traces to Tempo.
- Prometheus remote-writes metrics to Mimir.
- Grafana uses Mimir as the default metrics datasource.
- Prometheus remains available as a local/debug datasource.
- Loki and Tempo are configured for trace/log correlation.

Collector choices:

- No Promtail.
- No Grafana Alloy.
- No node-exporter.
- OpenTelemetry Collector is the main telemetry collection path.

## Argo CD CMP Model

Argo CD is configured with two plugins:

- `envsubstappofapp`: runs `kustomize build .` and then `envsubst`.
- `envsubst`: copies the app into a temp directory, runs `envsubst` over YAML
  files, then runs `kustomize build --enable-helm`.

Both plugins run as repo-server sidecars from the custom image referenced by
`argocd_cmp_image`. The image is built from `cmp-build/`, based on
`quay.io/argoproj/argocd:v3.4.2`, and includes `envsubst` plus the plugin
scripts.

The image version is stored in `cmp-build/VERSION`. The GitHub Actions workflow
builds and publishes the image to GHCR when `cmp-build/**` changes on `main` or
when the workflow is run manually.

## How To Run

Prepare local bootstrap inputs:

```bash
cp example.env.bootstrap .env.bootstrap
```

Edit `override-config/*.yaml` and `.env.bootstrap`, then bootstrap:

```bash
./scripts/bootstrap.sh
```

Typical checks:

```bash
kubectl --kubeconfig <path-from-kubeconfig_path> get nodes
kubectl --kubeconfig <path-from-kubeconfig_path> -n argocd get applications
kubectl --kubeconfig <path-from-kubeconfig_path> -n argocd get pods
```

## Generated Files

Bootstrap creates local generated content:

- `terraform/stack/main/artifacts/`
- `terraform/stack/main/.terraform/`
- `terraform/stack/main/.terraform.lock.hcl`
- `terraform/stack/main/terraform.tfstate`
- `terraform/stack/main/terraform.tfstate.backup`
- `.ansible/`
- runtime temp logs

These are runtime artifacts and are not part of the desired GitOps state.

## Destroy

To destroy Terraform-managed bootstrap resources:

```bash
./scripts/destroy.sh
```

When destroy succeeds, the script removes generated Terraform, Ansible, and log
artifacts. It does not delete the Kubernetes cluster.

## Current Caveats

- `example.env.bootstrap` only shows the GitHub App values. Add the AWS Route53
  `TF_VAR_*` values before bootstrapping.
- The default GitOps target revision in `override-config/gitops.yaml` points to
  the current development branch. Change it if you want Argo CD to follow another
  branch or tag.
- Service names for the observability backends should be confirmed after the
  first full Argo CD sync, then datasource and collector endpoints should be
  adjusted if chart output differs.
