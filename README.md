# a2-po-tools

Personal skills and extensions for [pi](https://github.com/mariozechner/pi), synced across machines.

## What's inside

| Type | Count | Path |
|------|-------|------|
| Skills | 13 | `skills/` |
| Extensions | 4 | `extensions/` |

Skills include: `frontend-design`, `obsidian`, `omarchy`, `pi-ai`, `pi-share`, `tavily-*`, `uv`

Extensions include: `explore-mode`, `plan-mode`, `files.ts`, `prompt-editor.ts`

## Usage

### Laptop (source of truth)

After editing skills or extensions on your laptop:

```bash
cd ~/a2-po-tools
./scripts/export.sh
git add -A
git commit -m "update: <describe what changed>"
git push
```

### New machine / Termux

```bash
git clone https://github.com/a2ajinkya/a2-po-tools.git ~/a2-po-tools
cd ~/a2-po-tools
./scripts/install.sh
```

## Excluded

No auth tokens, sessions, sticky notes, or settings are tracked. This repo only contains portable skills and extensions.
