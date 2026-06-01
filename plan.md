# Observability Plan

- Goal: add LGTM plus OpenTelemetry as a GitOps-managed platform layer.
- Scope: keep observability under `gitops/`, with chart versions coming from `override-config/gitops.yaml`.
- Namespace: use one `observability` namespace for foundation, runtime stack, and config CRs.
- Storage: use Garage S3 buckets and reflected secrets for Mimir, Loki, and Tempo.
- Access: expose Grafana through the existing Istio public gateway when Grafana is added.
- Sizing: keep replicas in `override-config/replication.yaml` and resources in `override-config/resources.yaml`.

## Deployment Steps

- ~~Create the observability app-of-apps entry and sync waves.~~
- ~~Create `obs-foundation` for namespace, CRDs, and real operators only.~~
- ~~Install Prometheus Operator CRDs for monitoring CRs. (kinds: ServiceMonitor, PodMonitor, PrometheusRule, Prometheus)~~
- ~~Install OpenTelemetry Operator for collector CRs. (kinds: OpenTelemetryCollector, Instrumentation, TargetAllocator, OpAMPBridge)~~
- ~~Install Grafana Operator for Grafana CRs. (kinds: Grafana, GrafanaDashboard, GrafanaDatasource, GrafanaFolder)~~
- ~~Create `obs-core-stack` for runtime observability systems.~~
- ~~Deploy Mimir with Garage S3 object storage.~~
- ~~Deploy Loki with Garage S3 object storage.~~
- ~~Deploy Tempo with Garage S3 object storage and OTLP enabled.~~
- ~~Keep Alloy disabled and use OpenTelemetry as the collector model.~~
- Add `obs-configuration` resources for collectors, Grafana, dashboards, datasources, and rules. (kinds: OpenTelemetryCollector, Instrumentation, Grafana, GrafanaDashboard, GrafanaDatasource, PrometheusRule)

## Wiring

- ~~Reflect Garage monitoring secrets into the `observability` namespace.~~
- ~~Use HTTPS Garage S3 endpoint for Mimir, Loki, and Tempo.~~
- ~~Keep core stack replicas externalized in `override-config/replication.yaml`.~~
- ~~Keep core stack resources externalized in `override-config/resources.yaml`.~~
- Create OpenTelemetryCollector CRs for metrics, logs, traces, and Kubernetes events. (kind: OpenTelemetryCollector)
- Create Instrumentation CRs for application auto-instrumentation where needed. (kind: Instrumentation)
- Send metrics to Mimir, logs to Loki, and traces to Tempo.
- Create Grafana datasource CRs for Mimir, Loki, and Tempo. (kind: GrafanaDatasource)
- Enable trace-to-logs and trace-to-metrics links in Grafana.

## Dashboards

- Create Grafana instance and folder CRs. (kinds: Grafana, GrafanaFolder)
- Add cluster health dashboards for nodes, pods, namespaces, and workloads. (kind: GrafanaDashboard)
- Add Argo CD dashboards for app sync and reconciliation health. (kind: GrafanaDashboard)
- Add Istio gateway dashboards for traffic, latency, and errors. (kind: GrafanaDashboard)
- Add Garage, OpenEBS, and Percona storage dashboards. (kind: GrafanaDashboard)
- Add Cilium, cert-manager, MetalLB, and Kyverno platform dashboards. (kind: GrafanaDashboard)

## Validation

- ~~Render `obs-foundation` through the repo CMP flow.~~
- ~~Render `obs-core-stack` through the repo CMP flow.~~
- ~~Confirm the Loki canary DaemonSet tolerates all taints.~~
- Confirm all observability Argo CD apps are synced and healthy.
- Confirm Garage S3 secrets exist in the `observability` namespace.
- Confirm Grafana can query Mimir, Loki, and Tempo.
- Generate a test log line, metric, and trace, then verify each appears in Grafana.
- Add alerts after dashboards show reliable baseline data. (kinds: PrometheusRule, GrafanaAlertRuleGroup)
