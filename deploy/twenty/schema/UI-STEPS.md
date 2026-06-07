# Data model — UI build steps (guaranteed path)

This builds the single `Lead` object, ~17 fields, and the 6 views by hand in the
Twenty UI. It matches `schema-spec.json` exactly. (The `setup-schema.mjs` script can
create the object + fields automatically; use these steps for the views regardless,
and as the fallback if the script errors on your version.)

## 1. Create the object
Settings → Data model → **+ Object**
- Singular: `Lead`  · Plural: `Leads` · Icon: target
- After it's created, open the object → its default **Name** field → rename label to
  **Company name** (keep type Text; it stays the record title shown on cards).

## 2. Add fields
Settings → Data model → **Lead** → **+ Field** for each row.
For SELECT fields, add the options in the order/labels below (colors are cosmetic).

| Label | Type | Options (label) |
|---|---|---|
| Business | Select | CallCrew, Utomat, Grease Trap Repair |
| Contact name | Text | — |
| Email | Emails | — |
| Phone | Phones | — |
| Email status | Select | Verified, Form/phone only, Not researched |
| Website | Links | — |
| City / location | Text | — |
| Rating | Number (1 decimal) | — |
| Reviews | Number (0 decimals) | — |
| Address | Text | — |
| Segment | Select | Garage door, Roofing, HVAC  *(add Utomat / Grease Trap values later)* |
| Source | Text | — |
| Outreach status | Select | Not contacted, Contacted, Follow-up 1, Follow-up 2, Replied, Booked, Dead |
| Last contacted | Date | — |
| Next action | Date | — |
| Notes | Text | — |

## 3. The three Kanban pipelines (favorited → sidebar sections)
Open **Leads** (the records page). For each business:
1. Top-left view switcher → **+ Add view** → name it, choose **Kanban**.
2. **Group by** → **Outreach status**.
3. **Filter** → **Business** → *is* → the business value.
4. Star/favorite the view (the ★ next to the view name) so it appears as its own
   section in the left sidebar.

Create:
- **CallCrew pipeline** — Kanban, group by Outreach status, filter Business = CallCrew ★
- **Utomat pipeline** — Kanban, group by Outreach status, filter Business = Utomat ★
- **Grease Trap pipeline** — Kanban, group by Outreach status, filter Business = Grease Trap Repair ★

## 4. The three "send list" table views
For each business, **+ Add view** → **Table**, then:
- Filter **Business** = the business **AND** **Email status** = Verified.
- Suggested visible columns: Company name, Contact name, Email, Phone, City / location,
  Segment, Outreach status, Last contacted, Next action.

Create:
- **CallCrew — send list** — Table, Business = CallCrew AND Email status = Verified
- **Utomat — send list** — Table, Business = Utomat AND Email status = Verified
- **Grease Trap — send list** — Table, Business = Grease Trap Repair AND Email status = Verified

## 5. Verify
- Sidebar shows **CallCrew pipeline**, **Utomat pipeline**, **Grease Trap pipeline**
  as favorited sections.
- Each Kanban has the 7 Outreach-status columns.
- Each "send list" table only shows Verified leads for that business.
