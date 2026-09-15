import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../widgets/store_widgets.dart';
import 'settings_screen.dart';
import 'store_detail_screen.dart';

/// 즐겨찾기·메모가 있는 판매점 목록
class MemoListScreen extends StatelessWidget {
  final AppServices services;
  const MemoListScreen({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final s = services;
    final df = DateFormat('yyyy.MM.dd');
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 메모'),
        actions: [
          IconButton(
            tooltip: '설정·정보',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => SettingsScreen(services: s))),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.memos, s.repo]),
        builder: (context, _) {
          final memos = s.memos.all;
          if (memos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_add_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    const Text('아직 저장한 명당이 없습니다', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      '지도나 랭킹에서 판매점을 열고 ★ 즐겨찾기 또는 메모를 남겨 보세요.\n메모는 이 기기에만 저장됩니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: memos.length,
            itemBuilder: (context, i) {
              final m = memos[i];
              final st = s.repo.byId(m.storeId);
              if (st == null) return const SizedBox.shrink();
              return Dismissible(
                key: ValueKey(m.storeId),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                confirmDismiss: (_) async =>
                    await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('메모 삭제'),
                        content: Text('${st.name} 의 메모와 즐겨찾기를 지울까요?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
                        ],
                      ),
                    ) ??
                    false,
                onDismissed: (_) => s.memos.remove(m.storeId),
                child: StoreTile(
                  store: st,
                  minRound: 0,
                  favorite: m.favorite,
                  hasMemo: m.text.isNotEmpty,
                  subtitleExtra: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.rating > 0 || m.visitedAt != null)
                        Text(
                          [
                            if (m.rating > 0) '★' * m.rating,
                            if (m.visitedAt != null) '방문 ${df.format(m.visitedAt!)}',
                          ].join('  '),
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                        ),
                      if (m.text.isNotEmpty)
                        Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  onTap: () => StoreDetailScreen.open(context, s, st),
                  onMapTap: () => s.state.focusOnMap(LatLng(st.lat, st.lng)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
