import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/navigation/main_shell.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text.dart';
import '../../core/models/expense.dart';
import '../../core/utils/day.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../history/month_calendar.dart';
import '../shared/expense_list.dart';
import '../shared/quick_entry_card.dart';

/// Geçmiş güne harcama ekleme: üstte takvim, altta giriş satırı. Yazılan
/// her satır ("taksi 260") seçili güne eklenir. Varsayılan gün dündür;
/// gelecek günler seçilemez.
class AddPastScreen extends StatefulWidget {
  const AddPastScreen({super.key});

  @override
  State<AddPastScreen> createState() => _AddPastScreenState();
}

class _AddPastScreenState extends State<AddPastScreen> {
  late AppState _state;
  late DateTime _today;
  late DateTime _month; // ayın 1'i
  late DateTime _selected;
  int _seenRevision = -1;

  Map<int, int> _totals = const {};
  List<Expense> _dayExpenses = const [];
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.of(context).state;
    if (_seenRevision == -1) {
      _today = Day.startOf(_state.now);
      _selected = DateTime(_today.year, _today.month, _today.day - 1);
      _month = DateTime(_selected.year, _selected.month);
    }
    if (_seenRevision != _state.revision) {
      _seenRevision = _state.revision;
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final totals = await _state.monthTotals(_month.year, _month.month);
    final expenses = await _state.expensesOn(_selected);
    if (!mounted || request != _request) return;
    setState(() {
      _totals = totals;
      _dayExpenses = expenses;
    });
  }

  void _changeMonth(int delta) {
    final month = DateTime(_month.year, _month.month + delta);
    final lastOfMonth = DateTime(
      month.year,
      month.month,
      Day.daysInMonth(month.year, month.month),
    );
    setState(() {
      _month = month;
      // Ay değişince ayın son günü (bugünü geçmeyecek şekilde) seçilir.
      _selected = lastOfMonth.isAfter(_today) ? _today : lastOfMonth;
    });
    _load();
  }

  void _selectDay(int day) {
    setState(() => _selected = DateTime(_month.year, _month.month, day));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final dayTotal = _dayExpenses.fold(0, (a, e) => a + e.amountKurus);
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: ScreenHeader(title: 'Geçmiş güne ekle'),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.gutter,
                    4,
                    AppDimens.gutter,
                    MainShell.bottomInset(context),
                  ),
                  children: [
                    MonthCalendar(
                      month: _month,
                      today: _today,
                      selectedDay: _selected.day,
                      totals: _totals,
                      lastDay: _today,
                      onPrevious: () => _changeMonth(-1),
                      onNext: () => _changeMonth(1),
                      onSelect: _selectDay,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: Day.long(_selected),
                              style: AppText.heading,
                            ),
                            const TextSpan(text: ' gününe ekle'),
                          ],
                        ),
                        style: AppText.body,
                      ),
                    ),
                    QuickEntryCard(day: _selected),
                    SectionTitle(
                      'Bu güne eklenenler',
                      trailing: dayTotal > 0
                          ? Text(Money.format(dayTotal), style: AppText.heading)
                          : null,
                    ),
                    ExpenseList(
                      expenses: _dayExpenses,
                      emptyText: 'Bu güne henüz harcama yazılmamış.',
                      onChanged: _load,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
