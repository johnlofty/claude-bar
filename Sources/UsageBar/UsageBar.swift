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

    var title: String {
        guard let s = snapshot else { return "✳︎ –" }
        let parts = [("5h", live(s.rate_limits.five_hour)), ("7d", live(s.rate_limits.seven_day))]
            .map { label, w in w.map { "\(label) \(Int($0.used_percentage.rounded()))%" } ?? "\(label) –" }
        return "✳︎ " + parts.joined(separator: " · ")
    }
}

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
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
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
            Text(store.title).monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
