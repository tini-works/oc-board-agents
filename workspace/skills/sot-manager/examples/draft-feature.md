# Example: Draft a Feature

## User input
"Add offline SQLite caching to the mobile app so it loads faster on startup"

## Expected flow

1. Clarify: "Is this a new component inside the Mobile App container, or does it also require a backend change?"
   - User: "Mobile app only"

2. Create branch: `draft/offline-sqlite-cache`

3. ADR: `c3x add adr offline-sqlite-cache`
   - Title: "Add Local SQLite Cache for Mobile App Startup Performance"
   - Status: proposed
   - Affects: c3-2-mobile-app

4. Add component: `c3x add component sqlite-cache --container c3-2`
   - Fills: Goal, Dependencies, Wiring sections

5. Wire to existing ref: `c3x wire c3-212-sqlite-cache cite ref-local-storage`

6. Check: `c3x check` → passes

7. Commit + prev-cli serve on port 3001

8. Notify: "📐 Architecture proposal ready: offline-sqlite-cache
   Review at: http://localhost:3001/mobile-app/sqlite-cache
   Reply 'approved' to merge."

## After approval

1. Merge `draft/offline-sqlite-cache` → main
2. ADR status → implemented
3. Emit handoff JSON with 1 task: implement c3-212-sqlite-cache
4. Send to Derived repo orchestrator
