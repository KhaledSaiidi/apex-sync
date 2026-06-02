# Observability Plan

- Goal: run observability as a GitOps-managed platform layer using Mimir, Loki, Tempo, Grafana, Prometheus, and OpenTelemetry.
- Scope: keep observability under `gitops/apps/observability/` with two Argo child apps only:
  - `obs-foundation`: CRDs and operators.
  - `obs-backends`: real observability systems, collectors, Grafana, and datasource config.
- Namespace: use one `observability` namespace for foundation, backends, collectors, and config CRs.
- Storage: use Garage S3 buckets and reflected secrets for Mimir, Loki, and Tempo.
- Collection model: use OpenTelemetry Collector for app telemetry and node/container log/metric collection. Do not deploy Promtail or Grafana Alloy.
- Sizing: keep replicas in `override-config/replication.yaml` and resources in `override-config/resources.yaml`.

## Completed

- ~~Create the observability app-of-apps entry and sync waves.~~
- ~~Create `obs-foundation` for namespace, CRDs, and operators only.~~
- ~~Install Prometheus Operator CRDs separately from the runtime stack.~~
- ~~Install Grafana Operator.~~
- ~~Install OpenTelemetry Operator.~~
- ~~Remove operator-only `kube-prometheus-stack` from `obs-foundation`.~~
- ~~Rename `obs-core-stack` to `obs-backends`.~~
- ~~Remove separate `obs-configuration` app and keep observability to two child apps.~~
- ~~Move Grafana datasources into `obs-backends/grafana-datasources.yaml`.~~
- ~~Deploy Mimir with Garage S3 object storage.~~
- ~~Deploy Loki with Garage S3 object storage and OTLP structured metadata enabled.~~
- ~~Deploy Tempo with Garage S3 object storage and OTLP enabled.~~
- ~~Deploy `kube-prometheus-stack` in `obs-backends` with `crds.enabled: false`.~~
- ~~Disable Grafana and node-exporter in `kube-prometheus-stack`.~~
- ~~Enable Prometheus remote write to Mimir.~~
- ~~Enable kube-prometheus-stack Alertmanager.~~
- ~~Create Grafana instance managed by Grafana Operator.~~
- ~~Create Grafana datasource CRs for Mimir, Prometheus, Loki, and Tempo.~~
- ~~Create OpenTelemetry Collector gateway for app OTLP metrics, logs, and traces.~~
- ~~Create OpenTelemetry Collector daemonset for host metrics, kubelet stats, and container logs.~~
- ~~Create OpenTelemetry Collector RBAC.~~
- ~~Externalize all observability replicas through `override-config/replication.yaml`.~~
- ~~Externalize all observability resource requests/limits through `override-config/resources.yaml`.~~
- ~~Rename collector manifest files from `otel-*` to `telemetry-*` to avoid editor schema confusion.~~

## Current Layout

```text
gitops/apps/observability/
  obs-foundation/
    namespace.yaml
    kustomization.yaml
    values-grafana-operator.yaml
    values-opentelemetry-operator.yaml

  obs-backends/
    kustomization.yaml
    values-kube-prometheus-stack.yaml
    values-mimir.yaml
    values-loki.yaml
    values-tempo.yaml
    telemetry-rbac.yaml
    telemetry-gateway.yaml
    telemetry-daemonset.yaml
    grafana.yaml
    grafana-datasources.yaml
```

## Data Flow

- App metrics/logs/traces:
  - apps send OTLP to OpenTelemetry gateway.
  - gateway sends metrics to Mimir, logs to Loki, and traces to Tempo.
- Node/container telemetry:
  - daemonset collects host metrics, kubelet stats, and container logs.
  - daemonset forwards telemetry to the OpenTelemetry gateway.
- Prometheus:
  - `kube-prometheus-stack` deploys Prometheus and Alertmanager.
  - Prometheus remote-writes metrics to Mimir.
- Grafana:
  - Grafana Operator manages the Grafana instance.
  - Mimir is the default metrics datasource.
  - Prometheus is available as a local/debug datasource.
  - Loki and Tempo are configured with trace/log correlation.

## Remaining Work

- Add Grafana route through the existing Istio public gateway.
- Confirm exact in-cluster service names after Helm render/sync:
  - Mimir gateway.
  - Loki gateway.
  - Tempo distributor and query frontend.
  - OpenTelemetry gateway collector service.
- Add OpenTelemetry `Instrumentation` CRs for application auto-instrumentation where needed.
- Add Kubernetes events collection if it is still required.
- Add Grafana folders and dashboards:
  - cluster health
  - Argo CD
  - Istio gateway
  - Garage
  - OpenEBS
  - Percona
  - Cilium
  - cert-manager
  - MetalLB
  - Kyverno
- Add alerting rules after dashboards show reliable baseline data:
  - `PrometheusRule`
  - Grafana alert rule groups if needed
- Decide whether Alertmanager should stay in `kube-prometheus-stack` or move alerting fully to Mimir ruler/Alertmanager later.
- Decide whether kube-state-metrics remains Prometheus-scraped or gets replaced by an OpenTelemetry-native Kubernetes object-state collection path later.

## Validation

- ~~YAML parse observability manifests.~~
- ~~Render `gitops/argo-apps/base/observability` with Kustomize.~~
- ~~Check envsubst placeholder wiring between apps.~~
- ~~Check no numeric observability `replicas:` literals remain.~~
- ~~Check no hardcoded Kubernetes resource CPU/memory values remain in observability manifests.~~
- Confirm all observability Argo CD apps are synced and healthy.
- Confirm Garage S3 secrets exist in the `observability` namespace.
- Confirm Prometheus remote write reaches Mimir.
- Confirm OpenTelemetry gateway exports metrics, logs, and traces to the correct backends.
- Confirm OpenTelemetry daemonset collects host metrics, kubelet stats, and container logs.
- Confirm Grafana can query Mimir, Prometheus, Loki, and Tempo.
- Generate a test log line, metric, and trace, then verify each appears in Grafana.
