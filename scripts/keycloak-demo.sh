#!/usr/bin/env bash
set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8090}"
CLIENT_ID="${SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_CLIENT_ID:-urlaubsverwaltung}"
CLIENT_SECRET="${SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_CLIENT_SECRET:-urlaubsverwaltung-secret}"
USERNAME="${OIDC_USERNAME:-office@urlaubsverwaltung.cloud}"
PASSWORD="${OIDC_PASSWORD:-secret}"

ACCESS_TOKEN=$(curl -s "$KEYCLOAK_URL/realms/urlaubsverwaltung/protocol/openid-connect/token" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "client_secret=$CLIENT_SECRET" \
  --data-urlencode 'scope=openid email profile' \
  --data-urlencode 'grant_type=password' \
  --data-urlencode "username=$USERNAME" \
  --data-urlencode "password=$PASSWORD" \
  | jq -r '.access_token')

echo "Bearer token (expires soon):"
echo "$ACCESS_TOKEN"