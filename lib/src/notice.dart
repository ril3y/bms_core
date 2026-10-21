// Vendor-specific things a battery wants the user to know or decide.
// Drivers put family quirks here (e.g. a BMS clock that needs setting) so apps
// can present them without knowing anything about that family.

enum NoticeSeverity { info, warning, problem }

/// Something the user can do about a notice.
class BatteryAction {
  final String label;

  /// True if running it changes settings on the battery. Apps must ask first.
  final bool changesBattery;

  /// Runs the action; returns a short confirmation to show, e.g. "Clock set".
  final Future<String?> Function() run;

  const BatteryAction({required this.label, required this.run, this.changesBattery = false});
}

class BatteryNotice {
  /// Stable per kind of notice (e.g. "eco.clock"), so apps can remember
  /// "don't ask again" per battery.
  final String id;
  final NoticeSeverity severity;
  final String title;
  final String message;
  final List<BatteryAction> actions;

  const BatteryNotice({
    required this.id,
    required this.title,
    required this.message,
    this.severity = NoticeSeverity.info,
    this.actions = const [],
  });
}
