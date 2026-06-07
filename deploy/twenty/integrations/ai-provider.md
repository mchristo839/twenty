# AI provider — you are not locked to Anthropic

Twenty v2.8.x picks its LLM from a provider catalog. You have two ways to supply one.

## A) Built-in providers (set one key, pick the model in the UI)
Set the matching key in `/opt/twenty/.env`, then choose the model in **Settings → AI**:

| Provider | Env var |
|---|---|
| OpenAI (GPT / o-series) | `OPENAI_API_KEY` |
| Anthropic (Claude) | `ANTHROPIC_API_KEY` |
| Google (Gemini) | `GOOGLE_API_KEY` |
| xAI (Grok) | `XAI_API_KEY` |
| Groq | `GROQ_API_KEY` |
| Mistral | `MISTRAL_API_KEY` |

## B) DeepSeek / OpenRouter / any OpenAI-compatible endpoint
DeepSeek and OpenRouter aren't in the built-in catalog, but the config schema supports
custom providers via the **`AI_PROVIDERS`** JSON variable. Use the
**`@ai-sdk/openai-compatible`** package — it talks `/v1/chat/completions`, which both
DeepSeek and OpenRouter support (this avoids the `@ai-sdk/openai` "Responses API"
incompatibility, [issue #16817](https://github.com/twentyhq/twenty/issues/16817)).

Schema fields (from twenty-server v2.8.3): `npm` (must be an allowed AI SDK package),
`label`, `baseUrl`, `apiKey`, `models[]`. The custom config is deep-merged onto the
built-in catalog. You can set it in `.env` (one-line JSON) **or** in the admin panel.

### Heads-up on your wording
OpenRouter does **not** take a DeepSeek key — it uses its own OpenRouter key and bills
through OpenRouter. So:
- **Cheapest / fewest hops:** point Twenty straight at DeepSeek with your **DeepSeek key**.
- **Most flexible (fallbacks, many models):** use **OpenRouter** with an **OpenRouter key**.

### DeepSeek direct (your DeepSeek key)
Add to `.env` (one line):
```env
AI_PROVIDERS={"deepseek":{"npm":"@ai-sdk/openai-compatible","label":"DeepSeek","baseUrl":"https://api.deepseek.com/v1","apiKey":"sk-REPLACE","models":[{"name":"deepseek-chat","label":"DeepSeek V3","modelFamily":"DeepSeek","contextWindowTokens":64000,"maxOutputTokens":8192},{"name":"deepseek-reasoner","label":"DeepSeek R1","modelFamily":"DeepSeek","contextWindowTokens":64000,"maxOutputTokens":8192,"supportsReasoning":true}]}}
```

### OpenRouter (OpenRouter key)
```env
AI_PROVIDERS={"openrouter":{"npm":"@ai-sdk/openai-compatible","label":"OpenRouter","baseUrl":"https://openrouter.ai/api/v1","apiKey":"sk-or-REPLACE","models":[{"name":"deepseek/deepseek-chat","label":"DeepSeek V3 (OpenRouter)","modelFamily":"DeepSeek","contextWindowTokens":64000,"maxOutputTokens":8192}]}}
```

## Apply + pick the default model
```bash
cd /opt/twenty
docker compose up -d        # re-reads .env
```
Then in **Settings → AI**, set the new model as the default (fast/smart). If a model
isn't selectable, set it via `AI_MODEL_PREFERENCES` or the admin panel.

## Verify (do this on the box after deploy)
- Open **Settings → AI** and confirm the provider/model appears.
- Run an AI action (e.g. the assistant) on a Lead and confirm it responds.
- Token costs in the catalog entry are cosmetic (for display); they don't affect billing.

> Derived from twenty-server `v2.8.3` source (provider schema + `@ai-sdk/openai-compatible`
> in the allowed packages). Not yet tested against your live instance — we'll confirm the
> exact JSON works during the on-box deploy and adjust models if needed.
