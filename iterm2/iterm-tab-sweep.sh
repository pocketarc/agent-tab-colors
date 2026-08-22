#!/bin/sh
# Repaints every paused Claude tab at its current point in the fade.

set -u

. "$(dirname "$0")/iterm-tab-lib.sh"

[ -d "$TAB_STATE_DIR" ] || exit 0
now=$(date +%s)

for file in "$TAB_STATE_DIR"/*; do
    [ -f "$file" ] || continue
    read -r state stamp pid < "$file" || continue
    [ "$state" = idle ] && continue

    device="/dev/$(basename "$file")"
    [ -w "$device" ] || continue

    # A dead session leaves its colour behind, and its device may since have been handed to something else entirely.
    if ps -p "$pid" > /dev/null 2>&1 && rgb=$(tab_rgb "$state" $((now - stamp))); then
        tab_paint "$device" $rgb
    else
        tab_clear "$device"
        printf 'idle 0 0\n' > "$file"
    fi
done
