#!/bin/bash
# Removes the Pause app helper from a Mac: stops it, and deletes its start-up
# entry and its folder. Nothing else was installed.
launchctl bootout "gui/$(id -u)/com.pause.helper" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.pause.helper.plist"
rm -rf "$HOME/.pause"
echo "Pause app helper removed."
