#!/usr/bin/env bash

set -u

input=$(cat 2>/dev/null || true)

model_id=""
model_name=""
cur_dir=""
five_hour=""
seven_day=""

if [ -n "$input" ]; then
  {
    IFS= read -r model_id
    IFS= read -r model_name
    IFS= read -r cur_dir
    IFS= read -r five_hour
    IFS= read -r seven_day
  } <<EOF
$(printf '%s' "$input" | jq -r '.model.id // "", .model.display_name // "", (.workspace.current_dir // .cwd // ""), (.rate_limits.five_hour.used_percentage // "" | if type == "number" then floor else "" end), (.rate_limits.seven_day.used_percentage // "" | if type == "number" then floor else "" end)' 2>/dev/null)
EOF
fi

[ -n "$cur_dir" ] || cur_dir=$PWD

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
upper() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

haystack="$(lower "$model_id") $(lower "$model_name")"

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

label=${label%%(*}
label=$(printf '%s' "$label" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
[ "$is_1m" = true ] && label="$label · 1M"

reset=$'\033[0m'
dir_style=$'\033[38;2;226;232;240m'
dim=$'\033[38;2;113;122;138m'
quiet=$'\033[38;2;148;158;173m'
warn=$'\033[38;2;251;191;36m'
alarm=$'\033[38;2;248;113;113m'

usage_style() {
  if [ "$1" -ge 80 ]; then
    printf '%s' "$alarm"
  elif [ "$1" -ge 50 ]; then
    printf '%s' "$warn"
  else
    printf '%s' "$dim"
  fi
}

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

  model_part="${edge}▐${reset}${body} $(upper "$label") ${reset}${edge}▌${reset}"
fi

dir_name=$(basename "$cur_dir")

branch=$(git -C "$cur_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
  branch_part="  ${dim}⎇ ${branch}${reset}"
else
  branch_part=""
fi

usage_part=""
case "$five_hour" in
  ''|*[!0-9]*) ;;
  *) usage_part="  $(usage_style "$five_hour")5h ${five_hour}%${reset}" ;;
esac

# Below 75% the 5-hour window is the one that runs out first, so the weekly figure is hidden until then.
case "$seven_day" in
  ''|*[!0-9]*) ;;
  *) [ "$seven_day" -ge 75 ] && usage_part="${usage_part}  $(usage_style "$seven_day")7d ${seven_day}%${reset}" ;;
esac

printf '%s  %s%s%s%s%s' "$model_part" "$dir_style" "$dir_name" "$reset" "$branch_part" "$usage_part"
