import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Cam alt menüdeki tek öğe.
class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;

  final IconData icon;
  final IconData selectedIcon;
}

/// EmuFit / EmuMini'deki cam alt menünün EmuGider uyarlaması.
///
/// Yatay kapsül biçiminde, arkasını hafif bulanık gösteren koyu sıcak cam
/// yüzey. Seçili sekmenin arkasında ayrı bir cam kapsül durur ve yay
/// fiziğiyle hareket eder. Basılı tutup yatay sürükleyince kapsül parmağı
/// izler, altındaki sekme vurgulanır ve parmak kalkınca o sekme seçilir
/// (EmuFit `LiquidGlassNavScope` ile aynı etkileşim; iOS shader merceği
/// yerine kapsül hafifçe büyüyüp belirginleşir). Parmak çubuğun çok
/// dışında bırakılırsa seçim iptal olur.
class GlassNavBar extends StatefulWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double barHeight = 68;
  static const double barInset = 5;
  static const double sideMargin = 14;
  static const double bottomGap = 6;

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar>
    with SingleTickerProviderStateMixin {
  /// Seçim kapsülünün sekme genişliğine oranı.
  static const double _pillScale = 0.9;

  /// Basılıyken kapsülün yatay büyüme oranı (bardan taşmaz).
  static const double _pressGrow = 0.08;

  /// Çubuğun bu kadar dışında bırakılırsa seçim iptal edilir.
  static const double _cancelSlop = 36;

  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  // Yay fiziği (iç alan koordinatları).
  double _x = 0;
  double _vx = 0;
  double _grow = 0;
  double _vGrow = 0;
  double _targetX = 0;
  double _targetGrow = 0;
  double _itemWidth = 1;
  double _innerWidth = 1;
  Duration _lastTick = Duration.zero;
  bool _positioned = false;

  bool _pressed = false;
  int _visualIndex = 0;

  int get _count => widget.items.length;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _visualIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(GlassNavBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex && !_pressed) {
      _visualIndex = widget.selectedIndex;
      _targetX = _centerOf(widget.selectedIndex);
      _kick();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- geometri

  double _centerOf(int index) => (index + 0.5) * _itemWidth;

  int _indexAt(double x) => (x / _itemWidth).floor().clamp(0, _count - 1);

  void _syncLayout(double innerWidth) {
    _innerWidth = innerWidth;
    final itemWidth = innerWidth / _count;
    if (!_positioned || (itemWidth - _itemWidth).abs() > 0.01) {
      _itemWidth = itemWidth;
      if (!_pressed) {
        _targetX = _centerOf(widget.selectedIndex);
        _x = _targetX;
      }
      _positioned = true;
    }
  }

  double _clampX(double x) {
    final half = _itemWidth * _pillScale * (1 + _pressGrow) / 2;
    return x.clamp(half, math.max(half, _innerWidth - half));
  }

  // ----------------------------------------------------------------- pointer

  void _onDown(PointerDownEvent event) {
    if (_pressed) return;
    _pressed = true;
    _visualIndex = _indexAt(event.localPosition.dx);
    _targetX = _clampX(_centerOf(_visualIndex));
    _targetGrow = 1;
    HapticFeedback.lightImpact();
    setState(() {});
    _kick();
  }

  void _onMove(PointerMoveEvent event) {
    if (!_pressed) return;
    final fingerX = event.localPosition.dx.clamp(0.0, _innerWidth);
    _targetX = _clampX(fingerX);
    final index = _indexAt(fingerX);
    if (index != _visualIndex) {
      _visualIndex = index;
      HapticFeedback.selectionClick();
      setState(() {});
    }
    _kick();
  }

  void _onUp(PointerUpEvent event) {
    if (!_pressed) return;
    _pressed = false;
    final dy = event.localPosition.dy;
    const innerHeight = GlassNavBar.barHeight - GlassNavBar.barInset * 2;
    if (dy < -_cancelSlop || dy > innerHeight + _cancelSlop) {
      _release(widget.selectedIndex);
      return;
    }
    final index = _visualIndex;
    _release(index);
    if (index != widget.selectedIndex) HapticFeedback.selectionClick();
    widget.onSelected(index);
  }

  void _onCancel(PointerCancelEvent event) {
    if (!_pressed) return;
    _pressed = false;
    _release(widget.selectedIndex);
  }

  void _release(int index) {
    _visualIndex = index;
    _targetX = _centerOf(index);
    _targetGrow = 0;
    setState(() {});
    _kick();
  }

  // -------------------------------------------------------------- yay fiziği

  void _kick() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    var dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    dt = dt.clamp(0.0, 1 / 20);

    // Sürüklerken parmağı sıkı izler; bırakınca hafif taşarak oturur.
    final xStiffness = _pressed ? 520.0 : 300.0;
    final xDamping = 2 * math.sqrt(xStiffness) * (_pressed ? 0.86 : 0.62);
    const growStiffness = 340.0;
    final growDamping = 2 * math.sqrt(growStiffness) * 0.6;

    var remaining = dt;
    while (remaining > 0) {
      final step = math.min(remaining, 1 / 120);
      remaining -= step;
      final ax = -xStiffness * (_x - _targetX) - xDamping * _vx;
      _vx += ax * step;
      _x += _vx * step;
      final ag = -growStiffness * (_grow - _targetGrow) - growDamping * _vGrow;
      _vGrow += ag * step;
      _grow += _vGrow * step;
    }

    final settled =
        !_pressed &&
        (_x - _targetX).abs() < 0.05 &&
        _vx.abs() < 0.5 &&
        (_grow - _targetGrow).abs() < 0.002 &&
        _vGrow.abs() < 0.01;
    if (settled) {
      _x = _targetX;
      _vx = 0;
      _grow = _targetGrow;
      _vGrow = 0;
      _ticker.stop();
    }
    _frame.value++;
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(GlassNavBar.barHeight / 2));
    const innerHeight = GlassNavBar.barHeight - GlassNavBar.barInset * 2;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GlassNavBar.sideMargin,
          0,
          GlassNavBar.sideMargin,
          GlassNavBar.bottomGap,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Color(0x2617332D),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99254540), Color(0xB3172C28)],
                  ),
                ),
                child: CustomPaint(
                  foregroundPainter: const _RimPainter(),
                  child: SizedBox(
                    height: GlassNavBar.barHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(GlassNavBar.barInset),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _syncLayout(constraints.maxWidth);
                          return Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: _onDown,
                            onPointerMove: _onMove,
                            onPointerUp: _onUp,
                            onPointerCancel: _onCancel,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: AnimatedBuilder(
                                      animation: _frame,
                                      builder: (context, _) => CustomPaint(
                                        painter: _PillPainter(
                                          centerX: _x,
                                          width:
                                              _itemWidth *
                                              _pillScale *
                                              (1 + _pressGrow * _grow),
                                          height: innerHeight,
                                          grow: _grow.clamp(0.0, 1.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    for (var i = 0; i < _count; i++)
                                      Expanded(
                                        child: _NavItemView(
                                          item: widget.items[i],
                                          selected: i == _visualIndex,
                                          onActivate: () =>
                                              widget.onSelected(i),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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

class _NavItemView extends StatelessWidget {
  const _NavItemView({
    required this.item,
    required this.selected,
    required this.onActivate,
  });

  final GlassNavItem item;
  final bool selected;

  /// Erişilebilirlik (pointer'sız) etkinleştirme; dokunma Listener'da işlenir.
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.7);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      onTap: onActivate,
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.06 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Icon(
              selected ? item.selectedIcon : item.icon,
              size: 25,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: AppText.label.copyWith(
              color: color,
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seçili sekmenin arkasındaki cam kapsül: hafif beyaz dolgu, üstte parlak
/// ince kenar ve çok hafif yeşil ışıma. Basılıyken ([grow]) belirginleşir.
class _PillPainter extends CustomPainter {
  const _PillPainter({
    required this.centerX,
    required this.width,
    required this.height,
    required this.grow,
  });

  final double centerX;
  final double width;
  final double height;
  final double grow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(centerX, size.height / 2),
      width: width,
      height: height,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(height / 2));

    // Yeşil ışıma (kapsülün içinde kalır, bar zaten kırpar).
    canvas.drawRRect(
      rrect.deflate(2),
      Paint()
        ..color = AppColors.green.withValues(alpha: 0.22 + 0.18 * grow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.24 + 0.1 * grow),
            Colors.white.withValues(alpha: 0.08 + 0.06 * grow),
          ],
        ).createShader(rect),
    );

    canvas.drawRRect(
      rrect.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.7),
            AppColors.greenSoft.withValues(alpha: 0.35 + 0.25 * grow),
            Colors.white.withValues(alpha: 0.2),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PillPainter old) =>
      old.centerX != centerX ||
      old.width != width ||
      old.height != height ||
      old.grow != grow;
}

/// Cam çubuğun ince kenarı: üstte parlak, alta doğru söner.
class _RimPainter extends CustomPainter {
  const _RimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(0.5),
        Radius.circular(size.height / 2),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.34),
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.16),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) => false;
}
