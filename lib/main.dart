import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ad_manager.dart';
import 'screens/home_shell.dart';
import 'services/app_state.dart';
import 'services/lucky_service.dart';
import 'services/memo_service.dart';
import 'services/navigation_apps.dart';
import 'services/store_repository.dart';

/// 앱 전역 서비스 묶음. 화면에 생성자로 넘긴다.
class AppServices {
  final StoreRepository repo;
  final MemoService memos;
  final LuckyService lucky;
  final AppState state;
  const AppServices({
    required this.repo,
    required this.memos,
    required this.lucky,
    required this.state,
  });
}

const kSeedColor = Color(0xFFC62828); // 로또 빨강

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 광고 SDK 초기화는 Android 메인 스레드를 수 초 잡을 수 있어 첫 프레임 뒤로 미룬다.
  WidgetsBinding.instance.addPostFrameCallback((_) => AdManager.instance.init());
  // 데이터(2.8MB JSON) 로드는 1~3초 걸리므로 네이티브 스플래시를 붙들지 않고
  // 앱 자체의 로딩 화면을 먼저 띄운 뒤 준비되면 홈으로 바꾼다.
  runApp(const LottoMapApp());
}

Future<AppServices> _bootstrap() async {
  await initializeDateFormatting('ko');
  final prefs = await SharedPreferences.getInstance();
  NavAppPrefs.init(prefs);
  final repo = await StoreRepository.load();
  final services = AppServices(
    repo: repo,
    memos: MemoService(prefs),
    lucky: LuckyService(prefs),
    state: AppState(),
  );
  // 내장 데이터 이후 회차를 백그라운드로 받아온다.
  repo.refresh();
  return services;
}

class LottoMapApp extends StatefulWidget {
  const LottoMapApp({super.key});

  @override
  State<LottoMapApp> createState() => _LottoMapAppState();
}

class _LottoMapAppState extends State<LottoMapApp> {
  late final Future<AppServices> _services = _bootstrap();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '로또 명당 지도',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: kSeedColor, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: kSeedColor,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ko'), Locale('en')],
      locale: const Locale('ko'),
      home: FutureBuilder<AppServices>(
        future: _services,
        builder: (context, snap) {
          if (snap.hasError) return _ErrorScreen(error: snap.error!);
          if (!snap.hasData) return const _LoadingScreen();
          return HomeShell(services: snap.data!);
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/icon.png', width: 96, height: 96),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('전국 명당 데이터를 불러오는 중…', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final Object error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '데이터를 불러오지 못했습니다.\n앱을 다시 실행해 주세요.\n\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
