import 'package:latlong2/latlong.dart';

/// 지도 타일 설정.
///
/// 개발·검증 단계에서는 OpenStreetMap 공개 타일을 쓴다. OSM 타일 서버는 대량 배포 앱에는
/// 사용 허가가 필요하므로(https://operations.osmfoundation.org/policies/tiles/),
/// 출시 전에 아래 [tileUrl] 을 키 발급형 제공자로 바꾸는 것을 권장한다. 예:
///   - VWorld (국토부, 무료 키): https://api.vworld.kr/req/wmts/1.0.0/{VWORLD_KEY}/Base/{z}/{y}/{x}.png
///   - MapTiler / Stadia 등 (무료 티어)
/// 키는 `--dart-define=TILE_URL=...` 로 넣으면 코드 수정 없이 바뀐다.
class MapConfig {
  MapConfig._();

  static const _fromEnv = String.fromEnvironment('TILE_URL');
  static const _osm = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static String get tileUrl => _fromEnv.isNotEmpty ? _fromEnv : _osm;
  static bool get isOsm => tileUrl == _osm;

  /// 타일 요청에 실리는 User-Agent (OSM 정책상 앱 식별 필수)
  static const userAgentPackage = 'com.jun5731.lotto_map';

  static bool get isVworld => tileUrl.contains('vworld.kr');

  /// 지도 하단 표기. 브이월드는 약관상 사용 표기가 의무.
  static String get attribution => isOsm
      ? 'OpenStreetMap contributors'
      : isVworld
          ? '브이월드 (국토교통부)'
          : '';

  /// 첫 화면: 서울시청
  static final initialCenter = LatLng(37.5665, 126.9780);
  static const initialZoom = 11.0;
  static const minZoom = 6.0;
  static const maxZoom = 18.0;

  /// 이 줌 이상에서는 묶지 않고 개별 마커
  static const clusterUntilZoom = 14.0;
}
