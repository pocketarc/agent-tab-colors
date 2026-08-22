#!/bin/sh
# Installs the tab-colour hooks and the launchd agent.

set -eu

LABEL=com.pocketarc.claude-tab-fade
HOOK_DIR="${HOME}/.claude/hooks"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
SOURCE_DIR=$(cd "$(dirname "$0")" && pwd)

xml_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

SWEEPER_XML=$(xml_escape "${HOOK_DIR}/iterm-tab-sweep.sh")
LOG_XML=$(xml_escape "${HOME}/.claude/run/tab-fade.err")

mkdir -p "$HOOK_DIR" "${HOME}/.claude/run" "${HOME}/Library/LaunchAgents"

for script in iterm-tab-lib.sh iterm-tab-color.sh iterm-tab-sweep.sh; do
    cp "${SOURCE_DIR}/${script}" "${HOOK_DIR}/${script}"
done
chmod +x "${HOOK_DIR}/iterm-tab-color.sh" "${HOOK_DIR}/iterm-tab-sweep.sh"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>${SWEEPER_XML}</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>${LOG_XML}</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true

# bootout is not synchronous on every macOS version.
attempt=1
until launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; do
    if [ "$attempt" -ge 5 ]; then
        echo "Could not load ${LABEL}." >&2
        exit 1
    fi
    attempt=$((attempt + 1))
    sleep 1
done

echo "Installed. Add the hooks block from settings-hooks.json to ~/.claude/settings.json,"
echo "then restart Claude Code: hook config is read once at session start."
