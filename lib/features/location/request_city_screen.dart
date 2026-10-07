import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/controllers/location_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/async_states.dart';
import '../../domain/models/location.dart';

/// "Request my city".
///
/// Submission is **mocked**: the request is stored on this device so the flow is
/// complete and testable, and nothing is sent anywhere. The screen says so
/// plainly rather than implying the request reached a team.
class RequestCityScreen extends StatefulWidget {
  const RequestCityScreen({super.key});

  @override
  State<RequestCityScreen> createState() => _RequestCityScreenState();
}

class _RequestCityScreenState extends State<RequestCityScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _submitting = false;
  bool _done = false;
  List<CityRequest> _previous = <CityRequest>[];

  @override
  void initState() {
    super.initState();
    _loadPrevious();
  }

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPrevious() async {
    final LocationController controller = context.read<LocationController>();
    final List<CityRequest> requests = await controller.cityRequests();
    if (!mounted) return;
    setState(() => _previous = requests);
  }

  Future<void> _submit() async {
    final LocationController controller = context.read<LocationController>();
    setState(() => _submitting = true);
    final CityRequestResult result = await controller.requestCity(
      cityName: _controller.text,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    final strings = context.strings;
    switch (result) {
      case CityRequestResult.submitted:
        setState(() => _done = true);
        await _loadPrevious();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.requestMyCitySubmitted)),
        );
      case CityRequestResult.alreadyRequested:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.requestMyCityAlreadyRequested)),
        );
      case CityRequestResult.emptyInput:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.fieldRequired)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final LocationController controller = context.watch<LocationController>();

    return Scaffold(
      appBar: AppBar(title: Text(strings.requestMyCity)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          AppBanner(
            message: strings.requestMyCityBody,
            title: strings.launchAvailabilityTitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: strings.cityLabel,
              hintText: strings.requestMyCityHint,
              prefixIcon: const Icon(Icons.location_city),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: strings.optionalLabel,
              hintText: strings.reportDetailsHint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed:
                _controller.text.trim().isEmpty || _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(strings.requestMyCity),
          ),
          const SizedBox(height: AppSpacing.md),
          AppBanner.development(
            message: strings.requestCityMockNotice,
            title: strings.sampleDataLabel,
          ),
          if (_done) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            AppBanner(
              message: strings.requestMyCitySubmitted,
              tone: AppBannerTone.success,
            ),
          ],
          if (_previous.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: strings.recentSearches),
            for (final CityRequest request in _previous)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(request.cityName),
                subtitle: Text(formatShortDate(request.requestedAt)),
              ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            '${strings.activeMarkets}: ${controller.activeCity?.name ?? ''}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppConfig.shareBaseUrl,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
