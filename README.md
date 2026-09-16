# 로또 명당 지도 (lotto_map)

전국 로또 6/45 1등·2등 배출 판매점을 지도·랭킹으로 보여주고, 판매점별 메모를 남길 수 있는 앱.
AdMob 광고(배너 / 전면 / 보상형)로 수익화. Flutter 로 작성, Android + iOS 대상.

## 구조

```
lib/
  main.dart                       앱 진입, 테마, AppServices(서비스 묶음)
  ads/ad_ids.dart                 AdMob 광고 단위 ID  ← 출시 전 교체
  ads/ad_manager.dart             전면(상세 3회마다)·보상형 광고 싱글톤
  widgets/banner_ad_widget.dart   하단 적응형 배너
  widgets/store_widgets.dart      당첨 배지, 판매점 타일, 필터 칩
  models/store.dart               Store / Win 모델, 회차→추첨일 계산
  services/store_repository.dart  내장 JSON 로드(isolate) + 동행복권에서 새 회차 자동 갱신·캐시
  services/memo_service.dart      메모·즐겨찾기·평점·방문일·구매/당첨 금액 (SharedPreferences)
  services/lucky_service.dart     행운 번호: 하루 1회 무료 + 보상형 광고 1번당 1회
  services/app_state.dart         1등만/1등 N회 이상/기간 필터, 탭, "지도에서 보기" 요청
  services/map_config.dart        타일 URL·초기 위치 (TILE_URL dart-define 으로 교체 가능)
  screens/home_shell.dart         탭 4개(지도·랭킹·내 메모·행운 번호) + 공통 배너
  screens/map_screen.dart         flutter_map + 격자 클러스터링 + 지역·상호 검색(결과만 표시) + 내 위치 + 마커 바텀시트
  screens/ranking_screen.dart     1등 횟수 랭킹, 검색, 시·도 필터
  screens/memo_list_screen.dart   내 메모 목록: 전체/방문(방문일 기록순)/즐겨찾기 세그먼트, 스와이프 삭제
  screens/store_detail_screen.dart 상세: 정보·길찾기·전화·메모(자동 저장)·당첨 이력
  services/navigation_apps.dart   길찾기 앱 선택(네이버/카카오/T맵/구글/기타), 기본 앱 기억, 미설치 시 웹·스토어 폴백
  screens/lucky_screen.dart       행운 번호 뽑기
  screens/settings_screen.dart    데이터 기준·출처·개인정보처리방침·전체 삭제
assets/data/stores.json           내장 판매점 데이터 (tool/fetch_stores.py 로 생성)
tool/fetch_stores.py              동행복권 당첨 판매점 API 262회~최신 수집 (회차별 캐시, 재실행 시 이어받기)
tool/make_icon.py                 앱 아이콘 생성
tool/make_store_assets.py         스토어 이미지 생성
docs/privacy-policy.html          개인정보처리방침 (GitHub Pages)
store/listing.md                  스토어 등록 문구·설정 값
```

## 데이터

- 현재 내장: 262~1241회 (2026-09-15 수집), 판매점 10,547곳 (1등 배출점 4,589곳, 영업 중 3,267곳), 2.9MB

- 출처: 동행복권 `wnprchsplcsrch/selectLtWnShp.do` (당첨 판매점 조회 화면이 쓰는 JSON, 좌표 포함). 262회부터 데이터가 있다.
- 갱신: `python tool/fetch_stores.py` → `assets/data/stores.json` 재생성 후 앱 업데이트.
  회차별 원본은 `tool/cache/` 에 캐시되어 실패한 회차만 다시 받는다. 사이트가 요청을 막으면(연결 타임아웃) 잠시 후 재실행.
- 앱 실행 시 `StoreRepository.refresh()` 가 내장 데이터 이후 회차(최대 30회)를 받아 앱 문서 폴더에 캐시·병합한다.
  실패해도 내장 데이터로 동작한다.

## 광고 노출 지점

| 위치 | 종류 | 동작 |
|---|---|---|
| 모든 탭 하단·상세 하단 | 배너 | 항상 표시 |
| 판매점 상세 진입 | 전면 | 3번째 진입마다 (`AdManager.interstitialEvery`) |
| 행운 번호 탭 | 보상형 | 무료 1회 소진 후 버튼 누르면 팝업 없이 바로 광고 → 광고 1번 = 뽑기 1번 (자동 뽑기) |

## 개발 빌드

```bash
flutter pub get
flutter build apk --debug
```

에뮬레이터: `flutter emulators --launch Small_Phone_API_35` 후 `flutter run`.

### 이 PC 전용 메모
Java 의 AF_UNIX 소켓이 `%TEMP%` 아래에서 실패해 Gradle 이 "Unable to establish loopback connection" 으로
죽는 문제가 있어, `android/gradle.properties` 와 `android/gradlew.bat` 에
`-Djdk.net.unixdomain.tmpdir=C:/tmp` 를 넣어 두었다. `C:\tmp` 폴더가 있어야 한다.

## 지도 타일

배경지도는 **브이월드(VWorld, 국토교통부) WMTS** 를 쓴다. 인증키는 코드에 넣지 않고 빌드 옵션(`--dart-define=TILE_URL=...`)으로
주입하며, 키가 들어 있는 `build_release.bat` 은 git 에서 제외되어 있다.

```bat
build_release.bat appbundle     REM → build/app/outputs/bundle/release/app-release.aab
build_release.bat apk           REM → 에뮬레이터 확인용
```

- 키 관리: https://www.vworld.kr/mypo/mypo_apiKey_s001.do (브이월드 로그인 필요). 키를 바꾸면 `build_release.bat` 의 `TILE_URL` 만 수정.
- 키 없이 `flutter build` 만 하면 OpenStreetMap 공개 타일로 폴백된다 (개발용. 대량 배포에는 OSM 정책상 부적합).
- 브이월드 약관: 결과물에 브이월드 사용 표기 필요(지도 하단·설정 화면에 표기함). 상업적 이용은 별도 허락 대상이므로
  트래픽이 커지면 고객센터(1661-0115)에 문의. 현재 키는 개발키이며 운영키는 별도 심사 신청.

## 출시 체크리스트

### 1. AdMob
- [x] AdMob 앱 등록 (Android) — 앱 ID `ca-app-pub-7493209423244427~5490888953`
- [x] 광고 단위 3개: 배너 `/8301332239`, 전면 `/3223818263`, 보상형 `/6988250561`
- [x] `lib/ads/ad_ids.dart`, `AndroidManifest.xml` 에 실제 ID 적용 (디버그 빌드는 여전히 테스트 ID)
- [ ] AdMob 에서 앱을 Play 스토어와 연결 (앱 게시 후 "앱 → 스토어 추가") → 광고 게재 검토 완료까지 며칠
- [ ] 실제 ID 로 나가는 릴리즈 빌드에서 광고 클릭 금지 (계정 정지 사유). 내부 테스트 빌드도 실제 ID 임
- [ ] AdMob 결제·세금 정보는 daily_fortune 과 같은 계정이므로 추가 작업 없음

### 2. 개인정보 / 정책
- [x] 개인정보처리방침: https://junshiva5732.github.io/lotto_map/privacy-policy.html (원본 `docs/privacy-policy.html`)
- [ ] iOS: ATT 팝업 — iOS 출시 시 `app_tracking_transparency` 로 요청
- [ ] EU 대상이면 UMP(동의 메시지) 설정

### 3. Android 출시
- [x] 릴리즈 서명 키: `android/upload-keystore.jks` + `android/key.properties` (daily_fortune 과 같은 업로드 키 재사용, git 제외 — **반드시 백업**)
- [x] 앱 아이콘: `tool/make_icon.py` → `dart run flutter_launcher_icons`
- [x] 위치 권한: 선택 사용. Play 데이터 보안 양식 작성 시 `store/listing.md` 참고
- [x] 지도 타일: 브이월드 키 적용 (`build_release.bat`)
- [x] `build_release.bat appbundle` → `build/app/outputs/bundle/release/app-release.aab` (업로드는 Play Console 에서)
- [x] 스토어 등록 정보: `store/listing.md`, `store/icon-512.png`, `store/feature-graphic.png`, `store/screenshots/01~06.png`

### 4. iOS 출시 (Mac 필요)
- [ ] Apple Developer Program, Xcode 팀 설정, `pod install`
- [x] `ios/Runner/Info.plist` 에 `NSLocationWhenInUseUsageDescription`, `GADApplicationIdentifier`(테스트 ID) 추가 — 실제 ID 로 교체 필요
- [ ] `flutter build ipa` → App Store Connect

### 5. 출시 후
- [ ] 매주 토요일 추첨 후 앱이 자동 갱신하지만, 몇 달에 한 번 `tool/fetch_stores.py` 로 내장 데이터를 갱신해 업데이트
- [ ] 동행복권 사이트 구조가 바뀌면 `StoreRepository._fetchRound` 와 `tool/fetch_stores.py` 수정
