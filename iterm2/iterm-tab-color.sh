#!/bin/sh
# Colours and records the iTerm2 tab of the Claude session that triggered the hook.
#
# Usage: iterm-tab-color.sh <blocked|done|clear>

set -u

. "$(dirname "$0")/iterm-tab-lib.sh"

owner=$(tab_session_owner) || exit 0
pid=${owner% *}
name=${owner#* }
device="/dev/$name"
[ -w "$device" ] || exit 0

mkdir -p "$TAB_STATE_DIR" || exit 0
state=${1:-clear}
file="$TAB_STATE_DIR/$name"

if rgb=$(tab_rgb "$state" 0); then
    tab_paint "$device" $rgb
    printf '%s %s %s\n' "$state" "$(date +%s)" "$pid" > "$file"
else
    # Leave it alone if the tab is already clear.
    current=
    [ -f "$file" ] && read -r current _stamp _pid < "$file"
    [ "$current" = idle ] && exit 0

    tab_clear "$device"
    printf 'idle 0 0\n' > "$file"
fi
