# BLE すれちがい試験アプリ

「アプリを閉じたまま、iPhone が近くの同じアプリを Bluetooth で見つけられるか」を確かめるための、いちばん小さい試しアプリです。Mac は使いません。

- iPhone アプリ（`ios/`）: 決まった合言葉（Service UUID `D8815C26-2A63-40B5-8914-75EF77F32C6C`）を**発信**しながら、同じ合言葉を**探し**ます。見つけたら「時刻・相手・電波の強さ（RSSI）・アプリが前か裏か・画面ロック中か」を記録して一覧に出します。裏で見つけたときは通知も出します。
- PC の信号役（`pc/beacon.py`）: Windows の Bluetooth で、同じ合言葉を発信します。
- ビルド（`.github/workflows/build.yml`）: GitHub の Mac（無料の macOS ランナー）で、署名なしの `.ipa` を作ります。

---

## 社長がやること

### 0. 最初の1回だけ
1. **Sideloadly を入れる**: https://sideloadly.io/ から Windows 版を入れる。iTunes と iCloud は「Microsoft Store 版ではなく、Apple サイトの Web 版」が要る（Store 版が入っていたら先に消す。Sideloadly 公式ページの説明）。
2. **iPhone のデベロッパモードをオンにする**（iOS 16 以降）: 設定 → プライバシーとセキュリティ → デベロッパモード → オン → 再起動 → 「オンにする」→ パスコード。
   - この項目は、一度 PC とつないで Sideloadly で入れようとしたあとに出てくることがあります（Apple 公式: 「つないだことがあるときだけ設定に出る」）。出ていなければ、先に 2. の手順で入れてみてから戻ってきてください。

### 1. ipa（アプリのファイル）を取る
1. GitHub のこのリポジトリの「Actions」タブ → 左の「build-ipa」→ 右の「Run workflow」。（main に push しても自動で動きます）
2. 5〜15分ほどで緑のチェックになる。その実行を開き、下の「Artifacts」の **BLETest-unsigned-ipa** を押してダウンロード。
3. ダウンロードした zip を開くと `BLETest-unsigned.ipa` が入っています。

### 2. Sideloadly で iPhone に入れる
1. iPhone を USB ケーブルで PC につなぐ（iPhone に「このコンピュータを信頼しますか」が出たら「信頼」）。
2. Sideloadly を開き、`BLETest-unsigned.ipa` をウィンドウにドラッグ。
3. 「Apple account」に**自分の Apple ID**（無料のもので可）を入れて「Start」。パスワードを聞かれたら入れる（2段階認証のコードも聞かれます）。
   - Apple ID を外の道具に入れることになります。気になる場合は、試し用の Apple ID を別に作る手もあります。
4. 「Done」と出たら完了。

### 3. iPhone でアプリを信頼する
設定 → 一般 → **VPN とデバイス管理** → 自分の Apple ID の名前 → 「信頼」。

### 4. 最初に開いたとき
- 「Bluetooth の使用」→ **許可**
- 「通知」→ **許可**（裏で見つけたときの知らせに使う）
- 画面の「いまの状態」が「探す: オン・探索中」「発信: オン・発信中」になっていれば準備完了。

### 注意: 7日で切れます
無料の Apple ID で入れたアプリは **7日で開けなくなります**（Sideloadly 公式）。切れたら 2. をもう一度やれば、記録は残ったまま入れ直せます（同じ Apple ID・同じ ipa のとき。※未確認）。

---

## PC の信号役の動かし方（Windows）

PowerShell で:

```
cd C:\Users\aito0\game-kikaku\ble-test\pc
python -m venv .venv            # 最初の1回だけ
.venv\Scripts\python -m pip install -r requirements.txt   # 最初の1回だけ
.venv\Scripts\python beacon.py   # 発信を始める。Ctrl+C で止める
```

`広告を開始しました … 状態=STARTED` と出れば発信中です。`beacon.py 120` のように秒数を付けると、その秒数で自動で止まります。

---

## 試し方

### 大事: 「閉じる」の意味
- **ホームに戻る・画面を消す（ロック）** … これが「閉じたまま」。この試験はこれでやる。
- **アプリ切り替え画面で上にスワイプして消す（強制終了）** … これをすると、iPhone は Bluetooth でアプリを起こし直さない（Apple 公式 QA1962）。**この試験ではやらない**。別の試験としてなら、やってみて「起こされない」ことを確かめる意味はある。
- iPhone の再起動後は、一度パスコードでロックを解除するまで起こされない（同じ資料）。

### ① アプリを開いたまま、PC の信号を見つけるか（まずこれ）
1. アプリを開いたまま、PC で `beacon.py` を動かす。
2. 数秒〜1分以内に一覧に「発見・前」が出れば成功。
3. 出なければここで止めて報告（PC の発信か、アプリの探索のどちらかが動いていない）。

### ② アプリを閉じ・画面を消したまま、PC の信号を見つけるか（本題）
1 回の試し:
1. PC の `beacon.py` を止めておく。
2. iPhone でアプリを開く（ここで探し直しの区切りが入る）→ ホームに戻る → 画面を消す（ロック）。
3. PC で `beacon.py` を動かし、**2分待つ**。iPhone は机に置いたまま触らない（PC から1〜2mの距離）。
4. 通知が来たかを見る（画面は消えたままでも、通知が出ると画面が点くことがある）。
5. `beacon.py` を Ctrl+C で止める。
6. アプリを開いて、手順 3 の時間に「発見・裏」の行があるかを見る。

これを **10回** くり返します。間に別の操作（ほかのアプリを使う等）を入れた回も混ぜると、実際の使い方に近くなります。

### ③ 将来: 2台目の iPhone で、両方閉じたまま
- 2台ともこのアプリを入れ、両方を ② と同じ形で閉じて、近くに置いて5分待つ。
- 片方は「裏で発信（overflow 領域）」、もう片方は「裏で探す」になる。Apple の説明では、裏で発信した合言葉は「それを名指しで探している iOS 端末にしか見つからない」。両方とも裏のときに見つかるかは、この試験で初めてわかる。
- PC では裏の iPhone の発信は確かめられません（overflow 領域は Apple 独自の形のため）。

---

## 記録の付け方

試すごとに1行。メモ帳でも紙でもよいです。

| 日時 | 試験 | 距離 | ロック | 待った時間 | 見つけた？ | 通知が来た？ | 見つけるまでの秒数 | RSSI | メモ |
|---|---|---|---|---|---|---|---|---|---|
| 10/16 21:00 | ② | 1m | ロック | 2分 | ○ | ○ | 約20秒 | -60 | |

まとめ: 「②: **10回中 何回** 見つけた（通知が来たのは何回）」の形で報告。

- 見つけるまでの秒数は、PC で `beacon.py` を始めた時刻と、アプリの記録の時刻の差です。
- アプリ右上の「共有」で記録を CSV で送れます（LINE・メール・メモなど）。
- 「起動（裏で起こされた）」「復元」の行は、iPhone がアプリを裏で起こし直した印です。これがあれば、アプリがメモリから消されていても動いたことになります。

---

## ファイル

```
ble-test/
├─ README.md
├─ .github/workflows/build.yml   … macOS ランナーで署名なし ipa を作る
├─ ios/
│  ├─ project.yml                … XcodeGen の設定（xcodeproj はランナー上で作る）
│  └─ BLETest/
│     ├─ BLETestApp.swift        … 起動。AppDelegate で Bluetooth を作り直す（復元用）
│     ├─ BLEManager.swift        … 発信（CBPeripheralManager）と探索（CBCentralManager）、通知
│     ├─ LogStore.swift          … 記録の保存（端末内の ble-log.json）
│     └─ ContentView.swift       … 画面（状態・記録一覧・消す・共有）
└─ pc/
   ├─ beacon.py                  … PC を信号役にする（Windows の GattServiceProvider）
   └─ requirements.txt           … pywinrt（winrt-* パッケージ）
```

## 出典
- Apple「Core Bluetooth Background Processing for iOS Apps」（旧資料、2013-09 更新）: https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html
- Apple「startAdvertising(_:)」: https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/startadvertising(_:)
- Apple「scanForPeripherals(withServices:options:)」: https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/scanforperipherals(withservices:options:)
- Apple「UIBackgroundModes」: https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes
- Apple「NSBluetoothAlwaysUsageDescription」: https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription
- Apple QA1962「Bluetooth State Restoration が起こし直す条件」（2017-09）: https://developer.apple.com/library/archive/qa/qa1962/_index.html
- Apple「Supported capabilities (iOS)」: https://developer.apple.com/help/account/reference/supported-capabilities-ios
- Apple「Enabling Developer Mode on a device」: https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device
- Sideloadly: https://sideloadly.io/
