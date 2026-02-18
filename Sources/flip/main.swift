import Cocoa

// MARK: - Configuration

let stackFilePath = (NSHomeDirectory() as NSString).appendingPathComponent(".flip_stack.txt")

// Virtual key codes
let kVK_ANSI_C: CGKeyCode = 8
let kVK_ANSI_V: CGKeyCode = 9

// MARK: - Stack file operations

/// Escapes newlines and backslashes so each clipboard entry occupies exactly one line.
func escape(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
}

/// Reverses the escaping applied by `escape(_:)`.
func unescape(_ text: String) -> String {
    var result = ""
    var i = text.startIndex
    while i < text.endIndex {
        let c = text[i]
        if c == "\\" {
            let next = text.index(after: i)
            if next < text.endIndex {
                switch text[next] {
                case "n":  result.append("\n"); i = text.index(after: next)
                case "r":  result.append("\r"); i = text.index(after: next)
                case "\\": result.append("\\"); i = text.index(after: next)
                default:   result.append(c);    i = next
                }
            } else {
                result.append(c)
                i = next
            }
        } else {
            result.append(c)
            i = text.index(after: i)
        }
    }
    return result
}

/// Appends `text` as a new entry at the bottom of the stack file.
func appendToStack(_ text: String) {
    let line = escape(text) + "\n"
    guard let data = line.data(using: .utf8) else { return }

    if FileManager.default.fileExists(atPath: stackFilePath) {
        guard let fh = FileHandle(forWritingAtPath: stackFilePath) else { return }
        fh.seekToEndOfFile()
        fh.write(data)
        fh.closeFile()
    } else {
        try? data.write(to: URL(fileURLWithPath: stackFilePath))
    }

    let preview = text.prefix(60).replacingOccurrences(of: "\n", with: "↵")
    print("  pushed → \"\(preview)\(text.count > 60 ? "…" : "")\"")
}

/// Removes and returns the first entry from the stack file, or `nil` if empty.
func popFromStack() -> String? {
    guard let content = try? String(contentsOfFile: stackFilePath, encoding: .utf8) else { return nil }

    var lines = content.components(separatedBy: "\n")
    if lines.last == "" { lines.removeLast() }   // drop trailing empty element
    guard !lines.isEmpty else { return nil }

    let first = lines.removeFirst()
    let remaining = lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"

    if remaining.isEmpty {
        try? FileManager.default.removeItem(atPath: stackFilePath)
    } else {
        try? remaining.write(toFile: stackFilePath, atomically: true, encoding: .utf8)
    }

    return unescape(first)
}

// MARK: - Keystroke simulation

/// Posts a key-down + key-up pair at the annotated session tap level, which is
/// downstream from our own session-level tap so we won't intercept it again.
func postKeystroke(keyCode: CGKeyCode, flags: CGEventFlags) {
    guard
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
        let up   = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    else { return }
    down.flags = flags
    up.flags   = flags
    down.post(tap: .cgAnnotatedSessionEventTap)
    up.post(tap:   .cgAnnotatedSessionEventTap)
}

// MARK: - Clipboard actions

func handleCopy() {
    // Snapshot the change count before we trigger the copy so we can detect
    // whether the target app actually wrote anything new to the pasteboard.
    let changeCountBefore = NSPasteboard.general.changeCount

    // Ask the focused app to copy its selection.
    postKeystroke(keyCode: kVK_ANSI_C, flags: .maskCommand)

    // Give the app time to process Cmd+C and update the pasteboard.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        guard NSPasteboard.general.changeCount != changeCountBefore else {
            print("  (clipboard unchanged — nothing selected?)")
            return
        }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            print("  (copied content is not plain text)")
            return
        }
        appendToStack(text)
    }
}

func handlePaste() {
    guard let text = popFromStack() else {
        print("  (stack is empty)")
        return
    }

    // Write the popped entry to the pasteboard, then trigger a paste.
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    postKeystroke(keyCode: kVK_ANSI_V, flags: .maskCommand)

    let preview = text.prefix(60).replacingOccurrences(of: "\n", with: "↵")
    print("  popped → \"\(preview)\(text.count > 60 ? "…" : "")\"")
}

// MARK: - Event tap

var eventTap: CFMachPort?

let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    // Re-enable the tap if the system disabled it (e.g. due to timeout).
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else { return Unmanaged.passRetained(event) }

    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let flags   = event.flags
    let hasCmd  = flags.contains(.maskCommand)
    let hasShift = flags.contains(.maskShift)
    let hasAlt  = flags.contains(.maskAlternate)
    let hasCtrl = flags.contains(.maskControl)

    guard hasCmd && hasCtrl && !hasShift && !hasAlt else {
        return Unmanaged.passRetained(event)
    }

    if keyCode == kVK_ANSI_C {
        handleCopy()
        return nil   // consume — don't let Cmd+Ctrl+C reach the app
    }

    if keyCode == kVK_ANSI_V {
        handlePaste()
        return nil   // consume — don't let Cmd+Ctrl+V reach the app
    }

    return Unmanaged.passRetained(event)
}

// MARK: - Accessibility permission check

func checkAccessibility() {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
    if !AXIsProcessTrustedWithOptions(options) {
        print("""

  ⚠  Accessibility permission required.
     Open System Settings → Privacy & Security → Accessibility
     and enable your terminal (or this binary).
     Then re-run flip.

""")
    }
}

// MARK: - Entry point

print("""
flip  —  clipboard stack manager
  Cmd+Ctrl+C   push selection onto stack  →  \(stackFilePath)
  Cmd+Ctrl+V   pop from stack and paste
""")

checkAccessibility()

let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: eventMask,
    callback: tapCallback,
    userInfo: nil
)

guard let tap = eventTap else {
    print("Failed to create event tap — Accessibility permission not granted.")
    exit(1)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("Running. Press Ctrl+C to quit.\n")
CFRunLoopRun()
