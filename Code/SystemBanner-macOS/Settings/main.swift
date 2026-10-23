//Copyright (c) 2026, Cole. MIT License Applies.
//SystemBanner Settings: changes the classification shown by SystemBanner, for administrators only.
//It opens only for members of the admin group, and every change asks for an administrator password,
//since /Library/Preferences/com.systembanner.plist can only be written as root.
import Cocoa
import OpenDirectory

//each item of the classification menu is tagged with the code of its classification (the Simple setting), 0 for "Not configured"
let customTag = -1
let separatorTag = -2

func isAdmin() -> Bool {
    guard let node = try? ODNode(session: ODSession.default(), type: ODNodeType(kODNodeTypeAuthentication)),
          let user = try? node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(), attributes: nil),
          let group = try? node.record(withRecordType: kODRecordTypeGroups, name: "admin", attributes: nil) else {
        return false
    }
    return (try? group.isMemberRecord(user)) != nil
}

//'text' for /bin/sh, so the custom text cannot run commands as root
func shellQuote(_ text: String) -> String {
    return "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

//pattern colors have no RGB value, nil keeps the previous one
func colorBytes(_ color: NSColor) -> [Int]? {
    guard let srgb = color.usingColorSpace(.sRGB) else {
        return nil
    }
    return [srgb.redComponent, srgb.greenComponent, srgb.blueComponent].map { Int(($0 * 255).rounded()) }
}

final class PreviewView: NSView {
    var text = ""
    var colors = unconfiguredColors

    override func draw(_ dirtyRect: NSRect) {
        drawBanner(bounds, text: text, background: sRGBColor(colors, 0), foreground: sRGBColor(colors, 3))
    }
}

final class SettingsController: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 324), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    let classification = NSPopUpButton(frame: NSRect(x: 137, y: 269, width: 345, height: 26), pullsDown: false)
    let textField = NSTextField(frame: NSRect(x: 140, y: 238, width: 360, height: 22))
    let backgroundWell = NSColorWell(frame: NSRect(x: 140, y: 200, width: 52, height: 28))
    let textWell = NSColorWell(frame: NSRect(x: 310, y: 200, width: 52, height: 28))
    let topAndBottomBox = NSButton(checkboxWithTitle: "Show a banner at the top and at the bottom of each screen", target: nil, action: nil)
    let arrangeBox = NSButton(checkboxWithTitle: "Keep windows out from under the banners (needs Accessibility access)", target: nil, action: nil)
    let debugBox = NSButton(checkboxWithTitle: "Debug logging (Console)", target: nil, action: nil)
    let preview = PreviewView(frame: NSRect(x: 20, y: 80, width: 480, height: 25))
    let status = NSTextField(labelWithString: "")
    let applyButton = NSButton(title: "Apply", target: nil, action: nil)

    func buildMenu() {
        //Quit, and Edit so copy and paste work in the text field
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit SystemBanner Settings", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = appMenu
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = editMenu
        NSApplication.shared.mainMenu = mainMenu
    }

    func addSeparator() {
        let separator = NSMenuItem.separator()
        separator.tag = separatorTag
        classification.menu?.addItem(separator)
    }

    func label(_ text: String, _ frame: NSRect) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = frame
        return label
    }

    func buildWindow() {
        window.title = "SystemBanner Settings"
        guard let content = window.contentView else {
            return
        }
        content.addSubview(label("Classification:", NSRect(x: 20, y: 276, width: 115, height: 17)))
        classification.addItem(withTitle: "Not configured")
        var system: String?
        for stock in presets {
            if stock.system != system {
                //a separator before each classification system
                addSeparator()
                system = stock.system
            }
            classification.addItem(withTitle: stock.title)
            classification.lastItem?.tag = stock.code
        }
        addSeparator()
        classification.addItem(withTitle: "Custom")
        classification.lastItem?.tag = customTag
        classification.target = self
        classification.action = #selector(classificationChanged)
        content.addSubview(classification)

        content.addSubview(label("Text:", NSRect(x: 20, y: 241, width: 115, height: 17)))
        textField.delegate = self
        content.addSubview(textField)

        content.addSubview(label("Background:", NSRect(x: 20, y: 206, width: 115, height: 17)))
        content.addSubview(backgroundWell)
        content.addSubview(label("Text color:", NSRect(x: 230, y: 206, width: 80, height: 17)))
        content.addSubview(textWell)
        for well in [backgroundWell, textWell] {
            well.target = self
            well.action = #selector(updatePreview)
        }

        topAndBottomBox.frame = NSRect(x: 18, y: 166, width: 480, height: 18)
        content.addSubview(topAndBottomBox)
        arrangeBox.frame = NSRect(x: 18, y: 142, width: 500, height: 18)
        content.addSubview(arrangeBox)
        debugBox.frame = NSRect(x: 18, y: 118, width: 480, height: 18)
        content.addSubview(debugBox)
        content.addSubview(preview)
        status.frame = NSRect(x: 20, y: 50, width: 480, height: 17)
        content.addSubview(status)

        let revertButton = NSButton(title: "Revert", target: self, action: #selector(loadSettings))
        revertButton.frame = NSRect(x: 294, y: 12, width: 110, height: 32)
        content.addSubview(revertButton)
        applyButton.frame = NSRect(x: 396, y: 12, width: 110, height: 32)
        applyButton.keyEquivalent = "\r"
        applyButton.target = self
        applyButton.action = #selector(apply)
        content.addSubview(applyButton)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        NSApplication.shared.activate(ignoringOtherApps: true)
        guard isAdmin() else {
            let alert = NSAlert()
            alert.messageText = "SystemBanner Settings is for administrators only."
            alert.informativeText = "Ask your administrator to change the classification of this Mac."
            alert.runModal()
            NSApplication.shared.terminate(nil)
            return
        }
        buildWindow()
        loadSettings()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func showStatus(_ text: String, error: Bool) {
        status.stringValue = text
        status.textColor = error ? .red : .controlTextColor
    }

    @objc func loadSettings() {
        let settings = readSettings()
        if let simple = prefInt("Simple"), preset(forCode: simple) != nil {
            classification.selectItem(withTag: simple)
        } else if prefValue("Text") != nil || prefValue("0") != nil || prefValue("3") != nil {
            classification.selectItem(withTag: customTag)
        } else {
            classification.selectItem(withTag: 0)
        }
        textField.stringValue = settings.text
        backgroundWell.color = settings.background
        textWell.color = settings.foreground
        topAndBottomBox.state = settings.topAndBottom ? .on : .off
        debugBox.state = settings.debug ? .on : .off
        arrangeBox.state = settings.arrangeWindows ? .on : .off
        classificationChanged()
        if prefsAreManaged() {
            //a profile wins over /Library/Preferences, a change here would never show
            showStatus("This Mac is managed by a configuration profile, change the classification there.", error: true)
            applyButton.isEnabled = false
        } else {
            showStatus("", error: false)
        }
    }

    @objc func classificationChanged() {
        let tag = classification.selectedTag()
        let custom = tag == customTag
        if !custom {
            //a stock classification sets its own text and colors, "Not configured" has none
            let stock = preset(forCode: tag)
            let colors = stock?.colors ?? unconfiguredColors
            textField.stringValue = stock?.text ?? unconfiguredText
            backgroundWell.color = sRGBColor(colors, 0)
            textWell.color = sRGBColor(colors, 3)
        }
        textField.isEnabled = custom
        backgroundWell.isEnabled = custom
        textWell.isEnabled = custom
        updatePreview()
    }

    func controlTextDidChange(_ notification: Notification) {
        updatePreview()
    }

    @objc func updatePreview() {
        preview.text = textField.stringValue
        if let background = colorBytes(backgroundWell.color), let foreground = colorBytes(textWell.color) {
            preview.colors = background + foreground
        }
        preview.needsDisplay = true
    }

    @objc func apply() {
        updatePreview()
        let tag = classification.selectedTag()
        let write = "/usr/bin/defaults write \(prefFile)"
        let delete = "/usr/bin/defaults delete \(prefFile)"
        var commands: [String] = []
        var customKeys = ["Text", "0", "1", "2", "3", "4", "5"]
        if tag == customTag {
            //the text cannot be empty, it would show a blank banner
            let text = textField.stringValue.components(separatedBy: .newlines).joined(separator: " ")
            if text.trimmingCharacters(in: .whitespaces).isEmpty {
                showStatus("Type the text of the banner.", error: true)
                return
            }
            commands.append("\(delete) Simple 2>/dev/null")
            commands.append("\(write) Text -string \(shellQuote(text))")
            for (i, value) in preview.colors.enumerated() {
                commands.append("\(write) \(i) -int \(value)")
            }
        } else {
            if tag > 0 {
                commands.append("\(write) Simple -int \(tag)")
            } else {
                customKeys.append("Simple")
            }
            commands += customKeys.map { "\(delete) \($0) 2>/dev/null" }
        }
        commands.append("\(write) TopAndBottom -int \(topAndBottomBox.state == .on ? 1 : 0)")
        commands.append("\(write) Debug -int \(debugBox.state == .on ? 1 : 0)")
        commands.append("\(write) ArrangeWindows -int \(arrangeBox.state == .on ? 1 : 0)")
        //the banners run as the user, they must be able to read the file
        commands.append("/bin/chmod 644 \(prefFile).plist")
        //escape for an AppleScript string, the shell command itself is already quoted
        let shell = commands.joined(separator: "; ").replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(shell)\" with administrator privileges")?.executeAndReturnError(&error)
        if let error = error {
            if error[NSAppleScript.errorNumber] as? Int == -128 {
                showStatus("Cancelled, nothing was changed.", error: true) //the password prompt was cancelled
            } else {
                showStatus("Error: \(error[NSAppleScript.errorMessage] ?? "unknown")", error: true)
            }
            return
        }
        showStatus("Saved. The banners change within a second.", error: false)
    }
}

let controller = SettingsController()
NSApplication.shared.delegate = controller
NSApplication.shared.run()
