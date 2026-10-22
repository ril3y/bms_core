// Some batteries need a user-supplied secret before they can produce data — for
// example a Victron device's per-device encryption key, copied from the vendor
// app. A battery that implements this is prompted by the UI, which passes the
// entered value to [submitSecret]; the battery stores it and starts decoding.

abstract interface class NeedsSecret {
  /// True until a valid secret has been supplied (and remembered).
  bool get needsSecret;

  /// Short label for the prompt, e.g. "Encryption key".
  String get secretLabel;

  /// One line on what it is and where to get it.
  String get secretHelp;

  /// Supply the secret. Returns true if accepted (valid + stored).
  Future<bool> submitSecret(String value);
}
