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


def get_json(path):
    req = urllib.request.Request(BASE + path, headers={
        "User-Agent": UA,
        "X-Requested-With": "XMLHttpRequest",
        "Referer": BASE + "/wnprchsplcsrch/home",
    })
    for attempt in range(8):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            print("retry", attempt + 1, path, e)
            time.sleep(3 * (attempt + 1))
    return None


def latest_round():
    d = get_json("/lt645/selectLtEpsdInfo.do")
    if d is None:
        raise RuntimeError("cannot reach dhlottery")
    # {"data":{"list":[{"ltEpsd":1241,...},...]}} — 첫 항목이 최신 회차
    return max(int(x["ltEpsd"]) for x in d["data"]["list"])


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
            time.sleep(1.0)  # 사이트가 빠른 연속 요청을 차단하므로 천천히
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
            time.sleep(10)
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
                "lat": lat, "lng": lng, "region": row.get("region") or "",
                "status": "", "wins": [],
            })
            # 최신 회차 정보로 이름/주소/상태를 덮어쓴다 (상호 변경 반영)
            s["name"] = (row.get("shpNm") or s["name"]).strip()
            s["addr"] = (row.get("shpAddr") or s["addr"]).strip()
            s["tel"] = row.get("shpTelno") or s["tel"]
            s["status"] = row.get("status") or s["status"]
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
