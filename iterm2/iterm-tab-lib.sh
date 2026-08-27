TAB_STATE_DIR="${HOME}/.claude/run/tab-color"
TAB_FADE_SECONDS=172800
TAB_NEUTRAL=120

# Echo "<pid> <tty-name>" for the nearest ancestor that owns a terminal.
tab_session_owner() {
    _pid=$$
    while [ "$_pid" -gt 1 ]; do
        _tty=$(ps -o tty= -p "$_pid" 2>/dev/null | tr -d ' ')
        case "$_tty" in
            '' | '??') ;;
            *)
                echo "$_pid $_tty"
                return 0
                ;;
        esac
        _pid=$(ps -o ppid= -p "$_pid" 2>/dev/null | tr -d ' ')
        [ -n "$_pid" ] || return 1
    done
    return 1
}

# tab_rgb <state> <age-seconds>: echo "r g b" interpolated from the state's base colour toward neutral grey.
tab_rgb() {
    case "$1" in
        blocked)
            _r=200 _g=40 _b=40
            ;;
        done)
            _r=190 _g=140 _b=30
            ;;
        *) return 1 ;;
    esac

    _age=$2
    [ "$_age" -lt 0 ] && _age=0
    [ "$_age" -ge "$TAB_FADE_SECONDS" ] && return 1

    echo "$((_r + (TAB_NEUTRAL - _r) * _age / TAB_FADE_SECONDS)) $((_g + (TAB_NEUTRAL - _g) * _age / TAB_FADE_SECONDS)) $((_b + (TAB_NEUTRAL - _b) * _age / TAB_FADE_SECONDS))"
}

# tab_paint <device> <r> <g> <b>
tab_paint() {
    printf '\033]6;1;bg;red;brightness;%s\a\033]6;1;bg;green;brightness;%s\a\033]6;1;bg;blue;brightness;%s\a' "$2" "$3" "$4" > "$1"
}

tab_clear() {
    printf '\033]6;1;bg;*;default\a' > "$1"
}
