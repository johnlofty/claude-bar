import SwiftUI

// Snapshot written by the Claude Code status line hook (scripts/usage-snapshot.sh).
struct Snapshot: Decodable {
    struct Window: Decodable {
        let used_percentage: Double
        let resets_at: TimeInterval
    }
    struct Limits: Decodable {
        let five_hour: Window?
        let seven_day: Window?
    }
    let rate_limits: Limits
    let captured_at: TimeInterval
}

@MainActor
final class UsageStore: ObservableObject {
    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/usage-bar.json")

    @Published var snapshot: Snapshot?
    @Published var now = Date()
    private var lastModified: Date?
    private var timer: Timer?

    init() {
        reload()
        // Polling a single small file is cheap and survives the hook's atomic rename,
        // which would break a file-descriptor based watcher.
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
                self?.reload()
            }
        }
    }

    func reload() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: Self.fileURL.path)
        let modified = attrs?[.modificationDate] as? Date
        guard modified != lastModified else { return }
        lastModified = modified
        guard let data = try? Data(contentsOf: Self.fileURL) else { snapshot = nil; return }
        snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    /// A window whose reset time has passed no longer describes current usage.
    func live(_ w: Snapshot.Window?) -> Snapshot.Window? {
        guard let w, w.resets_at > now.timeIntervalSince1970 else { return nil }
        return w
    }

    /// The windows chosen in settings, paired with their short labels.
    func shown(_ windows: ShownWindows) -> [(label: String, window: Snapshot.Window?)] {
        let s = snapshot?.rate_limits
        var out: [(String, Snapshot.Window?)] = []
        if windows != .weekly { out.append(("5h", live(s?.five_hour))) }
        if windows != .fiveHour { out.append(("7d", live(s?.seven_day))) }
        return out
    }
}

// MARK: - Menu bar label settings

enum ShownWindows: String, CaseIterable, Identifiable {
    case fiveHour, weekly, both
    var id: Self { self }
    var name: String {
        switch self {
        case .fiveHour: return "5h"
        case .weekly: return "7d"
        case .both: return "Both"
        }
    }
}

enum LabelStyle: String, CaseIterable, Identifiable {
    case labeled, compact, bars, barsAndPercent
    var id: Self { self }
    var name: String {
        switch self {
        case .labeled: return "5h 60%"
        case .compact: return "60%"
        case .bars: return "Bars"
        case .barsAndPercent: return "Bars + %"
        }
    }
}

/// Short countdown for the menu bar, e.g. "2h", "35m", "3d".
func shortCountdown(to resetsAt: TimeInterval, from now: Date) -> String {
    let secs = max(0, resetsAt - now.timeIntervalSince1970)
    if secs >= 86_400 { return "\(Int(secs / 86_400))d" }
    if secs >= 3_600 { return "\(Int(secs / 3_600))h" }
    return "\(Int(secs / 60))m"
}

/// Tiny horizontal meters, rendered as a template image so they follow the menu bar's appearance.
struct MiniBars: View {
    let values: [Double?]

    var body: some View {
        VStack(spacing: values.count > 1 ? 2 : 0) {
            ForEach(values.indices, id: \.self) { i in
                let h: CGFloat = values.count > 1 ? 5 : 7
                ZStack(alignment: .leading) {
                    Capsule().stroke(lineWidth: 1).frame(width: 26, height: h)
                    Capsule()
                        .frame(width: max(0, 26 * CGFloat(min(values[i] ?? 0, 100) / 100)), height: h)
                }
            }
        }
        .foregroundStyle(.black)
        .padding(.vertical, 1)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore
    @AppStorage("shownWindows") private var windows: ShownWindows = .both
    @AppStorage("labelStyle") private var style: LabelStyle = .labeled
    @AppStorage("showIcon") private var showIcon = true
    @AppStorage("showCountdown") private var showCountdown = false

    var body: some View {
        let items = store.shown(windows)
        HStack(spacing: 4) {
            if style == .bars || style == .barsAndPercent {
                barsImage(items.map { $0.window?.used_percentage })
            }
            if style != .bars || showIcon || showCountdown {
                Text(text(items)).monospacedDigit()
            }
        }
    }

    private func text(_ items: [(label: String, window: Snapshot.Window?)]) -> String {
        let parts: [String] = items.compactMap { item in
            let pct = item.window.map { "\(Int($0.used_percentage.rounded()))%" } ?? "–"
            let countdown = showCountdown ? item.window.map { " (\(shortCountdown(to: $0.resets_at, from: store.now)))" } ?? "" : ""
            switch style {
            case .labeled: return "\(item.label) \(pct)\(countdown)"
            case .compact, .barsAndPercent: return "\(pct)\(countdown)"
            case .bars: return countdown.isEmpty ? nil : countdown.trimmingCharacters(in: .whitespaces)
            }
        }
        let body = parts.joined(separator: style == .labeled ? " · " : "/")
        return showIcon ? (body.isEmpty ? "✳︎" : "✳︎ " + body) : body
    }

    @MainActor
    private func barsImage(_ values: [Double?]) -> Image {
        let renderer = ImageRenderer(content: MiniBars(values: values))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let ns = renderer.nsImage else { return Image(systemName: "chart.bar") }
        ns.isTemplate = true
        return Image(nsImage: ns)
    }
}

struct DisplaySettings: View {
    @AppStorage("shownWindows") private var windows: ShownWindows = .both
    @AppStorage("labelStyle") private var style: LabelStyle = .labeled
    @AppStorage("showIcon") private var showIcon = true
    @AppStorage("showCountdown") private var showCountdown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu bar").font(.caption).foregroundStyle(.secondary)
            Picker("Show", selection: $windows) {
                ForEach(ShownWindows.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Style", selection: $style) {
                ForEach(LabelStyle.allCases) { Text($0.name).tag($0) }
            }
            Toggle("Show ✳︎ icon", isOn: $showIcon)
            Toggle("Show time until reset", isOn: $showCountdown)
        }
        .controlSize(.small)
    }
}

/// "v1.2.3 · 2e3bc52" for a release, "dev · 2e3bc52" for a local build.
let buildVersion: String = {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["UBBuildVersion"] as? String ?? "dev"
    guard let commit = info["UBBuildCommit"] as? String else { return version }
    return "\(version) · \(commit)"
}()

func relative(_ date: Date, to now: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .short
    return f.localizedString(for: date, relativeTo: now)
}

struct WindowRow: View {
    let label: String
    let window: Snapshot.Window?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.headline)
                Spacer()
                Text(window.map { "\(Int($0.used_percentage.rounded()))%" } ?? "–")
                    .monospacedDigit()
            }
            ProgressView(value: min(window?.used_percentage ?? 0, 100), total: 100)
                .tint(tint)
            Text(window.map { "Resets \(relative(Date(timeIntervalSince1970: $0.resets_at), to: now))" }
                 ?? "Window reset or not reported yet")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var tint: Color {
        switch window?.used_percentage ?? 0 {
        case ..<60: return .green
        case ..<85: return .orange
        default: return .red
        }
    }
}

struct UsageMenu: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let s = store.snapshot {
                WindowRow(label: "5-hour", window: store.live(s.rate_limits.five_hour), now: store.now)
                WindowRow(label: "Weekly", window: store.live(s.rate_limits.seven_day), now: store.now)
                Text("Updated \(relative(Date(timeIntervalSince1970: s.captured_at), to: store.now)) by Claude Code")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No usage data yet").font(.headline)
                Text("Run a prompt in Claude Code. Its status line writes\n~/.claude/usage-bar.json.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            DisplaySettings()
            Divider()
            HStack {
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
                Spacer()
                Text(buildVersion)
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .help("Build version and commit")
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}

@main
struct UsageBarApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsageMenu(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
