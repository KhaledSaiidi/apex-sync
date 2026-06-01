# Monitoring Plan

- Goal: add LGTM plus OpenTelemetry as the next platform layer.
- Scope: keep the stack GitOps-managed under `gitops/`, with chart versions coming from config.
- Namespace: use one `monitoring` namespace unless a chart strongly needs its own.
- Storage: use Garage S3 buckets for Loki, Tempo, and Mimir object storage.
- Access: expose only Grafana through the existing Istio public gateway.
- Secrets: create one GitOps-safe pattern for S3 credentials and Grafana admin credentials.

## Deployment Steps

- Add monitoring app-of-apps entries and sync waves.
- Add shared monitoring resources: namespace, secrets, buckets, routes, and values files.
- Deploy Mimir for metrics.
  - Chart: `grafana/mimir-distributed`
  - Repo: `https://grafana.github.io/helm-charts`
  - Latest chart version: `6.0.6`
- Deploy Loki for logs.
  - Chart: `grafana-community/loki`
  - Repo: `https://grafana-community.github.io/helm-charts`
  - Latest chart version: `17.1.5`
- Deploy Tempo for traces.
  - Chart: `grafana/tempo-distributed`
  - Repo: `https://grafana.github.io/helm-charts`
  - Latest chart version: `1.61.3`
- Deploy OpenTelemetry for collection and forwarding.
  - Chart: `open-telemetry/opentelemetry-kube-stack`
  - Repo: `https://open-telemetry.github.io/opentelemetry-helm-charts`
  - Latest chart version: `0.15.2`
- Deploy Grafana for dashboards and exploration.
  - Chart: `grafana-community/grafana`
  - Repo: `https://grafana-community.github.io/helm-charts`
  - Latest chart version: `12.4.1`

## Wiring

- Configure OpenTelemetry to collect Kubernetes metrics, pod logs, events, and OTLP traces.
- Send metrics to Mimir, logs to Loki, and traces to Tempo.
- Provision Grafana datasources for Mimir, Loki, and Tempo.
- Enable trace-to-logs and trace-to-metrics links in Grafana.

## Dashboards

- Start with cluster health, nodes, pods, namespaces, and workloads.
- Add Argo CD dashboards for app sync and reconciliation health.
- Add ingress dashboards for Istio gateway traffic and errors.
- Add storage dashboards for Garage, OpenEBS, and Percona.
- Add platform dashboards for Cilium, cert-manager, MetalLB, and Kyverno.

## Validation

- Confirm all Argo CD monitoring apps are synced and healthy.
- Confirm Grafana can query Mimir, Loki, and Tempo.
- Generate a test log line, metric, and trace, then verify each appears in Grafana.
- Add alerts only after the dashboards show reliable baseline data.
