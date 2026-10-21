# bms_core

Shared building blocks for Bluetooth battery (BMS) drivers in Flutter/Dart:

- `BatteryDriver` / `Battery` base classes, advertisement matching (`BleSignature`),
  and a `BatteryRegistry` that builds scan filters and picks (or probes for) the
  right family per device.
- A brand-neutral data model: `BatterySnapshot`, `HealthReport`, `BatteryIdentity`,
  `BatteryLogEntry`.
- `ModbusRtu` framing + `ModbusAssembler` (reassembly, CRC-16/Modbus) for families
  that tunnel Modbus over BLE.
- `BleLink`, a small [universal_ble](https://pub.dev/packages/universal_ble) helper
  (discover characteristics, subscribe, chunked writes, serialized request/response).
- Vendor `BatteryNotice` / `BatteryAction` so a driver can surface family quirks
  (e.g. a BMS clock that needs setting) without the app knowing the family.

Used by the CellScope app and its per-family drivers (e.g. `jbd_bms`, `eco_battery_bms`).

## License

MIT. Not affiliated with any battery or BMS manufacturer.
