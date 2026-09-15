import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ad_manager.dart';
import 'screens/home_shell.dart';
import 'services/app_state.dart';
import 'services/lucky_service.dart';
import 'services/memo_service.dart';
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
  // 광고 SDK 초기화는 앱 표시를 막지 않도록 기다리지 않는다.
  AdManager.instance.init();
  await initializeDateFormatting('ko');
  final prefs = await SharedPreferences.getInstance();
  final repo = await StoreRepository.load();
  final services = AppServices(
    repo: repo,
    memos: MemoService(prefs),
    lucky: LuckyService(prefs),
    state: AppState(),
  );
  runApp(LottoMapApp(services: services));
  // 내장 데이터 이후 회차를 백그라운드로 받아온다.
  repo.refresh();
}

class LottoMapApp extends StatelessWidget {
  final AppServices services;
  const LottoMapApp({super.key, required this.services});

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
      home: HomeShell(services: services),
    );
  }
}
