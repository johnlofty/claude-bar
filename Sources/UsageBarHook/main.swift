// Claude Code status line command installed by UsageBar.
//
// Claude Code runs it with the status line JSON on stdin. It:
//   1. saves only the rate_limits windows (used_percentage, resets_at) to ~/.claude/usage-bar.json,
//   2. records that it ran, and whether limits were present, in ~/.claude/usagebar/last-run.json,
//   3. runs the status line command the user had before, with the same stdin, and passes its
//      output through, so their status line looks exactly as it did.
// Foundation only, so it starts fast and needs neither jq nor the app to be running.
import Foundation

// The user's status line may exit without reading stdin; writing to its closed pipe must not kill us.
signal(SIGPIPE, SIG_IGN)

// $HOME first, as Claude Code itself resolves ~/.claude.
let home = ProcessInfo.processInfo.environment["HOME"].map { URL(fileURLWithPath: $0) }
    ?? FileManager.default.homeDirectoryForCurrentUser
let claudeDir = home.appendingPathComponent(".claude")
let hookDir = claudeDir.appendingPathComponent("usagebar")
let input = FileHandle.standardInput.readDataToEndOfFile()

func writeJSON(_ object: Any, to url: URL) {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
    try? data.write(to: url, options: .atomic)
}

var hadLimits = false
if let status = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any],
   let limits = status["rate_limits"] as? [String: Any] {
    var windows: [String: Any] = [:]
    for key in ["five_hour", "seven_day"] {
        guard let w = limits[key] as? [String: Any],
              let used = w["used_percentage"] as? Double,
              let resets = w["resets_at"] as? Double else { continue }
        windows[key] = ["used_percentage": used, "resets_at": resets]
    }
    if !windows.isEmpty {
        hadLimits = true
        writeJSON(["rate_limits": windows, "captured_at": Int(Date().timeIntervalSince1970)],
                  to: claudeDir.appendingPathComponent("usage-bar.json"))
    }
}
writeJSON(["ran_at": Int(Date().timeIntervalSince1970), "had_rate_limits": hadLimits],
          to: hookDir.appendingPathComponent("last-run.json"))

// The status line the user had before connecting, saved by the app.
let config = (try? Data(contentsOf: hookDir.appendingPathComponent("config.json")))
    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
guard let original = config?["original_status_line"] as? [String: Any],
      original["type"] as? String == "command",
      let command = original["command"] as? String, !command.isEmpty else { exit(0) }

let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/sh")
process.arguments = ["-c", command]
let stdin = Pipe()
process.standardInput = stdin
do {
    try process.run()
} catch {
    exit(0)
}
// Throwing variant: the legacy write(_:) raises an uncaught exception on a closed pipe.
try? stdin.fileHandleForWriting.write(contentsOf: input)
try? stdin.fileHandleForWriting.close()
process.waitUntilExit()
exit(process.terminationStatus)
