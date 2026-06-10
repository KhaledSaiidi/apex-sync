#!/bin/sh
set -eu

root_password="$(cat /work/root-password)"
keycloak_username="$(cat /work/keycloak-username)"
keycloak_password="$(cat /work/keycloak-password)"

mysql \
  --protocol=TCP \
  --host=mysql-cluster-haproxy.stateful-resources.svc.cluster.local \
  --port=3306 \
  --user=root \
  --password="$root_password" <<SQL
CREATE DATABASE IF NOT EXISTS keycloak CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$keycloak_username'@'%' IDENTIFIED BY '$keycloak_password';
ALTER USER '$keycloak_username'@'%' IDENTIFIED BY '$keycloak_password';
GRANT ALL PRIVILEGES ON keycloak.* TO '$keycloak_username'@'%';
FLUSH PRIVILEGES;
SQL
