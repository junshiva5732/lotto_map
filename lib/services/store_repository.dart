import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/store.dart';

/// 판매점 데이터 저장소.
///
/// - 기본 데이터는 앱에 내장된 `assets/data/stores.json` (tool/fetch_stores.py 로 생성).
/// - 앱 실행 시 동행복권에서 내장 데이터 이후 회차를 받아와 앱 문서 폴더에 캐시하고 합친다.
///   네트워크가 없거나 사이트 구조가 바뀌어 실패해도 내장 데이터로 정상 동작한다.
class StoreRepository extends ChangeNotifier {
  StoreRepository._();

  static Future<StoreRepository> load() async {
    final repo = StoreRepository._();
    await repo._loadBundled();
    await repo._loadUpdates();
    return repo;
  }

  Map<String, Store> _stores = {};
  int _bundledLastRound = 0;
  int _lastRound = 0;
  String _fetchedAt = '';
  bool _refreshing = false;

  List<Store> get stores => _stores.values.toList(growable: false);
  Store? byId(String id) => _stores[id];

  /// 데이터에 포함된 마지막 회차
  int get lastRound => _lastRound;
  DateTime get lastDrawDate => drawDateOf(_lastRound);
  String get bundledFetchedAt => _fetchedAt;
  bool get refreshing => _refreshing;

  // ---------------------------------------------------------------- 로드

  Future<void> _loadBundled() async {
    final raw = await rootBundle.loadString('assets/data/stores.json');
    final parsed = await compute(_parseBundle, raw);
    _stores = parsed.stores;
    _bundledLastRound = parsed.lastRound;
    _lastRound = parsed.lastRound;
    _fetchedAt = parsed.fetchedAt;
  }

  static _Bundle _parseBundle(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final map = <String, Store>{};
    for (final s in j['stores'] as List) {
      final store = Store.fromJson(s as Map<String, dynamic>);
      map[store.id] = store;
    }
    return _Bundle(map, j['lastRound'] as int, j['fetchedAt'] as String? ?? '');
  }

  Future<File> _updatesFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/store_updates.json');
  }

  /// 캐시된 추가 회차(내장 데이터 이후)를 합친다. 형식: {"lastRound": n, "stores": [...]}
  Future<void> _loadUpdates() async {
    try {
      final f = await _updatesFile();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final last = j['lastRound'] as int;
      if (last <= _bundledLastRound) return; // 내장 데이터가 더 새롭다 (앱 업데이트 후)
      for (final s in j['stores'] as List) {
        _mergeStore(Store.fromJson(s as Map<String, dynamic>));
      }
      _lastRound = last;
    } catch (e) {
      debugPrint('updates load failed: $e');
    }
  }

  void _mergeStore(Store s) {
    final old = _stores[s.id];
    _stores[s.id] = old == null ? s : old.merge(s);
  }

  // ---------------------------------------------------------------- 갱신

  static const _base = 'https://www.dhlottery.co.kr';
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
    'X-Requested-With': 'XMLHttpRequest',
    'Referer': '$_base/wnprchsplcsrch/home',
  };

  /// 동행복권에서 [lastRound] 이후 회차를 받아 합친다. 최대 [maxRounds] 회차.
  /// 새 데이터가 있으면 true.
  Future<bool> refresh({int maxRounds = 30}) async {
    if (_refreshing) return false;
    _refreshing = true;
    notifyListeners();
    try {
      final latest = await _fetchLatestRound();
      if (latest == null || latest <= _lastRound) return false;

      final from = _lastRound + 1;
      final to = latest.clamp(from, from + maxRounds - 1);
      final fresh = <String, Store>{};
      for (var r = from; r <= to; r++) {
        final rows = await _fetchRound(r);
        if (rows == null) {
          // 중간에 실패하면 거기까지만 반영 (다음 실행 때 이어서)
          if (r == from) return false;
          return _applyUpdates(fresh, r - 1);
        }
        for (final s in rows) {
          final old = fresh[s.id];
          fresh[s.id] = old == null ? s : old.merge(s);
        }
      }
      return _applyUpdates(fresh, to);
    } catch (e) {
      debugPrint('refresh failed: $e');
      return false;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<bool> _applyUpdates(Map<String, Store> fresh, int newLast) async {
    // 기존 캐시 + 이번 결과를 합쳐 다시 저장
    final all = <String, Store>{};
    try {
      final f = await _updatesFile();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        if ((j['lastRound'] as int) > _bundledLastRound) {
          for (final s in j['stores'] as List) {
            final st = Store.fromJson(s as Map<String, dynamic>);
            all[st.id] = st;
          }
        }
      }
    } catch (_) {}
    for (final s in fresh.values) {
      final old = all[s.id];
      all[s.id] = old == null ? s : old.merge(s);
    }
    final f = await _updatesFile();
    await f.writeAsString(jsonEncode({
      'lastRound': newLast,
      'stores': all.values.map((s) => s.toJson()).toList(),
    }));

    for (final s in fresh.values) {
      _mergeStore(s);
    }
    _lastRound = newLast;
    notifyListeners();
    return true;
  }

  Future<int?> _fetchLatestRound() async {
    final res = await http
        .get(Uri.parse('$_base/lt645/selectLtEpsdInfo.do'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (j['data'] as Map<String, dynamic>)['list'] as List;
    var max = 0;
    for (final e in list) {
      final n = (e as Map<String, dynamic>)['ltEpsd'] as int;
      if (n > max) max = n;
    }
    return max == 0 ? null : max;
  }

  /// 한 회차의 당첨 판매점. 실패 시 null.
  Future<List<Store>?> _fetchRound(int round) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$_base/wnprchsplcsrch/selectLtWnShp.do?srchWnShpRnk=all&srchLtEpsd=$round&srchShpLctn='),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final list = ((j['data'] as Map<String, dynamic>?)?['list'] as List?) ?? const [];
      final out = <Store>[];
      for (final raw in list) {
        final row = raw as Map<String, dynamic>;
        final id = row['ltShpId'] as String?;
        final lat = row['shpLat'] as num?;
        final lng = row['shpLot'] as num?;
        if (id == null || lat == null || lng == null) continue;
        if (id == '51100000') continue; // 인터넷 판매
        final mode = switch (row['atmtPsvYn']) {
          'Q' => 'auto',
          'M' => 'manual',
          'S' => 'semi',
          _ => null,
        };
        out.add(Store(
          id: id,
          name: (row['shpNm'] as String? ?? '').trim(),
          addr: (row['shpAddr'] as String? ?? '').trim(),
          tel: row['shpTelno'] as String?,
          lat: lat.toDouble(),
          lng: lng.toDouble(),
          region: row['region'] as String? ?? '',
          status: row['status'] as String? ?? '',
          wins: [Win(round: round, rank: (row['wnShpRnk'] as num?)?.toInt() ?? 0, mode: mode)],
        ));
      }
      return out;
    } catch (e) {
      debugPrint('round $round fetch failed: $e');
      return null;
    }
  }
}

class _Bundle {
  final Map<String, Store> stores;
  final int lastRound;
  final String fetchedAt;
  _Bundle(this.stores, this.lastRound, this.fetchedAt);
}
