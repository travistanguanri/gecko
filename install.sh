#!/bin/bash
# Installs the Pause app helper on a Mac. CODE is the one on your sign-up page.
#   curl -fsSL https://travistanguanri.github.io/pause/install.sh | bash -s -- CODE
set -e

CODE="$(printf '%s' "$1" | tr -cd 'A-Za-z' | tr '[:lower:]' '[:upper:]')"
if [ "${#CODE}" -ne 4 ]; then
  echo "Add your 4-letter code at the end, like this: ... | bash -s -- ABCD"
  exit 1
fi

DIR="$HOME/.pause"
PLIST="$HOME/Library/LaunchAgents/com.pause.helper.plist"

mkdir -p "$DIR" "$HOME/Library/LaunchAgents"
# The helper is saved as "Pause" and run directly, because macOS lists a
# background item under the name of the file it runs. Run through bash, it
# would be listed as "bash".
curl -fsSL "https://travistanguanri.github.io/pause/helper.sh" -o "$DIR/Pause"
chmod +x "$DIR/Pause"
rm -f "$DIR/helper.sh"  # where an earlier version kept it
curl -fsSL "https://travistanguanri.github.io/pause/uninstall.sh" -o "$DIR/uninstall.sh"
printf '%s' "$CODE" > "$DIR/code.txt"

# Start the helper now and at every login.
cat > "$PLIST" <<PLIST_END
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.pause.helper</string>
  <key>ProgramArguments</key>
  <array><string>$DIR/Pause</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST_END
launchctl bootout "gui/$(id -u)/com.pause.helper" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Done. The Pause app helper is running for code $CODE."
echo "To remove it later: bash ~/.pause/uninstall.sh"
