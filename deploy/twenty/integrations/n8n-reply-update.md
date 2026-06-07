# n8n → Twenty: flip a lead to "Replied"

Your n8n (on `n8n.courseadvisor.ai`) watches Gmail for replies and updates the lead
in Twenty over **https** (public endpoint, not the Docker network).

## API key
Create it in Twenty: **Settings → APIs & Webhooks → Create API key**.
- Copy it once (you can't see it again). Store it in n8n **Credentials** as a
  *Header Auth* credential: header `Authorization`, value `Bearer <API_KEY>`.
- It lives only in Twenty's DB + your n8n credentials store — never in this repo.

Base URLs:
- REST:    `https://crm.utomat.com/rest`
- GraphQL: `https://crm.utomat.com/graphql`

## Step 1 — find the lead by email (READ)
REST, filtering on the Email field's primary address:
```bash
curl -s "https://crm.utomat.com/rest/leads?filter=email.primaryEmail[eq]:jane@acme.com&limit=1" \
  -H "Authorization: Bearer $TWENTY_API_KEY"
```
Grab `data.leads[0].id` from the response (a UUID).

> If the composite-field filter path differs on your version, confirm the exact
> field path under Settings → Data model → Lead → Email, or list one record with
> `GET /rest/leads?limit=1` and read the JSON shape.

## Step 2 — update Outreach status to Replied (WRITE)
REST PATCH (this is the call to build the n8n HTTP Request node around):
```bash
curl -s -X PATCH "https://crm.utomat.com/rest/leads/THE_LEAD_ID" \
  -H "Authorization: Bearer $TWENTY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"outreachStatus":"REPLIED","lastContacted":"2026-06-04T00:00:00.000Z"}'
```

GraphQL equivalent (if you prefer one endpoint for read+write):
```bash
curl -s -X POST "https://crm.utomat.com/graphql" \
  -H "Authorization: Bearer $TWENTY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($id: UUID!, $data: LeadUpdateInput!){ updateLead(id:$id, data:$data){ id outreachStatus } }",
    "variables": { "id": "THE_LEAD_ID", "data": { "outreachStatus": "REPLIED" } }
  }'
```

## n8n node sketch
1. **Gmail Trigger** (or Gmail node, polling) → new message in/label.
2. **Function/Set**: extract sender email.
3. **HTTP Request** (GET, Step 1) → find lead id. Header Auth credential.
4. **IF**: a lead was found.
5. **HTTP Request** (PATCH, Step 2) → set `outreachStatus = REPLIED`.

Select option **values** (what the API expects, not the labels):
`NOT_CONTACTED, CONTACTED, FOLLOW_UP_1, FOLLOW_UP_2, REPLIED, BOOKED, DEAD`
