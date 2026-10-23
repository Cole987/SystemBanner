#!/bin/sh
# Installs SystemBanner and its System Preferences pane.
# Run from Terminal as an administrator: sudo ./InstallSystemBanner_SnowLeopard-ElCapitan.sh
# This folder is for Mac OS X 10.6 Snow Leopard to OS X 10.11 El Capitan, on 64 bit Intel Macs.
MIN_VERSION=1006 # 10.6
MAX_VERSION=1011 # 10.11
ARM_ONLY=0
OTHER_FOLDERS="macOS 10.12 and later: the macOS folder (or macOS-ARM on Apple Silicon)"

cd "$(dirname "$0")"
APPDIR="/Library/Application Support/SystemBanner"
PANE="/Library/PreferencePanes/SystemBanner.prefPane"
AGENTS="com.systembanner.agent com.systembanner.loginwindow"

if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] Run this script with sudo: sudo $0"
    exit 1
fi
VERSION=$(sw_vers -productVersion)
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
MINOR=${MINOR:-0}
NUMBER=$((MAJOR * 100 + MINOR)) # 10.6 is 1006, 11.0 is 1100, 26.6 is 2606
if [ "$NUMBER" -lt "$MIN_VERSION" ] || [ "$NUMBER" -gt "$MAX_VERSION" ]; then
    echo "[ERROR] This Mac runs $VERSION, this folder is not for it."
    echo "        Use the right folder: $OTHER_FOLDERS"
    exit 1
fi
if [ "$ARM_ONLY" = "1" ] && [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" != "1" ]; then
    echo "[ERROR] This folder is for Apple Silicon Macs, use the macOS folder on an Intel Mac"
    exit 1
fi
if [ "$MAJOR" -eq 10 ] && [ "$(sysctl -n hw.cpu64bit_capable 2>/dev/null)" != "1" ]; then
    echo "[ERROR] SystemBanner needs a 64 bit Intel Mac, this Mac has a 32 bit Core Duo processor"
    exit 1
fi
if [ ! -d Binaries/SystemBanner.app ] || [ ! -d Binaries/SystemBanner.prefPane ]; then
    echo "[ERROR] Binaries/SystemBanner.app not found, copy the whole folder"
    exit 1
fi

# stop a previous version first
for agent in $AGENTS; do
    launchctl unload "/Library/LaunchAgents/$agent.plist" 2>/dev/null
done
killall SystemBanner 2>/dev/null

echo "Copying SystemBanner.app to $APPDIR"
mkdir -p "$APPDIR"
rm -rf "$APPDIR/SystemBanner.app"
ditto Binaries/SystemBanner.app "$APPDIR/SystemBanner.app"
chown -R root:wheel "$APPDIR"
chmod -R go-w "$APPDIR"

# the SystemBanner Settings app of earlier builds is replaced by the preference pane on these versions
rm -rf "/Applications/Utilities/SystemBanner Settings.app"
echo "Copying SystemBanner.prefPane to /Library/PreferencePanes"
rm -rf "$PANE"
ditto Binaries/SystemBanner.prefPane "$PANE"
chown -R root:wheel "$PANE"
chmod -R go-w "$PANE"
# a downloaded copy would be blocked by Gatekeeper, SystemBanner is not notarized
xattr -dr com.apple.quarantine "$APPDIR/SystemBanner.app" "$PANE" 2>/dev/null

echo "Installing the launchd agents in /Library/LaunchAgents"
for agent in $AGENTS; do
    cp "LaunchAgents/$agent.plist" /Library/LaunchAgents/
    chown root:wheel "/Library/LaunchAgents/$agent.plist"
    chmod 644 "/Library/LaunchAgents/$agent.plist"
done

# start the banner in the session of the user logged in at the screen, the next logons start it by themselves
USER_NAME=$(stat -f %Su /dev/console)
if [ -n "$USER_NAME" ] && [ "$USER_NAME" != "root" ] && [ "$USER_NAME" != "loginwindow" ]; then
    USER_ID=$(id -u "$USER_NAME")
    if [ "$NUMBER" -ge 1010 ]; then
        launchctl bootstrap "gui/$USER_ID" /Library/LaunchAgents/com.systembanner.agent.plist 2>/dev/null
    else
        # before 10.10, load the agent from inside the user's session, found through its loginwindow process
        LOGIN_PID=$(ps -axo pid=,uid=,comm= | awk -v uid="$USER_ID" '$2 == uid && $3 ~ /loginwindow$/ { print $1; exit }')
        launchctl bsexec "$LOGIN_PID" sudo -u "$USER_NAME" launchctl load -S Aqua /Library/LaunchAgents/com.systembanner.agent.plist
    fi
fi

sleep 3
if ps -axo comm= | grep -q "SystemBanner.app/Contents/MacOS/SystemBanner"; then
    echo "[OK] The SystemBanner banner is running"
else
    echo "[WARNING] The banner is not running yet, log out and back in to start it"
fi
echo "Change the classification in System Preferences > Other > SystemBanner (click the lock, administrators only)."
echo "The login window banner shows the next time the login window appears (log out to see it)."
