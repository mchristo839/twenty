#!/usr/bin/env bash
# Generate strong secrets into .env (idempotent: only fills placeholders, never
# overwrites values you've already set). Run from /opt/twenty:  ./scripts/gen-secrets.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
  cp .env.example "$ENV_FILE"
  echo "Created .env from .env.example"
fi

# Replace a placeholder value for KEY only if it still looks unset.
set_secret() {
  local key="$1" value="$2"
  local current
  current="$(grep -E "^${key}=" "$ENV_FILE" | head -1 | cut -d= -f2- || true)"
  if [[ -z "$current" || "$current" == __REDACTED__GENERATE_ME__* ]]; then
    # Use a temp file; escape nothing special since our values are base64/hex.
    awk -v k="$key" -v v="$value" 'BEGIN{FS=OFS="="}
      $1==k {print k "=" v; next} {print}' "$ENV_FILE" > "$ENV_FILE.tmp"
    mv "$ENV_FILE.tmp" "$ENV_FILE"
    echo "Set $key"
  else
    echo "Kept existing $key"
  fi
}

# PG password: strong but NO special characters (Twenty requirement) -> hex.
set_secret PG_DATABASE_PASSWORD "$(openssl rand -hex 24)"
# ENCRYPTION_KEY / APP_SECRET: base64 32 bytes.
set_secret ENCRYPTION_KEY "$(openssl rand -base64 32)"
set_secret APP_SECRET "$(openssl rand -base64 32)"

chmod 600 "$ENV_FILE"
echo
echo "Done. Secrets written to $ENV_FILE (perms 600)."
echo "BACK UP your ENCRYPTION_KEY now — losing it means losing all encrypted data."
