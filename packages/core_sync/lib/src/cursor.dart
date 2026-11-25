class ChangeCursor {
  const ChangeCursor({
    required this.stream,
    required this.value,
  });

  final String stream;
  final String value;

  ChangeCursor copyWith({String? value}) =>
      ChangeCursor(stream: stream, value: value ?? this.value);

  @override
  bool operator ==(Object other) =>
      other is ChangeCursor && stream == other.stream && value == other.value;

  @override
  int get hashCode => Object.hash(stream, value);
}

class CursorStore {
  final Map<String, ChangeCursor> _cursors = {};

  ChangeCursor? get(String stream) => _cursors[stream];

  void advance(ChangeCursor cursor) {
    _cursors[cursor.stream] = cursor;
  }

  void clear(String stream) {
    _cursors.remove(stream);
  }
}
