#!/usr/bin/env bash
# End-to-end API read/write proof against a LIVE Twenty instance.
# This is the same read/write path the MCP server uses, so a green run here proves
# the MCP integration will work too.
#
# Usage:
#   TWENTY_URL=https://crm.utomat.com TWENTY_API_KEY=eyJ... ./scripts/api-smoke.sh
#
# What it does:
#   1) GET /healthz                       (liveness)
#   2) GET  /rest/leads?limit=1           (READ)
#   3) POST /rest/leads                   (WRITE: create a throwaway lead)
#   4) PATCH /rest/leads/{id}             (WRITE: flip outreachStatus to REPLIED)
#   5) DELETE /rest/leads/{id}            (cleanup)
set -euo pipefail

: "${TWENTY_URL:?set TWENTY_URL, e.g. https://crm.utomat.com}"
: "${TWENTY_API_KEY:?set TWENTY_API_KEY (Settings > APIs & Webhooks)}"
AUTH=(-H "Authorization: Bearer ${TWENTY_API_KEY}" -H "Content-Type: application/json")

echo "== 1. healthz =="
curl -fsS "${TWENTY_URL}/healthz" && echo " OK"

echo "== 2. READ leads =="
curl -fsS "${AUTH[@]}" "${TWENTY_URL}/rest/leads?limit=1" | head -c 400; echo

echo "== 3. CREATE lead =="
CREATE=$(curl -fsS -X POST "${AUTH[@]}" "${TWENTY_URL}/rest/leads" -d '{
  "name": "API smoke test lead",
  "business": "CALL_CREW",
  "outreachStatus": "NOT_CONTACTED"
}')
echo "$CREATE" | head -c 400; echo
ID=$(echo "$CREATE" | sed -n 's/.*"id":"\([0-9a-f-]\{36\}\)".*/\1/p' | head -1)
echo "created id: ${ID:?could not parse created id}"

echo "== 4. UPDATE lead -> outreachStatus REPLIED =="
curl -fsS -X PATCH "${AUTH[@]}" "${TWENTY_URL}/rest/leads/${ID}" -d '{"outreachStatus":"REPLIED"}' | head -c 400; echo

echo "== 5. DELETE test lead =="
curl -fsS -X DELETE "${AUTH[@]}" "${TWENTY_URL}/rest/leads/${ID}" >/dev/null && echo "cleaned up ${ID}"

echo
echo "READ/WRITE smoke test PASSED."
echo "NOTE: field API names (business, outreachStatus, option values like CALL_CREW/REPLIED)"
echo "must match what you created. See them in Settings > Data model, or GET /rest/metadata."
