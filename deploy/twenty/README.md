# Twenty CRM — self-hosted runbook (Contabo VPS)

Single-instance Twenty CRM for cold outreach across **CallCrew**, **Utomat**, and
**Grease Trap Repair**, served at **https://crm.utomat.com** behind your existing
Caddy. Postgres + Redis stay private to the Docker network. Version pinned to a
known-good release.

> **Where to put these files:** copy the contents of this `deploy/twenty/` directory to
> **`/opt/twenty`** on the VPS. The paths in the scripts/cron assume `/opt/twenty`.

> **Heads-up on how this was prepared:** this package was authored in an isolated
> build container that has **no access to your VPS** (161.97.176.176 is unreachable
> from there, and there's no Docker daemon). So the resource check, the live bring-up,
> the admin-user creation, the Caddy reload, and the MCP read/write test are written as
> exact commands for **you** to run on the box (or for me to run in a session that's
> actually connected to it). Everything here is reproducible and committed.

Pinned version: **`TAG=v2.8.3`** (latest stable on Docker Hub as of 2026-05-27).

---

## 0. Pre-flight: resource headroom (HARD REQUIREMENT — do this first)
Twenty + Postgres + Redis wants ~4 GB RAM as a floor, on top of Evolution API,
Caddy, and Paperclip. Check before deploying:
```bash
free -h
docker stats --no-stream
```
- If `free -h` "available" is comfortably **> ~4 GB** beyond what's already in use, proceed.
- If not, **stop** — adding Twenty could OOM-kill your live Evolution API / Paperclip.
  Resize the VPS or free memory first.

## 1. DNS (Cloudflare — confirmed)
`utomat.com` is on Cloudflare (NS `steven/anahi.ns.cloudflare.com`); its apex is already
Cloudflare-proxied. `crm.utomat.com` does not exist yet. In the Cloudflare dashboard for
`utomat.com`:
- Add an **A** record: `crm` → `161.97.176.176`.
- Set it to **DNS only (grey cloud)** so Caddy can complete the Let's Encrypt challenge
  directly (this matches how Caddy already issues certs for your other subdomains).
- *(Alternative: keep it proxied/orange and install a Cloudflare Origin Cert — see the
  Caddyfile comments. DNS-only is simpler; recommended.)*

Verify it resolves to the VPS:
```bash
dig +short crm.utomat.com   # should print 161.97.176.176
```

## 2. Configure
```bash
cd /opt/twenty
cp .env.example .env
./scripts/gen-secrets.sh          # fills PG password + ENCRYPTION_KEY + APP_SECRET
# Confirm in .env:  TAG=v2.8.3,  SERVER_URL=https://crm.utomat.com,  IS_SIGNUP_ENABLED=true
# (Optional AI) paste your Anthropic key into ANTHROPIC_API_KEY=
```
**Back up your `ENCRYPTION_KEY`** somewhere safe — losing it means losing every
encrypted secret in the DB.

## 3. Bring the stack up (start)
```bash
cd /opt/twenty
docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f server   # watch until "healthy"; migrations run on first boot
curl -fsS http://127.0.0.1:3000/healthz && echo OK
```
Postgres/Redis publish **no host ports** (private). `server` publishes only on
`127.0.0.1:3000` (loopback) — nothing public except via Caddy.

## 4. Wiring Caddy to Twenty
Twenty's server is on `127.0.0.1:3000`. Add the site block from
`caddy/crm.utomat.com.Caddyfile` to your Caddyfile, pick the ONE `reverse_proxy`
line that matches how Caddy reaches your other containers, then reload:
```bash
# (adjust to your Caddy container/paths)
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```
- **Caddy on host / host networking:** `reverse_proxy 127.0.0.1:3000` (default in the file).
- **Caddy in a bridge container:** add `extra_hosts: ["host.docker.internal:host-gateway"]`
  to the Caddy container and use `reverse_proxy host.docker.internal:3000`.
- **Shared Docker network:** attach Twenty's `server` to your Caddy network (commented
  block in `docker-compose.yml`) and use `reverse_proxy server:3000`.

> Per your rules, anything that changes your existing Caddy config/container/network is
> flagged for your approval — pick the option that matches your setup before reloading.

## 5. First admin user, then lock signup (HARD REQUIREMENT)
1. Open **https://crm.utomat.com** → sign up → this first account is your admin/workspace owner.
2. Immediately disable open signup:
   ```bash
   cd /opt/twenty
   sed -i 's/^IS_SIGNUP_ENABLED=.*/IS_SIGNUP_ENABLED=false/' .env
   docker compose up -d        # recreates server with signup off
   ```

## 6. Data model + views
- Auto-create the object + fields: see `schema/setup-schema.mjs` (needs an API key).
- Or build by hand (guaranteed): `schema/UI-STEPS.md`.
- Build the 6 views in the UI per `UI-STEPS.md` (3 favorited Kanban pipelines + 3 "send list" tables).
- Field/option reference: `schema/schema-spec.json`.

## 7. Integrations
- **CSV import** (garage-door leads, Business = CallCrew): Twenty → Leads → Import CSV.
  Map columns to the fields in `schema-spec.json`. For the Business column put `CallCrew`
  (or set Business after import); Segment = `Garage door`.
- **n8n reply tracking:** `integrations/n8n-reply-update.md` (API key location + curl).
- **MCP for Claude Code:** `mcp/README-mcp.md` + `mcp/claude-mcp-config.json`.

---

## Backups
- Script: `scripts/backup.sh` — `pg_dump -Fc` of the `default` DB to `./backups/`,
  keeps the newest **14**, prunes older.
- Run once to test: `./scripts/backup.sh && ls -lh backups/`
- Cron (daily 03:15): install the line from `scripts/crontab.txt`:
  ```bash
  ( crontab -l 2>/dev/null; cat /opt/twenty/scripts/crontab.txt ) | crontab -
  crontab -l
  ```
- Restore (into the running db container):
  ```bash
  cat backups/twenty_default_<stamp>.dump | \
    docker compose exec -T db pg_restore -U postgres -d default --clean --if-exists
  ```

## Stop / start
```bash
docker compose stop        # stop (keep containers)
docker compose start       # start again
docker compose down        # stop + remove containers (DATA SAFE in named volumes)
docker compose up -d        # (re)start in background
```
`docker compose down -v` would **delete the volumes (all data)** — don't, unless wiping.

## Upgrade (safely)
1. **Back up first:** `./scripts/backup.sh` (and copy `.env` somewhere safe).
2. Pick the new stable tag from https://hub.docker.com/r/twentycrm/twenty/tags
   and bump it: `sed -i 's/^TAG=.*/TAG=vX.Y.Z/' .env`
3. Recreate:
   ```bash
   docker compose pull
   docker compose up -d      # server runs migrations on boot; worker waits for it
   docker compose logs -f server
   ```
4. Verify `https://crm.utomat.com` loads and `/healthz` is OK.
5. Rollback if needed: set `TAG=` back to the previous version and `docker compose up -d`
   (restore the DB from backup only if a migration is incompatible).

## Security checklist (matches your hard requirements)
- [x] Postgres/Redis have no published ports → not on the public internet.
- [x] `server` bound to `127.0.0.1:3000` → reachable only via Caddy/localhost.
- [x] Version pinned (`TAG=v2.8.3`), not `latest`.
- [x] Secrets live in `.env` (git-ignored), not in `docker-compose.yml`.
- [ ] Open signup disabled after creating the admin (step 5).
- [ ] `ENCRYPTION_KEY` backed up off-box.
