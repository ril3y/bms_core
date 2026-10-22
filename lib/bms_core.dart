/// Shared building blocks for Bluetooth battery (BMS) drivers: the driver and
/// battery base classes, advertisement matching, a brand-neutral data model,
/// vendor notices, Modbus RTU framing and BLE plumbing.
library;

export 'src/ble_link.dart';
export 'src/capabilities.dart';
export 'src/driver.dart';
export 'src/modbus.dart';
export 'src/model.dart';
export 'src/notice.dart';
export 'src/secret.dart';
