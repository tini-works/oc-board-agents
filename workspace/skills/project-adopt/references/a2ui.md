# A2UI JSONL Generation Reference

Detailed reference for Phase 3 — converting existing frontend code into A2UI JSONL.
This is the canonical spec used by both `project-adopt` and the `adopt` skill inside sot-template repos.

---

## Input

- `FRAMEWORK_CONTEXT` from analyze phase
- Route inventory from analyze phase
- Source files of the existing frontend

## Output

Per feature group:
- `docs/ui/a2ui/<feature>.screens.jsonl`
- `docs/ui/a2ui/<feature>.flow.jsonl`
- `docs/ui/a2ui/design-system.jsonl` (once, shared)

---

## JSONL Line Types

### `token`
```json
{"type":"token","id":"color-primary","value":"#6366f1","usage":"CTAs, links, active states"}
```

### `component`
```json
{
  "type": "component",
  "id": "EmailInput",
  "props": { "value": "string", "onChange": "fn", "error": "string|null" },
  "states": {
    "default": {},
    "error": { "borderColor": "color-error", "showHelperText": true }
  }
}
```

### `screen`
```json
{
  "type": "screen",
  "id": "LoginScreen",
  "route": "/login",
  "c3": "c3-101",
  "platform": "mobile|web|both",
  "title": "Login",
  "layout": { "type": "stack", "children": ["EmailInput", "PasswordInput", "SubmitButton"] },
  "states": {
    "idle": {},
    "loading": { "disable": ["SubmitButton"], "show": ["Spinner"] },
    "error": { "show": ["ErrorBanner"] }
  },
  "ac": [
    "Given idle, when valid credentials submitted, then navigate to HomeScreen",
    "Given idle, when invalid credentials, then show ErrorBanner",
    "Given loading, then SubmitButton is disabled"
  ]
}
```

### `flow`
```json
{
  "type": "flow",
  "id": "LoginFlow",
  "c3": "c3-101",
  "trigger": "User taps Login CTA from any unauthenticated screen",
  "steps": [
    { "screen": "LoginScreen", "action": "submit valid credentials", "next": "HomeScreen", "condition": "credentials valid" },
    { "screen": "LoginScreen", "action": "submit invalid credentials", "next": "LoginScreen", "condition": "credentials invalid", "effect": "show ErrorBanner" }
  ],
  "edge_cases": [
    { "scenario": "Deep link while unauthenticated", "behavior": "Redirect to LoginScreen, then back" }
  ]
}
```

---

## Framework Route → File Mapping

| Router | Route `/foo/bar` → File |
|--------|------------------------|
| `app-dir` | `app/foo/bar/page.tsx` |
| `pages-dir` | `pages/foo/bar.tsx` or `pages/foo/bar/index.tsx` |
| `expo-router` | `app/foo/bar.tsx` or `app/foo/bar/index.tsx` |
| `react-navigation` | Find `Stack.Screen name="FooBar"` → `component` prop → file |
| `react-router` | Find `<Route path="/foo/bar" element={<FooBar />}` → resolve component |
| `vue-router` | Find `{ path: '/foo/bar', component: () => import('./FooBar.vue') }` |

---

## Props Type Mapping

| TypeScript | JSONL |
|-----------|-------|
| `string` | `"string"` |
| `number` | `"number"` |
| `boolean` | `"boolean"` |
| `() => void` / `MouseEventHandler` / `() => any` | `"fn"` |
| `ReactNode` / `JSX.Element` | `"node"` |
| `T \| undefined` / `T \| null` | `"T\|null"` |
| `string[]` | `"string[]"` |
| `enum Value` | `"Value1\|Value2\|Value3"` |

---

## State Pattern → JSONL Mapping

| Code pattern | State name | Typical UI behavior |
|-------------|-----------|---------------------|
| `isLoading`, `isPending`, `status === 'loading'` | `loading` | `{ show: ["Spinner"], disable: ["SubmitButton"] }` |
| `isError`, `error !== null`, `status === 'error'` | `error` | `{ show: ["ErrorBanner"] }` |
| `!data \|\| data.length === 0`, `isEmpty` | `empty` | `{ show: ["EmptyState"] }` |
| `isSuccess`, `status === 'success'` | `success` | `{ show: ["SuccessBanner"] }` |
| `isSubmitting` | `submitting` | `{ disable: ["SubmitButton"], show: ["Spinner"] }` |
| XState `.matches('stateName')` | use state name directly | map from component renders |
| Zustand `store.isXxx` boolean | derive from flag name | map from conditional renders |

**How to map conditional renders:**
```
{isLoading && <Spinner />}       → loading: { show: ["Spinner"] }
{!isLoading && <Button />}       → loading: { hide: ["Button"] }
disabled={isLoading}             → loading: { disable: ["Button"] }
{error && <ErrorBanner />}       → error: { show: ["ErrorBanner"] }
className={error ? 'red' : ''}   → error: { className: "red" }   (approximate)
```

---

## Navigation Graph → Flow Steps

| Framework | Call pattern | What to extract |
|-----------|-------------|-----------------|
| Next.js | `router.push('/path')` | path → next screen |
| Next.js | `<Link href="/path">` | path → next, containing element = trigger |
| Expo Router | `router.push('/(tabs)/home')` | route → next screen |
| React Navigation | `navigation.navigate('ScreenName')` | name → next screen |
| React Navigation | `navigation.goBack()` | next = previous screen |
| React Router | `navigate('/path')` | path → next screen |

**Finding trigger + condition:**
- If navigation is inside `onPress` / `onClick` → trigger = that element
- If inside `onSuccess:` callback → condition = `"on API success"`
- If inside `useEffect(() => { if (data) navigate(...) })` → condition = `"when data available"`
- If inside `if (isValid) navigate(...)` → condition = `"when form valid"`

---

## Design System Extraction

**Priority order:**

1. Tailwind `theme.extend` in `tailwind.config.ts`:
```bash
grep -A 100 'extend:' tailwind.config.ts | grep -E 'colors|spacing|fontFamily'
```

2. CSS custom properties:
```bash
grep -r '\-\-color\-\|\-\-spacing\-\|\-\-font\-' src/ --include="*.css" --include="*.scss"
```

3. Theme/tokens file:
```bash
find src -name "theme.ts" -o -name "tokens.ts" -o -name "colors.ts" 2>/dev/null | head -5
```

4. React Native StyleSheet constants:
```bash
grep -r "StyleSheet.create\|const.*Colors\|const.*Spacing" src/ --include="*.ts" --include="*.tsx" | head -20
```

---

## Validation Commands

```bash
# Validate all JSONL in a2ui dir
for f in docs/ui/a2ui/*.jsonl; do
  echo "Checking: $f"
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [ -z "$line" ] && continue
    echo "$line" | node -e "JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'))" \
      > /dev/null 2>&1 || echo "  ✗ Line $line_num invalid: $line"
  done < "$f"
  echo "  ✓ $line_num lines checked"
done

# Check all screen children exist as components
node -e "
const fs = require('fs');
const lines = fs.readdirSync('docs/ui/a2ui')
  .filter(f => f.endsWith('.jsonl'))
  .flatMap(f => fs.readFileSync('docs/ui/a2ui/' + f, 'utf8').trim().split('\n').map(JSON.parse));
const components = new Set(lines.filter(l => l.type === 'component').map(l => l.id));
const screens = lines.filter(l => l.type === 'screen');
screens.forEach(s => {
  (s.layout?.children || []).forEach(c => {
    if (!components.has(c)) console.log('Missing component:', c, 'referenced in', s.id);
  });
});
console.log('Component reference check done.');
"

# Check all flow screens exist
node -e "
const fs = require('fs');
const lines = fs.readdirSync('docs/ui/a2ui')
  .filter(f => f.endsWith('.jsonl'))
  .flatMap(f => fs.readFileSync('docs/ui/a2ui/' + f, 'utf8').trim().split('\n').map(JSON.parse));
const screens = new Set(lines.filter(l => l.type === 'screen').map(l => l.id));
const flows = lines.filter(l => l.type === 'flow');
flows.forEach(f => {
  (f.steps || []).forEach(s => {
    if (!screens.has(s.screen)) console.log('Flow', f.id, 'references unknown screen:', s.screen);
  });
});
console.log('Flow screen reference check done.');
"
```

---

## Rules

- **Never invent** states, props, or routes not found in the source
- **Infer conservatively** — if unsure whether something is a state, omit it
- **One screen per route** — never merge multiple routes
- **Flows are user journeys** — group related navigation into one flow, not one per function call
- **AC must be testable** — "works" is not AC; "returns 401 when token missing" is
- **Partial adoption is valid** — if no frontend exists, skip; document in handoff `a2ui: []`
- **Dead code** — add screen entry, mark `"status": "deprecated"`
