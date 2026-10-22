//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
//macOS 10.12 Sierra and later port: Copyright (c) 2026, Cole. MIT License Applies.
//Shared by the banner (Banner/main.swift) and SystemBanner Settings (Settings/main.swift).
import Cocoa

//the preferences domain, the macOS counterpart of HKLM\SOFTWARE\Policies\SystemBanner
let prefDomain = "com.systembanner" as CFString
let prefFile = "/Library/Preferences/com.systembanner"
let prefKeys = ["Simple", "0", "1", "2", "3", "4", "5", "Text", "TopAndBottom", "Debug"]

//stock colors for basic us gov classification based on gsa form color info collected by Frank Caviggia @ https://github.com/fcaviggia/classification-banner
//background red, green, blue, then text red, green, blue, same order as the "0" to "5" preference keys
let stockColors: [[Int]] = [
    [255, 255, 255, 0, 0, 0],       //unconfigured
    [0, 122, 51, 255, 255, 255],    //UNCLASSIFIED
    [48, 31, 85, 255, 255, 255],    //CUI
    [0, 51, 160, 255, 255, 255],    //CONFIDENTIAL
    [200, 16, 46, 255, 255, 255],   //SECRET
    [255, 103, 31, 255, 255, 255],  //TOP SECRET
    [247, 234, 72, 0, 0, 0]         //TOP SECRET//SCI
]
let stockTexts = ["Classification is not configured.", "UNCLASSIFIED", "CUI", "CONFIDENTIAL", "SECRET", "TOP SECRET", "TOP SECRET//SCI"]

struct BannerSettings: Equatable {
    var colors = stockColors[0]
    var text = stockTexts[0]
    var topAndBottom = false
    var debug = false

    var summary: String {
        return "PREFERENCES: TEXT=\(text), COLORS=\(colors.map { String($0) }.joined(separator: ",")), TOPANDBOTTOM=\(topAndBottom)"
    }
    var background: NSColor { return sRGBColor(colors, 0) }
    var foreground: NSColor { return sRGBColor(colors, 3) }
}

//a value set by a configuration profile wins, otherwise only the computer wide /Library/Preferences file counts:
//CFPreferencesCopyAppValue alone would also read ~/Library/Preferences, and let any user override the classification
func prefValue(_ key: String) -> Any? {
    if CFPreferencesAppValueIsForced(key as CFString, prefDomain) {
        return CFPreferencesCopyAppValue(key as CFString, prefDomain)
    }
    if let value = CFPreferencesCopyValue(key as CFString, prefDomain, kCFPreferencesAnyUser, kCFPreferencesAnyHost) {
        return value
    }
    //Mac OS X 10.6.8 does not return these values to a user process, read the file itself in case a later version does the same
    return NSDictionary(contentsOfFile: prefFile + ".plist")?[key]
}

//profiles store numbers, hand made plists sometimes store strings, accept both
func prefInt(_ key: String) -> Int? {
    switch prefValue(key) {
    case let number as NSNumber:
        return number.intValue
    case let text as NSString:
        return text.integerValue
    default:
        return nil
    }
}

//true when a configuration profile sets SystemBanner, /Library/Preferences is then ignored
func prefsAreManaged() -> Bool {
    return prefKeys.contains { CFPreferencesAppValueIsForced($0 as CFString, prefDomain) }
}

func readSettings() -> BannerSettings {
    //pick up changes written by another process (defaults, profiles, SystemBanner Settings) since the last read
    CFPreferencesSynchronize(prefDomain, kCFPreferencesAnyUser, kCFPreferencesAnyHost)
    CFPreferencesAppSynchronize(prefDomain)
    var settings = BannerSettings()
    for i in 0..<6 {
        if let value = prefInt(String(i)), (0...255).contains(value) {
            settings.colors[i] = value
        }
    }
    if let text = prefValue("Text") as? String {
        settings.text = text
    }
    //override custom if simple value is set
    if let simple = prefInt("Simple"), (1...6).contains(simple) {
        settings.colors = stockColors[simple]
        settings.text = stockTexts[simple]
    }
    settings.debug = prefInt("Debug") == 1
    settings.topAndBottom = prefInt("TopAndBottom") == 1
    return settings
}

func sRGBColor(_ colors: [Int], _ offset: Int) -> NSColor {
    return NSColor(srgbRed: CGFloat(colors[offset]) / 255, green: CGFloat(colors[offset + 1]) / 255, blue: CGFloat(colors[offset + 2]) / 255, alpha: 1)
}

//draws a banner (color, centered text) in rect, also used by the Settings preview
func drawBanner(_ rect: NSRect, text: String, background: NSColor, foreground: NSColor, left: String? = nil, right: String? = nil) {
    background.set()
    rect.fill()
    let font = NSFont(name: "Arial-BoldMT", size: rect.height - 3) ?? NSFont.boldSystemFont(ofSize: rect.height - 3)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
    //center the capital letters, markings are in capitals: centering the whole line box (with room for descenders,
    //and computed differently by each macOS version) put the text too low; without .usesLineFragmentOrigin
    //the origin given to draw(with:) is the baseline, the same on every version
    let baseline = rect.minY + ((rect.height - font.capHeight) / 2).rounded(.up) //half points go up: sharp text, and it looks centered
    func draw(_ string: String, x: (CGFloat) -> CGFloat) {
        let width = (string as NSString).size(withAttributes: attributes).width
        (string as NSString).draw(with: NSRect(x: x(width), y: baseline, width: width + 1, height: 0), options: [], attributes: attributes)
    }
    draw(text) { rect.minX + floor((rect.width - $0) / 2) }
    if let left = left {
        draw(left) { _ in rect.minX + 4 }
    }
    if let right = right {
        draw(right) { rect.maxX - $0 - 4 }
    }
}
