"""PC を「信号を出す役」にするスクリプト（Windows 10/11 専用）。

iPhone の試しアプリと同じ Service UUID を Bluetooth LE で広告し続ける。
Ctrl+C で止まる。

使うもの: pywinrt（PyPI の winrt-* パッケージ。Windows の API を呼ぶだけで、外部への通信はしない）
  python -m venv .venv
  .venv\\Scripts\\python -m pip install -r requirements.txt
  .venv\\Scripts\\python beacon.py

しくみ: Windows の GattServiceProvider でサービスを1つ作り、StartAdvertising で
「接続できる・見つけられる」広告を出す。広告にはこのサービスの UUID が入る。
（BluetoothLEAdvertisementPublisher は Service UUID を自由に入れられないため、こちらを使う）
"""

import asyncio
import datetime
import sys
import uuid

from winrt.windows.devices.bluetooth import BluetoothAdapter, BluetoothError
from winrt.windows.devices.bluetooth.genericattributeprofile import (
    GattCharacteristicProperties,
    GattLocalCharacteristicParameters,
    GattProtectionLevel,
    GattServiceProvider,
    GattServiceProviderAdvertisementStatus,
    GattServiceProviderAdvertisingParameters,
)
from winrt.windows.storage.streams import DataWriter

# iPhone アプリ（ios/BLETest/BLEManager.swift）と同じ値にすること
SERVICE_UUID = uuid.UUID("D8815C26-2A63-40B5-8914-75EF77F32C6C")
# サービスを空にしないための読み取り専用の値（中身は "PC"）
CHAR_UUID = uuid.UUID("D8815C26-2A63-40B5-8914-75EF77F32C6D")


def status_name(v) -> str:
    try:
        return GattServiceProviderAdvertisementStatus(v).name
    except Exception:
        return str(v)


def now() -> str:
    return datetime.datetime.now().strftime("%H:%M:%S")


async def main(seconds: float | None) -> int:
    adapter = await BluetoothAdapter.get_default_async()
    if adapter is None:
        print("NG: この PC に Bluetooth アダプターが見つかりません")
        return 2
    print(f"アダプター: LE対応={adapter.is_low_energy_supported} "
          f"周辺機器の役(広告)に対応={adapter.is_peripheral_role_supported}")
    if not adapter.is_peripheral_role_supported:
        print("NG: この PC の Bluetooth は広告（周辺機器の役）に対応していません")
        return 3

    result = await GattServiceProvider.create_async(SERVICE_UUID)
    if result.error != BluetoothError.SUCCESS:
        print(f"NG: サービスを作れませんでした error={result.error}")
        return 4
    provider = result.service_provider

    # 読み取り専用の特性を1つ付ける（値 "PC"）
    w = DataWriter()
    w.write_bytes(b"PC")
    cp = GattLocalCharacteristicParameters()
    cp.characteristic_properties = GattCharacteristicProperties.READ
    cp.read_protection_level = GattProtectionLevel.PLAIN
    cp.static_value = w.detach_buffer()
    cres = await provider.service.create_characteristic_async(CHAR_UUID, cp)
    if cres.error != BluetoothError.SUCCESS:
        print(f"注意: 特性を作れませんでした error={cres.error}（広告は続けます）")

    def on_status(sender, args):
        print(f"[{now()}] 広告の状態: {status_name(args.status)} error={args.error}")

    token = provider.add_advertisement_status_changed(on_status)

    params = GattServiceProviderAdvertisingParameters()
    params.is_connectable = True
    params.is_discoverable = True
    provider.start_advertising_with_parameters(params)

    await asyncio.sleep(1.0)
    print(f"[{now()}] 広告を開始しました UUID={SERVICE_UUID} 状態={status_name(provider.advertisement_status)}")
    print("Ctrl+C で止まります。")

    try:
        if seconds is None:
            while True:
                await asyncio.sleep(3600)
        else:
            await asyncio.sleep(seconds)
    except (KeyboardInterrupt, asyncio.CancelledError):
        pass
    finally:
        provider.stop_advertising()
        provider.remove_advertisement_status_changed(token)
        print(f"[{now()}] 広告を止めました")
    return 0


if __name__ == "__main__":
    # 例: beacon.py 10  → 10秒だけ出して止まる（動作確認用）
    secs = float(sys.argv[1]) if len(sys.argv) > 1 else None
    try:
        sys.exit(asyncio.run(main(secs)))
    except KeyboardInterrupt:
        pass
