#!/bin/sh
set -eu

KC_URL="http://keycloak.keycloak.svc.cluster.local"
REALM="oidc"
CLIENT_ID="argocd"

last_data_line() {
  value=""
  cr="$(printf '\r')"

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%"$cr"}"

    case "$line" in
      "" | id | value)
        continue
        ;;
    esac

    value="$line"
  done <<EOF
$1
EOF

  printf "%s" "$value"
}

for attempt in $(seq 1 60); do
  if /opt/keycloak/bin/kcadm.sh config credentials \
    --server "$KC_URL" \
    --realm master \
    --user "$KEYCLOAK_ADMIN_USERNAME" \
    --password "$KEYCLOAK_ADMIN_PASSWORD" >/dev/null 2>&1; then
    break
  fi

  if [ "$attempt" -eq 60 ]; then
    echo "Timed out waiting for Keycloak admin API."
    exit 1
  fi

  sleep 10
done

client_uuid=""
for attempt in $(seq 1 60); do
  clients_output="$(
    /opt/keycloak/bin/kcadm.sh get clients \
      -r "$REALM" \
      -q clientId="$CLIENT_ID" \
      --fields id \
      --format csv \
      --noquotes 2>/dev/null || true
  )"
  client_uuid="$(last_data_line "$clients_output")"

  if [ -n "$client_uuid" ] && [ "$client_uuid" != "id" ]; then
    break
  fi

  if [ "$attempt" -eq 60 ]; then
    echo "Timed out waiting for Keycloak client ${REALM}/${CLIENT_ID}."
    exit 1
  fi

  sleep 10
done

client_secret_output="$(
  /opt/keycloak/bin/kcadm.sh get "clients/${client_uuid}/client-secret" \
    -r "$REALM" \
    --fields value \
    --format csv \
    --noquotes 2>/dev/null || true
)"
client_secret="$(last_data_line "$client_secret_output")"

if [ -z "$client_secret" ] || [ "$client_secret" = "value" ]; then
  /opt/keycloak/bin/kcadm.sh create "clients/${client_uuid}/client-secret" \
    -r "$REALM" >/dev/null

  client_secret_output="$(
    /opt/keycloak/bin/kcadm.sh get "clients/${client_uuid}/client-secret" \
      -r "$REALM" \
      --fields value \
      --format csv \
      --noquotes
  )"
  client_secret="$(last_data_line "$client_secret_output")"
fi

if [ -z "$client_secret" ] || [ "$client_secret" = "value" ]; then
  echo "Failed to read or generate Keycloak client secret for ${REALM}/${CLIENT_ID}."
  exit 1
fi

printf "%s" "$client_secret" > /work/argocd-client-secret
