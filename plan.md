# Observability Refactor Tasks

## Deployments

- ~~Keep only two observability Argo CD child apps: `obs-foundation` and `obs-backends`.~~
- ~~Deploy `obs-foundation` with the `observability` namespace, Prometheus Operator CRDs, Grafana Operator, and OpenTelemetry Operator.~~
- ~~Deploy `obs-backends` with Mimir, Loki, Tempo, Grafana, Grafana datasources, and Grafana Alloy.~~
- ~~Remove `kube-prometheus-stack`, Prometheus server, Alertmanager, and kube-state-metrics from the observability runtime.~~
- ~~Remove OpenTelemetry Collector gateway, daemonset, and collector RBAC from the observability runtime.~~
- ~~Deploy Grafana through the Grafana Operator using a `Grafana` CR.~~
- ~~Deploy Alloy gateway as the centralized OTLP receiver and ServiceMonitor/PodMonitor scraper.~~
- ~~Deploy Alloy daemonset for node-local logs and node metrics.~~

## Integrations

- ~~Keep Garage S3 object storage integration for Mimir, Loki, and Tempo.~~
- ~~Forward Alloy metrics to Mimir.~~
- ~~Forward Alloy logs to Loki.~~
- ~~Forward Alloy traces to Tempo.~~
- ~~Keep OpenTelemetry Operator only for `Instrumentation` CRs and auto-instrumentation.~~
- ~~Keep Prometheus Operator CRDs only so `ServiceMonitor`, `PodMonitor`, and related CRs can exist.~~
- ~~Keep Grafana datasources declarative through Grafana Operator CRs.~~
- Add declarative Grafana dashboards and folders where needed.
- Add Mimir ruler and alert routing when alerting requirements are finalized.

## Configuration

- ~~Externalize chart versions through `override-config/gitops.yaml`.~~
- ~~Externalize replica counts through `override-config/replication.yaml`.~~
- ~~Externalize resource requests and limits through `override-config/resources.yaml`.~~
- ~~Externalize observability runtime tuning through `override-config/observability.yaml`.~~
- ~~Pass `resource_*` values through Terraform to Argo CD envsubst.~~
- ~~Pass `observability_*` values through Terraform to Argo CD envsubst.~~
- ~~Replace hardcoded datasource timing, Alloy scrape/batch settings, Loki limits, Mimir limits, Tempo timing, and operator timing values with envsubst variables.~~
- ~~Externalize the Grafana Explore Traces plugin version.~~
- Review any future observability hardcoded tuning values before adding new manifests.

## Validation

- ~~Validate changed YAML with `yq`.~~
- ~~Validate Terraform formatting with `terraform fmt -check`.~~
- ~~Check placeholder wiring from manifests to Argo app env values.~~
- Render manifests locally with Argo/Kustomize plugin behavior before applying to a cluster.
- Run an Argo CD sync dry run or diff in the target environment before rollout.
