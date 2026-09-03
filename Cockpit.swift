import AppKit

let snapshotURL = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent(".claude/one-tap-claude-cockpit.json")

let warningThreshold = 75
let dangerThreshold = 90
let separator = "  📅 "
let refreshInterval: TimeInterval = 5

struct Limit {
    let percent: Double
    let resetsAt: Date

    var isExpired: Bool { resetsAt <= Date() }
    var roundedPercent: Int { Int(percent.rounded()) }
}

struct Snapshot {
    let fiveHour: Limit?
    let sevenDay: Limit?
    let updatedAt: Date
}

func loadSnapshot() -> Snapshot? {
    guard let data = try? Data(contentsOf: snapshotURL),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

    func limit(_ key: String) -> Limit? {
        guard let window = root[key] as? [String: Any],
              let percent = window["used_percentage"] as? Double,
              let resets = window["resets_at"] as? Double else { return nil }
        return Limit(percent: percent, resetsAt: Date(timeIntervalSince1970: resets))
    }

    let updated = (root["updated_at"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? .distantPast
    return Snapshot(fiveHour: limit("five_hour"), sevenDay: limit("seven_day"), updatedAt: updated)
}

func compact(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let days = total / 86400
    let hours = (total % 86400) / 3600
    let minutes = (total % 3600) / 60
    if days > 0 { return "\(days)d\(hours)h" }
    if hours > 0 { return "\(hours)h\(minutes)m" }
    return "\(minutes)m"
}

func absoluteReset(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "EEE HH:mm"
    return formatter.string(from: date)
}

func describe(_ limit: Limit?) -> (text: String, alert: Int) {
    guard let limit else { return ("—", 0) }
    if limit.isExpired { return ("0%", 0) }
    let percent = limit.roundedPercent
    let alert = percent >= dangerThreshold ? 2 : (percent >= warningThreshold ? 1 : 0)
    return ("\(percent)% · \(compact(limit.resetsAt.timeIntervalSinceNow))", alert)
}

func burstIcon(size: CGFloat) -> NSImage {
    let rays: [CGFloat] = [0.46, 0.33, 0.44, 0.30, 0.47, 0.32, 0.45, 0.31, 0.46, 0.34, 0.43]
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let center = CGPoint(x: rect.midX, y: rect.midY)
        NSColor.black.setStroke()
        for (index, reach) in rays.enumerated() {
            let angle = CGFloat(index) / CGFloat(rays.count) * 2 * .pi + 0.2
            let path = NSBezierPath()
            path.lineWidth = size * 0.085
            path.lineCapStyle = .round
            path.move(to: center)
            path.line(to: CGPoint(x: center.x + cos(angle) * rect.width * reach,
                                  y: center.y + sin(angle) * rect.height * reach))
            path.stroke()
        }
        return true
    }
    image.isTemplate = true
    return image
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        statusItem.menu = menu

        if let button = statusItem.button {
            let icon = NSImage(named: "ClaudeTemplate") ?? burstIcon(size: 15)
            icon.isTemplate = true
            icon.size = NSSize(width: 15, height: 15)
            button.image = icon
            button.imagePosition = .imageLeading
        }

        render()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.render()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let snapshot = loadSnapshot()

        if let snapshot {
            menu.addItem(detail("5-hour session", snapshot.fiveHour))
            menu.addItem(detail("7-day week", snapshot.sevenDay))
            menu.addItem(.separator())
            menu.addItem(info("Last read from Claude Code \(compact(-snapshot.updatedAt.timeIntervalSinceNow)) ago"))
        } else {
            menu.addItem(info("No data yet"))
            menu.addItem(info("Open a Claude Code session to populate it"))
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Open usage on claude.ai", action: #selector(openUsage), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
    }

    private func detail(_ label: String, _ limit: Limit?) -> NSMenuItem {
        guard let limit else { return info("\(label): no data") }
        if limit.isExpired { return info("\(label): 0% (window rolled over)") }
        let reset = "resets \(absoluteReset(limit.resetsAt)) · \(compact(limit.resetsAt.timeIntervalSinceNow)) left"
        return info("\(label): \(limit.roundedPercent)% · \(reset)")
    }

    private func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let snapshot = loadSnapshot()
        let five = describe(snapshot?.fiveHour)
        let seven = describe(snapshot?.sevenDay)

        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let separatorAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .baselineOffset: 0.5
        ]

        let title = NSMutableAttributedString()
        title.append(NSAttributedString(string: " ", attributes: attributes(font, 0)))
        title.append(NSAttributedString(string: five.text, attributes: attributes(font, five.alert)))
        title.append(NSAttributedString(string: separator, attributes: separatorAttributes))
        title.append(NSAttributedString(string: seven.text, attributes: attributes(font, seven.alert)))
        button.attributedTitle = title
        button.toolTip = "Claude Code usage — 5-hour session / 7-day week"
    }

    private func attributes(_ font: NSFont, _ alert: Int) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if alert == 2 { attributes[.foregroundColor] = NSColor.systemRed }
        if alert == 1 { attributes[.foregroundColor] = NSColor.systemOrange }
        return attributes
    }

    @objc private func openUsage() {
        NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
