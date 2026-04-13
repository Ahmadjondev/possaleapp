/// Safely parse a double from a JSON value that may be num, String, or null.
/// Django's DecimalField serializes as strings like "52000.00".
double parseDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Safely parse an int from a JSON value that may be num, String, or null.
int parseInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
