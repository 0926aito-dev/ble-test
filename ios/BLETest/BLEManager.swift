import CoreBluetooth
import UIKit
import UserNotifications

enum BLEConfig {
    /// PC のスクリプト（pc/beacon.py）と同じ値にすること
    static let serviceUUID = CBUUID(string: "D8815C26-2A63-40B5-8914-75EF77F32C6C")
    static let centralRestoreID = "bletest.central"
    static let peripheralRestoreID = "bletest.peripheral"
    /// 同じ相手を続けて記録しない間隔（秒）。前で動いているとき広告を何度も受け取るため
    static let sameDeviceInterval: TimeInterval = 30
}

/// 発信（CBPeripheralManager）と探索（CBCentralManager）を両方持つ。
/// どちらも復元 ID 付きで作るので、アプリがメモリから消されたあとも、
/// 相手が見つかれば iPhone がアプリを裏で起こし直す（はず。ユーザーが上にスワイプして終了した場合は起こされない: Apple QA1962）。
final class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()

    @Published var centralStateText = "未開始"
    @Published var peripheralStateText = "未開始"
    @Published var isScanning = false
    @Published var isAdvertising = false

    private var central: CBCentralManager?
    private var peripheral: CBPeripheralManager?
    private var lastSeen: [UUID: Date] = [:]
    private var serviceAdded = false

    /// 起動時に1回だけ呼ぶ（AppDelegate から）
    func start() {
        guard central == nil else { return }
        // queue: nil → 呼び出しはメインキューで来る
        central = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionRestoreIdentifierKey: BLEConfig.centralRestoreID,
            CBCentralManagerOptionShowPowerAlertKey: true,
        ])
        peripheral = CBPeripheralManager(delegate: self, queue: nil, options: [
            CBPeripheralManagerOptionRestoreIdentifierKey: BLEConfig.peripheralRestoreID,
        ])
    }

    /// 前に戻ったときに探し直す（裏では同じ相手の発見が1回にまとめられるため、試すたびに区切る）
    func restartScan() {
        guard let c = central, c.state == .poweredOn else { return }
        c.stopScan()
        lastSeen.removeAll()
        startScan()
    }

    private func startScan() {
        guard let c = central, c.state == .poweredOn else { return }
        // 裏で探すには Service UUID の指定が必須。AllowDuplicates は裏では無視される（Apple 公式）
        c.scanForPeripherals(withServices: [BLEConfig.serviceUUID],
                             options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
    }

    private func startAdvertising() {
        guard let p = peripheral, p.state == .poweredOn else { return }
        if p.isAdvertising {
            isAdvertising = true
            return
        }
        if !serviceAdded {
            p.removeAllServices()
            p.add(CBMutableService(type: BLEConfig.serviceUUID, primary: true))
            return // 追加できたら didAdd で広告を始める
        }
        // 裏では LocalName は無視され、UUID は「overflow」領域に入る（Apple 公式）
        p.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BLEConfig.serviceUUID],
            CBAdvertisementDataLocalNameKey: "BLETest",
        ])
    }

    private func info(_ text: String) {
        LogStore.shared.add(LogEntry(kind: .info, note: text))
    }

    static func text(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn: return "オン"
        case .poweredOff: return "Bluetooth オフ"
        case .unauthorized: return "許可されていない"
        case .unsupported: return "非対応"
        case .resetting: return "リセット中"
        case .unknown: return "不明"
        @unknown default: return "?"
        }
    }
}

// MARK: - 探す側

extension BLEManager: CBCentralManagerDelegate {
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        let services = (dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID])?.map(\.uuidString) ?? []
        LogStore.shared.add(LogEntry(kind: .restore, note: "central を復元 探していたUUID=\(services)"))
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralStateText = Self.text(central.state)
        if central.state == .poweredOn {
            startScan()
        } else {
            isScanning = false
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let now = Date()
        let id = peripheral.identifier
        if let last = lastSeen[id], now.timeIntervalSince(last) < BLEConfig.sameDeviceInterval {
            return
        }
        lastSeen[id] = now

        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "-"
        let inOverflow = (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID])?
            .contains(BLEConfig.serviceUUID) ?? false
        let entry = LogEntry(
            kind: .found,
            peer: id.uuidString,
            rssi: RSSI.intValue,
            note: "名前=\(name) overflow=\(inOverflow ? "あり" : "なし")"
        )
        LogStore.shared.add(entry)

        if AppStateInfo.isBackground {
            Notifier.post(title: "近くで見つけた",
                          body: "相手 \(id.uuidString.prefix(8)) RSSI \(RSSI.intValue)（\(entry.lock)）")
        }
    }
}

// MARK: - 発信する側

extension BLEManager: CBPeripheralManagerDelegate {
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] ?? []
        serviceAdded = services.contains { $0.uuid == BLEConfig.serviceUUID }
        LogStore.shared.add(LogEntry(kind: .restore,
                                     note: "peripheral を復元 サービス数=\(services.count)"))
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        peripheralStateText = Self.text(peripheral.state)
        if peripheral.state == .poweredOn {
            startAdvertising()
        } else {
            isAdvertising = false
            serviceAdded = false
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            info("サービス追加に失敗: \(error.localizedDescription)")
            return
        }
        serviceAdded = true
        startAdvertising()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            isAdvertising = false
            info("発信の開始に失敗: \(error.localizedDescription)")
        } else {
            isAdvertising = true
        }
    }
}

// MARK: - ローカル通知

enum Notifier {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if !granted {
                    LogStore.shared.add(LogEntry(kind: .info, note: "通知が許可されていない（裏で見つけても知らせが出ない）"))
                }
            }
        }
    }

    static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
