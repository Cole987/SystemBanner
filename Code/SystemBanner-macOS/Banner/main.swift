//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
//macOS 10.12 Sierra and later port: Copyright (c) 2026, Cole. MIT License Applies.
import Cocoa

//true for the login window banner, started by the LoginWindow launchd agent (the macOS counterpart of /winlogon)
let loginWindow = CommandLine.arguments.contains("--loginwindow")

func log(_ message: String, _ settings: BannerSettings) {
    if settings.debug {
        NSLog("%@", message) //shows in Console.app
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

    @objc func refresh() {
        let settings = readSettings()
        //log the settings only when they change
        if settings.summary != lastSummary {
            lastSummary = settings.summary
            log(settings.summary, settings)
        }
        //everything the banners depend on: settings, screens, menu bar, Dock and fullscreen apps
        var frames: [NSRect] = []
        for screen in NSScreen.screens {
            let fullscreen = !loginWindow && screenHasFullscreenApp(screen)
            frames.append(bannerFrame(screen, bottom: false, fullscreen: fullscreen))
            if settings.topAndBottom {
                frames.append(bannerFrame(screen, bottom: true, fullscreen: fullscreen))
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
