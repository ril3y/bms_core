// Battery drivers: how each BMS family is found, identified and spoken to.

import 'package:modbus_ble/modbus_ble.dart';
import 'package:universal_ble/universal_ble.dart';

import 'capabilities.dart';
import 'model.dart';
import 'notice.dart';

/// What a BMS family looks like in BLE advertisements.
class BleSignature {
  /// Advertised service UUIDs (any of). Also used to filter scans.
  final List<String> services;

  /// Advertised name pattern, if the family has a recognisable one.
  final RegExp? namePattern;

  /// Bluetooth SIG company ids seen in manufacturer data (any of).
  final List<int> manufacturerIds;

  BleSignature({List<String> services = const [], this.namePattern, this.manufacturerIds = const []})
      : services = services.map(normalizeUuid).toList();

  /// How well [device] matches: 0 = not at all. Each matching aspect adds weight,
  /// so a family with a specific name pattern beats one that only shares a service.
  int score(BleDevice device) {
    final advertised = device.services.map(normalizeUuid).toSet();
    final serviceHit = services.any(advertised.contains);
    final name = device.name ?? '';
    final nameHit = namePattern != null && namePattern!.hasMatch(name);
    final mfrHit = manufacturerIds.isNotEmpty &&
        device.manufacturerDataList.any((m) => manufacturerIds.contains(m.companyId));
    // Some platforms omit services from scan results; a name match alone still counts.
    if (!serviceHit && !nameHit && !mfrHit) return 0;
    return (serviceHit ? 10 : 0) + (nameHit ? 20 : 0) + (mfrHit ? 20 : 0);
  }
}

/// A BMS family: how to recognise it and how to talk to it.
abstract class BatteryDriver {
  /// Stable id, e.g. "jbd", "eco".
  String get id;

  /// Shown to users, e.g. "ECO Battery".
  String get name;

  BleSignature get signature;

  /// What this family exposes (the baseline before connecting). A specific
  /// battery may refine it per firmware via [Battery.capabilities].
  BatteryCapabilities get capabilities;

  /// False for families listed for the roadmap but not implemented.
  bool get supported => true;

  /// Score for [device]; override for family-specific heuristics.
  int score(BleDevice device) => supported ? signature.score(device) : 0;

  /// What can be said about [device] from its advertisement alone (no connection).
  BatteryIdentity describe(BleDevice device) => const BatteryIdentity();

  Battery create(BleDevice device);
}

/// A listed-but-unimplemented family, so it can appear in "supported soon" lists.
class PlannedDriver extends BatteryDriver {
  @override
  final String id;
  @override
  final String name;

  PlannedDriver(this.id, this.name);

  @override
  BleSignature get signature => BleSignature();

  @override
  BatteryCapabilities get capabilities => const BatteryCapabilities();

  @override
  bool get supported => false;

  @override
  Battery create(BleDevice device) => throw UnsupportedError('$name is not supported yet');
}

/// A connected (or simulated) battery of any family. Drivers extend this and
/// override [notices] for family-specific things the user should know or decide.
abstract class Battery {
  BatteryDriver get driver;

  /// What this connected battery exposes. Defaults to the family's baseline;
  /// a driver overrides this to refine it once the firmware/model is known.
  BatteryCapabilities get capabilities => driver.capabilities;

  /// Stable identifier used to key stored history.
  String get id;

  String get displayName;

  Stream<BatterySnapshot> get snapshots;
  Stream<List<double>> get cellVoltages;
  Stream<bool> get connection;

  Future<void> connect();

  /// Pause/resume live polling around one-off reads.
  void startLive();
  void stopLive();

  /// Model, firmware, size: shown when choosing between batteries.
  Future<BatteryIdentity> identify();

  /// Lifetime data; null if this family can't provide it.
  Future<HealthReport?> readHealth();

  /// Family-specific things to show the user, each with optional actions.
  /// Apps call this after connecting (and after [HasStoredLogs.downloadLogs]
  /// where supported) and again after running any action.
  Future<List<BatteryNotice>> notices() async => const [];

  Future<void> disconnect();
}

/// Batteries that keep their own log on board.
abstract interface class HasStoredLogs {
  /// Download and decode the on-board logs. Entries come back placed on the real
  /// timeline by the driver (any BMS-clock quirks are the driver's business).
  Future<List<BatteryLogEntry>> downloadLogs({void Function(double progress)? onProgress});
}

/// All known drivers; builds scan filters and picks the best driver per device.
class BatteryRegistry {
  final List<BatteryDriver> drivers;
  BatteryRegistry(this.drivers);

  List<BatteryDriver> get supported => drivers.where((d) => d.supported).toList();
  List<BatteryDriver> get planned => drivers.where((d) => !d.supported).toList();

  /// Service UUIDs to filter scans on (union of all supported signatures).
  List<String> get scanServices => {for (final d in supported) ...d.signature.services}.toList();

  /// Best-scoring supported driver for [device], or null if none matches.
  BatteryDriver? driverFor(BleDevice device) {
    BatteryDriver? best;
    var bestScore = 0;
    for (final d in supported) {
      final s = d.score(device);
      if (s > bestScore) {
        best = d;
        bestScore = s;
      }
    }
    return best;
  }

  /// Supported drivers tied at the top score for [device]. When more than one
  /// tie (e.g. several families share a service and none matched by name), the
  /// family can't be told apart from the advertisement alone — probe to decide.
  List<BatteryDriver> topCandidates(BleDevice device) {
    var best = 0;
    final scores = <BatteryDriver, int>{};
    for (final d in supported) {
      final s = d.score(device);
      if (s > 0) scores[d] = s;
      if (s > best) best = s;
    }
    return [for (final e in scores.entries) if (e.value == best) e.key];
  }

  /// True when the advertisement doesn't uniquely identify the family.
  bool isAmbiguous(BleDevice device) => topCandidates(device).length > 1;
}
