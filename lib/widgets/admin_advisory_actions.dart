import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/widgets/status_badge.dart';

// Admin-only tools on an advisory: change its status or delete it.
// Screens show this only when AuthProvider.isSignedIn is true, and the server
// rejects these requests without a valid admin session anyway.
class AdminAdvisoryActions extends StatefulWidget {
  const AdminAdvisoryActions({super.key, required this.advisory});

  final PowerInterruption advisory;

  @override
  State<AdminAdvisoryActions> createState() => _AdminAdvisoryActionsState();
}

class _AdminAdvisoryActionsState extends State<AdminAdvisoryActions> {
  static const amber = Color(0xFFFFBF00);
  static const danger = Color(0xFFF87171);
  static const statuses = ['scheduled', 'ongoing', 'restored', 'cancelled'];

  String? _savingStatus;
  bool _deleting = false;
  String? _selectedStatus;

  bool get _busy => _savingStatus != null || _deleting;

  Future<void> _setStatus(String status) async {
    if (_busy || status == widget.advisory.status.toLowerCase()) return;
    final provider = context.read<PowerInterruptionProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _savingStatus = status);
    final saved = await provider.updateInterruption(
      widget.advisory.copyWith(status: status),
    );
    // Still report the result if this widget is gone, e.g. a 401 signed the admin out.
    if (mounted) {
      setState(() {
        _savingStatus = null;
        if (saved) {
          _selectedStatus = null;
        }
      });
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Marked as ${StatusBadge.labelFor(status)}.'
              : provider.actionError ?? 'Could not update the advisory.',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111720),
        title: const Text(
          'Delete advisory?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '"${widget.advisory.title}" will be removed for every SUGA user. This cannot be undone.',
          style: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<PowerInterruptionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _deleting = true);
    final deleted = await provider.deleteInterruption(widget.advisory.id);
    if (mounted) setState(() => _deleting = false);

    if (deleted) {
      if (mounted) navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Advisory deleted.')),
      );
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

  @override
  Widget build(BuildContext context) {
    final current = widget.advisory.status.toLowerCase();
    final selected = _selectedStatus ?? current;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111720),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF292F38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: amber, size: 18),
              SizedBox(width: 8),
              Text(
                'ADMIN TOOLS',
                style: TextStyle(
                  color: amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'ADVISORY STATUS',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in statuses)
                ChoiceChip(
                  label: _savingStatus == status
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: amber,
                          ),
                        )
                      : Text(StatusBadge.labelFor(status)),
                  selected: selected == status,
                  onSelected: _busy
                      ? null
                      : (value) {
                          if (value) {
                            setState(() => _selectedStatus = status);
                          }
                        },
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  backgroundColor: const Color(0xFF111720),
                  selectedColor: StatusBadge.colorFor(status),
                  color: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return StatusBadge.colorFor(status);
                    }
                    return Color.alphaBlend(
                      StatusBadge.colorFor(status).withValues(alpha: 0.10),
                      const Color(0xFF111720),
                    );
                  }),
                  side: BorderSide(
                    color: StatusBadge.colorFor(
                      status,
                    ).withValues(alpha: selected == status ? 1.0 : 0.35),
                  ),
                  labelStyle: TextStyle(
                    color: selected == status
                        ? const Color(0xFF070A0F)
                        : StatusBadge.colorFor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _busy || selected == current
                  ? null
                  : () => _setStatus(selected),
              label: const Text('Save Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: amber,
                foregroundColor: const Color(0xFF070A0F),
                disabledBackgroundColor: const Color(0xFF292F38),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF292F38), height: 1),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _delete,
              icon: _deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: danger,
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete Advisory'),
              style: OutlinedButton.styleFrom(
                foregroundColor: danger,
                side: BorderSide(color: danger.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
