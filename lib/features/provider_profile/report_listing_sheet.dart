import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';
import '../../domain/models/enums.dart';

/// Report a listing.
///
/// This exists instead of editing because the product rule is explicit:
/// customers may report incorrect information but may never change someone
/// else's listing. The sheet keeps the boundary visible, and every report lands
/// in a review queue that a future moderation surface will action.
Future<void> showReportListingSheet(
  BuildContext context, {
  required String providerId,
  required String providerName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => _ReportSheet(
      providerId: providerId,
      providerName: providerName,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.providerId, required this.providerName});

  final String providerId;
  final String providerName;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final TextEditingController _details = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ReportReason? reason = _reason;
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.reportChooseReason)),
      );
      return;
    }
    setState(() => _submitting = true);
    final AppDependencies dependencies = context.read<AppDependencies>();
    await dependencies.reports.submit(
      providerId: widget.providerId,
      reason: reason,
      details: _details.text,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.reportSubmitted)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                children: <Widget>[
                  Text(strings.reportTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.providerName,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppBanner(message: strings.reportNoteForCustomers),
                  const SizedBox(height: AppSpacing.lg),
                  _ReasonOption(
                    reason: ReportReason.wrongPhoneNumber,
                    label: strings.reportReasonWrongNumber,
                    selected: _reason,
                    onSelect: (ReportReason r) => setState(() => _reason = r),
                  ),
                  _ReasonOption(
                    reason: ReportReason.incorrectDetails,
                    label: strings.reportReasonWrongDetails,
                    selected: _reason,
                    onSelect: (ReportReason r) => setState(() => _reason = r),
                  ),
                  _ReasonOption(
                    reason: ReportReason.noLongerInBusiness,
                    label: strings.reportReasonClosed,
                    selected: _reason,
                    onSelect: (ReportReason r) => setState(() => _reason = r),
                  ),
                  _ReasonOption(
                    reason: ReportReason.spamOrMisleading,
                    label: strings.reportReasonSpam,
                    selected: _reason,
                    onSelect: (ReportReason r) => setState(() => _reason = r),
                  ),
                  _ReasonOption(
                    reason: ReportReason.other,
                    label: strings.reportReasonOther,
                    selected: _reason,
                    onSelect: (ReportReason r) => setState(() => _reason = r),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _details,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: strings.reportDetailsHint,
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: FilledButton(
                  onPressed: _submitting || _submitted ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(strings.report),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReasonOption extends StatelessWidget {
  const _ReasonOption({
    required this.reason,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final ReportReason reason;
  final String label;
  final ReportReason? selected;
  final ValueChanged<ReportReason> onSelect;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ReportReason>(
      contentPadding: EdgeInsets.zero,
      value: reason,
      groupValue: selected,
      onChanged: (ReportReason? value) {
        if (value != null) onSelect(value);
      },
      title: Text(label),
    );
  }
}
