# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

---

## GitHub

- **Token:** `$GITHUB_TOKEN` (set in ~/.openclaw/.env — never commit this value)
- **User/Org:** ``

---

## chub (Context Hub CLI)

- **Binary:** `/usr/local/bin/chub` or `$(npm root -g)/.bin/chub`
- **Purpose:** Fetch curated, versioned API docs for coding agents before writing code
- **Skill:** `skills/get-api-docs/SKILL.md`

---

## prev-cli Config

- **PROJECT_PATH:** `/home/node/.openclaw/workspace/prev-cli`
- **C3X:** `/home/node/.openclaw/workspace/skills/c3/bin/c3x.sh`

---

## SOT Config

- **SOT_TEMPLATE_REPO:** `https://github.com/thanh-dong/sot-template.git`
  _(Fork this and update the URL if you use a custom sot-template)_

---

Add whatever helps you do your job. This is your cheat sheet.
