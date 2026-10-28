import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Figma 0 시작 화면 (846:2), 393 × 852 기준.
class AppStartScreen extends StatelessWidget {
  const AppStartScreen({super.key});
  static const background = Color(0xFFFAFAF8);
  static const logo = 'assets/branding/movid-start.png';
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: background,
    ),
    child: Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: false,
      body: Semantics(
        label: 'MOVID 시작 화면',
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              key: const Key('start-canvas'),
              width: 393,
              height: 852,
              child: Stack(
                children: [
                  Positioned(
                    left: 81,
                    top: 238,
                    width: 230,
                    height: 230,
                    child: Image.asset(
                      logo,
                      key: const Key('start-logo'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const Positioned(left: 153, top: 705, child: MovidWordmark()),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 네이티브 시작 리소스도 이 글꼴·배치로 생성한다.
class MovidWordmark extends StatelessWidget {
  const MovidWordmark({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    key: Key('start-wordmark'),
    width: 93,
    height: 39,
    child: Text(
      'MOVID',
      maxLines: 1,
      softWrap: false,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        inherit: false,
        fontWeight: FontWeight.w400,
        textBaseline: TextBaseline.alphabetic,
        decoration: TextDecoration.none,
        fontFamily: 'CapstoneUIMedium',
        fontSize: 30,
        height: 1.3,
        letterSpacing: -.7,
        color: Color(0xFF3C64FD),
      ),
    ),
  );
}
