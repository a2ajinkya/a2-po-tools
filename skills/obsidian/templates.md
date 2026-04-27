# Obsidian Templates

Templates are just `.md` files stored in a specific folder. `notesmd-cli` creates them like any other note — the trick is knowing **which folder** Obsidian expects.

## How Obsidian stores template settings

### Core Templates plugin

Config file: `<vault>/.obsidian/templates.json`

```json
{
  "folder": "Templates"
}
```

- If the file **doesn't exist** or `"folder"` is empty/missing, Obsidian uses the vault root (no subfolder).
- The `"folder"` value is a **relative path** from the vault root (e.g. `"Templates"`, `"Meta/Templates"`).

### Templater (community plugin)

Config file: `<vault>/.obsidian/plugins/templater-obsidian/settings.json`

```json
{
  "template_folder": "Templates"
}
```

- Key is `"template_folder"` (not `"folder"`).
- If missing, defaults to empty (vault root).

### Daily Notes template

Config file: `<vault>/.obsidian/daily-notes.json`

```json
{
  "folder": "Daily",
  "format": "YYYY-MM-DD",
  "template": "Templates/Daily Note"
}
```

- `"template"` is a **note path** (relative to vault, without `.md`).
- `notesmd-cli daily` already reads this config automatically.

## Detect the templates folder

Run this to find the configured templates folder for a vault:

```bash
obsidian-template-folder() {
  local vault_path="${1:-.}"
  local folder=""

  # 1. Try Templater settings (community plugin)
  if [ -f "$vault_path/.obsidian/plugins/templater-obsidian/settings.json" ]; then
    folder=$(python3 -c "
import json, sys
with open('$vault_path/.obsidian/plugins/templater-obsidian/settings.json') as f:
    d = json.load(f)
print(d.get('template_folder', ''))
" 2>/dev/null)
  fi

  # 2. Try core Templates plugin
  if [ -z "$folder" ] && [ -f "$vault_path/.obsidian/templates.json" ]; then
    folder=$(python3 -c "
import json, sys
with open('$vault_path/.obsidian/templates.json') as f:
    d = json.load(f)
print(d.get('folder', ''))
" 2>/dev/null)
  fi

  # 3. Default
  if [ -z "$folder" ]; then
    folder="Templates"
  fi

  echo "$folder"
}
```

Returns the relative folder path (e.g. `Templates`). Falls back to `Templates` if nothing is configured — this is the most common convention.

## Shell functions

Add these to your shell profile, or just run them inline.

### Create a template

```bash
obsidian-create-template() {
  local name="$1"
  local content="$2"
  local vault_flag="${3:---vault \"$(notesmd-cli list-vaults --default --path-only 2>/dev/null)\"}"
  local template_folder

  vault_path=$(notesmd-cli list-vaults --default --path-only 2>/dev/null)
  template_folder=$(obsidian-template-folder "$vault_path")

  notesmd-cli create "${template_folder}/${name}" --content "$content" $vault_flag
}
```

**Usage:**

```bash
obsidian-create-template "Meeting Note" "# {{title}}

**Date:** {{date}}
**Attendees:**
**Agenda:**

## Notes

## Action Items
- [ ] "
```

### List templates

```bash
obsidian-list-templates() {
  local vault_path
  vault_path=$(notesmd-cli list-vaults --default --path-only 2>/dev/null)
  local template_folder
  template_folder=$(obsidian-template-folder "$vault_path")

  notesmd-cli list "${template_folder}" "$@"
}
```

### Scaffold built-in templates

Creates a set of commonly-used templates at once. Pass `--templater` to use Templater syntax instead of core variables.

```bash
obsidian-scaffold-templates() {
  local vault_path
  vault_path=$(notesmd-cli list-vaults --default --path-only 2>/dev/null)
  local template_folder
  template_folder=$(obsidian-template-folder "$vault_path")
  local use_templater="${1:-}"  # pass "--templater" to use Templater syntax

  if [ "$use_templater" = "--templater" ]; then
    local date_var='<% tp.date.now("YYYY-MM-DD") %>'
    local time_var='<% tp.date.now("HH:mm") %>'
    local title_var='<% tp.file.title %>'
  else
    local date_var='{{date}}'
    local time_var='{{time}}'
    local title_var='{{title}}'
  fi

  # Meeting Note
  notesmd-cli create "${template_folder}/Meeting Note" --content "# ${title_var}

**Date:** ${date_var}
**Time:** ${time_var}
**Attendees:**
**Agenda:**

## Notes

## Action Items
- [ ] " --overwrite

  # Daily Review
  notesmd-cli create "${template_folder}/Daily Review" --content "---
type: review
date: ${date_var}
---

# Daily Review - ${date_var}

## Gratitude
-

## Highlights
-

## Tasks
- [ ]

## Reflections
" --overwrite

  # Project
  notesmd-cli create "${template_folder}/Project" --content "---
type: project
status: active
created: ${date_var}
---

# ${title_var}

## Overview
**Goal:**
**Deadline:**
**Status:** active

## Key Results
1.
2.
3.

## Notes

## Resources
-
" --overwrite

  # Book Note
  notesmd-cli create "${template_folder}/Book Note" --content "---
type: book
rating:
date_read: ${date_var}
---

# ${title_var}

**Author:**
**Genre:**
**Pages:**

## Summary

## Key Takeaways
1.
2.
3.

## Quotes
-

## Notes
" --overwrite

  echo "Scaffolded templates in ${template_folder}/"
}
```

## Instantiating notes from templates

`notesmd-cli` has no "insert template" command — that's an Obsidian UI feature. But you can create a new note based on a template:

```bash
# 1. Read the template content
template=$(notesmd-cli print "Templates/Meeting Note")

# 2. Create a new note with that content (customize as needed)
notesmd-cli create "Meetings/2026-04-17 Project Sync" --content "$template"
```

For a reusable shell function:

```bash
obsidian-new-from-template() {
  local template_name="$1"
  local note_name="$2"
  local vault_flag="${3:---vault \"$(notesmd-cli list-vaults --default --path-only 2>/dev/null)\"}"

  local template_folder
  vault_path=$(notesmd-cli list-vaults --default --path-only 2>/dev/null)
  template_folder=$(obsidian-template-folder "$vault_path")

  local content
  content=$(notesmd-cli print "${template_folder}/${template_name}" 2>/dev/null)

  if [ -z "$content" ]; then
    echo "Error: Template '${template_name}' not found in ${template_folder}/" >&2
    return 1
  fi

  notesmd-cli create "$note_name" --content "$content" $vault_flag
}
```

**Usage:**

```bash
obsidian-new-from-template "Meeting Note" "Meetings/2026-04-17 Project Sync"
```

Note: Core template variables (`{{title}}`, `{{date}}`, `{{time}}`) are **only resolved by Obsidian when inserting through the UI**. When you create a note from CLI, the literal `{{date}}` text stays as-is. If you need resolved values, substitute them yourself:

```bash
today=$(date +%Y-%m-%d)
now=$(date +%H:%M)
content=$(notesmd-cli print "Templates/Meeting Note")
content="${content//\{\{date\}\}/$today}"
content="${content//\{\{time\}\}/$now}"
content="${content//\{\{title\}\}/My Meeting}"
notesmd-cli create "Meetings/My Meeting" --content "$content"
```

## First-time setup

If the vault has no templates folder configured yet:

```bash
# 1. Create the folder in the vault
vault_path=$(notesmd-cli list-vaults --default --path-only 2>/dev/null)
mkdir -p "$vault_path/Templates"

# 2. Tell Obsidian about it — write the config
# For core Templates plugin:
echo '{"folder":"Templates"}' > "$vault_path/.obsidian/templates.json"

# 3. Scaffold starter templates
obsidian-scaffold-templates

# 4. (Re)open Obsidian — it will pick up the new config automatically
```

For Templater instead of core plugin:

```bash
mkdir -p "$vault_path/.obsidian/plugins/templater-obsidian"
echo '{"template_folder":"Templates"}' > "$vault_path/.obsidian/plugins/templater-obsidian/settings.json"
```

## Template variable reference

### Core Templates plugin

| Variable | Resolved by |
|---|---|
| `{{title}}` | Obsidian UI (insert template) |
| `{{date}}` | Obsidian UI (insert template) |
| `{{time}}` | Obsidian UI (insert template) |

Format overrides: `{{date:YYYY-MM-DD}}`, `{{time:HH:mm}}`

### Templater plugin

| Variable | Resolved by |
|---|---|
| `<% tp.file.title %>` | Obsidian UI / Templater |
| `<% tp.date.now("YYYY-MM-DD") %>` | Obsidian UI / Templater |
| `<% tp.date.now("HH:mm") %>` | Obsidian UI / Templater |
| `<% tp.date.yesterday("YYYY-MM-DD") %>` | Obsidian UI / Templater |
| `<% tp.date.tomorrow("YYYY-MM-DD") %>` | Obsidian UI / Templater |
| `<% tp.file.cursor() %>` | Obsidian UI / Templater |

Templater also supports prompts, multi-cursor, and JavaScript — see [Templater docs](https://silentvoid13.github.io/Templater/).
