import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/splash/emugider_intro.dart';
import '../features/splash/logo_arc_path.g.dart';
import 'app_scope.dart';
import 'app_state.dart';
import 'navigation/main_shell.dart';
import 'theme/app_theme.dart';

class EmuGiderApp extends StatelessWidget {
  const EmuGiderApp({super.key, required this.state, this.showIntro = false});

  final AppState state;

  /// Açılış logo animasyonu (uygulamada açık; testlerde kapalı).
  final bool showIntro;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'EmuGider',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) {
          // Çok büyük yazı ölçeği düzeni bozmasın; erişilebilirlik korunur.
          final media = MediaQuery.of(context);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.overlayStyle,
            child: MediaQuery(
              data: media.copyWith(
                textScaler: media.textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.3,
                ),
              ),
              child: child!,
            ),
          );
        },
        home: showIntro
            ? const EmuGiderIntro(child: AppRoot())
            : const AppRoot(),
      ),
    );
  }
}

/// Veriler yüklenene kadar sade bir zemin, ardından ana iskelet.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context).state;
    final Widget page = state.isLoaded ? const MainShell() : const _Splash();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
    );
  }
}

/// Açılış animasyonunun son karesiyle aynı: veriler yüklenirken geçişte
/// sıçrama olmaz.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: logoSplashBackground,
      child: Center(
        child: EmuGiderLogoMark(
          width: introLogoWidth(MediaQuery.sizeOf(context)),
        ),
      ),
    );
  }
}
