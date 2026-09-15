import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// 전면·보상형 광고를 미리 로드해 두고 필요할 때 보여주는 싱글톤.
///
/// 배너는 화면마다 붙어야 하므로 [BannerAdWidget] 에서 개별 관리한다.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  /// 전면 광고 노출 빈도: 판매점 상세를 이만큼 열 때마다 1회.
  static const interstitialEvery = 3;
  int _detailOpens = 0;

  Future<void> init() async {
    await MobileAds.instance.initialize();
    loadInterstitial();
    loadRewarded();
  }

  // ---------------------------------------------------------------- 전면 광고

  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial load failed: $err');
          _interstitial = null;
        },
      ),
    );
  }

  /// 판매점 상세 진입 시 호출. N번째마다 전면 광고를 보여준 뒤 [onDone].
  void onOpenDetailThen(VoidCallback onDone) {
    _detailOpens++;
    if (_detailOpens % interstitialEvery != 0) {
      onDone();
      return;
    }
    showInterstitialThen(onDone);
  }

  /// 로드된 전면 광고가 있으면 보여주고, 닫힌 뒤 [onDone] 을 호출한다.
  /// 아직 로드되지 않았으면 광고 없이 바로 [onDone].
  void showInterstitialThen(VoidCallback onDone) {
    final ad = _interstitial;
    if (ad == null) {
      loadInterstitial(); // 다음 기회를 위해 다시 시도
      onDone();
      return;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadInterstitial();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        loadInterstitial();
        onDone();
      },
    );
    ad.show();
  }

  // ---------------------------------------------------------------- 보상형 광고

  bool get isRewardedReady => _rewarded != null;

  void loadRewarded() {
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (err) {
          debugPrint('Rewarded load failed: $err');
          _rewarded = null;
        },
      ),
    );
  }

  /// 보상형 광고를 보여주고, 끝까지 봤으면 [onReward] 를 호출한다.
  /// 광고가 준비되지 않았으면 false 를 반환한다 (호출 측에서 안내).
  bool showRewarded({required VoidCallback onReward}) {
    final ad = _rewarded;
    if (ad == null) {
      loadRewarded();
      return false;
    }
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, _) => onReward());
    return true;
  }
}
