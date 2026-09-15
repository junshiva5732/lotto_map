import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/store.dart';

/// 기간 필터. [rounds] 는 최근 N회차 (0 = 전체). 1년 ≈ 52회.
enum Period {
  all('전체', 0),
  y1('최근 1년', 52),
  y3('최근 3년', 156),
  y5('최근 5년', 260);

  final String label;
  final int rounds;
  const Period(this.label, this.rounds);
}

/// 지도·랭킹 탭이 공유하는 필터와 탭 전환 요청.
class AppState extends ChangeNotifier {
  bool _firstOnly = true;
  Period _period = Period.all;
  int _tab = 0;
  LatLng? _pendingFocus;

  /// 1등 배출점만 (false 면 2등 포함)
  bool get firstOnly => _firstOnly;
  Period get period => _period;
  int get tab => _tab;

  set firstOnly(bool v) {
    if (v == _firstOnly) return;
    _firstOnly = v;
    notifyListeners();
  }

  set period(Period p) {
    if (p == _period) return;
    _period = p;
    notifyListeners();
  }

  set tab(int i) {
    if (i == _tab) return;
    _tab = i;
    notifyListeners();
  }

  /// 지도 탭으로 이동해 [point] 를 보여달라는 요청. 지도가 소비하면 [takeFocus] 로 비운다.
  void focusOnMap(LatLng point) {
    _pendingFocus = point;
    _tab = 0;
    notifyListeners();
  }

  LatLng? takeFocus() {
    final p = _pendingFocus;
    _pendingFocus = null;
    return p;
  }

  int minRound(int lastRound) => _period.rounds == 0 ? 0 : lastRound - _period.rounds + 1;

  /// 현재 필터를 통과하는 판매점인지. [lastRound] 는 데이터의 마지막 회차.
  bool passes(Store s, int lastRound) {
    final (first, second) = s.countsSince(minRound(lastRound));
    return _firstOnly ? first > 0 : (first + second) > 0;
  }

  /// 필터 기준 정렬 점수: 1등 횟수 우선, 2등은 보조
  int score(Store s, int lastRound) {
    final (first, second) = s.countsSince(minRound(lastRound));
    return first * 10 + (_firstOnly ? 0 : second);
  }
}
