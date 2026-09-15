import 'package:flutter/material.dart';

import '../models/store.dart';
import '../services/app_state.dart';

const kGold = Color(0xFFF2B705);
const kSilver = Color(0xFF9E9E9E);

/// "1등 3회 · 2등 5회" 배지 묶음
class WinBadges extends StatelessWidget {
  final int first;
  final int second;
  final bool compact;
  const WinBadges({
    super.key,
    required this.first,
    required this.second,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        if (first > 0)
          _Badge(color: kGold, text: '1등 $first회', compact: compact),
        if (second > 0)
          _Badge(color: kSilver, text: '2등 $second회', compact: compact),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final String text;
  final bool compact;
  const _Badge({
    required this.color,
    required this.text,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? color
                  : Color.lerp(color, Colors.black, .35),
        ),
      ),
    );
  }
}

/// 랭킹·메모 목록에서 쓰는 판매점 한 줄
class StoreTile extends StatelessWidget {
  final Store store;
  final int? rank;
  final int minRound;
  final bool favorite;
  final bool hasMemo;
  final Widget? subtitleExtra;
  final VoidCallback onTap;
  final VoidCallback? onMapTap;

  const StoreTile({
    super.key,
    required this.store,
    this.rank,
    required this.minRound,
    this.favorite = false,
    this.hasMemo = false,
    this.subtitleExtra,
    required this.onTap,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final (first, second) = store.countsSince(minRound);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading:
          rank == null
              ? null
              : CircleAvatar(
                radius: 18,
                backgroundColor:
                    rank! <= 3 ? kGold : scheme.surfaceContainerHighest,
                foregroundColor: rank! <= 3 ? Colors.black87 : scheme.onSurface,
                child: Text(
                  '$rank',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              store.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (store.isClosed)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '폐점',
                style: TextStyle(fontSize: 11, color: scheme.error),
              ),
            ),
          if (favorite)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.star, size: 16, color: kGold),
            ),
          if (hasMemo)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(
                Icons.sticky_note_2_outlined,
                size: 15,
                color: scheme.primary,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(store.addr, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          WinBadges(first: first, second: second, compact: true),
          if (subtitleExtra != null) ...[
            const SizedBox(height: 4),
            subtitleExtra!,
          ],
        ],
      ),
      isThreeLine: true,
      trailing:
          onMapTap == null
              ? null
              : IconButton(
                tooltip: '지도에서 보기',
                icon: const Icon(Icons.place_outlined),
                onPressed: onMapTap,
              ),
    );
  }
}

/// 1등만 / 1등 횟수 / 기간 필터 칩 줄. [AppState] 를 직접 바꾼다.
class FilterBar extends StatelessWidget {
  final AppState state;
  const FilterBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder:
          (context, _) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('1등만'),
                  selected: state.firstOnly,
                  onSelected: (v) => state.firstOnly = v,
                  avatar:
                      state.firstOnly
                          ? null
                          : const Icon(Icons.filter_alt_outlined, size: 16),
                ),
                const SizedBox(width: 8),
                // 1등 N회 이상 (메뉴 칩)
                PopupMenuButton<int>(
                  tooltip: '1등 횟수 하한',
                  initialValue: state.minFirst,
                  onSelected: (v) => state.minFirst = v,
                  itemBuilder:
                      (_) => [
                        for (final n in AppState.minFirstOptions)
                          PopupMenuItem(
                            value: n,
                            child: Text(n == 1 ? '횟수 제한 없음' : '1등 $n회 이상'),
                          ),
                      ],
                  child: Chip(
                    avatar: Icon(
                      Icons.filter_list,
                      size: 16,
                      color:
                          state.minFirst > 1
                              ? Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer
                              : null,
                    ),
                    label: Text(
                      state.minFirst > 1 ? '1등 ${state.minFirst}회↑' : '횟수 전체',
                    ),
                    backgroundColor:
                        state.minFirst > 1
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                  ),
                ),
                const SizedBox(width: 8),
                for (final p in Period.values) ...[
                  ChoiceChip(
                    label: Text(p.label),
                    selected: state.period == p,
                    onSelected: (_) => state.period = p,
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
    );
  }
}
