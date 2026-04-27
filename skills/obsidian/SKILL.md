---
name: obsidian
description: |
  Work with Obsidian vaults (plain Markdown notes) via notesmd-cli on Linux and headless environments. Use when reading, creating, searching, moving, or deleting notes in an Obsidian vault, managing vault configuration, working with daily notes or frontmatter, or automating vault operations from the terminal.
allowed-tools: Bash(notesmd-cli *)
compatibility: Linux (requires notesmd-cli)
---

# Obsidian

Obsidian vault = a normal folder on disk. `notesmd-cli` operates directly on the filesystem — Obsidian does **not** need to be running.

## Before running any command

If `notesmd-cli` is not found on PATH, install it first:

```bash
# Arch (AUR) — recommended
yay -S notesmd-cli-bin

# Or build from source (Go 1.19+)
git clone https://github.com/yakitrak/notesmd-cli.git && cd notesmd-cli && go build -o notesmd-cli . && sudo install -m 755 notesmd-cli /usr/local/bin/
```

Do not skip this step or fall back to other tools.

## Vault structure (typical)

- Notes: `*.md` (plain text Markdown; edit with any editor)
- Config: `.obsidian/` (workspace + plugin settings; usually don't touch from scripts)
- Canvases: `*.canvas` (JSON)
- Attachments: whatever folder you chose in Obsidian settings (images/PDFs/etc.)

## Find the active vault(s)

Obsidian desktop tracks vaults here (source of truth):

- Linux: `~/.config/obsidian/obsidian.json`

`notesmd-cli` resolves vaults from that file; vault name is typically the **folder name** (path suffix).

Fast "what vault is active / where are the notes?"

- If you've already set a default: `notesmd-cli list-vaults --default --path-only`
- Otherwise, read `~/.config/obsidian/obsidian.json` and use the vault entry with `"open": true`.
- Headless (no Obsidian installed): use `notesmd-cli add-vault /path/to/vault` instead.

Notes

- Multiple vaults common (work/personal, etc.). Don't guess; read config or use `--vault` flag.
- Avoid writing hardcoded vault paths into scripts; prefer reading the config or using `list-vaults`.

## Quick start

Pick a default vault (once):

- `notesmd-cli set-default-vault "<vault-folder-name>"`
- `notesmd-cli list-vaults --default` / `notesmd-cli list-vaults --default --path-only`

Vault management

- `notesmd-cli add-vault /path/to/vault [--set-default]` — register a vault (alias `av`)
- `notesmd-cli remove-vault "{vault-name}" | /path/to/vault` — remove from config, no files deleted (alias `rv`)
- `notesmd-cli list-vaults` — list all vaults (default marked) (alias `lv`)
- `notesmd-cli list-vaults --json` — JSON output
- `notesmd-cli list-vaults --path-only` — paths only (scripting)
- `notesmd-cli set-default-vault --open-type editor` — set default open type (obsidian|editor)

Open

- `notesmd-cli open "{note-name}" [--vault "{vault-name}"] [--section "{heading}"] [--editor]`

Search

- `notesmd-cli search [--vault "{vault-name}"] [--editor]` — interactive fuzzy search by note name
- `notesmd-cli search-content "term" [--vault "{vault-name}"] [--editor]` — search inside notes

Daily note

- `notesmd-cli daily [--vault] [--editor] [--content "..."]` — create/open daily note. Obsidian does **not** need to be running. Reads `.obsidian/daily-notes.json` for `folder`, `format`, `template`. `--content` appends if note already exists.

List & print

- `notesmd-cli list ["path"] [--vault "{vault-name}"]` — list vault contents
- `notesmd-cli print "{note-name}" [--vault "{vault-name}"]` — print note to stdout

Create / update

- `notesmd-cli create "{note-name}" --content "..." [--open] [--editor] [--vault "{vault-name}"]`
- Creates directly on disk. Obsidian does **not** need to be running.
- Existing note left unchanged unless `--overwrite` or `--append` is passed.
- When note name has no `/`, reads `.obsidian/app.json` for `newFileLocation`/`newFileFolderPath` default folder.
- Intermediate directories created automatically.

Move/rename (safe refactor)

- `notesmd-cli move "old/path/note" "new/path/note" [--open] [--editor]`
- Updates `[[wikilinks]]` and common Markdown links across the vault (this is the main win vs `mv`).

Delete

- `notesmd-cli delete "path/note" [--vault "{vault-name}"]`

Frontmatter

- `notesmd-cli frontmatter "{note}" --print [--vault "{vault-name}"]` — view (alias `fm`)
- `notesmd-cli frontmatter "{note}" --edit --key "status" --value "done"` — set field (creates if missing)
- `notesmd-cli frontmatter "{note}" --delete --key "draft"` — remove field

## Templates

Templates are `.md` files in a configured folder. `notesmd-cli` has no dedicated template command, but the skill provides shell functions for creating, listing, and scaffolding templates.

**Detect the templates folder:** Obsidian stores it in `.obsidian/templates.json` (core plugin, key `folder`) or `.obsidian/plugins/templater-obsidian/settings.json` (Templater, key `template_folder`). Falls back to `Templates/` if unconfigured.

**Shell functions** (defined in [templates.md](templates.md)):

- `obsidian-create-template "Name" "content"` — create a template in the configured folder
- `obsidian-list-templates` — list all templates in the folder
- `obsidian-scaffold-templates [--templater]` — scaffold 4 built-in templates (Meeting Note, Daily Review, Project, Book Note)
- `obsidian-new-from-template "Template Name" "New Note Path"` — instantiate a note from a template
- `obsidian-template-folder [vault_path]` — detect the configured templates folder

**Variable substitution:** Core variables (`{{date}}`, `{{time}}`, `{{title}}`) are only resolved by Obsidian's UI. For CLI-created notes, substitute them with `date`/shell replacements — see [templates.md](templates.md).

**First-time setup:** If no templates folder exists yet, see the "First-time setup" section in [templates.md](templates.md) to create the folder and write the config.

Full details, shell function source code, example templates, and Templater syntax → **[templates.md](templates.md)**

## Key flags

`--editor` (or `-e`): opens in `$EDITOR` instead of Obsidian (defaults to `vim`; auto-adds `--wait` for GUI editors like `code`, `subl`). Works with: `open`, `daily`, `search`, `search-content`, `create`, `move`.

`--vault "{vault-name}"`: specify which vault. Most commands support it. Required if no default vault is set.

`search-content` scripting flags:
- `--no-interactive` — grep-style output to stdout (no picker)
- `--format json` — JSON output (implies non-interactive)

## Headless / Server

`notesmd-cli` works **without Obsidian running** — it operates directly on the filesystem. This is different from the official Obsidian CLI (shipped with Obsidian 1.12+) which requires Obsidian running and communicates via IPC.

Setup on headless machines:

```bash
notesmd-cli add-vault /path/to/vault --set-default
notesmd-cli set-default-vault --open-type editor   # always use $EDITOR instead of Obsidian
```

Config directory: `~/.config/notesmd-cli` (migrated from `~/.config/obsidian-cli`).

## Excluded files

`search` and `search-content` respect Obsidian's **Excluded Files** setting (`Settings → Files & Links → Excluded Files`). Other commands (`open`, `move`, `print`, `frontmatter`) still access excluded files by name.

## Deprecated commands

Still work but print deprecation warning to stderr. Will be removed in next major version.

| Old | Replacement |
|---|---|
| `set-default` | `set-default-vault` |
| `print-default` | `list-vaults --default` |
| `print-default --path-only` | `list-vaults --default --path-only` |

Prefer direct edits when appropriate: open the `.md` file and change it; Obsidian will pick it up.
