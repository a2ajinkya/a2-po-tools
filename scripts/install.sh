#!/usr/bin/env bash
# install.sh — interactive picker to select skills & extensions to install
# Space = toggle, ↑/↓ = navigate, Enter/Shift+Enter = confirm, q = quit

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_DIR="${HOME}/.pi/agent"
SKILLS_SRC="${REPO_DIR}/skills"
EXTS_SRC="${REPO_DIR}/extensions"
SKILLS_DST="${AGENT_DIR}/skills"
EXTS_DST="${AGENT_DIR}/extensions"

# ── Colors ──────────────────────────────────────────────────────────
CLR='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
INV='\033[7m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'

# ── Helpers ─────────────────────────────────────────────────────────
_term_supports_color() { [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; }
! _term_supports_color && CLR='' && BOLD='' && DIM='' && INV='' && CYAN='' && GREEN='' && YELLOW='' && RED=''

_hide_cursor() { tput civis 2>/dev/null || printf '\033[?25l'; }
_show_cursor() { tput cnorm 2>/dev/null || printf '\033[?25h'; }
_clear_screen() { printf '\033[2J\033[H'; }
_move_up() { printf '\033[%dA' "$1"; }

# Read a single keypress (handles escape sequences including CSI u)
_read_key() {
    local key rest extra
    if ! IFS= read -rs -n1 key; then
        printf ''
        return
    fi

    # Not an escape — return as-is
    if [[ "$key" != $'\x1b' ]]; then
        printf '%s' "$key"
        return
    fi

    # Escape sequence — try to read the rest
    if IFS= read -rs -t 0.002 -n1 rest 2>/dev/null; then
        key="$key$rest"

        # CSI sequence: ESC [ ...
        if [[ "$rest" == "[" ]]; then
            while IFS= read -rs -t 0.002 -n1 extra 2>/dev/null; do
                key="$key$extra"
                # Terminators: letters, ~ (SS3), or u (kitty protocol)
                if [[ "$extra" =~ [A-Za-z~] ]] || [[ "$extra" == "u" ]]; then
                    break
                fi
            done
        fi
    fi

    printf '%s' "$key"
}

# ── Multi-select picker ─────────────────────────────────────────────
# Args: prompt_msg  items_array_name  selected_indices_array_name
picker() {
    local prompt="$1"
    local -n _items="$2"
    local -n _chosen="$3"
    local count=${#_items[@]}

    if (( count == 0 )); then
        _chosen=()
        return 0
    fi

    # State arrays
    local sel=()
    local types=()  # 'skill' or 'ext'
    for ((i = 0; i < count; i++)); do
        sel[i]=0
        if [[ "${_items[$i]}" == "[ext] "* ]]; then
            types[i]='ext'
        else
            types[i]='skill'
        fi
    done

    local cursor=0
    local header_lines=4  # title + blank + help + blank

    _hide_cursor
    trap '_show_cursor' EXIT INT TERM

    while true; do
        _clear_screen
        printf "${BOLD}a2-po-tools installer${CLR}\n\n"
        printf "%s\n\n" "$prompt"

        for ((i = 0; i < count; i++)); do
            local marker prefix item label_color

            if (( sel[i] == 1 )); then
                marker="${GREEN}◉${CLR}"
            else
                marker="${DIM}○${CLR}"
            fi

            if (( i == cursor )); then
                prefix="${INV} > ${CLR}"
            else
                prefix="   "
            fi

            item="${_items[$i]}"
            if [[ "${types[$i]}" == "ext" ]]; then
                label_color="${YELLOW}"
            else
                label_color="${CYAN}"
            fi

            printf "%s%s %s\n" "$prefix" "$marker" "${label_color}${item}${CLR}"
        done

        printf "\n${DIM}Space = toggle • ↑/↓ = navigate • Enter = confirm • q = quit${CLR}\n"

        local key
        key="$(_read_key)"

        case "$key" in
            # Arrow up
            $'\x1b[A')
                (( cursor > 0 )) && (( cursor-- ))
                ;;
            # Arrow down
            $'\x1b[B')
                (( cursor < count - 1 )) && (( cursor++ ))
                ;;
            # Space
            ' ')
                (( sel[cursor] = 1 - sel[cursor] ))
                ;;
            # Enter (CR or LF)
            $'\x0d'|$'\x0a')
                break
                ;;
            # Shift+Enter via kitty/modifyOtherKeys protocol: ESC [ 13 ; 2 u
            $'\x1b[13;2u')
                break
                ;;
            # q or Ctrl-C
            'q'|'Q')
                _show_cursor
                trap - EXIT INT TERM
                _chosen=()
                return 1
                ;;
            # Ctrl-C
            $'\x03')
                _show_cursor
                trap - EXIT INT TERM
                _chosen=()
                return 1
                ;;
        esac
    done

    _show_cursor
    trap - EXIT INT TERM

    # Build result
    _chosen=()
    for ((i = 0; i < count; i++)); do
        if (( sel[i] == 1 )); then
            _chosen+=("$i")
        fi
    done

    return 0
}

# ── Collect available items ─────────────────────────────────────────
_skills=()
_exts=()
_skill_paths=()
_ext_paths=()

if [[ -d "$SKILLS_SRC" ]]; then
    while IFS= read -r -d '' d; do
        name="$(basename "$d")"
        _skills+=("[skill] $name")
        _skill_paths+=("$d")
    done < <(find "$SKILLS_SRC" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
fi

if [[ -d "$EXTS_SRC" ]]; then
    while IFS= read -r -d '' f; do
        name="$(basename "$f")"
        _exts+=("[ext] $name")
        _ext_paths+=("$f")
    done < <(find "$EXTS_SRC" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) -print0 | sort -z)
fi

_all_items=("${_skills[@]}" "${_exts[@]}")

if (( ${#_all_items[@]} == 0 )); then
    echo "Nothing to install in ${REPO_DIR}."
    exit 1
fi

# ── Run picker ──────────────────────────────────────────────────────
_selected_indices=()
if ! picker "Select items to install (Space = toggle):" _all_items _selected_indices; then
    echo "Aborted. Nothing installed."
    exit 0
fi

if (( ${#_selected_indices[@]} == 0 )); then
    echo "Nothing selected. Nothing installed."
    exit 0
fi

# ── Install selected ────────────────────────────────────────────────
mkdir -p "$SKILLS_DST" "$EXTS_DST"

installed=0
for idx in "${_selected_indices[@]}"; do
    if (( idx < ${#_skills[@]} )); then
        src="${_skill_paths[$idx]}"
        name="$(basename "$src")"
        dst="${SKILLS_DST}/${name}"
        label="skill"
    else
        ext_idx=$(( idx - ${#_skills[@]} ))
        src="${_ext_paths[$ext_idx]}"
        name="$(basename "$src")"
        dst="${EXTS_DST}/${name}"
        label="extension"
    fi

    printf "→ Installing %s: %s\n" "$label" "$name"
    if [[ -d "$src" ]]; then
        rsync -aL --delete "$src/" "$dst/"
    else
        cp -f "$src" "$dst"
    fi
    (( ++installed ))
done

printf "\n${GREEN}Installed %d item(s).${CLR} Restart pi to pick them up.\n" "$installed"
