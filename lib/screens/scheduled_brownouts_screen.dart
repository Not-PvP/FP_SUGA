import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/widgets/advisory_card.dart';
import 'package:suga/widgets/ui.dart';
import 'package:suga/widgets/upcoming_advisories_widget.dart';

enum _DateRange { any, today, next7, thisMonth, past }

extension on _DateRange {
  String get label => switch (this) {
    _DateRange.any => 'Any time',
    _DateRange.today => 'Today',
    _DateRange.next7 => 'Next 7 days',
    _DateRange.thisMonth => 'This month',
    _DateRange.past => 'Past',
  };
}

class _Filters {
  const _Filters({this.area, this.range = _DateRange.any});

  final String? area;
  final _DateRange range;
}

enum _Scope { myAreas, allAreas }

// Scheduled tab: every upcoming brownout, grouped by day. Signed-in admins can
// also switch to every advisory, with search and filters.
class ScheduledBrownoutsScreen extends StatefulWidget {
  const ScheduledBrownoutsScreen({super.key});

  @override
  State<ScheduledBrownoutsScreen> createState() =>
      _ScheduledBrownoutsScreenState();
}

class _ScheduledBrownoutsScreenState extends State<ScheduledBrownoutsScreen> {
  // Users with saved areas see only those first; they can switch to every area.
  _Scope _scope = _Scope.myAreas;

  // Admin only: also list ongoing, restored, cancelled and past advisories,
  // so they can be opened and updated.
  bool _showAll = false;

  // Search and filters for the All Advisories tab.
  final _search = TextEditingController();
  String? _status; // null = all
  String? _area;
  _DateRange _range = _DateRange.any;
  bool _soonest = true;

  @override
  void initState() {
    super.initState();
    // Load after the first frame, because notifyListeners() must not run during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PowerInterruptionProvider>();
      if (!provider.hasLoaded) provider.loadInterruptions();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---- Filter state helpers ----

  bool get _filtersActive => _area != null || _range != _DateRange.any;

  bool get _anythingActive =>
      _filtersActive || _status != null || _search.text.trim().isNotEmpty;

  void _clearAll() {
    setState(() {
      _search.clear();
      _status = null;
      _area = null;
      _range = _DateRange.any;
    });
  }

  // ---- Helpers for area and feeder lists ----

  static String _nameOf(dynamic e) {
    if (e is String) return e;

    try {
      final name = (e as dynamic).name;
      if (name is String) return name;
    } catch (_) {}

    return e.toString();
  }

  static List<String> _names(dynamic list) {
    if (list is! Iterable) return const [];

    return [
      for (final e in list)
        if (_nameOf(e).trim().isNotEmpty) _nameOf(e).trim(),
    ];
  }

  // ---- Date filtering ----

  bool _inRange(PowerInterruption item) {
    if (_range == _DateRange.any) return true;

    final date = DateTime.tryParse(item.date);
    if (date == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);

    switch (_range) {
      case _DateRange.today:
        return day == today;

      case _DateRange.next7:
        return !day.isBefore(today) &&
            !day.isAfter(today.add(const Duration(days: 7)));

      case _DateRange.thisMonth:
        return day.year == today.year && day.month == today.month;

      case _DateRange.past:
        return day.isBefore(today);

      case _DateRange.any:
        return true;
    }
  }

  // ---- Search, filtering, and sorting ----

  List<PowerInterruption> _apply(List<PowerInterruption> items) {
    final query = _search.text.trim().toLowerCase();

    final result = items.where((item) {
      // Status filter
      if (_status != null && item.status.trim().toLowerCase() != _status) {
        return false;
      }

      // District filter
      if (_area != null && !_names(item.affectedAreas).contains(_area)) {
        return false;
      }

      // Date filter
      if (!_inRange(item)) return false;

      // Search across title, reason, description, areas, and feeders
      if (query.isNotEmpty) {
        final haystack = [
          item.title,
          item.reason,
          item.description,
          ..._names(item.affectedAreas),
          ..._names(item.feeders),
        ].join(' ').toLowerCase();

        if (!haystack.contains(query)) return false;
      }

      return true;
    }).toList();

    // Sort by date and start time.
    String key(PowerInterruption i) => '${i.date} ${i.startTime}';

    if (_soonest) {
      // Upcoming advisories first, nearest first.
      // Past advisories follow, most recent first.
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final upcoming =
          result.where((i) => i.date.compareTo(todayKey) >= 0).toList()
            ..sort((a, b) => key(a).compareTo(key(b)));

      final past = result.where((i) => i.date.compareTo(todayKey) < 0).toList()
        ..sort((a, b) => key(b).compareTo(key(a)));

      return [...upcoming, ...past];
    }

    result.sort((a, b) => key(b).compareTo(key(a)));

    return result;
  }

  // ---- Open district and date filters ----

  Future<void> _openFilters(List<PowerInterruption> items) async {
    final areas = <String>{
      for (final item in items) ..._names(item.affectedAreas),
    }.toList()..sort();

    final result = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111720),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        areas: areas,
        initial: _Filters(area: _area, range: _range),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _area = result.area;
      _range = result.range;
    });
  }

  Widget _buildAdminToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: SegmentedTabs<bool>(
        options: const [(false, 'Upcoming'), (true, 'All advisories')],
        value: _showAll,
        onChanged: (all) => setState(() => _showAll = all),
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _search,
        cursorColor: const Color(0xFFFFBF00),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search feeder, district…',
          hintStyle: const TextStyle(color: Color(0xFF6B7A90), fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFFFFBF00),
            size: 20,
          ),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFFFBF00),
                    size: 18,
                  ),
                  tooltip: 'Clear',
                  onPressed: () => setState(_search.clear),
                ),
          filled: true,
          fillColor: const Color(0xFF111720),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF292F38)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFBF00), width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(List<PowerInterruption> items) {
    return InkWell(
      onTap: () => _openFilters(items),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111720),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _filtersActive
                ? const Color(0xFFFFBF00).withValues(alpha: 0.5)
                : const Color(0xFF292F38),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune_rounded, color: Color(0xFFFFBF00), size: 18),
            const SizedBox(width: 6),
            const Text(
              'Filter',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_filtersActive) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFBF00),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<bool>(
      tooltip: 'Sort by date',
      color: const Color(0xFF111720),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF292F38)),
      ),
      onSelected: (soonest) => setState(() => _soonest = soonest),
      itemBuilder: (_) => [
        for (final entry in const {true: 'Soonest', false: 'Latest'}.entries)
          PopupMenuItem<bool>(
            value: entry.key,
            child: Text(
              entry.value,
              style: TextStyle(
                color: _soonest == entry.key
                    ? const Color(0xFFFFBF00)
                    : Colors.white,
                fontSize: 13,
                fontWeight: _soonest == entry.key
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111720),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF292F38)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              color: Color(0xFFFFBF00),
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              'Date: ',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
            Text(
              _soonest ? 'Soonest' : 'Latest',
              style: const TextStyle(
                color: Color(0xFFFFBF00),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required String? value,
    Color? dot,
  }) {
    final selected = _status == value;
    final statusColor = dot ?? const Color(0xFFFFBF00);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _status = value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? statusColor.withValues(alpha: 0.14)
                : const Color(0xFF111720),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? statusColor : const Color(0xFF292F38),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? statusColor : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(List<PowerInterruption> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSearchField()),
              const SizedBox(width: 8),
              _buildFilterButton(items),
              const SizedBox(width: 8),
              _buildSortButton(),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusChip(label: 'All', value: null),
                _statusChip(
                  label: 'Scheduled',
                  value: 'scheduled',
                  dot: const Color(0xFFFBBF24),
                ),
                _statusChip(
                  label: 'Ongoing',
                  value: 'ongoing',
                  dot: const Color(0xFFF97316),
                ),
                _statusChip(
                  label: 'Restored',
                  value: 'restored',
                  dot: const Color(0xFF34D399),
                ),
                _statusChip(
                  label: 'Cancelled',
                  value: 'cancelled',
                  dot: const Color(0xFFF87171),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllAdvisories(List<PowerInterruption> all) {
    if (all.isEmpty) {
      return const StatePanel(icon: Icons.inbox_outlined, title: 'No advisories yet');
    }

    final items = _apply(all);

    if (items.isEmpty) {
      return StatePanel(
        icon: Icons.search_off_rounded,
        title: 'No advisories match your search',
        message: 'Try a different search or clear the filters.',
        actionLabel: _anythingActive ? 'Clear filters' : null,
        onAction: _anythingActive ? _clearAll : null,
      );
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdvisoryCard(advisory: item, showStatus: true),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PowerInterruptionProvider>();
    final items = provider.allInterruptions;
    final isAdmin = context.watch<AuthProvider>().isSignedIn;
    final showAll = isAdmin && _showAll;
    final followed = {...provider.savedAreaIds, ?provider.selectedAreaId};
    final canFilter = followed.isNotEmpty && !showAll;
    final onlyMine = canFilter && _scope == _Scope.myAreas;

    final Widget body;
    if (items.isEmpty &&
        (provider.isLoading || !provider.hasLoaded) &&
        provider.error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty && provider.error != null) {
      body = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          StatePanel(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load brownouts",
            message: provider.error!,
            actionLabel: 'Retry',
            onAction: provider.loadInterruptions,
          ),
        ],
      );
    } else {
      body = RefreshIndicator(
        onRefresh: provider.loadInterruptions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            showAll
                ? _buildAllAdvisories(items)
                : UpcomingAdvisoriesWidget(
                    areaIds: onlyMine ? followed : null,
                    showHeader: false,
                    groupByDate: true,
                    emptyMessage: onlyMine
                        ? 'Nothing scheduled in your saved areas. Switch to All areas to see the rest of the city.'
                        : null,
                  ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: ScreenHeader(
                    title: 'Scheduled brownouts',
                    subtitle: 'Upcoming power interruptions, soonest first.',
                  ),
                ),
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 20, top: 8),
                    child: OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          AppRoutes.brownoutForm,
                        );

                        if (result == true && context.mounted) {
                          await context
                              .read<PowerInterruptionProvider>()
                              .loadInterruptions();
                        }
                      },
                      child: const Text('+ Add'),
                    ),
                  ),
              ],
            ),
            if (canFilter)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SegmentedTabs<_Scope>(
                  options: const [
                    (_Scope.myAreas, 'My areas'),
                    (_Scope.allAreas, 'All areas'),
                  ],
                  value: _scope,
                  onChanged: (scope) => setState(() => _scope = scope),
                ),
              ),

            // Only signed-in admins see this switch.
            if (isAdmin) _buildAdminToggle(),

            // Search and filters appear only on All Advisories.
            if (showAll) _buildControls(items),

            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

// Bottom sheet for the Filter button.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.areas, required this.initial});

  final List<String> areas;
  final _Filters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _area = widget.initial.area;
  late _DateRange _range = widget.initial.range;

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF292315) : const Color(0xFF070A0F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFFBF00) : const Color(0xFF292F38),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFFFBF00) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter advisories',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _area = null;
                        _range = _DateRange.any;
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF9CA3AF),
                    ),
                    child: const Text('Reset'),
                  ),
                ],
              ),

              _label('DATE'),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final range in _DateRange.values)
                    _pill(
                      range.label,
                      _range == range,
                      () => setState(() => _range = range),
                    ),
                ],
              ),

              _label('DISTRICT'),

              if (widget.areas.isEmpty)
                const Text(
                  'No districts to filter by.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(
                      'All districts',
                      _area == null,
                      () => setState(() => _area = null),
                    ),
                    for (final area in widget.areas)
                      _pill(
                        area,
                        _area == area,
                        () => setState(() => _area = area),
                      ),
                  ],
                ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _Filters(area: _area, range: _range),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFBF00),
                    foregroundColor: const Color(0xFF070A0F),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
