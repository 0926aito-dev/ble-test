import Foundation
import UIKit

/// アプリが前か裏か、画面が鍵で守られているか、を記録用の文字にする
enum AppStateInfo {
    static func stateText() -> String {
        switch UIApplication.shared.applicationState {
        case .active: return "前"
        case .inactive: return "前(切替中)"
        case .background: return "裏"
        @unknown default: return "?"
        }
    }

    static var isBackground: Bool {
        UIApplication.shared.applicationState == .background
    }

    /// パスコードを設定した端末で、画面ロック中は false になる
    static func lockText() -> String {
        UIApplication.shared.isProtectedDataAvailable ? "解除" : "ロック中"
    }
}

struct LogEntry: Codable, Identifiable {
    enum Kind: String, Codable {
        case found    // 相手を見つけた
        case launch   // アプリが起動した
        case restore  // 状態の復元が呼ばれた
        case info     // そのほか（エラーなど）
    }

    var id = UUID()
    var date = Date()
    var kind: Kind
    var peer: String? = nil     // 相手の識別子（iPhone がつける UUID。端末ごとに違う）
    var rssi: Int? = nil        // 電波の強さ（dBm。0 に近いほど強い）
    var appState: String = AppStateInfo.stateText()
    var lock: String = AppStateInfo.lockText()
    var note: String? = nil
}

/// 記録を端末内（アプリの書類フォルダの ble-log.json）に保存する。
/// Core Bluetooth の呼び出しはメインキューで来るので、ここもメインで使う前提。
final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var entries: [LogEntry] = []
    private let url: URL

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = dir.appendingPathComponent("ble-log.json")
        if let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([LogEntry].self, from: data) {
            entries = list
        }
    }

    func add(_ entry: LogEntry) {
        entries.insert(entry, at: 0)
        save()
    }

    func clear() {
        entries = []
        save()
    }

    /// 共有用の CSV（時刻,種類,相手,RSSI,前裏,ロック,メモ）
    func csv() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var lines = ["time,kind,peer,rssi,app,lock,note"]
        for e in entries.reversed() {
            let note = (e.note ?? "").replacingOccurrences(of: ",", with: " ")
            lines.append("\(f.string(from: e.date)),\(e.kind.rawValue),\(e.peer ?? ""),\(e.rssi.map(String.init) ?? ""),\(e.appState),\(e.lock),\(note)")
        }
        return lines.joined(separator: "\n")
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            // ロック中に裏で起こされても書けるよう「最初のロック解除のあとは読み書きできる」守り方にする
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("記録の保存に失敗: \(error)")
        }
    }
}
