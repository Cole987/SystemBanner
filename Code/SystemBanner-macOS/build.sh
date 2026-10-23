#!/bin/sh
# Builds SystemBanner.app and SystemBanner Settings.app from the same Swift sources, twice:
#   ../../macOS/Binaries      universal: x86_64 for macOS 10.12 Sierra and later, arm64 for macOS 11 Big Sur and later.
#                             The Swift runtime is copied inside the apps, macOS only ships it from 10.14.4.
#   ../../macOS-ARM/Binaries  arm64 only, macOS 11 and later: no Intel code, no embedded runtime.
set -e
cd "$(dirname "$0")"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# Swift 5 language mode: no Swift concurrency, its runtime does not exist before macOS 10.15
SWIFTFLAGS="-O -swift-version 5"

# copies a built bundle into the repository and checks the copy. The repository can sit in iCloud Drive, which was seen
# removing files of a bundle a moment after it was deleted and copied again at the same place (the embedded Swift runtime
# went missing): the files are overwritten in place instead, then compared with the build after iCloud Drive settled
install_bundle()
{
    # the signature is checked on the build, the copy only has to be identical to it:
    # iCloud Drive also adds Finder attributes to the copy, which codesign refuses but git does not keep
    codesign --verify --deep --strict "$1"
    for attempt in 1 2 3; do
        mkdir -p "$2"
        cp -RpX "$1/." "$2/"
        # files the new build no longer has
        (cd "$2" && find . -type f) | while IFS= read -r FILE; do
            [ -e "$1/$FILE" ] || rm -f "$2/$FILE"
        done
        sleep 3
        if diff -rq "$1" "$2" >/dev/null; then
            return 0
        fi
        echo "[WARNING] $2 differs from the build, copying again ($attempt)"
    done
    echo "[ERROR] could not copy $2 intact"
    exit 1
}

# $1 universal or arm, $2 app name, $3 Info.plist, $4 sources folder
bundle()
{
    # built and signed outside the repository: iCloud Drive adds extended attributes that break signing
    APP="$TMP/$1/$2.app"
    EXE="$APP/Contents/MacOS/$2"
    mkdir -p "$APP/Contents/MacOS"
    swiftc $SWIFTFLAGS -target arm64-apple-macos11 Shared/*.swift "$4"/*.swift -o "$TMP/arm64"
    if [ "$1" = universal ]; then
        OUT=../../macOS/Binaries
        MIN=10.12
        swiftc $SWIFTFLAGS -target x86_64-apple-macos10.12 Shared/*.swift "$4"/*.swift -o "$TMP/x86_64" \
            -Xlinker -rpath -Xlinker @executable_path/../Frameworks
        lipo -create "$TMP/x86_64" "$TMP/arm64" -output "$EXE"
        xcrun swift-stdlib-tool --copy --sign - --scan-executable "$TMP/x86_64" --platform macosx --destination "$APP/Contents/Frameworks" > "$TMP/stdlib-$2.log" 2>&1 || { cat "$TMP/stdlib-$2.log"; exit 1; }
    else
        OUT=../../macOS-ARM/Binaries
        MIN=11.0
        cp "$TMP/arm64" "$EXE"
    fi
    cp "$3" "$APP/Contents/Info.plist"
    mkdir -p "$APP/Contents/Resources"
    cp SystemBanner.icns "$APP/Contents/Resources/"
    plutil -replace LSMinimumSystemVersion -string "$MIN" "$APP/Contents/Info.plist"
    printf 'APPL????' > "$APP/Contents/PkgInfo"
    codesign --force --sign - "$APP"
    mkdir -p "$OUT"
    install_bundle "$APP" "$OUT/$2.app"
    echo "Built $OUT/$2.app"
}
for flavor in universal arm; do
    bundle $flavor SystemBanner Info.plist Banner
    bundle $flavor "SystemBanner Settings" Settings-Info.plist Settings
done
