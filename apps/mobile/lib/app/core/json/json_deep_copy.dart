Object? deepCopyJsonValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return deepCopyJsonMap(value);
  }
  if (value is List<dynamic>) {
    return value.map(deepCopyJsonValue).toList(growable: false);
  }
  return value;
}

Map<String, dynamic> deepCopyJsonMap(Map<String, dynamic> value) {
  return value.map<String, dynamic>(
    (key, nested) => MapEntry(key, deepCopyJsonValue(nested)),
  );
}
