# MCP server for Twenty (Claude Code)

Twenty's self-hosted build does **not** bundle an MCP server (it ships REST + GraphQL
APIs only). So we use the community Node server **`mhenry3164/twenty-crm-mcp-server`**
(MIT, Node ≥18). It's a **stdio** server: Claude Code launches it as a local subprocess,
and it talks to your Twenty over https using an API key. Nothing needs to listen on a
public port, and you can run it from any machine — that's how you "reconnect elsewhere."

## 1. Get a Twenty API key
Twenty UI → **Settings → APIs & Webhooks → Create API key**. Copy it (shown once).

## 2. Install the server (on whichever machine runs Claude Code)
```bash
git clone https://github.com/mhenry3164/twenty-crm-mcp-server.git
cd twenty-crm-mcp-server
npm install
# note the absolute path to index.js:
pwd   # -> e.g. /home/you/twenty-crm-mcp-server
```

## 3. Add it to Claude Code
**Option A — CLI (recommended):**
```bash
claude mcp add twenty-crm \
  --scope user \
  --env TWENTY_API_KEY=PASTE_YOUR_TWENTY_API_KEY \
  --env TWENTY_BASE_URL=https://crm.utomat.com \
  -- node /ABSOLUTE/PATH/TO/twenty-crm-mcp-server/index.js
```

**Option B — config file:** paste the `mcpServers` block from `claude-mcp-config.json`
into your project's `.mcp.json` (or `claude mcp add-json twenty-crm '<json>'`), fixing
the `index.js` path and API key. Then in Claude Code run `/mcp` to confirm `twenty-crm`
shows **connected**.

## 4. Prove read + write end to end
The server's typed tools cover the standard objects (people, companies, tasks, notes)
plus `get_metadata_objects` / `search_records`. Use a standard object for the connectivity
proof so it doesn't depend on the custom `Lead` schema:

In Claude Code, ask:
1. **Read:**  "Use twenty-crm to list the first 3 companies."  → returns rows (READ ok).
2. **Write:** "Use twenty-crm to create a company called 'MCP Test Co', then read it
   back and show its id."  → creates + reads (WRITE ok).
3. Clean up: "Delete the company 'MCP Test Co'."

> Heads-up (honest caveat): this community server's first-class tools target
> people/companies/tasks/notes, not the custom **Lead** object. It can still see Lead
> via `get_metadata_objects`/`search_records`, but the reliable, version-proof path for
> Lead automation (e.g. the n8n reply-tracking) is the REST/GraphQL API — see
> `../integrations/n8n-reply-update.md` and `../scripts/api-smoke.sh`. The
> `api-smoke.sh` script is a deterministic Lead read→create→update→delete proof you can
> run anytime.

## 5. Reconnect from another machine
Repeat steps 2–3 on the new machine (clone, `npm install`, `claude mcp add …` with the
same API key and `TWENTY_BASE_URL`). Keys are per-machine in your local Claude config;
the repo here holds no secrets.
