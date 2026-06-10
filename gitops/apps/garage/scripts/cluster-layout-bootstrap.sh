#!/bin/sh
set -eu

garage_namespace="${GARAGE_NAMESPACE:?missing GARAGE_NAMESPACE}"
garage_label_selector="${GARAGE_LABEL_SELECTOR:?missing GARAGE_LABEL_SELECTOR}"
garage_replica_count="${GARAGE_REPLICA_COUNT:?missing GARAGE_REPLICA_COUNT}"

echo "Waiting for $garage_replica_count Garage pods in namespace $garage_namespace"

WAIT_GARAGE_NAMESPACE="$garage_namespace" \
WAIT_GARAGE_LABEL_SELECTOR="$garage_label_selector" \
WAIT_GARAGE_REPLICA_COUNT="$garage_replica_count" \
  timeout 900 sh -ec '
  while [ "$(kubectl get pod \
    --namespace "$WAIT_GARAGE_NAMESPACE" \
    --selector "$WAIT_GARAGE_LABEL_SELECTOR" \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l | tr -d " ")" != "$WAIT_GARAGE_REPLICA_COUNT" ]; do
    sleep 5
  done
'

kubectl get pod \
  --namespace "$garage_namespace" \
  --selector "$garage_label_selector" \
  --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\t"}{.spec.nodeName}{"\n"}{end}' > /tmp/garage-pods.tsv

echo "Discovered Garage pods:"
cat /tmp/garage-pods.tsv

: > /tmp/garage-assignments.tsv

while IFS="$(printf '\t')" read -r pod_name pod_ip kubernetes_node_name; do
  [ -n "$pod_name" ] || continue

  echo "Collecting node data for $pod_name"
  until kubectl exec -n "$garage_namespace" "$pod_name" -- /garage node id >/tmp/garage-node-id 2>/dev/null; do
    sleep 5
  done

  pvc_capacity="$(kubectl get pvc \
    --namespace "$garage_namespace" \
    "data-$pod_name" \
    -o jsonpath="{.spec.resources.requests.storage}")"

  case "$pvc_capacity" in
    *Gi)
      garage_capacity="${pvc_capacity%Gi}GB"
      ;;
    *)
      echo "Unsupported Garage PVC capacity format for pod $pod_name" >&2
      exit 1
      ;;
  esac

  garage_zone="$(kubectl get node "$kubernetes_node_name" -o jsonpath="{.metadata.labels.topology\.kubernetes\.io/zone}" 2>/dev/null || true)"
  if [ -z "$garage_zone" ]; then
    garage_zone="$kubernetes_node_name"
  fi

  garage_node_id="$(cut -d@ -f1 /tmp/garage-node-id | tr -d "\n")"
  printf "%s\t%s\t%s\t%s\n" "$pod_ip" "$garage_node_id" "$garage_zone" "$garage_capacity" >> /tmp/garage-assignments.tsv
done </tmp/garage-pods.tsv

echo "Computed Garage assignments:"
cat /tmp/garage-assignments.tsv

WAIT_GARAGE_NAMESPACE="$garage_namespace" \
  timeout 900 sh -ec '
  until kubectl exec -n "$WAIT_GARAGE_NAMESPACE" garage-0 -- /garage status >/tmp/garage-status.txt 2>/dev/null; do
    sleep 5
  done
'

echo "Current Garage status:"
cat /tmp/garage-status.txt

if ! grep -q "NO ROLE ASSIGNED" /tmp/garage-status.txt; then
  expected_assignment_count="$(wc -l < /tmp/garage-assignments.tsv | tr -d ' ')"
  matched_assignment_count="0"

  while IFS="$(printf '\t')" read -r assignment_tag assignment_node_id assignment_zone assignment_capacity; do
    [ -n "$assignment_tag" ] || continue

    if grep -F "$assignment_tag" /tmp/garage-status.txt | grep -F "$assignment_zone" | grep -F "$assignment_capacity" >/dev/null; then
      matched_assignment_count="$((matched_assignment_count + 1))"
    fi
  done </tmp/garage-assignments.tsv

  if [ "$matched_assignment_count" = "$expected_assignment_count" ]; then
    echo "Garage layout already matches the desired topology"
    exit 0
  fi
fi

while IFS="$(printf '\t')" read -r assignment_tag assignment_node_id assignment_zone assignment_capacity; do
  [ -n "$assignment_tag" ] || continue

  echo "Assigning $assignment_node_id to zone=$assignment_zone capacity=$assignment_capacity tag=$assignment_tag"
  kubectl exec -n "$garage_namespace" garage-0 -- /garage layout assign "$assignment_node_id" -z "$assignment_zone" -c "$assignment_capacity" -t "$assignment_tag"
done </tmp/garage-assignments.tsv

kubectl exec -n "$garage_namespace" garage-0 -- /garage layout show >/tmp/garage-layout.txt
echo "Garage layout before apply:"
cat /tmp/garage-layout.txt

layout_version="$(sed -n 's/^Current cluster layout version:[[:space:]]*//p' /tmp/garage-layout.txt | tr -d ' ' | sed -n '1p')"
next_layout_version="$((layout_version + 1))"

echo "Applying Garage layout version $next_layout_version"
kubectl exec -n "$garage_namespace" garage-0 -- /garage layout apply --version "$next_layout_version"
