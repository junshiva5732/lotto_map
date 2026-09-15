/// 로또 6/45 회차별 추첨일. 1회 = 2002-12-07 (토), 이후 매주 토요일.
DateTime drawDateOf(int round) =>
    DateTime(2002, 12, 7).add(Duration(days: 7 * (round - 1)));

/// 판매점의 당첨 이력 한 건.
class Win {
  final int round;

  /// 1 = 1등, 2 = 2등
  final int rank;

  /// auto / manual / semi / null(정보 없음, 옛 회차)
  final String? mode;

  const Win({required this.round, required this.rank, this.mode});

  factory Win.fromJson(List<dynamic> j) =>
      Win(round: j[0] as int, rank: j[1] as int, mode: j.length > 2 ? j[2] as String? : null);

  List<dynamic> toJson() => [round, rank, mode];

  DateTime get date => drawDateOf(round);

  String get modeLabel => switch (mode) {
        'auto' => '자동',
        'manual' => '수동',
        'semi' => '반자동',
        _ => '',
      };
}

/// 당첨 이력이 있는 로또 판매점.
class Store {
  final String id;
  final String name;
  final String addr;
  final String? tel;
  final double lat;
  final double lng;

  /// 서울 / 경기 / 부산 … (동행복권 기준 시·도 약칭)
  final String region;

  /// 정상 / 폐업 등
  final String status;

  /// 회차 내림차순
  final List<Win> wins;

  const Store({
    required this.id,
    required this.name,
    required this.addr,
    required this.tel,
    required this.lat,
    required this.lng,
    required this.region,
    required this.status,
    required this.wins,
  });

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'] as String,
        name: j['name'] as String,
        addr: j['addr'] as String,
        tel: j['tel'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        region: j['region'] as String? ?? '',
        status: j['status'] as String? ?? '',
        wins: (j['wins'] as List).map((w) => Win.fromJson(w as List)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'addr': addr,
        'tel': tel,
        'lat': lat,
        'lng': lng,
        'region': region,
        'status': status,
        'wins': wins.map((w) => w.toJson()).toList(),
      };

  int get firstCount => wins.where((w) => w.rank == 1).length;
  int get secondCount => wins.where((w) => w.rank == 2).length;
  bool get isClosed => status.contains('폐'); // 폐점 / 폐업

  /// 가장 최근 1등 회차 (없으면 null)
  int? get lastFirstRound {
    for (final w in wins) {
      if (w.rank == 1) return w.round;
    }
    return null;
  }

  /// [minRound] 이후 회차만 세었을 때의 1등/2등 횟수
  (int, int) countsSince(int minRound) {
    var first = 0, second = 0;
    for (final w in wins) {
      if (w.round < minRound) break; // 내림차순이므로
      if (w.rank == 1) {
        first++;
      } else {
        second++;
      }
    }
    return (first, second);
  }

  /// 새 당첨 이력을 합친 사본. 이름·주소 등은 [newer] 값을 우선한다.
  Store merge(Store newer) {
    final rounds = wins.map((w) => '${w.round}-${w.rank}-${w.mode}').toSet();
    final merged = [
      ...wins,
      ...newer.wins.where((w) => !rounds.contains('${w.round}-${w.rank}-${w.mode}')),
    ]..sort((a, b) => b.round.compareTo(a.round));
    return Store(
      id: id,
      name: newer.name.isNotEmpty ? newer.name : name,
      addr: newer.addr.isNotEmpty ? newer.addr : addr,
      tel: newer.tel ?? tel,
      lat: newer.lat,
      lng: newer.lng,
      region: newer.region.isNotEmpty ? newer.region : region,
      status: newer.status.isNotEmpty ? newer.status : status,
      wins: merged,
    );
  }
}
