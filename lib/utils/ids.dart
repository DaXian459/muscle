int _sequence = 0;

/// 生成进程内唯一的标识，用于串联计划模板与训练记录里的同一台器械。
String newId() {
  _sequence++;
  return '${DateTime.now().microsecondsSinceEpoch}-$_sequence';
}
