import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/navigation/main_shell.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text.dart';
import '../../core/models/expense.dart';
import '../../core/utils/day.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../shared/expense_list.dart';
import 'month_calendar.dart';

/// Geçmiş: ayın toplamı, her günün altında o gün harcanan tutarı gösteren
/// takvim ve seçili günün harcamaları.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late AppState _state;
  late DateTime _month; // ayın 1'i
  late DateTime _selected;
  int _seenRevision = -1;

  Map<int, int> _totals = const {};
  List<Expense> _dayExpenses = const [];
  List<({String name, int totalKurus, int count})> _top = const [];
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.of(context).state;
    if (_seenRevision == -1) {
      _selected = Day.startOf(_state.now);
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
    final top = await _state.monthTop(_month.year, _month.month);
    if (!mounted || request != _request) return;
    setState(() {
      _totals = totals;
      _dayExpenses = expenses;
      _top = top;
    });
  }

  void _changeMonth(int delta) {
    final month = DateTime(_month.year, _month.month + delta);
    final today = Day.startOf(_state.now);
    setState(() {
      _month = month;
      _selected = (month.year == today.year && month.month == today.month)
          ? today
          : month;
    });
    _load();
  }

  void _selectDay(int day) {
    setState(() => _selected = DateTime(_month.year, _month.month, day));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final monthTotal = _totals.values.fold(0, (a, b) => a + b);
    final spentDays = _totals.values.where((v) => v > 0).length;
    final dayTotal = _dayExpenses.fold(0, (a, e) => a + e.amountKurus);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppDimens.gutter,
            24,
            AppDimens.gutter,
            MainShell.bottomInset(context),
          ),
          children: [
            TotalCard(
              label: '${Day.months[_month.month - 1]} toplam',
              amount: Money.format(monthTotal),
              caption: spentDays == 0
                  ? 'Bu ayda harcama yazılmamış.'
                  : '$spentDays günde harcama yazdın.',
            ),
            const SizedBox(height: 14),
            MonthCalendar(
              month: _month,
              today: Day.startOf(_state.now),
              selectedDay: _selected.day,
              totals: _totals,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
              onSelect: _selectDay,
            ),
            SectionTitle(
              Day.long(_selected),
              trailing: dayTotal > 0
                  ? Text(Money.format(dayTotal), style: AppText.heading)
                  : null,
            ),
            ExpenseList(
              expenses: _dayExpenses,
              emptyText: 'Bu güne harcama yazılmamış.',
              onChanged: _load,
            ),
            if (_top.isNotEmpty) ...[
              SectionTitle('${Day.months[_month.month - 1]} ayında en çok'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (var i = 0; i < _top.length; i++)
                      Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        decoration: BoxDecoration(
                          border: i < _top.length - 1
                              ? const Border(
                                  bottom: BorderSide(color: AppColors.divider),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _top[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.subheading.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('${_top[i].count} kez', style: AppText.small),
                            const SizedBox(width: 12),
                            Text(
                              Money.format(_top[i].totalKurus),
                              style: AppText.bodyStrong,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
