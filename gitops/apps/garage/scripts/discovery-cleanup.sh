#!/bin/sh
set -eu

garage_namespace="${GARAGE_NAMESPACE:?missing GARAGE_NAMESPACE}"
garage_label_selector="${GARAGE_LABEL_SELECTOR:?missing GARAGE_LABEL_SELECTOR}"
garage_replica_count="${GARAGE_REPLICA_COUNT:?missing GARAGE_REPLICA_COUNT}"

if ! kubectl get crd garagenodes.deuxfleurs.fr >/dev/null 2>&1; then
  echo "GarageNode CRD not present yet, nothing to clean"
  exit 0
fi

kubectl get garagenodes.deuxfleurs.fr \
  --namespace "$garage_namespace" \
  -l garage.deuxfleurs.fr/service=garage \
  -o name >/tmp/stale-garagenodes.txt 2>/dev/null || true

if [ ! -s /tmp/stale-garagenodes.txt ]; then
  echo "No stale GarageNode objects found"
  exit 0
fi

running_pod_count="$(kubectl get pod \
  --namespace "$garage_namespace" \
  --selector "$garage_label_selector" \
  --field-selector=status.phase=Running \
  --no-headers 2>/dev/null | wc -l | tr -d ' ')"

if [ "$running_pod_count" = "0" ]; then
  echo "No running Garage pods found, deleting all GarageNode discovery objects for a clean bootstrap"
  xargs -r kubectl delete --namespace "$garage_namespace" </tmp/stale-garagenodes.txt
  exit 0
fi

if [ "$running_pod_count" != "0" ] && [ "$running_pod_count" != "$garage_replica_count" ]; then
  echo "Garage has a partial running set ($running_pod_count/$garage_replica_count), skipping discovery cleanup to avoid disrupting a live cluster"
  exit 0
fi

kubectl get pod \
  --namespace "$garage_namespace" \
  --selector "$garage_label_selector" \
  --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}' > /tmp/current-garage-pods.tsv

kubectl get garagenodes.deuxfleurs.fr \
  --namespace "$garage_namespace" \
  -l garage.deuxfleurs.fr/service=garage \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.hostname}{"\t"}{.spec.address}{"\n"}{end}' > /tmp/current-garagenodes.tsv

while IFS="$(printf '\t')" read -r garage_node_name garage_node_hostname garage_node_address; do
  [ -n "$garage_node_name" ] || continue

  if grep -F "$(printf "%s\t%s" "$garage_node_hostname" "$garage_node_address")" /tmp/current-garage-pods.tsv >/dev/null; then
    echo "Keeping active GarageNode $garage_node_name for $garage_node_hostname at $garage_node_address"
    continue
  fi

  echo "Deleting stale GarageNode $garage_node_name for $garage_node_hostname at $garage_node_address"
  kubectl delete --namespace "$garage_namespace" "garagenodes.deuxfleurs.fr/$garage_node_name"
done </tmp/current-garagenodes.tsv
