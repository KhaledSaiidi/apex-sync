# Apex-Sync

`apex-sync` bootstraps a Kubernetes platform and hands steady-state management
to Argo CD.

The repo is organized around a short bootstrap phase and a longer GitOps phase:

1. Ensure Docker is running on the bootstrap host.
2. Review the tracked baseline values in `override-config/`.
3. Create `.env.bootstrap` for sensitive bootstrap inputs.
4. Run `scripts/bootstrap.sh`.
5. Terraform creates the Kind cluster and writes its kubeconfig.
6. Terraform renders Argo CD and Ansible artifacts.
7. Ansible installs Cilium, installs Argo CD, creates bootstrap secrets, and
   applies the root Argo CD application.
8. Argo CD reconciles the platform from `gitops/`.
9. Argo CD Config Management Plugins render environment-specific values and
   Helm chart versions during sync.

The local Kubernetes cluster is part of the active Terraform bootstrap. The
Kind module creates one control-plane node and three worker nodes, disables the
default CNI and kube-proxy, and writes the kubeconfig to the configured
`kubeconfig_path`. Cilium is then installed as both the CNI and kube-proxy
replacement. Do not run the old manual `kind create cluster` command before
bootstrapping. Cluster topology now lives in `terraform/modules/kind/main.tf`;

## What This Repo Manages

Bootstrap creates and installs:

- A Terraform-managed Kind cluster
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
- Percona operators for MySQL and PostgreSQL
- Percona MySQL and PostgreSQL resources, connection-secret reflection, and S3
  backup settings
- Keycloak and its declarative realm configuration
- The Testkube sample API and web application
- Argo CD HTTPRoute through the Istio public gateway
- Observability foundation and backends:
  - Prometheus Operator CRDs
  - Grafana Operator
  - OpenTelemetry Operator
  - kube-state-metrics
  - Mimir, Loki, and Tempo
  - Grafana Alloy gateway and daemonset collectors
  - Grafana instance and datasources
  - Declarative ServiceMonitors, Grafana folders, and Grafana dashboards

## Repository Layout

- `scripts/bootstrap.sh`: main bootstrap entrypoint; runs Terraform apply.
- `scripts/destroy.sh`: destroys the Kind cluster and cleans generated files.
- `override-config/`: tracked baseline configuration values used by bootstrap.
- `terraform/stack/main`: Terraform entrypoint.
- `terraform/modules/kind`: creates the local Kind cluster and kubeconfig.
- `terraform/modules/argocd`: renders Argo CD Helm values and root app.
- `terraform/modules/bootstrap_ansible`: renders Ansible inventory/vars and runs Ansible.
- `ansible/playbooks/bootstrap.yml`: local bootstrap playbook.
- `ansible/roles/`: Cilium, Argo CD, tooling, and root-app bootstrap roles.
- `gitops/argo-apps`: Argo CD app-of-apps definitions.
- `gitops/apps`: rendered application content.
- `gitops/apps/observability/obs-foundation`: observability CRDs and operators.
- `gitops/apps/observability/obs-backends`: observability storage, collectors,
  Grafana, and datasources.
- `gitops/apps/observability/obs-config`: declarative ServiceMonitors and
  Grafana folder/dashboard resources.
- `gitops/apps/testkube-sample`: Testkube sample Helm release overrides and
  namespace configuration.
- `cmp-build/`: custom Argo CD CMP image source.
- `.github/workflows/build-cmp-envsubst.yml`: GHCR image publish workflow.
- `example.env.bootstrap`: example secret bootstrap env file.

## Prerequisites

Install or have available:

- Terraform `>= 1.5.0`
- Docker with a running daemon for the Terraform Kind provider
- `yq`
- `ansible-playbook`
- `ansible-galaxy`

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
- `override-config/cilium.yaml`
- `override-config/gitops.yaml`
- `override-config/observability.yaml`
- `override-config/replication.yaml`
- `override-config/resources.yaml`
- `override-config/testkube-sample.yaml`

For local execution, create `.env.bootstrap` from the example:

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

`.env.bootstrap` is optional when the required values already exist in the
process environment. It is ignored by Git and should not be committed. The
bootstrap script maps `TF_VAR_aws_access_key_id` and
`TF_VAR_aws_secret_access_key` to the standard AWS environment variables used
by the S3 Terraform backend.

## Important Config Values

The main values to review before bootstrapping are:

- `cluster_name` (optional; defaults to `apex-sync`)
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

Platform chart versions are externalized in `override-config/gitops.yaml`,
including:

- `cert_manager_version`
- `external_dns_version`
- `gateway_api_version`
- `garage_version`
- `grafana_operator_version`
- `istio_main_version`
- `kiali_version`
- `keycloak_operator_version`
- `kube_state_metrics_version`
- `kyverno_version`
- `loki_version`
- `metallb_version`
- `mimir_version`
- `openebs_version`
- `opentelemetry_operator_version`
- `percona_version`
- `percona_pg_version`
- `prometheus_operator_crds_version`
- `alloy_version`
- `grafana_exploretraces_plugin_version`
- `reflector_version`
- `tempo_version`

Replication and sizing values live in `override-config/replication.yaml`.
Shared platform resource requests and limits live in
`override-config/resources.yaml` and are passed through Terraform as
`resource_*` environment values.
Testkube sample settings live in `override-config/testkube-sample.yaml`. That
file separates developer-owned settings, such as database identity and
application images, from platform-owned settings, such as the chart version,
namespace, replicas, database secret integration, PDBs, routing, and the
application's resource requests and limits.
Observability runtime tuning, such as datasource refresh periods, scrape
intervals, retention windows, and collector batch settings, lives in
`override-config/observability.yaml` and is passed through Terraform as
`observability_*` environment values.

## Bootstrap Flow

`scripts/bootstrap.sh` does the following:

1. Checks for Terraform and `yq`.
2. Loads `.env.bootstrap` when it exists and CI has not disabled local env loading.
3. Validates the required GitHub App and AWS variables.
4. Requires at least one YAML file in `override-config/`.
5. Exports each YAML key as a `TF_VAR_*` variable.
6. Runs noninteractive `terraform init` in `terraform/stack/main`.
7. Runs noninteractive `terraform apply --auto-approve`.
8. Writes Terraform logs under the runtime temp log directory.

Terraform then:

1. Reads and merges `override-config/*.yaml`.
2. Creates the Kind cluster through `terraform/modules/kind` and writes the
   generated kubeconfig to `kubeconfig_path`.
3. Renders Argo CD Helm values into `terraform/stack/main/artifacts/`.
4. Renders the root Argo CD application manifest.
5. Renders the local Ansible inventory and vars file.
6. Installs Ansible collections into `.ansible/collections`.
7. Runs `ansible/playbooks/bootstrap.yml` after the Kind cluster exists.

Ansible then:

1. Validates the kubeconfig path.
2. Ensures `kubectl` and Helm are available.
3. Installs Cilium via Helm if the release is missing.
4. Installs Argo CD via Helm using Terraform-rendered values if the release is missing.
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
| -90 | `cilium` |
| -20 | `cert-manager`, `reflector` |
| -10 | `metallb`, `openebs` |
| 0 | `istio-main` |
| 1 | `argocd` |
| 5 | `kyverno` |
| 8 | `external-dns` |
| 10 | `garage`, `stateful-operator` |
| 20 | `stateful-resources` |
| 21 | `keycloak` |
| 22 | `keycloak-config` |
| 23 | `testkube-sample` |
| 25 | `observability` |

`istio-main` is itself a small app-of-apps layer that deploys:

- `istio-main-app`: Gateway API CRDs, Istio base, and Istiod.
- `public-gateway`: Istio Gateway API infrastructure, wildcard certificate,
  Gateway, and Envoy filters.
- `kiali`: Kiali in `istio-system`.

`observability` is also an app-of-apps layer:

- `obs-foundation` at wave 23:
  - `prometheus-operator-crds`
  - `grafana-operator`
  - `opentelemetry-operator`
- `obs-backends` at wave 26:
  - Mimir
  - Loki
  - Tempo
  - kube-state-metrics
  - Grafana Alloy gateway and daemonset collectors
  - Grafana instance and datasources
- `obs-config` at wave 29:
  - Declarative ServiceMonitors for platform workloads and observability targets
  - Grafana folders for Kubernetes, Istio, storage, and observability dashboards
  - Grafana dashboards for Kubernetes, Istio, Argo CD, and Keycloak

Most child applications use the `envsubst` CMP plugin, then run
`kustomize build --enable-helm`.

## Observability Model

The observability stack uses three layers:

```text
obs-foundation
  CRDs and operators only

obs-backends
  real observability systems, collectors, Grafana, and datasource config

obs-config
  declarative scrape config, Grafana folders, and Grafana dashboards
```

Data flow:

- Applications can send OTLP metrics, logs, and traces to the Alloy gateway.
- The Alloy daemonset collects host metrics, kubelet stats, cAdvisor metrics,
  resource metrics, and container logs.
- The Alloy gateway discovers `ServiceMonitor` and `PodMonitor` resources and
  remote-writes scraped metrics to Mimir.
- The Alloy gateway exports OTLP metrics to Mimir, logs to Loki, and traces to
  Tempo.
- Kubernetes events are converted into logs and written to Loki.
- Grafana uses Mimir as the default metrics datasource.
- Loki and Tempo are configured for trace/log correlation.

Collector choices:

- No Promtail.
- No node-exporter.
- Grafana Alloy is the main telemetry collection path.
- OpenTelemetry Operator is installed for OpenTelemetry CRDs and future
  application instrumentation, while the current collection pipeline is Alloy.

ServiceMonitor model:

- Chart-created ServiceMonitors are disabled where practical.
- `obs-config` owns most ServiceMonitors declaratively so scrape intent lives in
  one GitOps layer. Operator-owned monitors are used when the owning CR exposes
  a first-class, versioned ServiceMonitor contract, such as Keycloak.
- Argo CD, Kyverno, and cert-manager monitors are split by component to avoid
  collapsing jobs under one generic label.
- ServiceMonitors avoid blanket `honorLabels` so target labels do not override
  collector labels unexpectedly.
- MetalLB monitor Services are declared alongside the MetalLB app because the
  chart normally creates them only when chart-managed ServiceMonitors are
  enabled.

Grafana model:

- The Grafana instance is selected by the `dashboards: grafana` label.
- Datasources are managed by `GrafanaDatasource` resources in `obs-backends`.
- Folders and dashboards are managed by `GrafanaFolder` and
  `GrafanaDashboard` resources in `obs-config`.
- The initial managed folders are `kubernetes`, `istio`, `observability`, and
  `storage`.
- The first managed dashboard is the Istio mesh dashboard, placed in the
  `istio` folder and mapped to the `Mimir` datasource.

Loki mode:

- Loki runs in `SimpleScalable` mode.
- `loki_read_replicas`, `loki_write_replicas`, and `loki_backend_replicas`
  define the active Loki topology.
- `loki_single_binary_replicas` stays `0` in this mode so the monolithic Loki
  deployment is not mixed with the read/write/backend deployment.

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

## Automated Bootstrap

`.github/workflows/bootstrap.yml` runs when a push to `main` changes a file
under `override-config/`. The GitHub-hosted runner only orchestrates the
deployment: it reads `public_gateway_dns_target` from
`override-config/gitops.yaml`, connects to the Apex-Sync server over SSH,
clones or reuses `/home/apex-sync/apex-sync`, checks out the exact triggering
commit, and runs the bootstrap on that server.

Create a GitHub Environment named `apex-sync` with these secrets:

- `APEX_SYNC_SSH_PRIVATE_KEY`
- `APP_ID`
- `APP_INSTALLATION_ID`
- `APP_PRIVATE_KEY`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

The AWS credentials authenticate both the configured S3 Terraform backend and
the existing Route53 bootstrap integration. The workflow streams Terraform,
Ansible, and verification output until the remote process finishes. For the
initial MVP, SSH host-key checking is disabled; replace that temporary setting
with host-key pinning before treating the workflow as hardened.

Typical checks:

```bash
kubectl --kubeconfig kind-kubeconfig.yaml get nodes
kubectl --kubeconfig kind-kubeconfig.yaml -n argocd get applications
kubectl --kubeconfig kind-kubeconfig.yaml -n argocd get pods
```

The commands above use the default repository-root path produced by
`kubeconfig_path: "../../../kind-kubeconfig.yaml"` in
`override-config/ansible.yaml`. Use the configured path if you change it.

## Generated Files

Bootstrap creates local generated content:

- `kind-kubeconfig.yaml`
- `terraform/stack/main/artifacts/`
- `terraform/stack/main/.terraform/`
- `.ansible/`
- runtime temp logs

Terraform state is stored in the S3 backend configured by
`terraform/stack/main/backend.tf`. The remaining entries are runtime artifacts
and are not part of the desired GitOps state.

## Destroy

To destroy Terraform-managed bootstrap resources:

```bash
./scripts/destroy.sh
```

Terraform destroy deletes the Terraform-managed Kind cluster. When destruction
succeeds, the script also removes generated Terraform, Ansible, and log
artifacts.

## Current Caveats

- The default GitOps target revision in `override-config/gitops.yaml` points to
  the current development branch. Change it if you want Argo CD to follow another
  branch or tag.
- Grafana dashboards currently use `grafanaCom` references. For stricter
  offline GitOps, vendor dashboard JSON into the repo later.
