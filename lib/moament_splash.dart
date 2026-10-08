import 'package:flutter/material.dart';

/// 앱 시작 시 회사 로고(모아먼트)를 잠깐 보여 주는 오버레이.
/// MaterialApp(builder: (context, child) => MoamentSplash(child: child!)) 로 감싼다.
/// 로고가 떠 있는 동안에도 아래 앱은 미리 초기화된다.
class MoamentSplash extends StatefulWidget {
  const MoamentSplash({super.key, required this.child});

  final Widget child;

  static const background = Color(0xFFEDF3F6);

  @override
  State<MoamentSplash> createState() => _MoamentSplashState();
}

class _MoamentSplashState extends State<MoamentSplash> {
  bool _fading = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _fading = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedOpacity(
          opacity: _fading ? 0 : 1,
          duration: const Duration(milliseconds: 400),
          onEnd: () => setState(() => _done = true),
          child: ColoredBox(
            color: MoamentSplash.background,
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.62,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Image.asset('assets/brand/moament_logo.png', fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
