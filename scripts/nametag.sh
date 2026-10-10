#!/usr/bin/env bash
# ------------------------------------------------------------
# Named tags for mango WM.
#
# mango has no native tag names, so this maps arbitrary names to
# real tag slots in the range 10..31 (tags 1-9 stay untouched).
# The mapping is persisted in a small state file outside the repo.
#
# Usage:
#   nametag.sh define            prompt for a new name and allocate a slot
#   nametag.sh rename            pick a name and rename it
#   nametag.sh delete            pick a name and drop the mapping
#   nametag.sh go                pick a name and view it
#   nametag.sh assign            pick a name and move focused window to it
#   nametag.sh toggle            pick a name and toggle focused window on it
#   nametag.sh show              pick a name and toggle its view
#   nametag.sh prev | next       switch to the previous / next named tag
#   nametag.sh list              print the names (one per line)
# ------------------------------------------------------------

set -euo pipefail

BASE=10            # first named-tag slot
MAX=31             # last named-tag slot
FUZZEL_LINES=10

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mango"
STATE_FILE="$STATE_DIR/named_tags"

mkdir -p "$STATE_DIR"
touch "$STATE_FILE"

die() { printf '%s\n' "$*" >&2; exit 1; }

msg() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "named tags" "$*" >/dev/null 2>&1
    else
        printf '%s\n' "$*" >&2
    fi
}

# slot<TAB>name, ordered by slot
list_slots() { sort -n -k1,1 "$STATE_FILE"; }

slot_of_name() { awk -F'\t' -v n="$1" '$2==n{print $1; exit}' "$STATE_FILE"; }

free_slot() {
    local s
    for ((s = BASE; s <= MAX; s++)); do
        if ! awk -F'\t' -v x="$s" '$1==x{found=1} END{exit found?0:1}' "$STATE_FILE"; then
            printf '%s\n' "$s"
            return 0
        fi
    done
    return 1
}

# Prompt for free text (new/renamed name).
prompt_text() {
    fuzzel --dmenu --prompt-only "$1" 2>/dev/null | head -n1
}

# Pick one existing named tag; echoes "slot<TAB>name".
select_tag() {
    local prompt="$1" idx slot name count=0
    local -a slots names
    while IFS=$'\t' read -r slot name; do
        [ -n "${slot:-}" ] || continue
        slots+=("$slot")
        names+=("$name")
        count=$((count + 1))
    done < <(list_slots)

    if [ "$count" -eq 0 ]; then
        msg "no named tags yet - create one with Mod+e then n"
        return 1
    fi

    idx=$(printf '%s\n' "${names[@]}" | \
        fuzzel --dmenu --index --lines "$FUZZEL_LINES" --minimal-lines \
        --prompt "$prompt " 2>/dev/null) || return 1
    [ -n "$idx" ] || return 1
    [ "$idx" -ge 0 ] 2>/dev/null || return 1
    printf '%s\t%s\n' "${slots[$idx]}" "${names[$idx]}"
}

cmd_define() {
    local name slot
    name=$(prompt_text "new named tag: ") || exit 0
    [ -n "$name" ] || exit 0

    if [ -n "$(slot_of_name "$name")" ]; then
        msg "named tag '$name' already exists"
        exit 0
    fi

    if ! slot=$(free_slot); then
        msg "no free tag slots ($BASE-$MAX)"
        exit 1
    fi

    printf '%s\t%s\n' "$slot" "$name" >>"$STATE_FILE"
}

cmd_rename() {
    local sel old new other slot tmp
    sel=$(select_tag "rename") || exit 0
    IFS=$'\t' read -r slot old <<<"$sel"

    new=$(prompt_text "rename '$old' to: ") || exit 0
    [ -n "$new" ] || exit 0

    other=$(slot_of_name "$new")
    if [ -n "$other" ] && [ "$other" != "$slot" ]; then
        msg "named tag '$new' already exists"
        exit 0
    fi

    tmp=$(mktemp)
    awk -F'\t' -v s="$slot" -v n="$new" 'BEGIN{OFS="\t"} $1==s{print s,n; next} {print}' \
        "$STATE_FILE" >"$tmp" && mv "$tmp" "$STATE_FILE"
}

cmd_delete() {
    local sel slot tmp
    sel=$(select_tag "delete") || exit 0
    IFS=$'\t' read -r slot _ <<<"$sel"

    tmp=$(mktemp)
    awk -F'\t' -v s="$slot" '$1!=s' "$STATE_FILE" >"$tmp" && mv "$tmp" "$STATE_FILE"
}

dispatch() { mmsg dispatch "$@"; }

# Leave the nametag key mode before opening fuzzel. Otherwise the
# unmodified letters typed into fuzzel would be intercepted by the
# nametag mode bindings (a/t/g/s/n/r/d/h/l) instead of reaching fuzzel.
reset_mode() { mmsg dispatch setkeymode,default >/dev/null 2>&1 || true; }
reset_mode

cmd_go() {
    local sel slot
    sel=$(select_tag "switch to") || exit 0
    IFS=$'\t' read -r slot _ <<<"$sel"
    dispatch view,"$slot",0
}

cmd_assign() {
    local sel slot
    sel=$(select_tag "assign window to") || exit 0
    IFS=$'\t' read -r slot _ <<<"$sel"
    dispatch tag,"$slot",0
}

cmd_toggle() {
    local sel slot
    sel=$(select_tag "toggle window on") || exit 0
    IFS=$'\t' read -r slot _ <<<"$sel"
    dispatch toggletag,"$slot"
}

cmd_show() {
    local sel slot
    sel=$(select_tag "toggle view of") || exit 0
    IFS=$'\t' read -r slot _ <<<"$sel"
    dispatch toggleview,"$slot"
}

cmd_step() {
    local dir="$1" mon active i next target slot_list count
    local -a slots

    slot_list=$(list_slots | cut -f1)
    [ -n "$slot_list" ] || exit 0
    mapfile -t slots <<<"$slot_list"
    count=${#slots[@]}

    mon=$(mmsg get cursorpos | jq -r '.monitor')
    active=$(mmsg get monitor "$mon" | jq -r '.active_tags[0]')

    target=""
    for i in "${!slots[@]}"; do
        if [ "${slots[$i]}" = "$active" ]; then
            next=$(((i + dir + count) % count))
            target="${slots[$next]}"
            break
        fi
    done

    if [ -z "$target" ]; then
        if [ "$dir" -ge 0 ]; then
            target="${slots[0]}"
        else
            target="${slots[$((count - 1))]}"
        fi
    fi

    dispatch view,"$target",0
}

case "${1:-}" in
define) cmd_define ;;
rename) cmd_rename ;;
delete) cmd_delete ;;
go) cmd_go ;;
assign) cmd_assign ;;
toggle) cmd_toggle ;;
show) cmd_show ;;
prev) cmd_step -1 ;;
next) cmd_step 1 ;;
list) list_slots | cut -f2 ;;
*) die "usage: ${0##*/} {define|rename|delete|go|assign|toggle|show|prev|next|list}" ;;
esac
