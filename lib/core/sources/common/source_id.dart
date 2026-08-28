import 'package:flutter/foundation.dart';

/// A stable identifier for a configured source.
///
/// The value is intentionally opaque to feature code.  A source-specific
/// identifier must never be used without the source id that owns it.
@immutable
class SourceId {
  const SourceId(this.value);

  factory SourceId.of(String value) => SourceId(value.trim().toLowerCase());

  final String value;

  bool get isEmpty => value.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SourceId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
