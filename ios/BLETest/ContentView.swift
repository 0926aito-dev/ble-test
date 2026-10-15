import SwiftUI

struct ContentView: View {
    @ObservedObject private var ble = BLEManager.shared
    @ObservedObject private var log = LogStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmClear = false

    private static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm:ss"
        return f
    }()

    private var foundFront: Int { log.entries.filter { $0.kind == .found && $0.appState != "裏" }.count }
    private var foundBack: Int { log.entries.filter { $0.kind == .found && $0.appState == "裏" }.count }

    var body: some View {
        NavigationStack {
            List {
                Section("いまの状態") {
                    row("探す（central）", "\(ble.centralStateText)\(ble.isScanning ? "・探索中" : "")")
                    row("発信（peripheral）", "\(ble.peripheralStateText)\(ble.isAdvertising ? "・発信中" : "")")
                    row("見つけた回数", "前 \(foundFront) ／ 裏 \(foundBack)")
                }
                Section("記録（新しい順）") {
                    if log.entries.isEmpty {
                        Text("まだ記録はありません").foregroundStyle(.secondary)
                    }
                    ForEach(log.entries) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(Self.timeFormat.string(from: e.date)).monospacedDigit()
                                Text(label(e.kind)).bold()
                                Spacer()
                                Text("\(e.appState)・\(e.lock)")
                                    .foregroundStyle(e.appState == "裏" ? .orange : .secondary)
                            }
                            if let peer = e.peer {
                                Text("相手 \(String(peer.prefix(8)))  RSSI \(e.rssi.map(String.init) ?? "-")")
                                    .font(.caption.monospaced())
                            }
                            if let note = e.note {
                                Text(note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("BLE すれちがい試験")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("消す", role: .destructive) { confirmClear = true }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: log.csv()) { Text("共有") }
                }
            }
            .confirmationDialog("記録をすべて消しますか？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("消す", role: .destructive) { log.clear() }
            }
        }
        .onAppear { Notifier.requestPermission() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { ble.restartScan() }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func label(_ kind: LogEntry.Kind) -> String {
        switch kind {
        case .found: return "発見"
        case .launch: return "起動"
        case .restore: return "復元"
        case .info: return "メモ"
        }
    }
}
