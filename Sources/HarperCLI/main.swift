import Cocoa
import HarperSwift

@main
struct HarperCLI {
    static func main() {
        let isGUI = CommandLine.arguments.count > 1 && CommandLine.arguments[1] == "-w"
        let cliArgs = isGUI ? Array(CommandLine.arguments.dropFirst()) : CommandLine.arguments

        let docText = cliArgs.count > 1 ? cliArgs[1] : "Hello, World ! This is Harper text parsing."
        let doc = Harper.Document(text: docText)!
        let lintGroup = Harper.LintGroup()!
        let lints = doc.getLints(lintGroup: lintGroup)

        if !isGUI {
            print("👓 Harper Swift CLI")
            print("ℹ️ Version: \(Harper.version())")

            print("📝 Document text: \(doc.getText() ?? "<nil>")")
            print("📊 Token count: \(doc.getTokenCount())")
            print("🔍 Lint count: \(lints.count)")

            for (i, lint) in lints.enumerated() {
                let fragment = lint.textFragment(from: doc) ?? "<nil>"
                print("⚠️ Lint \(i): \(lint.message() ?? "<nil>") [\"\(fragment)\"]")

                let suggCount = lint.suggestionCount()
                if suggCount > 0 {
                    print("  \(suggCount) suggestion(s):")
                    for j in 0..<suggCount {
                        if let suggestion = lint.suggestionText(at: j) {
                            print("    👉 \(j + 1). \(suggestion)")
                        }
                    }
                }
            }
        } else {
            // print("🎨 GUI mode enabled - opening rich text window")

            class AppDelegate: NSObject, NSApplicationDelegate {
                var window: NSWindow?
                var scrollView: NSScrollView?
                var textView: NSTextView?

                // Keep references to data models inside the delegate
                var doc: Harper.Document?
                var lints: [Harper.Lint] = []

                func applicationDidFinishLaunching(_ notification: Notification) {
                    let screen = NSScreen.main ?? NSScreen.screens[0]
                    let screenSize = screen.frame.size

                    let width = screenSize.width * 7 / 8
                    let height = screenSize.height * 7 / 8
                    let x = (screenSize.width - width) / 2
                    let y = (screenSize.height - height) / 2

                    let frameRect = NSRect(x: x, y: y, width: width, height: height)

                    window = NSWindow(
                        contentRect: frameRect,
                        styleMask: [.titled, .closable, .resizable],
                        backing: .buffered,
                        defer: false
                    )

                    window?.title = "Harper Swift (Harper Core version \(Harper.version()))"

                    let scroll = NSScrollView(
                        frame: NSRect(x: 0, y: 0, width: width, height: height))
                    scroll.hasVerticalScroller = true
                    scroll.hasHorizontalScroller = false
                    scroll.autoresizingMask = [.width, .height]
                    self.scrollView = scroll

                    let text = NSTextView(frame: scroll.bounds)
                    text.autoresizingMask = [.width]
                    text.isRichText = true
                    // Make it a read-only terminal dashboard style, but selectable
                    text.isEditable = false
                    text.isSelectable = true
                    text.textContainerInset = NSSize(width: 24, height: 24)
                    self.textView = text

                    // --- Build Rich Text Stream mirroring CLI output ---
                    let richConsoleOutput = NSMutableAttributedString()

                    // Define Base Monospace Typography (Matches Terminal Look)
                    let standardFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
                    let boldFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)

                    // Helper to append a single line with dedicated styling
                    func appendLine(_ string: String, color: NSColor, font: NSFont = standardFont) {
                        let attrs: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: color,
                        ]
                        let attributedLine = NSAttributedString(
                            string: string + "\n", attributes: attrs)
                        richConsoleOutput.append(attributedLine)
                    }

                    // Header Metadata Block
                    appendLine("👓 Harper Dashboard Output", color: .labelColor, font: boldFont)
                    appendLine(
                        "----------------------------------------", color: .secondaryLabelColor)
                    appendLine("📝 Document text: \(doc?.getText() ?? "<nil>")", color: .labelColor)
                    appendLine(
                        "📊 Token count:  \(doc?.getTokenCount() ?? 0)", color: .secondaryLabelColor)
                    appendLine(
                        "🔍 Lint count:   \(lints.count)",
                        color: lints.isEmpty ? .systemGreen : .systemOrange,
                        font: boldFont)
                    appendLine(
                        "----------------------------------------\n", color: .secondaryLabelColor)

                    // Print Out Colored Issues Stream
                    if lints.isEmpty {
                        appendLine(
                            "✨ No grammar or style issues found!", color: .systemGreen,
                            font: boldFont)
                    } else {
                        for (i, lint) in lints.enumerated() {
                            guard let currentDoc = doc else { continue }
                            let fragment = lint.textFragment(from: currentDoc) ?? "<nil>"
                            let message = lint.message() ?? "<nil>"

                            // Yellow warning title line
                            appendLine(
                                "⚠️ Lint [\(i + 1)]: \(message)", color: .systemOrange,
                                font: boldFont)

                            // Context fragment snippet line
                            appendLine("   Context: \"\(fragment)\"", color: .systemRed)

                            let suggCount = lint.suggestionCount()
                            if suggCount > 0 {
                                appendLine(
                                    "   💡 \(suggCount) fix suggestion(s) available:",
                                    color: .systemCyan)
                                for j in 0..<suggCount {
                                    if let suggestion = lint.suggestionText(at: j) {
                                        appendLine(
                                            "      👉 \(j + 1). \(suggestion)", color: .systemGreen)
                                    }
                                }
                            }
                            // Add spacing between blocks
                            appendLine("", color: .clear)
                        }
                    }

                    // Inject finalized dynamic rich text to text storage instance
                    text.textStorage?.setAttributedString(richConsoleOutput)

                    scroll.documentView = text
                    window?.contentView = scroll

                    window?.makeKeyAndOrderFront(nil)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }

                func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication)
                    -> Bool
                {
                    return true
                }
            }

            let app = NSApplication.shared
            app.setActivationPolicy(.regular)

            let delegate = AppDelegate()
            // Forward variables directly into our application runner instance
            delegate.doc = doc
            delegate.lints = lints

            app.delegate = delegate
            app.run()
        }
    }
}
