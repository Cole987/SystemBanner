#!/bin/sh
# Removes SystemBanner, SystemBanner Settings and the SystemBanner preference pane. Run from Terminal as an administrator: sudo ./RemoveSystemBanner_macOS.sh
# The same script works for every macOS folder, they all install to the same places.
# The configuration (/Library/Preferences/com.systembanner.plist, profiles) is kept, delete it separately.
AGENTS="com.systembanner.agent com.systembanner.loginwindow"

if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] Run this script with sudo: sudo $0"
    exit 1
fi
VERSION=$(sw_vers -productVersion)
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
MINOR=${MINOR:-0}

USER_NAME=$(stat -f %Su /dev/console)
if [ -n "$USER_NAME" ] && [ "$USER_NAME" != "root" ] && [ "$USER_NAME" != "loginwindow" ]; then
    USER_ID=$(id -u "$USER_NAME")
    if [ "$MAJOR" -gt 10 ] || [ "$MINOR" -ge 10 ]; then
        launchctl bootout "gui/$USER_ID/com.systembanner.agent" 2>/dev/null
    else
        LOGIN_PID=$(ps -axo pid=,uid=,comm= | awk -v uid="$USER_ID" '$2 == uid && $3 ~ /loginwindow$/ { print $1; exit }')
        launchctl bsexec "$LOGIN_PID" sudo -u "$USER_NAME" launchctl unload -S Aqua /Library/LaunchAgents/com.systembanner.agent.plist 2>/dev/null
    fi
fi
# without the agent files launchd cannot start the banner again
for agent in $AGENTS; do
    rm -f "/Library/LaunchAgents/$agent.plist"
done
killall SystemBanner 2>/dev/null
rm -rf "/Library/Application Support/SystemBanner" "/Applications/Utilities/SystemBanner Settings.app" /Library/PreferencePanes/SystemBanner.prefPane

if ps -axo comm= | grep -q "SystemBanner.app/Contents/MacOS/SystemBanner"; then
    echo "[WARNING] A banner is still running, restart the Mac to remove it"
else
    echo "[OK] SystemBanner is removed"
fi
