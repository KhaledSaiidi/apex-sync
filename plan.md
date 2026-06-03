# Observability Platform Plan

## Goal

Deploy observability as a GitOps-managed platform layer using:

* Grafana Mimir for metrics storage.
* Grafana Loki for logs storage.
* Grafana Tempo for traces storage.
* Grafana Alloy as the primary telemetry collection and forwarding layer.
* Grafana Operator for Grafana, datasources, folders, dashboards, and dashboard lifecycle.
* Prometheus Operator CRDs only as the Kubernetes monitoring API contract.
* OpenTelemetry Operator for application auto-instrumentation and optional advanced OpenTelemetry pipelines.

The target design is fully declarative and managed through Argo CD.

## Core Design Decision

The observability stack must not use OpenTelemetry Collector as the default collector for everything.

The default collection model is:

* Alloy DaemonSet for node-local collection:

  * container logs
  * pod logs
  * node-local telemetry
  * optional Kubernetes events collection

* Alloy Gateway or Alloy Deployment for centralized collection:

  * OTLP metrics, logs, and traces from applications
  * ServiceMonitor and PodMonitor scraping
  * forwarding metrics to Mimir
  * forwarding logs to Loki
  * forwarding traces to Tempo

OpenTelemetry Collector may still be used only when a specific OpenTelemetry Collector feature is required and cannot be handled cleanly by Alloy.

## Scope

Keep observability under:

```text
gitops/apps/observability/
```

Use three Argo CD child apps instead of only two:

```text
obs-foundation
obs-backends
obs-collectors
```

Optional later app:

```text
obs-configuration
```

The reason for separating collectors from backends is to avoid coupling backend lifecycle with telemetry pipeline lifecycle. Mimir, Loki, and Tempo are stateful systems. Alloy configuration changes should not be tied to backend upgrades.

## Namespaces

Use one namespace for the full observability platform unless there is a strict security requirement to split it:

```text
observability
```

All of the following live in the same namespace:

* Grafana Operator
* OpenTelemetry Operator
* Grafana instance
* Mimir
* Loki
* Tempo
* Alloy
* datasource CRs
* dashboard CRs
* instrumentation CRs
* monitoring rules

## Storage

Use Garage S3 buckets for:

* Mimir blocks
* Loki chunks/ruler/admin data if required
* Tempo blocks

Garage S3 credentials must be provided through reflected secrets or ExternalSecrets before deploying the backends.

The observability backends must not rely on bundled demo MinIO, local filesystem storage, or ephemeral storage for production-like environments.

## Argo CD Sync Model

### Wave -3: Prerequisites

Deploy:

* `observability` namespace
* Garage S3 secrets
* object storage bucket references
* ExternalSecret or reflected Secret objects
* service accounts
* IAM/workload identity if applicable
* NetworkPolicies if used
* certificates and gateway prerequisites if needed

### Wave -2: Foundation APIs and Operators

Deploy:

* Prometheus Operator CRDs only
* Grafana Operator
* OpenTelemetry Operator
* cert-manager dependency if the OpenTelemetry Operator webhook requires it and it is not already present

Important: Prometheus Operator CRDs are installed only to provide Kubernetes API types such as:

* `ServiceMonitor`
* `PodMonitor`
* `PrometheusRule`
* `Probe`
* `ScrapeConfig` if needed

Do not install a fake or operator-only `kube-prometheus-stack` just to get CRDs.

### Wave -1: Backend Configuration Prerequisites

Deploy:

* Mimir configuration secrets
* Loki configuration secrets
* Tempo configuration secrets
* Grafana admin secret
* datasource secret references
* gateway certificates if Grafana is exposed through Istio

### Wave 0: Stateful Observability Backends

Deploy with Helm values managed in Git:

* `mimir-distributed`
* `loki`
* `tempo-distributed`

Production requirements:

* external Garage S3 object storage
* explicit retention
* explicit resource requests and limits
* explicit replica counts
* anti-affinity or topology spread where possible
* persistence where required
* compactor enabled where required
* query/frontend limits configured
* ingestion limits configured
* self-monitoring enabled where possible

### Wave 1: Grafana

Deploy Grafana through Grafana Operator.

Resources:

* `Grafana`
* `GrafanaDatasource`
* `GrafanaFolder`
* later `GrafanaDashboard`
* later Grafana alerting resources if used

Grafana datasources:

* Mimir as the default metrics datasource
* Loki as the logs datasource
* Tempo as the traces datasource
* Prometheus only if a local Prometheus is intentionally kept for debugging or rule evaluation

Do not deploy Grafana through both Helm and Grafana Operator. Grafana must have one owner.

### Wave 2: Collection Layer

Deploy Alloy as two separate logical components.

#### 1. Alloy DaemonSet

Purpose:

* collect container logs from every node
* collect pod logs
* optionally collect Kubernetes events
* optionally collect node-local metrics

This component should be deployed as a DaemonSet.

It forwards:

* logs to Loki directly or through the Alloy Gateway
* node-local metrics to Mimir directly or through the Alloy Gateway

#### 2. Alloy Gateway / Alloy Deployment

Purpose:

* receive OTLP from applications
* receive forwarded telemetry from Alloy DaemonSet if using a gateway pattern
* scrape `ServiceMonitor` resources
* scrape `PodMonitor` resources
* remote-write metrics to Mimir
* write logs to Loki
* export traces to Tempo

This component should be deployed as a Deployment or StatefulSet depending on the clustering and scaling model.

It should expose internal services for:

* OTLP gRPC
* OTLP HTTP
* optional Prometheus scrape endpoints for Alloy self-metrics

### Wave 3: Declarative Observability Configuration

Deploy:

* `ServiceMonitor`
* `PodMonitor`
* `PrometheusRule`
* `GrafanaDashboard`
* `GrafanaFolder`
* `GrafanaDatasource`
* `Instrumentation`
* optional `OpenTelemetryCollector` only for special use cases

This wave should not deploy infrastructure. It should only deploy observability configuration.

## Revised Repository Layout

```text
gitops/apps/observability/
  obs-foundation/
    namespace.yaml
    kustomization.yaml
    values-prometheus-operator-crds.yaml
    values-grafana-operator.yaml
    values-opentelemetry-operator.yaml

  obs-backends/
    kustomization.yaml
    values-mimir.yaml
    values-loki.yaml
    values-tempo.yaml
    backend-secrets.yaml
    backend-networkpolicy.yaml

  obs-grafana/
    kustomization.yaml
    grafana.yaml
    grafana-datasources.yaml
    grafana-folders.yaml
    grafana-route.yaml

  obs-collectors/
    kustomization.yaml
    alloy-rbac.yaml
    alloy-logs-daemonset-values.yaml
    alloy-gateway-values.yaml
    alloy-config-logs.yaml
    alloy-config-gateway.yaml

  obs-configuration/
    kustomization.yaml
    servicemonitors/
    podmonitors/
    prometheusrules/
    dashboards/
    instrumentation/
```

If you want fewer apps, `obs-grafana` may be merged into `obs-backends`, but `obs-collectors` should remain separate.

## Corrected Data Flow

### Metrics From Kubernetes Infrastructure

```text
node-exporter / kube-state-metrics / kubelet / app metrics
        ↓
ServiceMonitor / PodMonitor
        ↓
Alloy Gateway
        ↓
Mimir
        ↓
Grafana
```

### Application OTLP Metrics

```text
Application
        ↓ OTLP
Alloy Gateway
        ↓
Mimir
        ↓
Grafana
```

### Logs

```text
Container logs on nodes
        ↓
Alloy DaemonSet
        ↓
Loki
        ↓
Grafana
```

or, if using a gateway pattern:

```text
Container logs on nodes
        ↓
Alloy DaemonSet
        ↓
Alloy Gateway
        ↓
Loki
        ↓
Grafana
```

### Traces

```text
Application with SDK or auto-instrumentation
        ↓ OTLP
Alloy Gateway
        ↓
Tempo
        ↓
Grafana
```

### Dashboards

```text
GrafanaDashboard CR
        ↓
Grafana Operator
        ↓
Grafana instance
```

### Datasources

```text
GrafanaDatasource CR
        ↓
Grafana Operator
        ↓
Grafana instance
```

### Auto-Instrumentation

```text
Instrumentation CR
        ↓
OpenTelemetry Operator
        ↓
application pod injection
        ↓
application sends OTLP to Alloy Gateway
```

## What Must Be Removed From the Current Plan

Remove the following assumptions:

* OpenTelemetry Collector is the main collector for app telemetry, container logs, and node metrics.
* Alloy is not deployed.
* Observability should stay limited to two Argo CD child apps.
* `kube-prometheus-stack` is required as the main infrastructure metrics runtime.
* Prometheus remote-write to Mimir is the preferred long-term path if Alloy can scrape `ServiceMonitor` and `PodMonitor` directly.
* Alertmanager should automatically stay inside `kube-prometheus-stack`.

## What May Stay From the Current Plan

Keep:

* GitOps-managed observability.
* One `observability` namespace.
* Garage S3 object storage for Mimir, Loki, and Tempo.
* Prometheus Operator CRDs installed separately.
* Grafana Operator.
* OpenTelemetry Operator.
* Mimir, Loki, and Tempo deployed through Helm values.
* Grafana managed by Grafana Operator.
* Datasources managed declaratively.
* Replicas externalized through `override-config/replication.yaml`.
* Resources externalized through `override-config/resources.yaml`.

## Decision: kube-prometheus-stack

Do not deploy `kube-prometheus-stack` by default.

Use this instead:

* Prometheus Operator CRDs only
* kube-state-metrics chart
* prometheus-node-exporter chart
* ServiceMonitor/PodMonitor resources
* Alloy Gateway scraping these resources
* Mimir as the long-term metrics backend

Only keep `kube-prometheus-stack` if there is a clear reason to run a local Prometheus and Alertmanager, such as:

* temporary migration
* local rule evaluation
* compatibility with existing alerts
* debugging during rollout

If kept temporarily:

* disable Grafana
* disable CRDs
* remote-write to Mimir
* document it as transitional
* define a later migration plan to Alloy-native scraping and Mimir ruler/alerting

## Decision: Alerting

Alerting must be explicitly designed.

Preferred long-term model:

* metrics stored in Mimir
* alert rules evaluated by Mimir ruler
* Alertmanager-compatible alert routing
* Grafana dashboards and optional Grafana-managed alerts only where useful

Temporary model:

* Prometheus from kube-prometheus-stack evaluates `PrometheusRule`
* Alertmanager from kube-prometheus-stack handles routing
* Prometheus remote-writes metrics to Mimir

Do not leave alerting undecided permanently.

## Decision: OpenTelemetry Collector

Do not use OpenTelemetry Collector as the default telemetry backbone.

Use OpenTelemetry Operator for:

* `Instrumentation` CRs
* auto-instrumentation
* optional `OpenTelemetryCollector` CRs for specific advanced pipelines

Examples where an OpenTelemetryCollector may be justified:

* vendor-specific exporter not handled by Alloy
* complex processor chain needed temporarily
* migration from existing OTel Collector config
* team already owns an OTel pipeline that cannot be replaced immediately

Otherwise, use Alloy.

## Decision: Grafana

Grafana is owned by Grafana Operator.

Deploy:

* `Grafana`
* `GrafanaDatasource`
* `GrafanaFolder`
* `GrafanaDashboard`

Do not deploy Grafana from the kube-prometheus-stack chart.

Do not deploy Grafana from the standalone Grafana Helm chart unless you decide to abandon the Grafana Operator model.

## Remaining Work

### Backend Validation

* Confirm Garage S3 secrets exist in `observability`.
* Confirm Mimir can write blocks to Garage.
* Confirm Loki can write chunks and index data to Garage.
* Confirm Tempo can write blocks to Garage.
* Confirm retention and compaction are enabled where required.
* Confirm resource requests and limits are wired from override files.
* Confirm all backend pods have stable readiness.

### Alloy Validation

* Deploy Alloy DaemonSet.
* Confirm Alloy DaemonSet reads container logs.
* Confirm log labels are controlled and not high-cardinality.
* Confirm logs arrive in Loki.
* Deploy Alloy Gateway.
* Confirm OTLP gRPC and HTTP endpoints are reachable inside the cluster.
* Confirm Alloy Gateway discovers ServiceMonitor resources.
* Confirm Alloy Gateway discovers PodMonitor resources.
* Confirm Alloy Gateway remote-writes metrics to Mimir.
* Confirm Alloy Gateway exports traces to Tempo.
* Confirm Alloy self-metrics are scraped.

### Grafana Validation

* Confirm Grafana instance is created by Grafana Operator.
* Confirm Grafana datasource CRs are reconciled.
* Confirm Mimir datasource works.
* Confirm Loki datasource works.
* Confirm Tempo datasource works.
* Confirm trace-to-logs correlation works.
* Confirm logs-to-traces correlation works where trace IDs exist.
* Confirm dashboards are provisioned through `GrafanaDashboard` CRs.

### Instrumentation Validation

* Add `Instrumentation` CRs only for selected applications.
* Start with non-critical services.
* Validate pod injection behavior.
* Validate app startup.
* Validate trace generation.
* Validate traces in Tempo.
* Validate service graph or trace search in Grafana.

### Dashboards To Add

Add dashboards in this order:

1. Observability stack self-monitoring
2. Kubernetes cluster overview
3. Node health
4. Pod health
5. Argo CD
6. Istio gateway
7. Cilium
8. cert-manager
9. Garage
10. OpenEBS
11. Percona
12. Kyverno
13. MetalLB

Do not add all dashboards blindly. Add dashboards only when the required metrics/logs/traces are confirmed available.

### Alerts To Add

Add alerts after dashboards prove the data is reliable.

First alert groups:

* Mimir ingestion failures
* Mimir query failures
* Loki ingestion failures
* Loki write errors
* Tempo ingestion failures
* Alloy remote-write failures
* Alloy dropped logs/spans/metrics
* object storage errors
* pod crash loops in observability namespace
* PVC usage if applicable
* high cardinality growth
* no logs received from a node
* no metrics received from a cluster

## Validation Checklist

### GitOps

* Render all observability apps with Kustomize.
* Render all Helm values.
* Confirm Argo CD sync waves are correct.
* Confirm CRDs are applied before CRs.
* Confirm no collector CR is applied before its operator exists.
* Confirm no Grafana CR is applied before Grafana Operator exists.
* Confirm all Argo CD apps are Synced and Healthy.

### Backends

* Mimir is healthy.
* Loki is healthy.
* Tempo is healthy.
* All three can use Garage S3.
* Compaction is running where required.
* Retention is configured.
* Replicas are controlled through `override-config/replication.yaml`.
* Resources are controlled through `override-config/resources.yaml`.

### Collection

* Alloy DaemonSet is running on all expected nodes.
* Alloy Gateway is running with the expected number of replicas.
* Alloy discovers ServiceMonitor resources.
* Alloy discovers PodMonitor resources.
* Alloy receives OTLP metrics.
* Alloy receives OTLP logs if enabled.
* Alloy receives OTLP traces.
* Alloy sends metrics to Mimir.
* Alloy sends logs to Loki.
* Alloy sends traces to Tempo.

### Grafana

* Grafana is created by the operator.
* Datasources are reconciled.
* Folders are reconciled.
* Dashboards are reconciled.
* Mimir queries work.
* Loki queries work.
* Tempo queries work.
* Correlations work.

### End-to-End Test

Generate:

* one test metric
* one test log line
* one test trace

Verify:

* metric appears in Mimir through Grafana
* log appears in Loki through Grafana
* trace appears in Tempo through Grafana
* trace ID can correlate logs and traces if application logging supports it

## Final Target Architecture

```text
GitOps Repository
      ↓
Argo CD
      ↓
Foundation
  - namespace
  - Prometheus Operator CRDs
  - Grafana Operator
  - OpenTelemetry Operator
      ↓
Backends
  - Mimir
  - Loki
  - Tempo
      ↓
Grafana
  - Grafana CR
  - Datasources
  - Folders
  - Dashboards
      ↓
Collectors
  - Alloy DaemonSet
  - Alloy Gateway
      ↓
Configuration
  - ServiceMonitor
  - PodMonitor
  - PrometheusRule
  - Instrumentation
  - Dashboards
```

## Final Rule

The long-term production model is:

```text
Alloy collects.
Mimir stores metrics.
Loki stores logs.
Tempo stores traces.
Grafana visualizes.
Grafana Operator manages Grafana resources.
OpenTelemetry Operator injects instrumentation.
Prometheus Operator CRDs provide the monitoring API.
```

OpenTelemetry Collector and kube-prometheus-stack are not the default backbone of this design. They are optional transitional or special-purpose components only.
