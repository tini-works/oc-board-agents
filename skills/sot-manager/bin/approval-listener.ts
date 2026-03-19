#!/usr/bin/env bun
/**
 * sot-manager approval-listener
 * Listens for prev-cli webhook POSTs and triggers merge+handoff when status === 'approved'
 *
 * Usage:
 *   bun /path/to/approval-listener.ts --sot-repo /path/to/sot --port 3999
 *
 * Env vars (override flags):
 *   SOT_REPO, DERIVED_REPO, LISTENER_PORT, C3X, PREV, OPENCLAW_WEBHOOK_URL
 */

import { execSync } from 'child_process'
import { existsSync, readFileSync, writeFileSync } from 'fs'
import path from 'path'

// ── Config ────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2)
function argVal(flag: string): string | undefined {
  const i = args.indexOf(flag)
  return i !== -1 ? args[i + 1] : undefined
}

const SOT_REPO       = argVal('--sot-repo')      ?? process.env.SOT_REPO       ?? process.cwd()
const DERIVED_REPO   = argVal('--derived-repo')  ?? process.env.DERIVED_REPO   ?? ''
const PORT           = Number(argVal('--port')   ?? process.env.LISTENER_PORT  ?? 3999)
const C3X            = argVal('--c3x')           ?? process.env.C3X            ?? 'c3x'
const PREV           = argVal('--prev')          ?? process.env.PREV           ?? 'prev'
const GITHUB_SECRET  = argVal('--github-secret') ?? process.env.GITHUB_WEBHOOK_SECRET ?? ''
// Optional: POST progress events back to OpenClaw
const OC_WEBHOOK     = argVal('--oc-webhook')    ?? process.env.OPENCLAW_WEBHOOK_URL ?? ''

const STATE_FILE   = path.join(SOT_REPO, '.sot-manager-state.json')
const ACTIVE_CRS_FILE = path.join(SOT_REPO, 'active-crs.json')

// ── Helpers ───────────────────────────────────────────────────────────────────

function log(msg: string) {
  console.log(`[approval-listener] ${new Date().toISOString()} ${msg}`)
}

function readState(): Record<string, unknown> {
  if (!existsSync(STATE_FILE)) return {}
  try { return JSON.parse(readFileSync(STATE_FILE, 'utf-8')) } catch { return {} }
}

function writeState(patch: Record<string, unknown>) {
  const current = readState()
  writeFileSync(STATE_FILE, JSON.stringify({ ...current, ...patch }, null, 2))
}

// ── Active CRs ────────────────────────────────────────────────────────────────

interface CREntry {
  id: string
  slug: string
  user: string
  branch: string
  pr_number?: number
  pr_url?: string
  prev_port?: number
  prev_pid?: number
  tunnel_url?: string
  tunnel_pid?: number
  status: string
  created_at: string
  files_changed?: string[]
}

function readActiveCRs(): Record<string, CREntry> {
  if (!existsSync(ACTIVE_CRS_FILE)) return {}
  try { return JSON.parse(readFileSync(ACTIVE_CRS_FILE, 'utf-8')) } catch { return {} }
}

function writeActiveCRs(crs: Record<string, CREntry>) {
  writeFileSync(ACTIVE_CRS_FILE, JSON.stringify(crs, null, 2))
}

function findCRByBranch(branch: string): CREntry | undefined {
  const crs = readActiveCRs()
  return Object.values(crs).find(cr => cr.branch === branch)
}

function findCRByPRNumber(prNumber: number): CREntry | undefined {
  const crs = readActiveCRs()
  return Object.values(crs).find(cr => cr.pr_number === prNumber)
}

function cleanupCRInstances(cr: CREntry) {
  // Kill prev-cli instance
  if (cr.prev_pid) {
    try { process.kill(cr.prev_pid); log(`killed prev-cli pid ${cr.prev_pid}`) } catch {}
  }
  // Kill tunnel
  if (cr.tunnel_pid) {
    try { process.kill(cr.tunnel_pid); log(`killed tunnel pid ${cr.tunnel_pid}`) } catch {}
  }
  // Remove git worktree
  const worktree = `/tmp/sot-preview-${cr.id}`
  try {
    run(`git worktree remove --force ${worktree}`)
    log(`removed worktree ${worktree}`)
  } catch {}
}

function run(cmd: string, cwd = SOT_REPO): string {
  log(`$ ${cmd}`)
  return execSync(cmd, { cwd, encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }).trim()
}

async function notifyOpenClaw(payload: Record<string, unknown>) {
  if (!OC_WEBHOOK) return
  try {
    await fetch(OC_WEBHOOK, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })
  } catch (e) {
    log(`warn: OpenClaw notify failed: ${e}`)
  }
}

// ── Core Pipeline ─────────────────────────────────────────────────────────────

async function runMergeAndHandoff(
  branch: string,
  updatedBy: string,
  source: 'github_pr' | 'prev_cli' | 'manual',
  crId?: string,
  page?: string,
  alreadyMerged = false,
): Promise<void> {
  // Resolve CR
  const cr = crId ? readActiveCRs()[crId] : findCRByBranch(branch)
  const resolvedCrId = cr?.id ?? crId ?? 'unknown'
  const resolvedBranch = cr?.branch ?? branch

  log(`=== APPROVAL RECEIVED: cr=${resolvedCrId} branch=${resolvedBranch} source=${source} by=${updatedBy} ===`)

  // Legacy compat — page param used only for old per-page flow
  const pageMeta = page ?? resolvedCrId

  // Step 1: c3x check (on main checkout after GitHub merge, or on branch for others)
  try {
    run(`${C3X} check --c3-dir ${path.join(SOT_REPO, '.c3')}`)
    log('c3x check passed')
  } catch (err) {
    log(`ERROR: c3x check failed — aborting pipeline`)
    await notifyOpenClaw({ event: 'merge_blocked', reason: 'c3x_check_failed', cr_id: resolvedCrId, detail: String(err) })
    return
  }

  // Step 2: Merge branch → main (skip if GitHub already merged the PR)
  if (resolvedBranch && !alreadyMerged) {
    try {
      run(`git checkout main`)
      run(`git merge --no-ff ${resolvedBranch} -m "feat: merge ${resolvedBranch} [${resolvedCrId}] — approved"`)
      log(`merged ${resolvedBranch} → main`)
    } catch (err) {
      log(`ERROR: merge failed: ${err}`)
      await notifyOpenClaw({ event: 'merge_failed', cr_id: resolvedCrId, branch: resolvedBranch, detail: String(err) })
      return
    }
  } else if (alreadyMerged) {
    log(`GitHub already merged — pulling main`)
    try { run(`git checkout main && git pull origin main`) } catch {}
  }

  // Step 3: Rebuild c3x index
  try {
    run(`${C3X} list --json --c3-dir ${path.join(SOT_REPO, '.c3')}`)
    log('c3x index rebuilt')
  } catch { log('warn: c3x index rebuild failed — continuing') }

  // Step 4: Build static preview artifact
  try {
    run(`${PREV} build`, SOT_REPO)
    log('prev build complete')
  } catch (e) { log(`warn: prev build failed: ${e}`) }

  // Step 5: Write handoff payload
  const now = new Date().toISOString()
  const slug = resolvedBranch.replace(/^draft\//, '') || `cr-${Date.now()}`
  const handoffPayload = {
    schema: 'sot-handoff.v1',
    cr_id: resolvedCrId,
    slug,
    approvedAt: now,
    approvedBy: updatedBy,
    approvalSource: source,
    sotRepo: SOT_REPO,
    derivedRepo: DERIVED_REPO || null,
    mergedBranch: resolvedBranch || null,
    c3IndexPath: path.join(SOT_REPO, '.c3', '_index', 'structural.md'),
    docsPath: path.join(SOT_REPO, 'docs'),
    distPath: path.join(SOT_REPO, 'dist'),
    filesChanged: cr?.files_changed ?? [],
    instruction: `Implement the architecture described in the SOT. Read .c3/_index/structural.md for context map. Read docs/ for specs. Write all code in the Derived repo. Do not create architectural decisions — defer to SOT.`,
  }

  const handoffDir = path.join(SOT_REPO, 'handoffs')
  if (!existsSync(handoffDir)) { run(`mkdir -p ${handoffDir}`) }
  const handoffPath = path.join(handoffDir, `${resolvedCrId}-${slug}.json`)
  writeFileSync(handoffPath, JSON.stringify(handoffPayload, null, 2))
  log(`handoff written: ${handoffPath}`)

  // Step 6: Cleanup CR instances (prev-cli + tunnel + worktree)
  if (cr) {
    cleanupCRInstances(cr)
    const crs = readActiveCRs()
    delete crs[resolvedCrId]
    writeActiveCRs(crs)
    log(`CR ${resolvedCrId} removed from active-crs.json`)
  }

  // Step 7: Update global state
  writeState({
    lastMergeAt: now,
    lastMergedCR: resolvedCrId,
    lastHandoffPath: handoffPath,
  })

  // Step 8: Notify OpenClaw
  await notifyOpenClaw({
    event: 'handoff_ready',
    cr_id: resolvedCrId,
    slug,
    handoffPath,
    approvedAt: now,
    approvedBy: updatedBy,
    approvalSource: source,
    pr_url: cr?.pr_url ?? null,
    sotRepo: SOT_REPO,
    derivedRepo: DERIVED_REPO || null,
  })

  log(`=== PIPELINE COMPLETE [${resolvedCrId}]: handoff ready at ${handoffPath} ===`)
}

// ── Server ────────────────────────────────────────────────────────────────────

interface ApprovalWebhookBody {
  schema?: string
  event?: string
  page: string
  status: string
  updatedAt: string
  updatedBy: string
}

interface GitHubPRWebhookBody {
  action: string
  pull_request?: {
    number: number
    merged: boolean
    head: { ref: string }
    merged_by?: { login: string }
    user?: { login: string }
  }
}

interface ManualApproveBody {
  cr_id: string
  approved_by?: string
}

const server = Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url)

    // ── Health check ──────────────────────────────────────────────────────────
    if (url.pathname === '/health' && req.method === 'GET') {
      return Response.json({
        status: 'ok', sotRepo: SOT_REPO, listening: PORT,
        activeCRs: Object.keys(readActiveCRs()),
      })
    }

    // ── Active CRs list ───────────────────────────────────────────────────────
    if (url.pathname === '/active-crs' && req.method === 'GET') {
      return Response.json(readActiveCRs())
    }

    // ── GitHub PR merge webhook (PRIMARY approval signal) ─────────────────────
    if (url.pathname === '/github-webhook' && req.method === 'POST') {
      const event = req.headers.get('x-github-event')
      let body: GitHubPRWebhookBody
      try { body = await req.json() as GitHubPRWebhookBody }
      catch { return Response.json({ error: 'invalid JSON' }, { status: 400 }) }

      if (event === 'pull_request' && body.action === 'closed' && body.pull_request?.merged) {
        const pr = body.pull_request
        const branch = pr.head.ref
        const mergedBy = pr.merged_by?.login ?? pr.user?.login ?? 'github'
        log(`GitHub PR #${pr.number} merged: branch=${branch} by=${mergedBy}`)

        const cr = findCRByBranch(branch) ?? findCRByPRNumber(pr.number)
        if (!cr) {
          log(`warn: no CR found for branch=${branch} pr=${pr.number} — ignoring`)
          return Response.json({ received: true, action: 'ignored', reason: 'no_matching_cr' })
        }

        runMergeAndHandoff(branch, mergedBy, 'github_pr', cr.id, undefined, true)
          .catch(err => log(`pipeline error: ${err}`))
        return Response.json({ received: true, action: 'pipeline_triggered', cr_id: cr.id })
      }

      return Response.json({ received: true, action: 'ignored', event, prAction: body.action })
    }

    // ── prev-cli approval webhook (SECONDARY — per-page badge) ────────────────
    if (url.pathname === '/sot-approval' && req.method === 'POST') {
      let body: ApprovalWebhookBody
      try { body = await req.json() as ApprovalWebhookBody }
      catch { return Response.json({ error: 'invalid JSON' }, { status: 400 }) }

      log(`prev-cli webhook: page=${body.page} status=${body.status} by=${body.updatedBy}`)

      if (body.status === 'approved') {
        // Try to find CR from page path
        const cr = Object.values(readActiveCRs()).find(c =>
          c.files_changed?.some(f => body.page.includes(f)) || body.page.includes(c.slug)
        )
        runMergeAndHandoff(
          cr?.branch ?? '', body.updatedBy, 'prev_cli', cr?.id, body.page, false
        ).catch(err => log(`pipeline error: ${err}`))
        return Response.json({ received: true, action: 'pipeline_triggered', cr_id: cr?.id ?? null })
      }

      return Response.json({ received: true, action: 'logged', status: body.status })
    }

    // ── Manual approve via chat (FALLBACK) ────────────────────────────────────
    if (url.pathname === '/manual-approve' && req.method === 'POST') {
      let body: ManualApproveBody
      try { body = await req.json() as ManualApproveBody }
      catch { return Response.json({ error: 'invalid JSON' }, { status: 400 }) }

      const cr = readActiveCRs()[body.cr_id]
      if (!cr) return Response.json({ error: `CR ${body.cr_id} not found` }, { status: 404 })

      log(`manual approve: cr=${body.cr_id} by=${body.approved_by ?? 'human'}`)
      runMergeAndHandoff(
        cr.branch, body.approved_by ?? 'human', 'manual', body.cr_id, undefined, false
      ).catch(err => log(`pipeline error: ${err}`))
      return Response.json({ received: true, action: 'pipeline_triggered', cr_id: body.cr_id })
    }

    return Response.json({ error: 'not found' }, { status: 404 })
  },
})

log(`listening on :${PORT}`)
log(`SOT_REPO: ${SOT_REPO}`)
log(`C3X: ${C3X}`)
log(`PREV: ${PREV}`)
log(`Routes:`)
log(`  POST /github-webhook     ← GitHub PR merge (primary approval)`)
log(`  POST /sot-approval       ← prev-cli badge (secondary)`)
log(`  POST /manual-approve     ← chat fallback { cr_id }`)
log(`  GET  /active-crs         ← list active CRs`)
log(`  GET  /health             ← status`)
