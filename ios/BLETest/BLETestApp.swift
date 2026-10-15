import SwiftUI
import UIKit

/// 起動のたびに（裏で起こされたときも）最初に呼ばれる。
/// 状態の復元を受けるには、ここで同じ復元 ID の CBCentralManager / CBPeripheralManager を作り直す必要がある
/// （Apple「Core Bluetooth Background Processing for iOS Apps」Reinstantiate Your Central and Peripheral Managers）。
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let centrals = launchOptions?[.bluetoothCentrals] as? [String] ?? []
        let peripherals = launchOptions?[.bluetoothPeripherals] as? [String] ?? []
        let bg = application.applicationState == .background
        LogStore.shared.add(LogEntry(
            kind: .launch,
            note: "起動（\(bg ? "裏で起こされた" : "ふつうに開いた")） 復元central=\(centrals) 復元peripheral=\(peripherals)"
        ))
        BLEManager.shared.start()
        return true
    }
}

@main
struct BLETestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
