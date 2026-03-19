#!/usr/bin/env bash
# analyze_project.sh — Quick project analysis for project-adopt skill
# Usage: analyze_project.sh <project-path>
# Outputs a structured summary to stdout

set -euo pipefail

PROJECT="${1:-.}"
cd "$PROJECT" 2>/dev/null || { echo "ERROR: Cannot access $PROJECT"; exit 1; }

echo "=== PROJECT ANALYSIS: $PROJECT ==="
echo ""

# ---------- File counts ----------
echo "## File Counts"
TOTAL=$(find . -type f | grep -v -E '(node_modules|\.git|dist|build|\.next|\.cache|__pycache__|\.venv|vendor)' | wc -l | tr -d ' ')
echo "Total source files: $TOTAL"
echo ""

# Language breakdown
echo "## Language Breakdown"
for ext in ts tsx js jsx py go rs java kt swift rb php cs; do
  count=$(find . -name "*.$ext" -not -path "*/node_modules/*" -not -path "*/.git/*" \
    -not -path "*/dist/*" -not -path "*/build/*" 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -gt 0 ] && echo "  .$ext: $count"
done
echo ""

# ---------- Framework detection ----------
echo "## Detected Frameworks / Runtimes"

# Node / JS ecosystem
if [ -f "package.json" ]; then
  echo "  - Node.js project (package.json)"
  # React
  grep -q '"react"' package.json 2>/dev/null && echo "  - React"
  grep -q '"next"' package.json 2>/dev/null && echo "  - Next.js"
  grep -q '"vue"' package.json 2>/dev/null && echo "  - Vue"
  grep -q '"nuxt"' package.json 2>/dev/null && echo "  - Nuxt"
  grep -q '"svelte"' package.json 2>/dev/null && echo "  - Svelte"
  grep -q '"express"' package.json 2>/dev/null && echo "  - Express.js"
  grep -q '"fastify"' package.json 2>/dev/null && echo "  - Fastify"
  grep -q '"nestjs\|@nestjs"' package.json 2>/dev/null && echo "  - NestJS"
  grep -q '"hono"' package.json 2>/dev/null && echo "  - Hono"
  grep -q '"@trpc"' package.json 2>/dev/null && echo "  - tRPC"
  grep -q '"prisma"' package.json 2>/dev/null && echo "  - Prisma"
  grep -q '"drizzle"' package.json 2>/dev/null && echo "  - Drizzle ORM"
fi

# Python
[ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ] && echo "  - Python project"
grep -q "django" requirements.txt 2>/dev/null && echo "  - Django"
grep -q "fastapi" requirements.txt 2>/dev/null && echo "  - FastAPI"
grep -q "flask" requirements.txt 2>/dev/null && echo "  - Flask"

# Go
[ -f "go.mod" ] && echo "  - Go module (go.mod)"

# Rust
[ -f "Cargo.toml" ] && echo "  - Rust (Cargo.toml)"

# Java / Kotlin
[ -f "pom.xml" ] && echo "  - Maven (Java/Kotlin)"
[ -f "build.gradle" ] || [ -f "build.gradle.kts" ] && echo "  - Gradle (Java/Kotlin)"

# Container/infra
[ -f "Dockerfile" ] && echo "  - Docker"
[ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] && echo "  - Docker Compose"
[ -d ".github/workflows" ] && echo "  - GitHub Actions CI"
echo ""

# ---------- Top-level structure ----------
echo "## Top-Level Directories"
find . -maxdepth 1 -mindepth 1 -type d \
  | grep -v -E '(node_modules|\.git|dist|build|\.next|\.cache|__pycache__|\.venv|vendor|\.c3)' \
  | sort | sed 's|^\./|  - |'
echo ""

# ---------- Entry points ----------
echo "## Likely Entry Points"
for f in main.ts main.js index.ts index.js app.ts server.ts main.py app.py manage.py main.go cmd/main.go src/main.rs; do
  [ -f "$f" ] && echo "  - $f"
done
echo ""

# ---------- Config files ----------
echo "## Config / Schema Files"
for f in .env.example tsconfig.json vite.config.ts next.config.js next.config.ts \
  prisma/schema.prisma drizzle.config.ts swagger.json openapi.yaml; do
  [ -f "$f" ] && echo "  - $f"
done
echo ""

# ---------- Complexity estimate ----------
echo "## Complexity Estimate"
if [ "$TOTAL" -lt 50 ]; then
  echo "  Size: SMALL (<50 files) — single pass ingest, ~2 containers"
elif [ "$TOTAL" -lt 200 ]; then
  echo "  Size: MEDIUM (50-200 files) — 2-4 containers expected"
elif [ "$TOTAL" -lt 500 ]; then
  echo "  Size: LARGE (200-500 files) — 4-8 containers, consider phased ingest"
else
  echo "  Size: XLARGE (500+ files) — multi-phase ingest recommended"
fi
echo ""
echo "=== END ANALYSIS ==="
