//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
//macOS 10.12 Sierra and later port: Copyright (c) 2026, Cole. MIT License Applies.
//Shared by the banner (Banner/main.swift) and SystemBanner Settings (Settings/main.swift).
import Cocoa

//the preferences domain, the macOS counterpart of HKLM\SOFTWARE\Policies\SystemBanner
let prefDomain = "com.systembanner" as CFString
let prefFile = "/Library/Preferences/com.systembanner"
let prefKeys = ["Simple", "0", "1", "2", "3", "4", "5", "Text", "TopAndBottom", "Debug", "ArrangeWindows"]

//a stock classification, chosen with the Simple setting
struct Preset {
    let code: Int       //value of the Simple setting
    let system: String  //classification system, groups the classifications in the settings
    let text: String
    let colors: [Int]   //background red, green, blue, then text red, green, blue, same order as the "0" to "5" preference keys

    var title: String { //"France – SECRET", for the settings
        return "\(system) \u{2013} \(text)"
    }
}

let unconfiguredColors = [255, 255, 255, 0, 0, 0]
let unconfiguredText = "Classification is not configured."

//stock classifications, by system; the code is the value of the Simple setting, 1 to 6 for the United States as before,
//then a range of ten per system; national colors are used where an official text sets them, NATO follows a common unofficial convention, the others are neutral
//(white on black, so they cannot be taken for the black on white unconfigured banner)
let presets = [
    //United States: gsa form color info collected by Frank Caviggia @ https://github.com/fcaviggia/classification-banner
    Preset(code: 1, system: "United States", text: "UNCLASSIFIED", colors: [0, 122, 51, 255, 255, 255]),
    Preset(code: 2, system: "United States", text: "CUI", colors: [48, 31, 85, 255, 255, 255]),
    Preset(code: 3, system: "United States", text: "CONFIDENTIAL", colors: [0, 51, 160, 255, 255, 255]),
    Preset(code: 4, system: "United States", text: "SECRET", colors: [200, 16, 46, 255, 255, 255]),
    Preset(code: 5, system: "United States", text: "TOP SECRET", colors: [255, 103, 31, 255, 255, 255]),
    Preset(code: 6, system: "United States", text: "TOP SECRET//SCI", colors: [247, 234, 72, 0, 0, 0]),
    //France: decree 2019-1271 and IGI 1300 (2021) stamp SECRET and TRES SECRET in red; DIFFUSION RESTREINTE is a protection mark, not a classification, with no color: neutral
    Preset(code: 11, system: "France", text: "DIFFUSION RESTREINTE", colors: [0, 0, 0, 255, 255, 255]),
    Preset(code: 12, system: "France", text: "SECRET", colors: [200, 16, 46, 255, 255, 255]),
    Preset(code: 13, system: "France", text: "TRÈS SECRET", colors: [200, 16, 46, 255, 255, 255]),
    //Germany: VS-Anweisung annex IV (2023) marks STRENG GEHEIM and GEHEIM in red, with crossed yellow and red stripes for STRENG GEHEIM folders,
    //and a blue stripe for VS-VERTRAULICH; VS-NUR FUER DEN DIENSTGEBRAUCH is marked in black or blue: neutral
    Preset(code: 21, system: "Germany", text: "VS-NUR FÜR DEN DIENSTGEBRAUCH", colors: [0, 0, 0, 255, 255, 255]),
    Preset(code: 22, system: "Germany", text: "VS-VERTRAULICH", colors: [0, 51, 160, 255, 255, 255]),
    Preset(code: 23, system: "Germany", text: "GEHEIM", colors: [200, 16, 46, 255, 255, 255]),
    Preset(code: 24, system: "Germany", text: "STRENG GEHEIM", colors: [200, 16, 46, 247, 234, 72]),
    //United Kingdom: the Government Security Classifications guidance discourages color coding: neutral
    Preset(code: 31, system: "United Kingdom", text: "OFFICIAL", colors: [0, 0, 0, 255, 255, 255]),
    Preset(code: 32, system: "United Kingdom", text: "OFFICIAL-SENSITIVE", colors: [0, 0, 0, 255, 255, 255]),
    Preset(code: 33, system: "United Kingdom", text: "SECRET", colors: [0, 0, 0, 255, 255, 255]),
    Preset(code: 34, system: "United Kingdom", text: "TOP SECRET", colors: [0, 0, 0, 255, 255, 255]),
    //NATO: AC/35-D/2002-REV5 sets no colors; common unofficial convention reusing the United States colors (orange for NATO RESTRICTED, yellow for COSMIC TOP SECRET)
    Preset(code: 41, system: "NATO", text: "NATO UNCLASSIFIED", colors: [0, 122, 51, 255, 255, 255]),
    Preset(code: 42, system: "NATO", text: "NATO RESTRICTED", colors: [255, 103, 31, 255, 255, 255]),
    Preset(code: 43, system: "NATO", text: "NATO CONFIDENTIAL", colors: [0, 51, 160, 255, 255, 255]),
    Preset(code: 44, system: "NATO", text: "NATO SECRET", colors: [200, 16, 46, 255, 255, 255]),
    Preset(code: 45, system: "NATO", text: "COSMIC TOP SECRET", colors: [247, 234, 72, 0, 0, 0]),
    //United Nations: ST/SGB/2007/6 sets no colors: neutral; "UN" keeps the levels apart from the United States ones
    Preset(code: 51, system: "United Nations", text: "UN CONFIDENTIAL", colors: [0, 0, 0, 255, 255, 255]),
    Preset(code: 52, system: "United Nations", text: "UN STRICTLY CONFIDENTIAL", colors: [0, 0, 0, 255, 255, 255])
]

func preset(forCode code: Int) -> Preset? { //nil when no stock classification has this code
    return presets.first { $0.code == code }
}

struct BannerSettings: Equatable {
    var colors = unconfiguredColors
    var text = unconfiguredText
    var topAndBottom = false
    var arrangeWindows = false //move the windows of other apps out from under the banners (needs Accessibility access)
    var debug = false

    var summary: String {
        return "PREFERENCES: TEXT=\(text), COLORS=\(colors.map { String($0) }.joined(separator: ",")), TOPANDBOTTOM=\(topAndBottom), ARRANGEWINDOWS=\(arrangeWindows)"
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
    if let simple = prefInt("Simple"), let stock = preset(forCode: simple) {
        settings.colors = stock.colors
        settings.text = stock.text
    }
    settings.debug = prefInt("Debug") == 1
    settings.topAndBottom = prefInt("TopAndBottom") == 1
    settings.arrangeWindows = prefInt("ArrangeWindows") == 1
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
