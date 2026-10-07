import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../app/app_routes.dart';
import '../../app/controllers/session_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/provider_avatar.dart';
import '../../core/widgets/provider_contact.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/moderation.dart';
import '../../domain/models/provider.dart';

/// Provider dashboard.
///
/// Answers three questions in order: is my listing live, what do customers see,
/// and what happened. The statistics section is deliberately explicit that it
/// counts *button taps*, not calls, leads or jobs — the app hands off to the
/// dialer or WhatsApp and cannot observe the outcome, so it must not imply one.
class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  bool _loaded = false;
  EngagementSummary _summary = const EngagementSummary.empty();
  bool _loadingSummary = true;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final SessionController session = context.read<SessionController>();
    final String? profileId = session.profile?.id;
    if (profileId == null) {
      setState(() => _loadingSummary = false);
      return;
    }
    final EngagementSummary summary = await context
        .read<AppDependencies>()
        .engagement
        .summaryFor(profileId);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loadingSummary = false;
    });
  }

  Future<void> _togglePause(SessionController session) async {
    final ProviderProfile? profile = session.profile;
    if (profile == null) return;
    final bool pausing = profile.status == ListingStatus.published;
    setState(() => _busy = true);
    final bool ok = await session.setListingStatus(
      pausing ? ListingStatus.paused : ListingStatus.published,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final strings = context.strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (pausing ? strings.listingPaused : strings.listingResumed)
              : strings.somethingWentWrong,
        ),
      ),
    );
  }

  Future<void> _setAvailability(
    SessionController session,
    AvailabilityStatus availability,
  ) async {
    setState(() => _busy = true);
    final bool ok = await session.setAvailability(availability);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.availabilityUpdated)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final SessionController session = context.watch<SessionController>();
    final ProviderProfile? profile = session.profile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.dashboardTitle)),
        body: AppEmptyState(
          title: strings.providerSignIn,
          body: strings.providerSignInSubtitle,
          icon: Icons.storefront_outlined,
          actionLabel: strings.providerSignIn,
          onAction: () => Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.providerOnboarding,
            (Route<dynamic> r) => false,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.dashboardTitle),
        actions: <Widget>[
          IconButton(
            tooltip: strings.previewProfile,
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.providerProfile,
              arguments: profile.id,
            ),
            icon: const Icon(Icons.visibility_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.lg,
            AppSpacing.pagePadding,
            AppSpacing.xxxl,
          ),
          children: <Widget>[
            _ListingStatusCard(profile: profile),
            const SizedBox(height: AppSpacing.lg),

            SectionHeader(title: strings.listingStatus),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(strings.editProfile),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.providerEdit),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(strings.setWorkingHours),
                    subtitle: Text(
                      formatWorkingHoursSummary(
                        profile.workingHours,
                        closedLabel: strings.closedAllDay,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.providerEdit),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      profile.status == ListingStatus.published
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                    title: Text(
                      profile.status == ListingStatus.published
                          ? strings.pauseListing
                          : strings.resumeListing,
                    ),
                    subtitle: Text(strings.listingPausedExplainer),
                    enabled: !_busy,
                    onTap: () => _togglePause(session),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: strings.updateAvailability),
            Card(
              child: Column(
                children: <Widget>[
                  for (final AvailabilityStatus status
                      in AvailabilityStatus.values)
                    RadioListTile<AvailabilityStatus>(
                      value: status,
                      groupValue: profile.availability,
                      onChanged: _busy
                          ? null
                          : (AvailabilityStatus? value) {
                              if (value != null) {
                                _setAvailability(session, value);
                              }
                            },
                      title: Text(_availabilityLabel(context, status)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: strings.growYourBusiness),
            Card(
              child: ListTile(
                leading: const Icon(Icons.trending_up),
                title: Text(strings.monetizationTitle),
                subtitle: Text(strings.monetizationSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.growBusiness),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: strings.listingStatus,
              subtitle: strings.engagementExplainer,
            ),
            if (_loadingSummary)
              const AppLoadingState(compact: true)
            else
              _EngagementGrid(summary: _summary),

            const SizedBox(height: AppSpacing.xl),
            AppBanner(
              message: strings.noVerificationForSale,
              tone: AppBannerTone.info,
              icon: Icons.verified_user_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(context, session),
              icon: const Icon(Icons.delete_outline),
              label: Text(strings.deleteListingConfirm),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _availabilityLabel(
    BuildContext context,
    AvailabilityStatus status,
  ) {
    final strings = context.strings;
    switch (status) {
      case AvailabilityStatus.available:
        return strings.availabilityAvailable;
      case AvailabilityStatus.busy:
        return strings.availabilityBusy;
      case AvailabilityStatus.unavailable:
        return strings.availabilityUnavailable;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SessionController session,
  ) async {
    final strings = context.strings;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined),
        title: Text(strings.deleteListingTitle),
        content: Text(strings.deleteListingBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.deleteListingConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final bool ok = await session.deleteListing();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? context.strings.listingDeleted : context.strings.somethingWentWrong,
        ),
      ),
    );
  }
}

/// Status header: exactly which state the listing is in, and what that means.
class _ListingStatusCard extends StatelessWidget {
  const _ListingStatusCard({required this.profile});

  final ProviderProfile profile;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);

    final (String label, Color colour, IconData icon) = switch (profile.status) {
      ListingStatus.published => (
          strings.statusPublished,
          const Color(0xFF1B7F4B),
          Icons.check_circle_outline,
        ),
      ListingStatus.paused => (
          strings.statusPaused,
          const Color(0xFF8A5200),
          Icons.pause_circle_outline,
        ),
      ListingStatus.draft => (
          strings.statusDraft,
          theme.colorScheme.onSurfaceVariant,
          Icons.edit_note,
        ),
      ListingStatus.deleted => (
          strings.statusDraft,
          theme.colorScheme.error,
          Icons.delete_outline,
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            ProviderAvatar(
              initials: profile.initials(),
              size: AppSpacing.avatarMd,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    profile.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: <Widget>[
                      Icon(icon, size: 16, color: colour),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colour,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (profile.status == ListingStatus.paused) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      strings.listingPausedExplainer,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The engagement grid.
///
/// Sample data is labelled on screen, because seeded numbers must never be read
/// as real performance.
class _EngagementGrid extends StatelessWidget {
  const _EngagementGrid({required this.summary});

  final EngagementSummary summary;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (summary.isSampleData) ...<Widget>[
          AppBanner.sampleData(
            message: strings.sampleStatsNotice,
            title: strings.sampleDataLabel,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: strings.profileViews,
                value: summary.profileViews,
                icon: Icons.visibility_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatTile(
                label: strings.callButtonTaps,
                value: summary.callButtonTaps,
                icon: Icons.call_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: strings.whatsappButtonTaps,
                value: summary.whatsappButtonTaps,
                icon: Icons.chat_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatTile(
                label: strings.share,
                value: summary.shareTaps,
                icon: Icons.share_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          strings.engagementExplainer,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              formatCount(value),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
