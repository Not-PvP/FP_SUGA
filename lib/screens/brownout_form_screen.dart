import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/area.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/services/area_service.dart';

const _amber = Color(0xFFFFBF00);
const _background = Color(0xFF070A0F);
const _card = Color(0xFF111720);
const _border = Color(0xFF292F38);
const _secondary = Color(0xFF9CA3AF);
const _danger = Color(0xFFF87171);

InputDecoration _fieldDecoration({
  required String label,
  String? hint,
  String? errorText,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: null,
    hintText: hint,
    errorText: errorText,
    hintStyle: const TextStyle(color: Color(0xFF6B7A90), fontSize: 14),
    errorStyle: const TextStyle(color: _danger, fontSize: 12),
    errorMaxLines: 3,
    filled: true,
    fillColor: _card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(_border),
    enabledBorder: border(_border),
    focusedBorder: border(_amber, 1.2),
    errorBorder: border(_danger),
    focusedErrorBorder: border(_danger, 1.2),
  );
}

// Admin only. Used for both "New Advisory" (no route argument) and
// "Edit Advisory" (the PowerInterruption to edit as the route argument).
//
// Pops with `true` after a save and with `'deleted'` after a delete, so the screen
// that opened it can react.
class BrownoutFormScreen extends StatefulWidget {
  const BrownoutFormScreen({super.key, this.areaService});

  final AreaService? areaService;

  @override
  State<BrownoutFormScreen> createState() => _BrownoutFormScreenState();
}

class _BrownoutFormScreenState extends State<BrownoutFormScreen> {
  static const _statuses = ['scheduled', 'ongoing', 'restored', 'cancelled'];

  late final AreaService _areaService = widget.areaService ?? AreaService();
  late Future<List<Area>> _areas;

  final _title = TextEditingController();
  final _reason = TextEditingController();
  final _description = TextEditingController();

  PowerInterruption? _editing;
  bool _initialized = false;

  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  TimeOfDay? _restoration;
  String _status = 'scheduled';
  Set<int> _areaIds = {};
  Set<int> _feederIds = {};

  // Checked on this device before sending, and sent back by the API after a rejection.
  // Both are keyed by the API's field names, e.g. 'start_time'.
  Map<String, String> _localErrors = const {};
  Map<String, String> _serverErrors = const {};

  @override
  void initState() {
    super.initState();
    _areas = _areaService.fetchAreas();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final argument = ModalRoute.of(context)?.settings.arguments;
    if (argument is PowerInterruption) {
      _editing = argument;
      _fill(argument);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  void _fill(PowerInterruption item) {
    _title.text = item.title;
    _reason.text = item.reason;
    _description.text = item.description;
    _date = DateTime.tryParse(item.date);
    _start = _parseTime(item.startTime);
    _end = _parseTime(item.endTime);
    _restoration = _parseTime(item.estimatedRestorationTime);
    final status = item.status.trim().toLowerCase();
    _status = status.isEmpty ? 'scheduled' : status;
    _areaIds = {...item.areaIds};
    _feederIds = {...item.feederIds};
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _hhmm(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  static int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  String? _errorFor(String key) => _localErrors[key] ?? _serverErrors[key];

  // Call inside setState.
  void _clearError(String key) {
    if (_localErrors.containsKey(key))
      _localErrors = {..._localErrors}..remove(key);
    if (_serverErrors.containsKey(key))
      _serverErrors = {..._serverErrors}..remove(key);
  }

  Widget _pickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: _amber,
          onPrimary: Colors.black,
          secondary: _amber,
          onSecondary: Colors.black,
          secondaryContainer: Color(0xFF1F2937),
          onSecondaryContainer: Colors.white,
          surface: _card,
          onSurface: Colors.white,
        ),
        timePickerTheme: const TimePickerThemeData(
          backgroundColor: _card,
          dialHandColor: _amber,
          dialBackgroundColor: Color(0xFF1F2937),
          hourMinuteColor: Color(0xFF1F2937),
          hourMinuteTextColor: Colors.white,

          dayPeriodColor: _amber,
          dayPeriodTextColor: Colors.white,
          dayPeriodBorderSide: BorderSide.none,

          entryModeIconColor: _amber,
        ),
      ),
      child: child!,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _date ?? today;
    final first = DateTime(today.year - 2);
    final last = DateTime(today.year + 3, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: initial.isAfter(last) ? initial : last,
      builder: _pickerTheme,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _clearError('date');
    });
  }

  Future<void> _pickTime(
    TimeOfDay? current,
    String errorKey,
    ValueChanged<TimeOfDay> assign,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 9, minute: 0),
      builder: _pickerTheme,
    );
    if (picked == null || !mounted) return;
    setState(() {
      assign(picked);
      _clearError(errorKey);
      if (errorKey == 'start_time') _clearError('end_time');
    });
  }

  Future<void> _selectAreas(List<Area> areas) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AreaPickerSheet(areas: areas, selected: _areaIds),
    );

    if (result == null || !mounted) return;

    // Keep only feeders that belong to the newly selected areas.
    final availableFeederIds = areas
        .where((area) => result.contains(area.id))
        .expand((area) => area.feeders)
        .map((feeder) => feeder.id)
        .toSet();

    setState(() {
      _areaIds = result;
      _feederIds = _feederIds.intersection(availableFeederIds);
      _clearError('area_ids');
    });
  }

  Future<void> _selectFeeders(List<Feeder> feeders) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _FeederPickerSheet(feeders: feeders, selected: _feederIds),
    );

    if (result == null || !mounted) return;

    setState(() {
      _feederIds = result;
    });
  }

  void _reloadAreas() {
    setState(() => _areas = _areaService.fetchAreas());
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_title.text.trim().isEmpty) errors['title'] = 'Enter a title.';
    if (_date == null) errors['date'] = 'Pick the date.';
    if (_start == null) errors['start_time'] = 'Pick a start time.';
    final start = _start;
    final end = _end;
    if (end == null) {
      errors['end_time'] = 'Pick an end time.';
    } else if (start != null && _minutes(end) <= _minutes(start)) {
      errors['end_time'] = 'End time must be later than the start time.';
    }
    if (_areaIds.isEmpty)
      errors['area_ids'] = 'Select at least one affected area.';
    return errors;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final errors = _validate();
    setState(() {
      _localErrors = errors;
      _serverErrors = const {};
    });
    if (errors.isNotEmpty) return;

    final provider = context.read<PowerInterruptionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final existing = _editing;

    // Built from scratch (not copyWith) so a cleared restoration time is really cleared.
    // Feeders are carried over from the advisory being edited, so saving does not wipe them.
    final item = PowerInterruption(
      id: existing?.id ?? '',
      title: _title.text.trim(),
      description: _description.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(_date!),
      startTime: _hhmm(_start!),
      endTime: _hhmm(_end!),
      affectedAreas: existing?.affectedAreas ?? const [],
      reason: _reason.text.trim(),
      status: _status,
      estimatedRestorationTime: _restoration == null
          ? null
          : _hhmm(_restoration!),
      areaIds: _areaIds.toList()..sort(),
      feeders: existing?.feeders ?? const [],
      feederIds: _feederIds.toList()..sort(),
    );

    final ok = existing == null
        ? await provider.addInterruption(item)
        : await provider.updateInterruption(item);
    if (!mounted) return;

    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Advisory created.' : 'Advisory updated.',
          ),
        ),
      );
      // Pull the server's copy so area names, feeders and timestamps are up to date.
      unawaited(provider.loadInterruptions());
      navigator.pop(true);
    } else {
      setState(() => _serverErrors = provider.fieldErrors);
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.actionError ?? 'Could not save the advisory.'),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final existing = _editing;
    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _border),
        ),
        title: const Text(
          'Delete this advisory?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '"${existing.title}" will be removed for everyone. This cannot be undone.',
          style: const TextStyle(
            color: _secondary,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: _secondary),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<PowerInterruptionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final ok = await provider.deleteInterruption(existing.id);
    if (!mounted) return;

    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Advisory deleted.')),
      );
      unawaited(provider.loadInterruptions());
      navigator.pop('deleted');
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.actionError ?? 'Could not delete the advisory.',
          ),
        ),
      );
    }
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    String? errorKey,
    String? hint,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          cursorColor: _amber,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _fieldDecoration(
            label: '',
            hint: hint,
            errorText: errorKey == null ? null : _errorFor(errorKey),
          ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.never),
          onChanged: (_) {
            if (errorKey != null && _errorFor(errorKey) != null) {
              setState(() => _clearError(errorKey));
            }
          },
        ),
      ],
    );
  }

  Widget _pickerField({
    required String label,
    required String placeholder,
    required IconData icon,
    required VoidCallback? onTap,
    String? value,
    String? errorText,
    VoidCallback? onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: _fieldDecoration(label: '', errorText: errorText)
                .copyWith(
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  suffixIcon: value != null && onClear != null
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: _secondary,
                          ),
                          tooltip: 'Clear',
                          onPressed: onClear,
                        )
                      : Icon(icon, size: 18, color: _secondary),
                ),
            child: Text(
              value ?? placeholder,
              style: TextStyle(
                color: value == null ? _secondary : Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatus(bool saving) {
    final options = {..._statuses, _status}.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: _fieldDecoration(
            label: '',
            errorText: _errorFor('status'),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _status,
              isExpanded: true,
              isDense: true,
              dropdownColor: _card,
              iconEnabledColor: _secondary,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: [
                for (final status in options)
                  DropdownMenuItem(
                    value: status,
                    child: Text(_capitalize(status)),
                  ),
              ],
              onChanged: saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _status = value;
                        _clearError('status');
                      });
                    },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAreas(bool saving) {
    return FutureBuilder<List<Area>>(
      future: _areas,
      builder: (context, snapshot) {
        final areas = snapshot.data;
        final byId = {
          for (final area in areas ?? const <Area>[]) area.id: area,
        };
        final error = _errorFor('area_ids');

        final Widget content;
        if (snapshot.hasError) {
          content = Row(
            children: [
              const Expanded(
                child: Text(
                  'Could not load the areas.',
                  style: TextStyle(color: _secondary, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: _reloadAreas,
                style: TextButton.styleFrom(foregroundColor: _amber),
                child: const Text('Retry'),
              ),
            ],
          );
        } else if (areas == null) {
          content = const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _amber),
            ),
          );
        } else {
          final selected = _areaIds.toList()..sort();
          content = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in selected)
                Chip(
                  label: Text(
                    byId[id]?.name ?? 'Area #$id',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: const Color(0xFF1F2937),
                  side: const BorderSide(color: Color(0xFF374151)),
                  deleteIconColor: _secondary,
                  onDeleted: saving
                      ? null
                      : () => setState(() {
                          _areaIds.remove(id);
                          _clearError('area_ids');
                        }),
                ),
              ActionChip(
                avatar: Icon(
                  _areaIds.isEmpty ? Icons.add_rounded : Icons.edit_outlined,
                  size: 16,
                  color: _amber,
                ),
                label: Text(
                  _areaIds.isEmpty ? 'Select areas' : 'Edit areas',
                  style: const TextStyle(
                    color: _amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFF292315),
                side: BorderSide(color: _amber.withValues(alpha: 0.5)),
                onPressed: saving ? null : () => _selectAreas(areas),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Affected Areas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: error == null ? _border : _danger),
              ),
              child: content,
            ),

            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error, style: const TextStyle(color: _danger, fontSize: 12)),
            ],

            if (areas != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Affected Feeders',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: _buildFeeders(areas, saving),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFeeders(List<Area> areas, bool saving) {
    final selectedAreas = areas
        .where((area) => _areaIds.contains(area.id))
        .toList();

    final availableFeeders = selectedAreas
        .expand((area) => area.feeders)
        .toList();

    final byId = {for (final feeder in availableFeeders) feeder.id: feeder};

    if (_areaIds.isEmpty) {
      return const Text(
        'Select affected areas first.',
        style: TextStyle(color: _secondary, fontSize: 13),
      );
    }

    if (availableFeeders.isEmpty) {
      return const Text(
        'No feeders are available for the selected areas.',
        style: TextStyle(color: _secondary, fontSize: 13),
      );
    }

    final selected = _feederIds.where(byId.containsKey).toList()..sort();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in selected)
          Chip(
            label: Text(
              byId[id]!.name,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            backgroundColor: const Color(0xFF1F2937),
            side: const BorderSide(color: Color(0xFF374151)),
            deleteIconColor: _secondary,
            onDeleted: saving
                ? null
                : () => setState(() => _feederIds.remove(id)),
          ),
        ActionChip(
          avatar: Icon(
            _feederIds.isEmpty ? Icons.add_rounded : Icons.edit_outlined,
            size: 16,
            color: _amber,
          ),
          label: Text(
            _feederIds.isEmpty ? 'Select feeders' : 'Edit feeders',
            style: const TextStyle(
              color: _amber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF292315),
          side: BorderSide(color: _amber.withValues(alpha: 0.5)),
          onPressed: saving ? null : () => _selectFeeders(availableFeeders),
        ),
      ],
    );
  }

  Widget _buildSignedOut(AuthProvider auth) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, color: _amber, size: 32),
              const SizedBox(height: 12),
              Text(
                auth.notice ?? 'Sign in as an admin to manage advisories.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.adminLogin),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _amber,
                  side: BorderSide(color: _amber.withValues(alpha: 0.5)),
                ),
                child: const Text('Admin sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isSignedIn) return _buildSignedOut(auth);

    final saving = context.watch<PowerInterruptionProvider>().isSaving;
    final isEdit = _editing != null;
    const gap = SizedBox(height: 16);

    return PopScope(
      canPop: !saving,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: saving ? null : () => Navigator.pop(context),
          ),
          title: Text(
            'Manage Advisory',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                isEdit ? 'Edit Brownout Advisory' : 'Add Brownout Advisory',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Keep your community informed.',
                style: TextStyle(
                  color: _amber,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              _textField(
                controller: _title,
                label: 'Title',
                hint: 'e.g. Scheduled maintenance',
                errorKey: 'title',
                enabled: !saving,
              ),
              gap,
              _pickerField(
                label: 'Date',
                placeholder: 'Select a date',
                icon: Icons.calendar_today_outlined,
                value: _date == null
                    ? null
                    : DateFormat('EEE, MMM d, y').format(_date!),
                errorText: _errorFor('date'),
                onTap: saving ? null : _pickDate,
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _pickerField(
                      label: 'Start time',
                      placeholder: 'Select',
                      icon: Icons.schedule_rounded,
                      value: _start?.format(context),
                      errorText: _errorFor('start_time'),
                      onTap: saving
                          ? null
                          : () => _pickTime(
                              _start,
                              'start_time',
                              (t) => _start = t,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pickerField(
                      label: 'End time',
                      placeholder: 'Select',
                      icon: Icons.schedule_rounded,
                      value: _end?.format(context),
                      errorText: _errorFor('end_time'),
                      onTap: saving
                          ? null
                          : () => _pickTime(_end, 'end_time', (t) => _end = t),
                    ),
                  ),
                ],
              ),
              gap,
              _buildStatus(saving),
              gap,
              _buildAreas(saving),
              gap,
              _textField(
                controller: _reason,
                label: 'Reason',
                hint: 'e.g. Line maintenance',
                errorKey: 'reason',
                enabled: !saving,
              ),
              gap,
              _textField(
                controller: _description,
                label: 'Advisory details',
                hint: 'What residents should know',
                errorKey: 'description',
                minLines: 3,
                maxLines: 6,
                enabled: !saving,
              ),
              gap,
              _pickerField(
                label: 'Estimated restoration (optional)',
                placeholder: 'Not specified',
                icon: Icons.access_time_rounded,
                value: _restoration?.format(context),
                errorText: _errorFor('estimated_restoration'),
                onTap: saving
                    ? null
                    : () => _pickTime(
                        _restoration,
                        'estimated_restoration',
                        (t) => _restoration = t,
                      ),
                onClear: saving
                    ? null
                    : () => setState(() {
                        _restoration = null;
                        _clearError('estimated_restoration');
                      }),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: _background,
                    disabledBackgroundColor: const Color(0xFF1F2937),
                    disabledForegroundColor: _secondary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _amber,
                          ),
                        )
                      : Text(isEdit ? 'Save Changes' : 'Create Advisory'),
                ),
              ),
              if (isEdit) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: const Text('Delete Advisory'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _danger,
                      side: BorderSide(color: _danger.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Bottom sheet with a search box and a checkbox per area. Pops with the chosen ids,
// or with nothing when dismissed, which leaves the selection unchanged.
class _AreaPickerSheet extends StatefulWidget {
  const _AreaPickerSheet({required this.areas, required this.selected});

  final List<Area> areas;
  final Set<int> selected;

  @override
  State<_AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends State<_AreaPickerSheet> {
  late final Set<int> _selected = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final area in widget.areas)
        if (query.isEmpty ||
            '${area.name} ${area.city}'.toLowerCase().contains(query))
          area,
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Affected areas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${_selected.length} selected',
                      style: const TextStyle(color: _secondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  cursorColor: _amber,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _fieldDecoration(label: 'Search areas').copyWith(
                    prefixIcon: const Icon(Icons.search_rounded, color: _amber),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(
                        child: Text(
                          'No matching areas',
                          style: TextStyle(color: _secondary, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final area = visible[index];
                          return CheckboxListTile(
                            value: _selected.contains(area.id),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _selected.add(area.id);
                              } else {
                                _selected.remove(area.id);
                              }
                            }),
                            activeColor: _amber,
                            checkColor: _background,
                            side: const BorderSide(color: _secondary),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              '${area.name}, ${area.city}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, {..._selected}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: _background,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeederPickerSheet extends StatefulWidget {
  const _FeederPickerSheet({required this.feeders, required this.selected});

  final List<Feeder> feeders;
  final Set<int> selected;

  @override
  State<_FeederPickerSheet> createState() => _FeederPickerSheetState();
}

class _FeederPickerSheetState extends State<_FeederPickerSheet> {
  late final Set<int> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select feeders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _secondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final feeder in widget.feeders)
                      CheckboxListTile(
                        value: _selected.contains(feeder.id),
                        activeColor: _amber,
                        checkColor: Colors.black,
                        title: Text(
                          feeder.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(feeder.id);
                            } else {
                              _selected.remove(feeder.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Apply selection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
