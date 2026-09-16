import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 판매점 하나에 대한 사용자 기록. 기기 내부(SharedPreferences)에만 저장.
class StoreMemo {
  final String storeId;
  final String text;
  final bool favorite;

  /// 0 = 없음, 1~5
  final int rating;
  final DateTime? visitedAt;

  /// 이 판매점에서 산 로또 금액(원) / 당첨된 금액(원). 방문 기록용.
  final int spent;
  final int won;
  final DateTime updatedAt;

  const StoreMemo({
    required this.storeId,
    this.text = '',
    this.favorite = false,
    this.rating = 0,
    this.visitedAt,
    this.spent = 0,
    this.won = 0,
    required this.updatedAt,
  });

  /// 금액은 방문 기록의 일부라 방문일이 없으면 기록으로 치지 않는다.
  bool get isEmpty =>
      text.isEmpty && !favorite && rating == 0 && visitedAt == null;

  StoreMemo copyWith({
    String? text,
    bool? favorite,
    int? rating,
    DateTime? visitedAt,
    bool clearVisited = false,
    int? spent,
    int? won,
  }) => StoreMemo(
    storeId: storeId,
    text: text ?? this.text,
    favorite: favorite ?? this.favorite,
    rating: rating ?? this.rating,
    visitedAt: clearVisited ? null : (visitedAt ?? this.visitedAt),
    spent: spent ?? this.spent,
    won: won ?? this.won,
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'storeId': storeId,
    'text': text,
    'favorite': favorite,
    'rating': rating,
    'visitedAt': visitedAt?.toIso8601String(),
    'spent': spent,
    'won': won,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StoreMemo.fromJson(Map<String, dynamic> j) => StoreMemo(
    storeId: j['storeId'] as String,
    text: j['text'] as String? ?? '',
    favorite: j['favorite'] as bool? ?? false,
    rating: j['rating'] as int? ?? 0,
    visitedAt:
        j['visitedAt'] == null
            ? null
            : DateTime.tryParse(j['visitedAt'] as String),
    spent: (j['spent'] as num?)?.toInt() ?? 0,
    won: (j['won'] as num?)?.toInt() ?? 0,
    updatedAt:
        DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// 1234567 → "1,234,567원"
String formatWon(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf원';
}

class MemoService extends ChangeNotifier {
  static const _key = 'memos';
  final SharedPreferences _prefs;
  final Map<String, StoreMemo> _memos = {};

  MemoService(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        for (final m in jsonDecode(raw) as List) {
          final memo = StoreMemo.fromJson(m as Map<String, dynamic>);
          if (memo.isEmpty) continue; // 방문일 없이 금액만 남은 옛 기록 등은 버린다
          _memos[memo.storeId] = memo;
        }
      } catch (e) {
        debugPrint('memo load failed: $e');
      }
    }
  }

  StoreMemo? of(String storeId) => _memos[storeId];
  bool isFavorite(String storeId) => _memos[storeId]?.favorite ?? false;
  bool hasMemo(String storeId) => (_memos[storeId]?.text.isNotEmpty) ?? false;

  /// 최근 수정순
  List<StoreMemo> get all =>
      _memos.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> save(StoreMemo memo) async {
    if (memo.isEmpty) {
      _memos.remove(memo.storeId);
    } else {
      _memos[memo.storeId] = memo;
    }
    notifyListeners();
    await _prefs.setString(
      _key,
      jsonEncode(_memos.values.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> toggleFavorite(String storeId) {
    final cur =
        _memos[storeId] ??
        StoreMemo(storeId: storeId, updatedAt: DateTime.now());
    return save(cur.copyWith(favorite: !cur.favorite));
  }

  Future<void> remove(String storeId) =>
      save(StoreMemo(storeId: storeId, updatedAt: DateTime.now()));
}
