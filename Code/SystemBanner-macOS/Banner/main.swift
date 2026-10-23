//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
//macOS 10.12 Sierra and later port: Copyright (c) 2026, Cole. MIT License Applies.
import Cocoa
import os.log

//true for the login window banner, started by the LoginWindow launchd agent (the macOS counterpart of /winlogon)
let loginWindow = CommandLine.arguments.contains("--loginwindow")

func log(_ message: String, _ settings: BannerSettings) {
    if settings.debug {
        //public: the unified log of macOS 10.12 and later hides "%@" arguments as <private>, NSLog included
        os_log("%{public}@", message) //shows in Console.app
    }
}

func bannerHeight(_ screen: NSScreen) -> CGFloat {
    return screen.frame.height < 1441 ? 17 : 25 //same sizes as the Windows banner, in points
}

//true when a window of another app covers the whole screen (fullscreen video, presentation, fullscreen Space)
func screenHasFullscreenApp(_ screen: NSScreen) -> Bool {
    let frame = screen.frame
    //window list coordinates start at the top left of the main screen, AppKit ones at its bottom left
    let mainHeight = NSScreen.screens[0].frame.height
    let target = CGRect(x: frame.minX, y: mainHeight - frame.maxY, width: frame.width, height: frame.height)
    guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        return false
    }
    let ownPid = Int(ProcessInfo.processInfo.processIdentifier)
    for info in windows {
        //only normal app windows: the Dock, Notification Center and others own invisible screen sized windows on higher layers
        if info[kCGWindowLayer as String] as? Int != 0 || info[kCGWindowOwnerPID as String] as? Int == ownPid {
            continue
        }
        if let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary, let bounds = CGRect(dictionaryRepresentation: boundsInfo as CFDictionary), bounds == target {
            return true
        }
    }
    return false
}

func bannerFrame(_ screen: NSScreen, bottom: Bool, fullscreen: Bool) -> NSRect {
    let frame = screen.frame
    //the visible frame leaves out the menu bar and the Dock, like the WorkingArea leaves out the taskbar on Windows;
    //there is no menu bar nor Dock on the login window, and a fullscreen app hides them
    var area = (loginWindow || fullscreen) ? frame : screen.visibleFrame
    if loginWindow && screen == NSScreen.screens[0] {
        //the login window shows its status icons (battery, Wi-Fi, user switching) at the top of the main screen, in a strip as high as the menu bar
        var strip = max(NSStatusBar.system.thickness, frame.maxY - screen.visibleFrame.maxY)
        if #available(macOS 12, *) {
            strip = max(strip, screen.safeAreaInsets.top) //the strip is as high as the notch on MacBooks that have one
        }
        area.size.height -= strip
    }
    let height = bannerHeight(screen)
    return NSRect(x: frame.minX, y: bottom ? area.minY : area.maxY - height, width: frame.width, height: height)
}

final class BannerView: NSView {
    let screenIndex: Int
    let settings: BannerSettings

    init(frame: NSRect, screenIndex: Int, settings: BannerSettings) {
        self.screenIndex = screenIndex
        self.settings = settings
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) {
        fatalError("not used")
    }
    override var isOpaque: Bool {
        return true
    }
    override func draw(_ dirtyRect: NSRect) {
        let left = settings.debug ? "\(loginWindow ? "LOGINWINDOW" : "SCREEN"): \(screenIndex)" : nil
        drawBanner(bounds, text: settings.text, background: settings.background, foreground: settings.foreground, left: left, right: settings.debug ? "DEBUG: True" : nil)
    }
}

final class BannerController: NSObject, NSApplicationDelegate {
    var banners: [NSWindow] = []
    var layout = "" //what the banners were built for, rebuilt when it changes
    var lastSummary = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        refresh()
        //1 second, the configuration and the fullscreen state have no change notification
        let timer = Timer(timeInterval: 1, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        RunLoop.current.add(timer, forMode: .common) //keep running while a menu is open
        //react right away to screens plugged in, removed or resized, and to Space changes (fullscreen apps)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    func buildBanner(_ frame: NSRect, screenIndex: Int, bottom: Bool, settings: BannerSettings) {
        let banner = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        banner.isReleasedWhenClosed = false
        banner.isOpaque = true
        banner.hasShadow = false
        banner.hidesOnDeactivate = false
        banner.canHide = false //"Hide Others" must not hide the banner
        banner.ignoresMouseEvents = true //clicks go through to the window below, a title bar under the banner can still be dragged
        //above windows and fullscreen apps; like the bottom banner of Windows sits below the taskbar, the top banner stays
        //below the menu bar (Spotlight and menus open over it) and the bottom banner below the Dock (magnified icons show over it)
        if loginWindow {
            banner.level = .screenSaver
        } else {
            banner.level = NSWindow.Level(rawValue: bottom ? Int(CGWindowLevelForKey(.dockWindow)) - 1 : NSWindow.Level.mainMenu.rawValue - 1)
        }
        banner.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        if loginWindow {
            banner.canBecomeVisibleWithoutLogin = true
        }
        banner.contentView = BannerView(frame: NSRect(origin: .zero, size: frame.size), screenIndex: screenIndex, settings: settings)
        banner.setFrame(frame, display: true)
        banner.orderFrontRegardless()
        banners.append(banner)
    }

    //frames of windows already moved or that could not be moved, not tried again until the mouse is used
    var triedWindows = Set<String>()
    var accessibilityPrompted = false

    //Accessibility access, needed to move the windows of other apps: the app itself is allowed in Security & Privacy
    //(or Privacy & Security), the system prompt is shown once per launch
    func accessibilityAllowed() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: !accessibilityPrompted] as CFDictionary
        accessibilityPrompted = true
        return AXIsProcessTrustedWithOptions(options)
    }

    //the Accessibility element of a window of pid, found by its frame: the Accessibility API has no window numbers
    func windowElement(pid: pid_t, frame: CGRect) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success, let windows = value as? [AXUIElement] else {
            return nil
        }
        for window in windows {
            var position: CFTypeRef?
            var size: CFTypeRef?
            var origin = CGPoint.zero
            var extent = CGSize.zero
            guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position) == .success,
                  AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size) == .success,
                  let positionValue = position, let sizeValue = size,
                  AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin), AXValueGetValue(sizeValue as! AXValue, .cgSize, &extent) else {
                continue
            }
            if abs(origin.x - frame.minX) < 1 && abs(origin.y - frame.minY) < 1 && abs(extent.width - frame.width) < 1 && abs(extent.height - frame.height) < 1 {
                return window
            }
        }
        return nil
    }

    //moves the windows of other apps out from under the banners, the counterpart of the AppBars of Windows;
    //rooms: for each screen without a fullscreen app, the screen and the room between its banners,
    //in window list coordinates (top left of the main screen)
    func arrangeWindows(_ rooms: [(screen: CGRect, room: CGRect)], settings: BannerSettings) {
        if NSEvent.pressedMouseButtons != 0 {
            //never fight a window being dragged or resized, and try every window again once the mouse is released
            triedWindows.removeAll()
            return
        }
        guard !rooms.isEmpty, accessibilityAllowed(),
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        let ownPid = Int(ProcessInfo.processInfo.processIdentifier)
        for info in windows {
            //only the normal windows of other apps
            guard info[kCGWindowLayer as String] as? Int == 0, let pid = info[kCGWindowOwnerPID as String] as? Int, pid != ownPid,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary, let bounds = CGRect(dictionaryRepresentation: boundsInfo as CFDictionary),
                  let area = rooms.first(where: { $0.screen.contains(CGPoint(x: bounds.midX, y: bounds.midY)) }) else {
                continue
            }
            let room = area.room
            let underTop = bounds.minY < room.minY - 0.5
            let underBottom = settings.topAndBottom && bounds.maxY > room.maxY + 0.5
            let key = "\(pid) \(bounds)"
            guard (underTop || underBottom) && !triedWindows.contains(key) else {
                continue
            }
            triedWindows.insert(key)
            //below the top banner, and shortened to end above the bottom banner, unless that leaves it too small to use
            var target = bounds
            target.origin.y = max(bounds.minY, room.minY)
            if target.maxY > room.maxY && room.maxY - target.minY >= 100 {
                target.size.height = room.maxY - target.minY
            }
            guard let window = windowElement(pid: pid_t(pid), frame: bounds) else {
                continue
            }
            var origin = target.origin
            var extent = target.size
            if let position = AXValueCreate(.cgPoint, &origin), let size = AXValueCreate(.cgSize, &extent) {
                //size first, so the window fits where it moves, then again in case the move limited it
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size)
                AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size)
                log("ARRANGED \(info[kCGWindowOwnerName as String] as? String ?? "") (\(pid)) FROM \(bounds) TO \(target)", settings)
            }
        }
    }

    @objc func refresh() {
        let settings = readSettings()
        //log the settings only when they change
        if settings.summary != lastSummary {
            lastSummary = settings.summary
            log(settings.summary, settings)
        }
        //everything the banners depend on: settings, screens, menu bar, Dock and fullscreen apps
        var frames: [NSRect] = []
        var rooms: [(screen: CGRect, room: CGRect)] = [] //for arrangeWindows, in window list coordinates
        let mainHeight = NSScreen.screens[0].frame.height
        for screen in NSScreen.screens {
            let fullscreen = !loginWindow && screenHasFullscreenApp(screen)
            let top = bannerFrame(screen, bottom: false, fullscreen: fullscreen)
            frames.append(top)
            if settings.topAndBottom {
                frames.append(bannerFrame(screen, bottom: true, fullscreen: fullscreen))
            }
            if settings.arrangeWindows && !loginWindow && !fullscreen {
                //the room between the banners, or between the top banner and the Dock
                let frame = screen.frame
                let bottom = settings.topAndBottom ? bannerFrame(screen, bottom: true, fullscreen: false).maxY : screen.visibleFrame.minY
                rooms.append((screen: CGRect(x: frame.minX, y: mainHeight - frame.maxY, width: frame.width, height: frame.height),
                              room: CGRect(x: frame.minX, y: mainHeight - top.minY, width: frame.width, height: top.minY - bottom)))
            }
        }
        let newLayout = "\(settings.summary) \(settings.debug) \(frames)"
        if newLayout != layout {
            log("REBUILDING BANNERS: \(newLayout)", settings)
            layout = newLayout
            for banner in banners {
                banner.orderOut(nil)
                banner.close()
            }
            banners.removeAll()
            for (i, frame) in frames.enumerated() {
                buildBanner(frame, screenIndex: settings.topAndBottom ? i / 2 : i, bottom: settings.topAndBottom && i % 2 == 1, settings: settings)
            }
        }
        //no periodic reordering: the few windows sharing a banner's level, like Spotlight on Snow Leopard, must stay over it while open
        if settings.arrangeWindows && !loginWindow {
            arrangeWindows(rooms, settings: settings)
        }
    }
}

//"--diag" prints what SystemBanner sees in the preferences, then quits
func writeDiagnostics() {
    var report = "SystemBanner diagnostics, \(Date())\n"
    report += "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString), user: \(NSUserName())\n\n[\(prefDomain)]\n"
    for key in prefKeys {
        let forced = CFPreferencesAppValueIsForced(key as CFString, prefDomain)
        if let value = prefValue(key) {
            report += "  \(key) = \(value) (\(type(of: value))\(forced ? ", managed" : ""))\n"
        } else {
            report += "  \(key) = not set\n"
        }
    }
    let settings = readSettings()
    report += "\nSystemBanner reads: \(settings.summary), DEBUG=\(settings.debug)\n"
    print(report, terminator: "")
}

if CommandLine.arguments.contains("--diag") {
    writeDiagnostics()
    exit(0)
}
let controller = BannerController()
NSApplication.shared.delegate = controller
NSApplication.shared.run()
