#!/bin/sh
# Builds SystemBanner.app and the SystemBanner.prefPane System Preferences pane into ../../SnowLeopard-ElCapitan/Binaries,
# for Mac OS X 10.6 Snow Leopard to OS X 10.11 El Capitan: x86_64 only, these versions only run on Intel Macs.
# Snow Leopard also ran on 32 bit Intel Macs, today's SDK cannot build i386 any more.
set -e
cd "$(dirname "$0")"
OUT=../../SnowLeopard-ElCapitan/Binaries
FLAGS="-arch x86_64 -mmacosx-version-min=10.6 -O2 -Wall -Wunguarded-availability -fno-objc-arc -framework Cocoa"

# System Preferences of 10.6 and 10.7 is 64 bit with garbage collection, and reopens in 32 bit for a pane that does not support it,
# which then fails since there is no i386 code. Today's compilers dropped -fobjc-gc: set the "supports garbage collection"
# bit (0x2) of the Objective-C image info flags by hand, SettingsPane.m is written to run with and without garbage collection.
mark_gc_supported()
{
    OFFSET=$(otool -l "$1" | awk '/sectname __objc_imageinfo/ { found = 1 } found && $1 == "offset" { print $2; exit }')
    FLAGS=$(xxd -s $((OFFSET + 4)) -l 1 -p "$1")
    if [ -z "$OFFSET" ] || [ "$FLAGS" != "40" ]; then
        echo "[ERROR] unexpected Objective-C image info flags ($FLAGS) in $1"
        exit 1
    fi
    printf '\102' | dd of="$1" bs=1 seek=$((OFFSET + 4)) conv=notrunc 2>/dev/null # 0x40 | 0x2
}

# $1 bundle name with its extension, $2 Info.plist, then the clang options and sources
bundle()
{
    # built and signed outside the repository: iCloud Drive adds extended attributes that break signing
    NAME="$1"
    BUNDLE="$TMP/$NAME"
    PLIST="$2"
    shift 2
    mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
    clang $FLAGS "$@" -o "$BUNDLE/Contents/MacOS/SystemBanner"
    if [ "$PLIST" = Pane-Info.plist ]; then
        mark_gc_supported "$BUNDLE/Contents/MacOS/SystemBanner"
    fi
    cp "$PLIST" "$BUNDLE/Contents/Info.plist"
    cp SystemBanner.icns "$BUNDLE/Contents/Resources/"
    codesign --force --sign - "$BUNDLE"
    rm -rf "$OUT/$NAME"
    ditto --noextattr --norsrc "$BUNDLE" "$OUT/$NAME"
    echo "Built $OUT/$NAME"
}
mkdir -p "$OUT"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
bundle SystemBanner.app Info.plist SystemBanner.m Shared.m
printf 'APPL????' > "$OUT/SystemBanner.app/Contents/PkgInfo"
bundle SystemBanner.prefPane Pane-Info.plist -bundle -framework PreferencePanes -framework SecurityInterface -framework Security SettingsPane.m Shared.m
