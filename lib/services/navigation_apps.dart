import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/store.dart';

/// 길찾기에 쓸 외부 지도 앱.
enum NavApp {
  naver('네이버 지도', Icons.navigation_outlined, Color(0xFF03C75A)),
  kakao('카카오맵', Icons.map_outlined, Color(0xFFFEE500)),
  tmap('T맵', Icons.directions_car_outlined, Color(0xFF1E6BE6)),
  google('구글 지도', Icons.public, Color(0xFF4285F4)),
  other('다른 앱으로 열기', Icons.open_in_new, Color(0xFF9E9E9E));

  final String label;
  final IconData icon;
  final Color color;
  const NavApp(this.label, this.icon, this.color);

  /// 앱 스킴 URL. 앱이 없으면 [fallback] 으로.
  Uri primary(Store s) {
    final name = Uri.encodeComponent(s.name);
    return switch (this) {
      naver => Uri.parse(
        'nmap://route/public?dlat=${s.lat}&dlng=${s.lng}&dname=$name&appname=com.jun5731.lotto_map',
      ),
      kakao => Uri.parse(
        'kakaomap://route?ep=${s.lat},${s.lng}&by=PUBLICTRANSIT',
      ),
      tmap => Uri.parse(
        'tmap://route?goalname=$name&goalx=${s.lng}&goaly=${s.lat}',
      ),
      google => Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lng}',
      ),
      other => Uri.parse('geo:${s.lat},${s.lng}?q=${s.lat},${s.lng}($name)'),
    };
  }

  /// 앱 미설치 시: 웹 지도 또는 스토어
  Uri fallback(Store s) {
    final name = Uri.encodeComponent(s.name);
    return switch (this) {
      naver => Uri.parse('market://details?id=com.nhn.android.nmap'),
      kakao => Uri.parse(
        'https://map.kakao.com/link/to/$name,${s.lat},${s.lng}',
      ),
      tmap => Uri.parse('market://details?id=com.skt.tmap.ku'),
      google => Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${s.lat},${s.lng}',
      ),
      other => Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${s.lat},${s.lng}',
      ),
    };
  }

  /// 앱 → 폴백 순으로 시도. 둘 다 실패하면 false.
  Future<bool> launch(Store s) async {
    try {
      if (await launchUrl(primary(s), mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}
    try {
      return await launchUrl(fallback(s), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

/// 기본 길찾기 앱 설정 (없으면 매번 선택).
class NavAppPrefs {
  NavAppPrefs._();
  static const _key = 'nav_app_default';
  static SharedPreferences? _prefs;
  static final ValueNotifier<NavApp?> current = ValueNotifier(null);

  static void init(SharedPreferences prefs) {
    _prefs = prefs;
    final name = prefs.getString(_key);
    current.value = NavApp.values.where((a) => a.name == name).firstOrNull;
  }

  static Future<void> set(NavApp? app) async {
    current.value = app;
    if (app == null) {
      await _prefs?.remove(_key);
    } else {
      await _prefs?.setString(_key, app.name);
    }
  }
}

/// 길찾기. 기본 앱이 설정돼 있으면 바로 열고, 아니면 선택 시트를 띄운다.
/// [forcePicker] 가 true 면 기본 앱이 있어도 시트를 띄운다 (길게 누르기 등).
Future<void> openDirections(
  BuildContext context,
  Store store, {
  bool forcePicker = false,
}) async {
  final def = NavAppPrefs.current.value;
  if (def != null && !forcePicker) {
    final ok = await def.launch(store);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${def.label}을(를) 열 수 없습니다')));
    }
    return;
  }
  if (!context.mounted) return;
  return showNavAppPicker(context, store);
}

/// 길찾기 앱 선택 바텀시트. 선택한 앱으로 바로 연다.
Future<void> showNavAppPicker(BuildContext context, Store store) {
  var remember = NavAppPrefs.current.value != null;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setSheet) => SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '어떤 앱으로 길찾기 할까요?',
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      for (final app in NavApp.values)
                        ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: app.color.withValues(alpha: .18),
                            foregroundColor:
                                app == NavApp.kakao
                                    ? const Color(0xFF3C1E1E)
                                    : app.color,
                            child: Icon(app.icon),
                          ),
                          title: Text(app.label),
                          subtitle:
                              app == NavApp.other
                                  ? const Text('설치된 지도 앱 목록에서 선택')
                                  : null,
                          trailing:
                              NavAppPrefs.current.value == app
                                  ? Text(
                                    '기본',
                                    style: TextStyle(
                                      color: Theme.of(ctx).colorScheme.primary,
                                      fontSize: 12,
                                    ),
                                  )
                                  : null,
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await NavAppPrefs.set(remember ? app : null);
                            final ok = await app.launch(store);
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${app.label}을(를) 열 수 없습니다'),
                                ),
                              );
                            }
                          },
                        ),
                      SwitchListTile(
                        dense: true,
                        title: const Text('다음부터 이 앱으로 바로 열기'),
                        subtitle: const Text('길찾기 버튼을 길게 누르면 다시 고를 수 있어요'),
                        value: remember,
                        onChanged: (v) => setSheet(() => remember = v),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
        ),
  );
}
