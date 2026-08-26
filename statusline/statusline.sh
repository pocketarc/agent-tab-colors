#!/usr/bin/env bash
# Claude Code statusLine. Reads the status JSON on stdin and prints one line.
#
# The model is styled by exception: Opus 5 with the 1M context is the configured
# default, so it renders as quiet text. Anything else gets a coloured badge —
# the badge means "you are not on your default model", and its colour says which
# model you are on instead.
#
# Written for bash 3.2 (the /bin/bash macOS ships), so no ${var^^} or mapfile.

set -u

input=$(cat 2>/dev/null || true)

model_id=""
model_name=""
cur_dir=""

if [ -n "$input" ]; then
  # One field per line rather than @tsv: bash treats tab as IFS whitespace and
  # collapses runs of it, so an empty model name would shift the directory into
  # the model slot. A blank line survives `read` intact.
  {
    IFS= read -r model_id
    IFS= read -r model_name
    IFS= read -r cur_dir
  } <<EOF
$(printf '%s' "$input" | jq -r '.model.id // "", .model.display_name // "", (.workspace.current_dir // .cwd // "")' 2>/dev/null)
EOF
fi

[ -n "$cur_dir" ] || cur_dir=$PWD

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
upper() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

haystack="$(lower "$model_id") $(lower "$model_name")"

# Matched against the id as well as the display name, so a renamed display
# string cannot silently turn the default into a false alarm. "opus-5" does not
# match "claude-opus-4-5", which is the point of anchoring on the "opus-5" pair
# rather than a bare "5".
is_1m=false
case "$haystack" in
  *"[1m]"*|*"1m context"*) is_1m=true ;;
esac

is_default=false
case "$haystack" in
  *opus-5*|*"opus 5"*) [ "$is_1m" = true ] && is_default=true ;;
esac

label=$model_name
[ -n "$label" ] || label=$model_id
[ -n "$label" ] || label="unknown model"

# Display names arrive as e.g. "Opus 5 (1M context)". The parenthetical is
# noise once the context size has its own tag.
label=${label%%(*}
label=$(printf '%s' "$label" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
[ "$is_1m" = true ] && label="$label · 1M"

reset=$'\033[0m'
dir_style=$'\033[38;2;226;232;240m'
dim=$'\033[38;2;113;122;138m'
quiet=$'\033[38;2;148;158;173m'

if [ "$is_default" = true ]; then
  model_part="${quiet}${label}${reset}"
else
  case "$haystack" in
    *opus*)   bg="167;139;250"; fg="26;16;46"   ;;
    *sonnet*) bg="96;165;250";  fg="8;24;48"    ;;
    *haiku*)  bg="74;222;128";  fg="6;38;20"    ;;
    *fable*)  bg="251;191;36";  fg="48;32;4"    ;;
    *)        bg="248;113;113"; fg="45;8;8"     ;;
  esac

  edge=$'\033[38;2;'"$bg"$'m'
  body=$'\033[1;38;2;'"$fg"$';48;2;'"$bg"$'m'

  # ▐ then ▌ fill the half-cells either side, so the chip reads as one pill
  # instead of a rectangle butted against its neighbours.
  model_part="${edge}▐${reset}${body} $(upper "$label") ${reset}${edge}▌${reset}"
fi

dir_name=$(basename "$cur_dir")

branch=$(git -C "$cur_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
  branch_part="  ${dim}⎇ ${branch}${reset}"
else
  branch_part=""
fi

printf '%s  %s%s%s%s' "$model_part" "$dir_style" "$dir_name" "$reset" "$branch_part"
