#!/usr/bin/env node
/**
 * Create the Lead object + all fields from schema-spec.json against a LIVE Twenty
 * instance, via the GraphQL Metadata API (SERVER_URL/metadata).
 *
 *   TWENTY_URL=https://crm.utomat.com \
 *   TWENTY_API_KEY=eyJ... \
 *   node schema/setup-schema.mjs
 *
 * Notes / honesty:
 * - This drives Twenty's metadata API. Mutation shapes are stable across recent
 *   2.x releases but CAN change. If a call errors, the field-by-field UI steps in
 *   UI-STEPS.md are the guaranteed fallback — and you only have ~17 fields.
 * - It is idempotent-ish: it skips creation if the object already exists.
 * - Views (Kanban/Table) are intentionally created in the UI (UI-STEPS.md): the
 *   view/filter/group API is the most version-sensitive part and not worth the risk.
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const spec = JSON.parse(readFileSync(join(__dirname, "schema-spec.json"), "utf8"));

const URL_BASE = process.env.TWENTY_URL?.replace(/\/$/, "");
const API_KEY = process.env.TWENTY_API_KEY;
if (!URL_BASE || !API_KEY) {
  console.error("Set TWENTY_URL and TWENTY_API_KEY env vars.");
  process.exit(1);
}
const META = `${URL_BASE}/metadata`;

async function gql(query, variables) {
  const res = await fetch(META, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${API_KEY}`,
    },
    body: JSON.stringify({ query, variables }),
  });
  const json = await res.json();
  if (json.errors) {
    throw new Error(JSON.stringify(json.errors, null, 2));
  }
  return json.data;
}

async function findObject(nameSingular) {
  const data = await gql(
    `query { objects(filter: {}, paging: {first: 200}) { edges { node { id nameSingular } } } }`
  );
  return data.objects.edges
    .map((e) => e.node)
    .find((o) => o.nameSingular === nameSingular);
}

async function createObject(o) {
  const data = await gql(
    `mutation Create($input: CreateObjectInput!) {
       createOneObject(input: $input) { id nameSingular }
     }`,
    {
      input: {
        object: {
          nameSingular: o.nameSingular,
          namePlural: o.namePlural,
          labelSingular: o.labelSingular,
          labelPlural: o.labelPlural,
          description: o.description,
          icon: o.icon,
        },
      },
    }
  );
  return data.createOneObject;
}

function buildFieldInput(objectMetadataId, f) {
  const input = {
    objectMetadataId,
    name: f.apiName,
    label: f.label,
    type: f.type,
    description: f.note ?? undefined,
  };
  if (f.type === "SELECT" && f.options) {
    input.options = f.options.map((opt, i) => ({
      label: opt.label,
      value: opt.value,
      color: opt.color ?? "gray",
      position: i,
    }));
  }
  return input;
}

async function createField(objectMetadataId, f) {
  const data = await gql(
    `mutation Create($input: CreateFieldInput!) {
       createOneField(input: $input) { id name }
     }`,
    { input: { field: buildFieldInput(objectMetadataId, f) } }
  );
  return data.createOneField;
}

(async () => {
  console.log(`Target: ${META}`);
  let obj = await findObject(spec.object.nameSingular);
  if (obj) {
    console.log(`Object '${spec.object.nameSingular}' already exists (${obj.id}).`);
  } else {
    obj = await createObject(spec.object);
    console.log(`Created object '${obj.nameSingular}' (${obj.id}).`);
  }

  for (const f of spec.fields) {
    if (f.apiName === "name") {
      console.log(`- skip '${f.label}' (rename the default Name field in the UI).`);
      continue;
    }
    try {
      const created = await createField(obj.id, f);
      console.log(`+ field '${f.label}' (${created.name})`);
    } catch (e) {
      console.error(`! field '${f.label}' failed: ${e.message.split("\n")[0]}`);
    }
  }

  console.log("\nFields done. Now create the 6 views from UI-STEPS.md (Kanban x3 + Table x3).");
})();
