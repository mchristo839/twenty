#!/usr/bin/env bash
# Daily Postgres backup for the Twenty stack.
# - pg_dump (custom format) of the `default` DB from the `db` container
# - writes a dated file to ./backups
# - keeps the most recent 14, deletes older
# Designed to run from /opt/twenty (cron entry is in the README / crontab.txt).
set -euo pipefail

cd "$(dirname "$0")/.."

# Load PG creds from .env without exporting the whole file.
PG_USER="$(grep -E '^PG_DATABASE_USER=' .env | cut -d= -f2- || echo postgres)"
PG_USER="${PG_USER:-postgres}"
PG_DB="$(grep -E '^PG_DATABASE_NAME=' .env | cut -d= -f2- || echo default)"
PG_DB="${PG_DB:-default}"

BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
OUT="$BACKUP_DIR/twenty_${PG_DB}_${STAMP}.dump"

echo "[$(date -Is)] Dumping $PG_DB -> $OUT"
# -Fc = custom format (compressed, restorable with pg_restore).
docker compose exec -T db pg_dump -U "$PG_USER" -Fc "$PG_DB" > "$OUT"

# Verify the dump is non-trivial in size before we prune old ones.
if [[ ! -s "$OUT" ]]; then
  echo "ERROR: dump is empty, aborting prune." >&2
  exit 1
fi

# Retention: keep newest 14 .dump files, remove the rest.
ls -1t "$BACKUP_DIR"/twenty_*.dump 2>/dev/null | tail -n +15 | while read -r old; do
  echo "Pruning old backup: $old"
  rm -f "$old"
done

echo "[$(date -Is)] Backup OK ($(du -h "$OUT" | cut -f1))"
