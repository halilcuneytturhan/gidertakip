import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logo_arc_path.g.dart';

/// Açılış logosunun katmanları (tool/brand/build_intro_layers.py üretir).
abstract final class LogoLayers {
  static const String emu = 'assets/images/brand/splash/emu.webp';
  static const String arc = 'assets/images/brand/splash/arc.webp';
  static const String gider = 'assets/images/brand/splash/gider.webp';
  static const List<String> all = [emu, arc, gider];
}

/// Üç boyutlu "EMU Gider" logosu (durağan).
class EmuGiderLogoMark extends StatelessWidget {
  const EmuGiderLogoMark({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'EmuGider',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: width / logoCanvasAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [for (final layer in LogoLayers.all) _layer(layer)],
        ),
      ),
    );
  }
}

Widget _layer(String asset) => Image.asset(
  asset,
  fit: BoxFit.fill,
  filterQuality: FilterQuality.medium,
  gaplessPlayback: true,
);

/// Açılış ekranının logo genişliği.
double introLogoWidth(Size screen) => (screen.width * 0.66).clamp(190, 290);

/// EMU ailesinin açılış dili (EmuFit, EmuMini, EmuEzan, EmuBoykot ile aynı
/// sıra): koyu zeminde önce "EMU" harfleri soldan sağa belirir, ardından
/// yeşil yay çizilir, en son "Gider" yükselerek gelir. Altında EmuEzan'daki
/// gibi ince bir yükleme çubuğu dolar. Bitince [child] yumuşak geçişle
/// görünür. Hareket azaltma açıksa logo durağan gösterilir.
///
/// [child] animasyon bitene kadar kurulmaz; veri yükleme bundan etkilenmez.
class EmuGiderIntro extends StatefulWidget {
  const EmuGiderIntro({super.key, required this.child});

  final Widget child;

  static const Duration animationDuration = Duration(milliseconds: 2600);
  static const Duration holdDuration = Duration(milliseconds: 250);
  static const Duration fadeDuration = Duration(milliseconds: 300);

  @override
  State<EmuGiderIntro> createState() => _EmuGiderIntroState();
}

class _EmuGiderIntroState extends State<EmuGiderIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: EmuGiderIntro.animationDuration,
  );

  bool _started = false;
  bool _finishing = false;
  bool _finished = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _timer = Timer(const Duration(milliseconds: 600), _finish);
      return;
    }
    _start();
  }

  Future<void> _start() async {
    // Katmanlar çözülmeden animasyon başlamaz (en fazla 700 ms beklenir).
    await Future.wait([
      for (final asset in LogoLayers.all)
        precacheImage(AssetImage(asset), context, onError: (_, _) {}),
    ]).timeout(const Duration(milliseconds: 700), onTimeout: () => []);
    if (!mounted) return;
    await _controller.forward();
    if (!mounted) return;
    _timer = Timer(EmuGiderIntro.holdDuration, _finish);
  }

  void _finish() {
    if (_finishing || !mounted) return;
    setState(() => _finishing = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_finishing) widget.child,
        if (!_finished)
          IgnorePointer(
            ignoring: _finishing,
            child: AnimatedOpacity(
              key: const ValueKey('emugider-intro'),
              opacity: _finishing ? 0 : 1,
              duration: EmuGiderIntro.fadeDuration,
              curve: Curves.easeOut,
              onEnd: () {
                if (_finishing && mounted) setState(() => _finished = true);
              },
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.transparent,
                ),
                child: ColoredBox(
                  color: logoSplashBackground,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnimatedLogo(
                          animation: _controller,
                          width: introLogoWidth(MediaQuery.sizeOf(context)),
                        ),
                        const SizedBox(height: 28),
                        _ProgressBar(
                          animation: _controller,
                          width:
                              introLogoWidth(MediaQuery.sizeOf(context)) * 0.5,
                          done: _finishing,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedLogo extends AnimatedWidget {
  const _AnimatedLogo({
    required Animation<double> animation,
    required this.width,
  }) : super(listenable: animation);

  final double width;

  // Zaman çizelgesi (0..1): EMU yazısı, yay, Gider.
  static const _emu = Interval(0.04, 0.42, curve: Curves.easeOutCubic);
  static const _arc = Interval(0.38, 0.78, curve: Curves.easeInOutCubic);
  static const _word = Interval(0.72, 0.96, curve: Curves.easeOutBack);
  static const _wordFade = Interval(0.72, 0.9, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final emu = _emu.transform(t);
    final arc = _arc.transform(t);
    final word = _word.transform(t);
    final wordFade = _wordFade.transform(t);

    return Semantics(
      label: 'EmuGider',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: width / logoCanvasAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // EMU: soldan sağa yumuşak kenarlı açılma.
            if (emu > 0)
              Opacity(
                opacity: (0.35 + emu * 0.65).clamp(0, 1),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    colors: const [Colors.white, Colors.transparent],
                    stops: [
                      (emu * 1.25 - 0.25).clamp(0.0, 1.0),
                      (emu * 1.25).clamp(0.0, 1.0),
                    ],
                  ).createShader(rect),
                  child: _layer(LogoLayers.emu),
                ),
              ),
            // Yay: orta çizgisi boyunca kalemle çiziliyormuş gibi.
            if (arc > 0)
              ClipPath(
                clipper: _ArcRevealClipper(arc),
                child: _layer(LogoLayers.arc),
              ),
            // Gider: hafifçe yükselerek belirir.
            if (wordFade > 0)
              Opacity(
                opacity: wordFade,
                child: Transform.translate(
                  offset: Offset(0, (1 - word) * width * 0.035),
                  child: Transform.scale(
                    scale: 0.94 + 0.06 * word,
                    alignment: const Alignment(0, 0.75),
                    child: _layer(LogoLayers.gider),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Yayın orta çizgisi boyunca [progress] kadar ilerlemiş kalın bir kalem
/// izi. Gölgeyi de kapsaması için iz, yay kalınlığından geniştir.
class _ArcRevealClipper extends CustomClipper<Path> {
  const _ArcRevealClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    if (progress >= 1) return Path()..addRect(Offset.zero & size);
    final points = logoArcCenterline;
    final radius = logoArcStrokeRadius * size.width * 2.6;
    final path = Path();
    final end = progress * (points.length - 1);
    void dot(Offset p) => path.addOval(
      Rect.fromCircle(
        center: Offset(p.dx * size.width, p.dy * size.height),
        radius: radius,
      ),
    );
    for (var i = 0; i <= end.floor(); i++) {
      dot(points[i]);
      if (i + 1 < points.length) {
        // Noktalar arasında boşluk kalmasın.
        dot(Offset.lerp(points[i], points[i + 1], 0.5)!);
      }
    }
    final i = end.floor();
    if (i + 1 < points.length) {
      dot(Offset.lerp(points[i], points[i + 1], end - i)!);
    }
    return path;
  }

  @override
  bool shouldReclip(_ArcRevealClipper old) => old.progress != progress;
}

/// İnce yükleme çubuğu (EmuEzan ile aynı): animasyonla dolar, açılış
/// biterken tamamlanır.
class _ProgressBar extends AnimatedWidget {
  const _ProgressBar({
    required Animation<double> animation,
    required this.width,
    required this.done,
  }) : super(listenable: animation);

  final double width;
  final bool done;

  @override
  Widget build(BuildContext context) {
    const height = 3.0;
    final t = (listenable as Animation<double>).value;
    final value = done ? 1.0 : Curves.easeOutCubic.transform(t) * 0.92;
    return Semantics(
      label: 'Yükleniyor',
      value: '${(value * 100).round()}%',
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: ColoredBox(
            color: Colors.white.withValues(alpha: 0.12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                heightFactor: 1,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF148C75), Color(0xFF8CE6CF)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
