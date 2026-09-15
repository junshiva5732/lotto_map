import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../main.dart';
import '../widgets/store_widgets.dart';

/// 행운 번호 뽑기: 하루 1세트 무료, 광고 보면 추가.
class LuckyScreen extends StatefulWidget {
  final AppServices services;
  const LuckyScreen({super.key, required this.services});

  @override
  State<LuckyScreen> createState() => _LuckyScreenState();
}

class _LuckyScreenState extends State<LuckyScreen> {
  AppServices get s => widget.services;

  void _draw() {
    final picked = s.lucky.draw();
    if (picked == null) _askReward();
  }

  void _askReward() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('오늘 무료 뽑기를 다 썼어요'),
        content: Text('짧은 광고를 보면 ${s.lucky.perRewardLabel} 더 뽑을 수 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('다음에')),
          FilledButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('광고 보고 뽑기'),
            onPressed: () {
              Navigator.pop(ctx);
              _watchAd();
            },
          ),
        ],
      ),
    );
  }

  void _watchAd() {
    final ok = AdManager.instance.showRewarded(onReward: () {
      s.lucky.addReward();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.lucky.perRewardLabel} 추가됐어요!')),
        );
      }
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고를 아직 불러오지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('행운 번호')),
      body: ListenableBuilder(
        listenable: s.lucky,
        builder: (context, _) {
          final sets = s.lucky.sets;
          final credits = s.lucky.credits;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.auto_awesome, size: 40, color: kGold),
                      const SizedBox(height: 8),
                      Text('오늘의 행운 번호',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('남은 뽑기 $credits회', style: TextStyle(color: scheme.onPrimaryContainer)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _draw,
                          icon: const Icon(Icons.casino_outlined),
                          label: Text(credits > 0 ? '번호 뽑기' : '광고 보고 더 뽑기'),
                        ),
                      ),
                      if (credits > 0)
                        TextButton.icon(
                          onPressed: _watchAd,
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: Text('광고 보고 ${s.lucky.perRewardLabel} 충전'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (sets.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '버튼을 눌러 오늘의 번호를 뽑아 보세요.\n뽑은 번호는 오늘 하루 동안 여기에 남아 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.outline),
                  ),
                )
              else
                for (var i = 0; i < sets.length; i++)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(String.fromCharCode(65 + (sets.length - 1 - i) % 26),
                                style: TextStyle(fontWeight: FontWeight.w800, color: scheme.outline)),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [for (final n in sets[i]) _Ball(n)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              Text(
                '재미로 보는 무작위 번호입니다. 당첨을 보장하지 않으며, 복권 구매는 만 19세 이상만 가능합니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 동행복권 공 색상: 1~10 노랑, 11~20 파랑, 21~30 빨강, 31~40 회색, 41~45 초록
class _Ball extends StatelessWidget {
  final int n;
  const _Ball(this.n);

  Color get _color => switch (n) {
        <= 10 => const Color(0xFFFBC400),
        <= 20 => const Color(0xFF69C8F2),
        <= 30 => const Color(0xFFFF7272),
        <= 40 => const Color(0xFFAAAAAA),
        _ => const Color(0xFFB0D840),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-.3, -.4),
          colors: [Color.lerp(_color, Colors.white, .35)!, _color, Color.lerp(_color, Colors.black, .2)!],
          stops: const [0, .6, 1],
        ),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
    );
  }
}
