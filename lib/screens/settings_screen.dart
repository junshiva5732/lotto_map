import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/map_config.dart';

/// 데이터 기준·출처·개인정보처리방침·초기화
class SettingsScreen extends StatelessWidget {
  final AppServices services;
  const SettingsScreen({super.key, required this.services});

  static const privacyUrl = 'https://junshiva5732.github.io/lotto_map/privacy-policy.html';

  @override
  Widget build(BuildContext context) {
    final s = services;
    final df = DateFormat('yyyy.MM.dd');
    return Scaffold(
      appBar: AppBar(title: const Text('설정·정보')),
      body: ListenableBuilder(
        listenable: s.repo,
        builder: (context, _) => ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.dataset_outlined),
              title: Text('당첨 데이터: ${s.repo.lastRound}회 (${df.format(s.repo.lastDrawDate)} 추첨) 까지'),
              subtitle: Text('앱 내장 데이터 ${s.repo.bundledFetchedAt} 기준 · 실행 시 최신 회차 자동 반영'),
              trailing: s.repo.refreshing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      tooltip: '지금 갱신',
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        final ok = await s.repo.refresh();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? '최신 회차를 반영했습니다' : '새 회차가 없거나 가져오지 못했습니다')),
                        );
                      },
                    ),
            ),
            const ListTile(
              leading: Icon(Icons.source_outlined),
              title: Text('출처'),
              subtitle: Text('동행복권(dhlottery.co.kr) 당첨 판매점 조회. 262회(2007년) 이후 1·2등 배출점.\n'
                  '상호·주소·좌표는 동행복권 등록 정보 기준이며 실제와 다를 수 있습니다.'),
            ),
            if (MapConfig.isOsm)
              const ListTile(
                leading: Icon(Icons.map_outlined),
                title: Text('지도'),
                subtitle: Text('© OpenStreetMap contributors'),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('개인정보처리방침'),
              subtitle: const Text('메모·즐겨찾기는 기기에만 저장되며 서버로 전송되지 않습니다'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => launchUrl(Uri.parse(privacyUrl), mode: LaunchMode.externalApplication),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('내 메모·즐겨찾기 전체 삭제'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('전체 삭제'),
                    content: const Text('저장한 메모와 즐겨찾기를 모두 지웁니다. 되돌릴 수 없습니다.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
                    ],
                  ),
                );
                if (ok != true) return;
                for (final m in s.memos.all) {
                  await s.memos.remove(m.storeId);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제했습니다')));
                }
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '이 앱은 동행복권과 무관한 개인 개발 앱입니다. 복권은 만 19세 이상만 구매할 수 있으며, '
                '과도한 구매는 삼가세요. 당첨 이력은 참고용이며 당첨을 보장하지 않습니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
