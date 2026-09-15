"""동행복권 당첨 판매점 데이터 수집 → assets/data/stores.json
실행: python tool/fetch_stores.py            (262회 ~ 최신 회차 전체)
      python tool/fetch_stores.py 1200 1241  (회차 범위 지정)

동행복권 사이트의 '당첨 판매점 조회' 가 쓰는 JSON API 를 회차별로 호출해
판매점(ltShpId) 단위로 1등/2등 당첨 이력을 모은다. 262회부터 데이터가 있다.
결과 스키마는 lib/models/store.dart 의 Store.fromJson 과 맞춘다.
"""
import json
import os
import sys
import time
import urllib.request

BASE = "https://www.dhlottery.co.kr"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "stores.json")
FIRST_ROUND_WITH_DATA = 262
REQUEST_INTERVAL = 3.0  # 초. 분당 20회 정도면 차단을 피하는 듯


BLOCK_WAIT_SEC = 15 * 60


def get_json(path):
    """JSON GET. 동행복권은 연속 요청이 많으면 IP 를 잠시 끊는다(연결 타임아웃).
    그 경우 BLOCK_WAIT_SEC 쉬었다가 다시 시도한다. 완전히 실패하면 None."""
    req = urllib.request.Request(BASE + path, headers={
        "User-Agent": UA,
        "X-Requested-With": "XMLHttpRequest",
        "Referer": BASE + "/wnprchsplcsrch/home",
    })
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            print(f"  blocked? ({e.__class__.__name__}) waiting {BLOCK_WAIT_SEC // 60} min "
                  f"(attempt {attempt + 1}/6) {path[-40:]}", flush=True)
            time.sleep(BLOCK_WAIT_SEC)
    return None


def latest_round():
    d = get_json("/lt645/selectLtEpsdInfo.do")
    if d is None:
        raise RuntimeError("cannot reach dhlottery")
    # {"data":{"list":[{"ltEpsd":1241,...},...]}} — 첫 항목이 최신 회차
    return max(int(x["ltEpsd"]) for x in d["data"]["list"])


REGIONS = ("서울", "경기", "인천", "부산", "대구", "광주", "대전", "울산", "세종", "강원",
           "충북", "충남", "전북", "전남", "경북", "경남", "제주", "전남광주")


def pick_addr(row):
    """폐점한 판매점은 shpAddr 이 비거나 '1층' 같은 상세만 남는다. 그때는 befAddr(당첨 당시 주소)."""
    shp = (row.get("shpAddr") or "").strip()
    if shp and shp.split()[0][:2] in [r[:2] for r in REGIONS]:
        return shp
    bef = (row.get("befAddr") or "").strip()
    return bef or shp


# 2026년 전남·광주 통합에 따라 동행복권은 '전남광주' 로 표기한다. 옛 회차 값도 맞춘다.
REGION_ALIAS = {"전남": "전남광주", "광주": "전남광주"}


def norm_region(r):
    r = (r or "").strip()
    return REGION_ALIAS.get(r, r)


def region_of(addr):
    tok = addr.split()[0] if addr else ""
    for r in sorted(REGIONS, key=len, reverse=True):
        if tok.startswith(r):
            return r
    return ""


def fetch_round(rnd):
    d = get_json(f"/wnprchsplcsrch/selectLtWnShp.do?srchWnShpRnk=all&srchLtEpsd={rnd}&srchShpLctn=")
    if d is None:
        return None
    return (d.get("data") or {}).get("list") or []


def main():
    start = int(sys.argv[1]) if len(sys.argv) > 1 else FIRST_ROUND_WITH_DATA
    end = int(sys.argv[2]) if len(sys.argv) > 2 else latest_round()
    print(f"rounds {start}..{end}")

    cache = os.path.join(os.path.dirname(__file__), "cache")
    os.makedirs(cache, exist_ok=True)

    def load_round(rnd):
        """캐시에 있으면 캐시, 없으면 서버. 실패하면 None."""
        cp = os.path.join(cache, f"{rnd}.json")
        if os.path.exists(cp):
            with open(cp, encoding="utf-8") as f:
                return json.load(f)
        rows = fetch_round(rnd)
        if rows is not None:
            with open(cp, "w", encoding="utf-8") as f:
                json.dump(rows, f, ensure_ascii=False)
            time.sleep(REQUEST_INTERVAL)
        return rows

    stores = {}
    failed = []
    retry_passes = 0
    rounds = list(range(start, end + 1))
    while rounds:
        rnd = rounds.pop(0)
        rows = load_round(rnd)
        if rows is None:
            print("  skip for now:", rnd)
            failed.append(rnd)
            continue
        for row in rows:
            sid = row.get("ltShpId")
            lat, lng = row.get("shpLat"), row.get("shpLot")
            if not sid or lat is None or lng is None:
                continue
            if sid == "51100000":  # 인터넷 판매 (동행복권 사이트) 는 지도에 의미 없음
                continue
            s = stores.setdefault(sid, {
                "id": sid, "name": "", "addr": "", "tel": None,
                "lat": lat, "lng": lng, "region": norm_region(row.get("region")),
                "status": "", "wins": [],
            })
            # 최신 회차 정보로 이름/주소/상태를 덮어쓴다 (상호 변경 반영)
            s["name"] = (row.get("shpNm") or s["name"]).strip()
            s["addr"] = pick_addr(row) or s["addr"]
            s["tel"] = row.get("shpTelno") or s["tel"]
            s["status"] = (row.get("status") or s["status"]).strip()
            s["region"] = norm_region(row.get("region")) or s["region"] or norm_region(region_of(s["addr"]))
            s["lat"], s["lng"] = lat, lng
            auto = {"Q": "auto", "M": "manual", "S": "semi"}.get(row.get("atmtPsvYn"))
            s["wins"].append([rnd, int(row.get("wnShpRnk") or 0), auto])
        if rnd % 20 == 0 or rnd == end:
            print(f"  {rnd}: {len(rows)} rows, {len(stores)} stores so far", flush=True)
        # 마지막까지 왔는데 실패 회차가 남아 있으면 한 번 더 시도
        if not rounds and failed and retry_passes < 3:
            retry_passes += 1
            print("  retrying failed rounds:", failed, flush=True)
            rounds, failed = failed, []
            time.sleep(30)
    if failed:
        print("WARNING: rounds still missing:", failed, "- rerun the script later", flush=True)

    for s in stores.values():
        s["wins"].sort(key=lambda w: -w[0])

    out = {
        "source": "동행복권 (dhlottery.co.kr) 당첨 판매점 조회",
        "fetchedAt": time.strftime("%Y-%m-%d"),
        "firstRound": start,
        "lastRound": end,
        "stores": sorted(stores.values(), key=lambda s: s["id"]),
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print("written:", os.path.abspath(OUT), len(stores), "stores",
          os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main()
