---
name: get-api-docs
description: |
  Use this skill when you need documentation for a third-party library, SDK, or API
  before writing code that uses it. For example: "use the OpenAI API", "call the
  GitHub API", "use the Anthropic SDK", "query Stripe", or any time the user asks
  you to write code against an external service and you need current API reference.
  Fetch the docs with chub before answering, rather than relying on training knowledge.
  Also use when a SOT handoff payload includes chub_ids — fetch those docs first.
---

# Get API Docs via chub

When you need documentation for a library or API, fetch it with the `chub` CLI
rather than guessing from training data. This gives you the current, correct API.

**chub path:** `/home/node/.npm-global/bin/chub`

## Step 1 — Find the right doc ID

```bash
/home/node/.npm-global/bin/chub search "<library name>" --json
```

Pick the best-matching `id` from the results (e.g. `github/octokit`, `anthropic/claude-api`,
`stripe/api`). If nothing matches, try a broader term.

**Currently available docs (20 total):**
- `anthropic/claude-api` — Claude API (JS/PY)
- `github/octokit` — GitHub REST + GraphQL (JS)
- `openai/chat` — OpenAI API (JS/PY)
- `stripe/api` / `stripe/payments` — Stripe payments (JS)
- `aws/s3` — AWS S3 SDK v3 (JS/PY)
- `auth0/identity` / `clerk/auth` — Auth (JS/PY)
- `cloudflare/workers` — Edge functions (JS/PY)
- `chromadb/embeddings-db` — Vector DB (JS/PY)
- `deepseek/llm` / `cohere/llm` — LLMs (JS)
- Plus: airtable, amplitude, asana, assemblyai, atlassian/confluence, binance, braintree, cockroachdb, datadog, deepgram, deepl, directus

## Step 2 — Fetch the docs

```bash
/home/node/.npm-global/bin/chub get <id> --lang js    # or --lang py
```

Omit `--lang` if the doc has only one language variant.

## Step 3 — Use the docs

Read the fetched content and use it to write accurate code or answer the question.
Do not rely on memorized API shapes — use what the docs say.

## Step 4 — Annotate what you learned

After completing the task, if you discovered something not in the doc — a gotcha,
workaround, version quirk, or project-specific detail — save it so future sessions
start smarter:

```bash
/home/node/.npm-global/bin/chub annotate <id> "Webhook verification requires raw body — do not parse before verifying"
```

Annotations are local, persist across sessions, and appear automatically on future
`chub get` calls. Keep notes concise and actionable.

## Step 5 — Give feedback

Rate the doc so authors can improve it:

```bash
/home/node/.npm-global/bin/chub feedback <id> up                        # doc worked well
/home/node/.npm-global/bin/chub feedback <id> down --label outdated     # doc needs updating
```

## Quick reference

| Goal | Command |
|------|---------|
| List everything | `chub search` |
| Find a doc | `chub search "stripe"` |
| Fetch JS docs | `chub get stripe/api --lang js` |
| Fetch Python docs | `chub get openai/chat --lang py` |
| Save to file | `chub get anthropic/claude-api --lang js -o .context/claude.md` |
| Fetch multiple | `chub get github/octokit stripe/api --lang js` |
| Save all to dir | `chub get github/octokit stripe/api -o .context/` |
| Save a note | `chub annotate stripe/api "needs raw body for webhooks"` |
| List notes | `chub annotate --list` |
| Rate a doc | `chub feedback stripe/api up` |
| Refresh registry | `chub update` |

## SOT Integration

When you receive a SOT handoff payload that includes a `chub_ids` field:

```bash
# Fetch all required docs before starting implementation
/home/node/.npm-global/bin/chub get <chub_ids[0]> <chub_ids[1]> ... --lang js -o .context/
```

Read the docs in `.context/` before writing any code that calls those APIs.
