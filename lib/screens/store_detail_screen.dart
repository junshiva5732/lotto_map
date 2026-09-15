import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ad_manager.dart';
import '../main.dart';
import '../models/store.dart';
import '../services/memo_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/store_widgets.dart';

/// 판매점 상세: 정보 + 당첨 이력 + 내 메모.
/// [open] 으로 열면 N번째마다 전면 광고가 먼저 나온다.
class StoreDetailScreen extends StatefulWidget {
  final AppServices services;
  final Store store;
  const StoreDetailScreen({super.key, required this.services, required this.store});

  static void open(BuildContext context, AppServices services, Store store) {
    AdManager.instance.onOpenDetailThen(() {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StoreDetailScreen(services: services, store: store)),
      );
    });
  }

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  late final TextEditingController _text;
  Timer? _debounce;

  MemoService get _memos => widget.services.memos;
  Store get store => widget.store;
  StoreMemo get memo =>
      _memos.of(store.id) ?? StoreMemo(storeId: store.id, updatedAt: DateTime.now());

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: memo.text);
    _text.addListener(_onTextChanged);
    _memos.addListener(_onMemos);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _saveText();
    _memos.removeListener(_onMemos);
    _text.dispose();
    super.dispose();
  }

  void _onMemos() {
    if (mounted) setState(() {});
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _saveText);
  }

  void _saveText() {
    if (_text.text == memo.text) return;
    _memos.save(memo.copyWith(text: _text.text));
  }

  Future<void> _openMap() async {
    // geo: 는 설치된 지도 앱(네이버/카카오/구글)이 받는다. 없으면 웹 지도로.
    final q = Uri.encodeComponent(store.name);
    final geo = Uri.parse('geo:${store.lat},${store.lng}?q=${store.lat},${store.lng}($q)');
    if (await canLaunchUrl(geo) && await launchUrl(geo)) return;
    final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=${store.lat},${store.lng}');
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }

  Future<void> _call() async {
    final tel = store.tel;
    if (tel == null) return;
    await launchUrl(Uri.parse('tel:${tel.replaceAll(RegExp(r'[^0-9+]'), '')}'));
  }

  Future<void> _pickVisited() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: memo.visitedAt ?? DateTime.now(),
      firstDate: DateTime(2002, 12, 7),
      lastDate: DateTime.now(),
    );
    if (picked != null) _memos.save(memo.copyWith(visitedAt: picked));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = memo;
    final df = DateFormat('yyyy.MM.dd');
    final wins = store.wins;

    return Scaffold(
      appBar: AppBar(
        title: Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: m.favorite ? '즐겨찾기 해제' : '즐겨찾기',
            icon: Icon(m.favorite ? Icons.star : Icons.star_border, color: m.favorite ? kGold : null),
            onPressed: () => _memos.toggleFavorite(store.id),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // ── 기본 정보
                WinBadges(first: store.firstCount, second: store.secondCount),
                const SizedBox(height: 12),
                _InfoRow(icon: Icons.place_outlined, text: store.addr),
                if (store.tel != null) _InfoRow(icon: Icons.phone_outlined, text: store.tel!),
                if (store.isClosed)
                  _InfoRow(icon: Icons.storefront_outlined, text: '현재 ${store.status} 상태입니다', color: scheme.error),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: _tight,
                        onPressed: _openMap,
                        icon: const Icon(Icons.directions),
                        label: const Text('길찾기'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: _tight,
                        onPressed: store.tel == null ? null : _call,
                        icon: const Icon(Icons.call),
                        label: const Text('전화'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: _tight,
                        onPressed: () {
                          widget.services.state.focusOnMap(LatLng(store.lat, store.lng));
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('지도'),
                      ),
                    ),
                  ],
                ),

                // ── 내 메모
                const SizedBox(height: 24),
                Text('내 메모', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('내 평점  '),
                            for (var i = 1; i <= 5; i++)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: Icon(i <= m.rating ? Icons.star : Icons.star_border,
                                    color: i <= m.rating ? kGold : scheme.outline),
                                onPressed: () => _memos.save(m.copyWith(rating: m.rating == i ? 0 : i)),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('방문일  '),
                            TextButton.icon(
                              onPressed: _pickVisited,
                              icon: const Icon(Icons.event, size: 18),
                              label: Text(m.visitedAt == null ? '기록하기' : df.format(m.visitedAt!)),
                            ),
                            if (m.visitedAt != null)
                              IconButton(
                                tooltip: '방문일 지우기',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => _memos.save(m.copyWith(clearVisited: true)),
                              ),
                          ],
                        ),
                        TextField(
                          controller: _text,
                          maxLines: null,
                          minLines: 3,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: '예) 주차 가능, 사장님 친절, 토요일 오후 줄 김…\n(자동 저장, 이 기기에만 저장됩니다)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 당첨 이력
                const SizedBox(height: 24),
                Text('당첨 이력 (${wins.length}건)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final w in wins)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: w.rank == 1 ? kGold : kSilver,
                      child: Text('${w.rank}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87, fontSize: 13)),
                    ),
                    title: Text('${w.round}회  ${w.rank}등'),
                    subtitle: Text(df.format(w.date)),
                    trailing: w.modeLabel.isEmpty ? null : Text(w.modeLabel, style: TextStyle(color: scheme.outline)),
                  ),
                const SizedBox(height: 8),
                Text(
                  '출처: 동행복권 당첨 판매점 조회 (262회 이후). 상호·주소는 최근 당첨 시점 기준이며 실제와 다를 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

/// 작은 화면에서 버튼 3개가 한 줄에 들어가도록 좌우 패딩을 줄인다.
final _tight = ButtonStyle(padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)));

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
