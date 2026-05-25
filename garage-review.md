# Overview

Garage is now deployed as:

- ArgoCD app
- Kustomize app wrapper
- Helm chart for the main StatefulSet
- small Argo hook Jobs for bootstrap and lifecycle tasks

The storage model is correct:

`OpenEBS PVC -> Garage -> S3`

Garage consumes Kubernetes storage and exposes S3. It is not a Kubernetes storage provider.

# Current Architecture

- `StatefulSet`
- `3` replicas
- `replicationFactor: 3`
- separate `meta` and `data` PVCs
- `meta: 8Gi`
- `data: 20Gi`
- path-style S3 API exposure
- required pod anti-affinity on `kubernetes.io/hostname`

Bootstrap flow:

1. `garage-backup-bootstrap` SA/RBAC sync first
2. `garage-internal-secrets-bootstrap` creates `garage-rpc-secret` and `garage-admin-token` in-cluster
3. Helm deploys Garage using those existing secrets
4. `garage-cluster-layout-bootstrap` reconciles layout after pods are ready
5. `garage-backup-bootstrap` creates bucket/key access and writes `percona-backup-garage-s3`
6. reflector mirrors that secret to `stateful-resources`
7. `garage-backup-lifecycle` applies lifecycle rules

# Findings

## Critical Issues

1. Secret material is no longer stored in Git, which is correct, but it is still generated imperatively by Jobs. This is acceptable operationally, but it is not fully declarative GitOps.

2. The bootstrap flow still depends on `kubectl exec` into Garage pods for layout, key, and bucket operations. It works, but it is still runtime automation, not desired state expressed directly in manifests.

3. Zone handling is improved but still basic. The layout job prefers `topology.kubernetes.io/zone` and falls back to `nodeName`. This is better than before, but still depends on node labeling quality.

## Improvements

1. `envsubst` breakage is fixed inside the Garage app by making the shell logic envsubst-safe.

2. Helm secret drift is fixed by precreating `garage-rpc-secret` and `garage-admin-token` before the chart runs.

3. Garage image pinning is fixed with `v2.3.1`.

4. Metadata storage sizing is improved from `1Gi` to `8Gi`.

5. Scheduling is stronger with required anti-affinity instead of preferred anti-affinity.

6. S3 exposure is simpler and safer now because the deployment uses path-style access instead of bucket subdomains.

## Nice To Have

1. Add `ServiceMonitor` and alerts.
2. Add Garage-specific backup and restore runbooks.
3. Replace runtime secret generation with a proper secret manager later if needed.

# GitOps Alignment Score (/10)

**6/10**

Better than before:

- no secrets in Git
- no Helm render-time secret drift
- envsubst-safe bootstrap

Still not fully declarative because bootstrap and secret generation are still handled by Jobs.

# Production Readiness Score (/10)

**7/10**

Good enough for a clear and reliable production-style baseline:

- stable StatefulSet
- pinned Garage version
- persistent storage
- stronger scheduling
- no secret material in Git
- automated bootstrap and secret mirroring

Main remaining gaps are observability, DR, and the fact that some Garage operations still happen through runtime Jobs.

# Recommended Target Architecture

Keep:

- ArgoCD
- Helm + Kustomize wrapper
- StatefulSet
- PVC-backed Garage
- in-cluster secret generation
- reflected S3 secret for consumers

Improve later:

- monitoring and alerting
- documented backup and restore
- cleaner zone labeling
- optional external secret manager if the platform grows

# Migration Plan

1. Keep the current structure as the working baseline.
2. Validate the bootstrap Jobs on a fresh cluster.
3. Add monitoring next.
4. Add DR and restore testing next.
5. Only revisit deeper GitOps refactoring if the current model becomes operationally painful.
