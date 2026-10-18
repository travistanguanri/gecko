#!/bin/bash
# Installs the Gecko app helper on a Mac. CODE is the one on your sign-up page.
#   curl -fsSL https://travistanguanri.github.io/gecko/install.sh | bash -s -- CODE
set -e

CODE="$(printf '%s' "$1" | tr -cd 'A-Za-z' | tr '[:lower:]' '[:upper:]')"
if [ "${#CODE}" -ne 4 ]; then
  echo "Add your 4-letter code at the end, like this: ... | bash -s -- ABCD"
  exit 1
fi

DIR="$HOME/.gecko"
PLIST="$HOME/Library/LaunchAgents/com.gecko.helper.plist"

# This used to be called Pause, then Snapshot: take away an older helper, so only one runs.
for old in pause snapshot; do
  launchctl bootout "gui/$(id -u)/com.$old.helper" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/com.$old.helper.plist"
  rm -rf "$HOME/.$old"
done

mkdir -p "$DIR" "$HOME/Library/LaunchAgents"
# The helper is saved as "Gecko" and run directly, because macOS lists a
# background item under the name of the file it runs. Run through bash, it
# would be listed as "bash".
curl -fsSL "https://travistanguanri.github.io/gecko/helper.sh" -o "$DIR/Gecko"
chmod +x "$DIR/Gecko"
rm -f "$DIR/helper.sh"  # where an earlier version kept it
curl -fsSL "https://travistanguanri.github.io/gecko/uninstall.sh" -o "$DIR/uninstall.sh"
printf '%s' "$CODE" > "$DIR/code.txt"

# Start the helper now and at every login.
cat > "$PLIST" <<PLIST_END
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.gecko.helper</string>
  <key>ProgramArguments</key>
  <array><string>$DIR/Gecko</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST_END
launchctl bootout "gui/$(id -u)/com.gecko.helper" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Done. The Gecko app helper is running for code $CODE."
echo "To remove it later: bash ~/.gecko/uninstall.sh"
