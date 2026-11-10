import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/history/history_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/today/today_screen.dart';
import '../app_scope.dart';
import 'app_nav_bar.dart';

enum AppTab {
  today('Özet', Icons.home_outlined, Icons.home_rounded),
  history(
    'Geçmiş',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
  ),
  settings('Ayarlar', Icons.tune_outlined, Icons.tune_rounded);

  const AppTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Üç sekmeli ana iskelet. Her sekmenin kendi Navigator'ı vardır; detay
/// ekranları alt menü görünür kalacak şekilde sekme içinde açılır.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Kaydırılabilir içeriğin alt menünün altında kalmaması için alt boşluk.
  static double bottomInset(BuildContext context) =>
      AppNavBar.barHeight + MediaQuery.paddingOf(context).bottom + 20;

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> with WidgetsBindingObserver {
  AppTab _current = AppTab.today;
  final Map<AppTab, GlobalKey<NavigatorState>> _navigators = {
    for (final tab in AppTab.values) tab: GlobalKey<NavigatorState>(),
  };
  final Set<AppTab> _visited = {AppTab.today};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppScope.read(context).state.refreshIfDayChanged();
    }
  }

  void selectTab(AppTab tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (tab == _current) {
      _navigators[tab]!.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _current = tab;
      _visited.add(tab);
    });
  }

  Widget _rootFor(AppTab tab) => switch (tab) {
    AppTab.today => const TodayScreen(),
    AppTab.history => const HistoryScreen(),
    AppTab.settings => const SettingsScreen(),
  };

  void _handleBack() {
    final navigator = _navigators[_current]!.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else if (_current != AppTab.today) {
      selectTab(AppTab.today);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _current.index,
          children: [
            for (final tab in AppTab.values)
              _visited.contains(tab)
                  ? TickerMode(
                      enabled: tab == _current,
                      child: Navigator(
                        key: _navigators[tab],
                        onGenerateRoute: (settings) => MaterialPageRoute(
                          settings: settings,
                          builder: (_) => _rootFor(tab),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: AppNavBar(
          items: [
            for (final tab in AppTab.values)
              AppNavItem(
                label: tab.label,
                icon: tab.icon,
                selectedIcon: tab.selectedIcon,
              ),
          ],
          selectedIndex: _current.index,
          onSelected: (index) => selectTab(AppTab.values[index]),
        ),
      ),
    );
  }
}
