import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../models/store.dart';
import '../widgets/store_widgets.dart';
import 'store_detail_screen.dart';

/// 1등 배출 횟수 랭킹 + 상호/주소 검색 + 지역 필터
class RankingScreen extends StatefulWidget {
  final AppServices services;
  const RankingScreen({super.key, required this.services});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final _search = TextEditingController();
  String _region = '전체';
  List<Store> _rows = const [];
  List<String> _regions = const ['전체'];

  AppServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.state.addListener(_recompute);
    s.repo.addListener(_recompute);
    s.memos.addListener(_onMemos);
    _search.addListener(_recompute);
    _recompute();
  }

  @override
  void dispose() {
    s.state.removeListener(_recompute);
    s.repo.removeListener(_recompute);
    s.memos.removeListener(_onMemos);
    _search.dispose();
    super.dispose();
  }

  void _onMemos() {
    if (mounted) setState(() {});
  }

  void _recompute() {
    final last = s.repo.lastRound;
    final all = s.repo.stores;
    final regions = all.map((e) => e.region).where((r) => r.isNotEmpty).toSet().toList()..sort();
    _regions = ['전체', ...regions];
    if (!_regions.contains(_region)) _region = '전체';

    final q = _search.text.trim();
    final rows = all.where((st) {
      if (!s.state.passes(st, last)) return false;
      if (_region != '전체' && st.region != _region) return false;
      if (q.isNotEmpty && !st.name.contains(q) && !st.addr.contains(q)) return false;
      return true;
    }).toList();
    rows.sort((a, b) {
      final d = s.state.score(b, last).compareTo(s.state.score(a, last));
      if (d != 0) return d;
      return (b.lastFirstRound ?? 0).compareTo(a.lastFirstRound ?? 0);
    });
    if (mounted) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final last = s.repo.lastRound;
    final minRound = s.state.minRound(last);
    return Scaffold(
      appBar: AppBar(
        title: const Text('명당 랭킹'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _region,
              items: [for (final r in _regions) DropdownMenuItem(value: r, child: Text(r))],
              onChanged: (v) {
                _region = v ?? '전체';
                _recompute();
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: '상호 또는 주소 검색 (예: 강남, 노다지)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), onPressed: _search.clear),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                isDense: true,
              ),
            ),
          ),
          FilterBar(state: s.state),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${_rows.length}곳 · $last회 기준',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
            ),
          ),
          Expanded(
            child: _rows.isEmpty
                ? const Center(child: Text('조건에 맞는 판매점이 없습니다'))
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, i) {
                      final st = _rows[i];
                      return StoreTile(
                        store: st,
                        rank: i + 1,
                        minRound: minRound,
                        favorite: s.memos.isFavorite(st.id),
                        hasMemo: s.memos.hasMemo(st.id),
                        onTap: () => StoreDetailScreen.open(context, s, st),
                        onMapTap: () => s.state.focusOnMap(LatLng(st.lat, st.lng)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
