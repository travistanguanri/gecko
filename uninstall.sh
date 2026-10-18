#!/bin/bash
# Removes the Snapshot app helper from a Mac: stops it, and deletes its start-up
# entry and its folder. Nothing else was installed.
# Also the helper from when this was called Pause, if it is still there.
for name in snapshot pause; do
  launchctl bootout "gui/$(id -u)/com.$name.helper" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/com.$name.helper.plist"
  rm -rf "$HOME/.$name"
done
echo "Snapshot app helper removed."
