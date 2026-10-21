// What a battery family — and, where it differs, a specific firmware — exposes.
// The UI consults this so it only renders what the pack actually provides,
// instead of inferring from whether a value happened to arrive. A new family
// or firmware ships its own capabilities and the screens adapt unchanged.

class BatteryCapabilities {
  /// Per-cell voltages.
  final bool cells;

  /// Per-cell balancing state.
  final bool cellBalancing;

  /// At least one temperature sensor.
  final bool temperatures;

  /// Reports (or derives) a state-of-health estimate.
  final bool stateOfHealth;

  /// Reports a charge-cycle counter.
  final bool cycleCount;

  /// Keeps lifetime protection-event counters (totals, no dates).
  final bool protectionTotals;

  /// Stores a time-stamped log on the device (alarms / running history).
  final bool onBoardLog;

  /// Has a real-time clock that can be read and set.
  final bool clock;

  /// Has configuration parameters CellScope can write.
  final bool settings;

  const BatteryCapabilities({
    this.cells = false,
    this.cellBalancing = false,
    this.temperatures = false,
    this.stateOfHealth = false,
    this.cycleCount = false,
    this.protectionTotals = false,
    this.onBoardLog = false,
    this.clock = false,
    this.settings = false,
  });

  /// Everything on — a convenient base to switch individual features off from.
  static const full = BatteryCapabilities(
    cells: true,
    cellBalancing: true,
    temperatures: true,
    stateOfHealth: true,
    cycleCount: true,
    protectionTotals: true,
    onBoardLog: true,
    clock: true,
    settings: true,
  );

  BatteryCapabilities copyWith({
    bool? cells,
    bool? cellBalancing,
    bool? temperatures,
    bool? stateOfHealth,
    bool? cycleCount,
    bool? protectionTotals,
    bool? onBoardLog,
    bool? clock,
    bool? settings,
  }) =>
      BatteryCapabilities(
        cells: cells ?? this.cells,
        cellBalancing: cellBalancing ?? this.cellBalancing,
        temperatures: temperatures ?? this.temperatures,
        stateOfHealth: stateOfHealth ?? this.stateOfHealth,
        cycleCount: cycleCount ?? this.cycleCount,
        protectionTotals: protectionTotals ?? this.protectionTotals,
        onBoardLog: onBoardLog ?? this.onBoardLog,
        clock: clock ?? this.clock,
        settings: settings ?? this.settings,
      );
}
