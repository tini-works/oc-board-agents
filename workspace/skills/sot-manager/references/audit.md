# Audit Reference

Background drift detection. Run periodically via Heartbeat or on-demand.

## Flow

`SOT check → Derived coverage → Drift report → Alert if needed`

## Phases

### Phase 0: SOT Structural Check

```bash
bash $C3X check --c3-dir $SOT_REPO/.c3 --json
```

Catches: broken links, orphaned entities, schema violations, invalid frontmatter.

**If errors:** Flag immediately — SOT integrity is compromised.

### Phase 1: SOT Inventory

```bash
bash $C3X list --json --c3-dir $SOT_REPO/.c3
```

Extract: total containers, components, refs, ADRs, their statuses.

### Phase 2: Derived Repo Coverage

```bash
bash $C3X coverage --c3-dir $SOT_REPO/.c3
```

Reports:
- Mapped files (linked to c3 component)
- Excluded files (intentionally unmapped: tests, build output)
- Unmapped files ← **these are the problem**

**Unmapped files = agent hallucination or undocumented human changes.**

### Phase 3: Drift Detection

```bash
bash $C3X sweep --c3-dir $SOT_REPO/.c3
```

Impact assessment across the entity graph. Identifies what's at risk.

### Phase 4: ADR Lifecycle

Check for ADRs stuck in `proposed` status older than 7 days → flag as stale.

### Phase 5: Report

**Green (no action):**
```
✅ SOT Audit — Clean
Entities: {N} components, {N} refs, {N} ADRs
Coverage: {N}% mapped ({N} unmapped)
Last merge: {date}
```

**Yellow (warning):**
```
⚠️ SOT Audit — Warnings
- {N} unmapped files in Derived repo
- Stale ADRs: [list]
Action: Review and map or add to _exclude
```

**Red (action required):**
```
🚨 SOT Audit — Drift Detected
- SOT check failures: [list errors]
- Unmapped files: [list files]
- Suspected cause: undocumented changes in Derived repo
Action required: trigger reverse-sync or notify team
```

## Heartbeat Integration

Add to HEARTBEAT.md:
```markdown
## SOT Audit (every 4 hours)
Run: bash $C3X check --c3-dir $SOT_REPO/.c3
Run: bash $C3X coverage --c3-dir $SOT_REPO/.c3
Alert if: check failures OR unmapped file count increases
```
