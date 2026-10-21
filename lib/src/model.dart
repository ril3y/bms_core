// Brand-neutral battery data. Drivers translate their BMS's data into these.

/// One live reading.
class BatterySnapshot {
  final DateTime time;
  final double voltage;
  final double current; // A, + charging / - discharging
  final int soc;
  final double remainingAh;
  final double fullAh;
  final int cycles;
  final List<double> temperaturesC;
  final int balanceMask;
  final List<String> activeProtections;
  final int protectionMask;
  final bool chargeEnabled;
  final bool dischargeEnabled;

  const BatterySnapshot({
    required this.time,
    required this.voltage,
    required this.current,
    required this.soc,
    required this.remainingAh,
    required this.fullAh,
    required this.cycles,
    required this.temperaturesC,
    this.balanceMask = 0,
    this.activeProtections = const [],
    this.protectionMask = 0,
    this.chargeEnabled = true,
    this.dischargeEnabled = true,
  });

  double get powerW => voltage * current;

  double? get maxTempC => temperaturesC.isEmpty ? null : temperaturesC.reduce((a, b) => a > b ? a : b);

  /// Hours to full (charging) or empty (discharging); null when resting.
  double? get hoursRemaining {
    if (current > 0.05) return (fullAh - remainingAh) / current;
    if (current < -0.05) return remainingAh / -current;
    return null;
  }
}

/// Lifetime / identity data used to judge remaining life.
class HealthReport {
  final int cycles;
  final DateTime? productionDate;
  final String? model;
  final String? firmware;
  final double? designAh;
  final double? fullChargeAh;

  /// State of health reported directly by the BMS (0..1), if it reports one.
  final double? reportedSoh;

  /// Lifetime protection-event totals, if the BMS keeps them.
  final Map<String, int> protectionCounts;

  const HealthReport({
    required this.cycles,
    this.productionDate,
    this.model,
    this.firmware,
    this.designAh,
    this.fullChargeAh,
    this.reportedSoh,
    this.protectionCounts = const {},
  });

  /// BMS state of health: reported directly, or full-charge / design capacity.
  double? get stateOfHealth =>
      reportedSoh ??
      (designAh != null && fullChargeAh != null && designAh! > 0 ? fullChargeAh! / designAh! : null);

  int get totalProtectionEvents => protectionCounts.values.fold(0, (a, b) => a + b);
}

/// What a battery says about itself, to tell batteries apart when choosing one.
class BatteryIdentity {
  final String? model;
  final String? firmware;
  final String? serial;
  final int? cellCount;
  final double? nominalAh;
  final double? nominalVoltage;
  final int? soc;

  const BatteryIdentity({
    this.model,
    this.firmware,
    this.serial,
    this.cellCount,
    this.nominalAh,
    this.nominalVoltage,
    this.soc,
  });

  /// e.g. "51.2 V 95 Ah, 16 cells"
  String get summary => [
        if (nominalVoltage != null && nominalAh != null)
          '${nominalVoltage!.toStringAsFixed(1)} V ${nominalAh!.toStringAsFixed(0)} Ah'
        else if (nominalAh != null)
          '${nominalAh!.toStringAsFixed(0)} Ah',
        if (cellCount != null) '$cellCount cells',
      ].join(', ');
}

enum BatteryLogKind {
  /// Something went wrong or a protection tripped.
  alarm,

  /// A state change or periodic sample (charge start/end, sleep, wake, …).
  state,
}

/// One entry from a battery's own stored log, placed on the real timeline.
class BatteryLogEntry {
  /// Stable identity, for de-duplicating overlapping downloads.
  final String key;
  final BatteryLogKind kind;

  /// Corrected local time, or null if the BMS clock was unset/reset back then.
  final DateTime? time;

  /// Time exactly as the BMS recorded it, for re-correcting later.
  final DateTime? bmsTime;

  /// If [time] is null: the entry happened before this time.
  final DateTime? before;

  final String title;
  final List<String> faults;
  final int? soc;
  final double? voltage;
  final double? current;
  final double? peakCurrent;
  final int? minCellMv;
  final int? maxCellMv;
  final List<int> temperaturesC;

  /// True for state entries that start / end a charge or discharge.
  final bool sessionStart;
  final bool sessionEnd;

  const BatteryLogEntry({
    required this.key,
    required this.kind,
    required this.title,
    this.time,
    this.bmsTime,
    this.before,
    this.faults = const [],
    this.soc,
    this.voltage,
    this.current,
    this.peakCurrent,
    this.minCellMv,
    this.maxCellMv,
    this.temperaturesC = const [],
    this.sessionStart = false,
    this.sessionEnd = false,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'kind': kind.name,
        'title': title,
        if (time != null) 't': time!.millisecondsSinceEpoch,
        if (bmsTime != null) 'bms': bmsTime!.toIso8601String(),
        if (before != null) 'before': before!.millisecondsSinceEpoch,
        if (faults.isNotEmpty) 'faults': faults,
        if (soc != null) 'soc': soc,
        if (voltage != null) 'v': voltage,
        if (current != null) 'i': current,
        if (peakCurrent != null) 'ipk': peakCurrent,
        if (minCellMv != null) 'cmin': minCellMv,
        if (maxCellMv != null) 'cmax': maxCellMv,
        if (temperaturesC.isNotEmpty) 'temps': temperaturesC,
        if (sessionStart) 'start': true,
        if (sessionEnd) 'end': true,
      };

  factory BatteryLogEntry.fromJson(Map<String, dynamic> j) => BatteryLogEntry(
        key: j['key'] as String,
        kind: BatteryLogKind.values.byName(j['kind'] as String),
        title: j['title'] as String,
        time: j['t'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
        bmsTime: j['bms'] == null ? null : DateTime.parse(j['bms'] as String),
        before: j['before'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['before'] as int),
        faults: (j['faults'] as List?)?.cast<String>() ?? const [],
        soc: j['soc'] as int?,
        voltage: (j['v'] as num?)?.toDouble(),
        current: (j['i'] as num?)?.toDouble(),
        peakCurrent: (j['ipk'] as num?)?.toDouble(),
        minCellMv: j['cmin'] as int?,
        maxCellMv: j['cmax'] as int?,
        temperaturesC: (j['temps'] as List?)?.cast<int>() ?? const [],
        sessionStart: j['start'] == true,
        sessionEnd: j['end'] == true,
      );
}
