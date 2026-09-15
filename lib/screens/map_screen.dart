import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../models/store.dart';
import '../services/map_config.dart';
import '../widgets/store_widgets.dart';
import 'store_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final AppServices services;
  const MapScreen({super.key, required this.services});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  List<Store> _filtered = const [];
  List<Marker> _markers = const [];
  LatLng? _myLocation;
  bool _locating = false;
  Timer? _debounce;
  bool _mapReady = false;

  AppServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.state.addListener(_onStateChanged);
    s.repo.addListener(_recompute);
    s.memos.addListener(_rebuildMarkers);
    _recompute();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    s.state.removeListener(_onStateChanged);
    s.repo.removeListener(_recompute);
    s.memos.removeListener(_rebuildMarkers);
    _map.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    _recompute();
    _consumeFocus();
  }

  /// 다른 탭에서 "지도에서 보기" 를 눌렀을 때
  void _consumeFocus() {
    final p = s.state.takeFocus();
    if (p == null || !_mapReady) return;
    _map.move(p, 16.5);
  }

  /// 필터 통과 판매점 목록 갱신 (필터·데이터가 바뀔 때만)
  void _recompute() {
    final last = s.repo.lastRound;
    _filtered = s.repo.stores.where((st) => s.state.passes(st, last)).toList(growable: false);
    _rebuildMarkers();
  }

  void _scheduleRebuild() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), _rebuildMarkers);
  }

  void _rebuildMarkers() {
    if (!mounted || !_mapReady) return;
    final camera = _map.camera;
    final zoom = camera.zoom;
    final b = camera.visibleBounds;
    // 화면 밖 20% 여유
    final dLat = (b.north - b.south) * .2, dLng = (b.east - b.west) * .2;
    final n = b.north + dLat, so = b.south - dLat, e = b.east + dLng, w = b.west - dLng;
    final visible = _filtered.where((st) => st.lat <= n && st.lat >= so && st.lng <= e && st.lng >= w);
    final last = s.repo.lastRound;
    final minRound = s.state.minRound(last);

    final markers = <Marker>[];
    if (zoom >= MapConfig.clusterUntilZoom) {
      for (final st in visible) {
        markers.add(_storeMarker(st, minRound));
      }
    } else {
      // 화면 픽셀 기준 격자 클러스터링 (Web Mercator)
      final scale = 256 * math.pow(2, zoom).toDouble();
      const cell = 64.0;
      final buckets = <int, _Cluster>{};
      for (final st in visible) {
        final x = (st.lng + 180) / 360 * scale;
        final latR = st.lat * math.pi / 180;
        final y = (1 - math.log(math.tan(latR) + 1 / math.cos(latR)) / math.pi) / 2 * scale;
        final key = (x ~/ cell) * 1000003 + (y ~/ cell);
        final (f, sec) = st.countsSince(minRound);
        (buckets[key] ??= _Cluster()).add(st, f + (s.state.firstOnly ? 0 : sec));
      }
      for (final c in buckets.values) {
        if (c.stores.length == 1) {
          markers.add(_storeMarker(c.stores.first, minRound));
        } else {
          markers.add(_clusterMarker(c, zoom));
        }
      }
    }
    setState(() => _markers = markers);
  }

  Marker _storeMarker(Store st, int minRound) {
    final (first, second) = st.countsSince(minRound);
    final isFav = s.memos.isFavorite(st.id);
    final big = first >= 3;
    final size = big ? 44.0 : 36.0;
    return Marker(
      point: LatLng(st.lat, st.lng),
      width: size,
      height: size + 6,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _showStoreSheet(st),
        child: _Pin(
          label: first > 0 ? '$first' : '2',
          color: first > 0 ? kGold : kSilver,
          size: size,
          favorite: isFav,
          closed: st.isClosed,
          secondOnly: first == 0 && second > 0,
        ),
      ),
    );
  }

  Marker _clusterMarker(_Cluster c, double zoom) {
    final count = c.stores.length;
    final size = count >= 100 ? 52.0 : (count >= 20 ? 46.0 : 40.0);
    final scheme = Theme.of(context).colorScheme;
    return Marker(
      point: c.center,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _map.move(c.center, math.min(zoom + 2.5, MapConfig.maxZoom)),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: .88),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38, offset: Offset(0, 2))],
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w800,
              fontSize: count >= 1000 ? 12 : 14,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 내 위치

  Future<void> _goMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast('기기의 위치 서비스가 꺼져 있습니다');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _toast('위치 권한이 없어 내 주변을 찾을 수 없습니다');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 12));
      _myLocation = LatLng(pos.latitude, pos.longitude);
      _map.move(_myLocation!, 14.5);
    } catch (e) {
      _toast('현재 위치를 가져오지 못했습니다');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------- 마커 탭

  void _showStoreSheet(Store st) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListenableBuilder(
        listenable: s.memos,
        builder: (ctx, _) {
          final memo = s.memos.of(st.id);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(st.name,
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                        icon: Icon(
                          (memo?.favorite ?? false) ? Icons.star : Icons.star_border,
                          color: (memo?.favorite ?? false) ? kGold : null,
                        ),
                        onPressed: () => s.memos.toggleFavorite(st.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(st.addr, style: TextStyle(color: Theme.of(ctx).colorScheme.outline)),
                  const SizedBox(height: 10),
                  WinBadges(first: st.firstCount, second: st.secondCount),
                  if (st.lastFirstRound != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('최근 1등: ${st.lastFirstRound}회', style: Theme.of(ctx).textTheme.bodySmall),
                    ),
                  if (memo != null && memo.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('📝 ${memo.text}', maxLines: 3, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        StoreDetailScreen.open(context, s, st);
                      },
                      icon: const Icon(Icons.edit_note),
                      label: Text(memo == null || memo.text.isEmpty ? '상세 보기 · 메모 쓰기' : '상세 보기 · 메모 수정'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: MapConfig.initialCenter,
            initialZoom: MapConfig.initialZoom,
            minZoom: MapConfig.minZoom,
            maxZoom: MapConfig.maxZoom,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () {
              _mapReady = true;
              _rebuildMarkers();
              _consumeFocus();
            },
            onPositionChanged: (_, _) => _scheduleRebuild(),
          ),
          children: [
            TileLayer(
              urlTemplate: MapConfig.tileUrl,
              userAgentPackageName: MapConfig.userAgentPackage,
              maxNativeZoom: 19,
            ),
            if (_myLocation != null)
              MarkerLayer(markers: [
                Marker(
                  point: _myLocation!,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
                    ),
                  ),
                ),
              ]),
            MarkerLayer(markers: _markers),
            if (MapConfig.attribution.isNotEmpty)
              SimpleAttributionWidget(
                source: Text(MapConfig.attribution, style: const TextStyle(fontSize: 10)),
                alignment: Alignment.bottomLeft,
              ),
          ],
        ),

        // 상단 필터
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(999),
                    color: scheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: ListenableBuilder(
                        listenable: s.repo,
                        builder: (_, _) => Row(
                          children: [
                            const Icon(Icons.location_on, color: kGold, size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '명당 ${_filtered.length}곳 · ${s.repo.lastRound}회 기준',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (s.repo.refreshing)
                              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Material(color: Colors.transparent, child: FilterBar(state: s.state)),
              ],
            ),
          ),
        ),

        // 내 위치
        Positioned(
          right: 12,
          bottom: 24,
          child: FloatingActionButton.small(
            heroTag: 'myloc',
            onPressed: _goMyLocation,
            child: _locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

class _Cluster {
  final stores = <Store>[];
  double _lat = 0, _lng = 0;
  int weight = 0;

  void add(Store s, int w) {
    stores.add(s);
    _lat += s.lat;
    _lng += s.lng;
    weight += w;
  }

  LatLng get center => LatLng(_lat / stores.length, _lng / stores.length);
}

/// 판매점 핀: 원 안에 1등 횟수
class _Pin extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final bool favorite;
  final bool closed;
  final bool secondOnly;
  const _Pin({
    required this.label,
    required this.color,
    required this.size,
    required this.favorite,
    required this.closed,
    required this.secondOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: closed ? color.withValues(alpha: .45) : color,
            border: Border.all(color: favorite ? Colors.redAccent : Colors.white, width: favorite ? 3 : 2),
            boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black38, offset: Offset(0, 2))],
          ),
          alignment: Alignment.center,
          child: secondOnly
              ? const Text('2등', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87))
              : Text(label,
                  style: TextStyle(fontSize: size * .42, fontWeight: FontWeight.w900, color: Colors.black87)),
        ),
        // 아래쪽 꼬리
        CustomPaint(size: const Size(10, 6), painter: _TailPainter(closed ? color.withValues(alpha: .45) : color)),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  _TailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}
