import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 행운 번호 뽑기. 하루 1세트 무료, 보상형 광고 1회당 [perReward] 세트(=1) 추가.
/// 뽑은 번호는 당일 동안 보관한다.
class LuckyService extends ChangeNotifier {
  static const perReward = 1;
  String get perRewardLabel => '$perReward회';
  static const _kDate = 'lucky_date';
  static const _kCredits = 'lucky_credits';
  static const _kSets = 'lucky_sets';

  final SharedPreferences _prefs;
  final _rng = Random();

  String _date = '';
  int _credits = 0;

  /// 오늘 뽑은 번호 세트들 (각 6개, 오름차순). 최신이 앞.
  List<List<int>> _sets = [];

  LuckyService(this._prefs) {
    _date = _prefs.getString(_kDate) ?? '';
    _credits = _prefs.getInt(_kCredits) ?? 0;
    _sets = (_prefs.getStringList(_kSets) ?? const [])
        .map((s) => s.split(',').map(int.parse).toList())
        .toList();
    _rollDay();
  }

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  /// 날짜가 바뀌었으면 무료 1세트로 초기화
  void _rollDay() {
    final t = _today();
    if (_date == t) return;
    _date = t;
    _credits = 1;
    _sets = [];
    _persist();
  }

  int get credits {
    _rollDay();
    return _credits;
  }

  List<List<int>> get sets {
    _rollDay();
    return List.unmodifiable(_sets);
  }

  bool get canDraw => credits > 0;

  /// 크레딧 1개를 써서 번호 6개를 뽑는다. 크레딧이 없으면 null.
  List<int>? draw() {
    _rollDay();
    if (_credits <= 0) return null;
    _credits--;
    final pool = List.generate(45, (i) => i + 1)..shuffle(_rng);
    final picked = pool.take(6).toList()..sort();
    _sets.insert(0, picked);
    if (_sets.length > 20) _sets = _sets.sublist(0, 20);
    _persist();
    notifyListeners();
    return picked;
  }

  void addReward() {
    _rollDay();
    _credits += perReward;
    _persist();
    notifyListeners();
  }

  void _persist() {
    _prefs.setString(_kDate, _date);
    _prefs.setInt(_kCredits, _credits);
    _prefs.setStringList(_kSets, _sets.map((s) => s.join(',')).toList());
  }
}
