import 'package:flutter/foundation.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/provider.dart';
import '../../domain/repositories/engagement_repository.dart';
import '../../domain/repositories/provider_repository.dart';

/// Drives search and category result screens.
///
/// Holds the query, the results and the loading/error/empty state so the widget
/// stays declarative. Created per results screen rather than app-wide, because
/// search state is inherently screen-scoped.
class ProviderSearchController extends ChangeNotifier {
  ProviderSearchController({
    required ProviderRepository repository,
    required EngagementRepository engagement,
  })  : _repository = repository,
        _engagement = engagement;

  final ProviderRepository _repository;
  final EngagementRepository _engagement;

  ProviderQuery? _query;
  ProviderSearchResults _results = const ProviderSearchResults.empty();
  bool _isLoading = false;
  Object? _error;
  bool _hasLoadedOnce = false;

  /// Bumped per request so a slow, superseded response cannot overwrite the
  /// results of a newer query (phase 065).
  int _requestId = 0;

  ProviderQuery? get query => _query;

  /// Sponsored items first, then organic results. The flag travels with each
  /// item so a card can render its own "Sponsored" label.
  List<ProviderResultItem> get items => _results.items;

  List<ProviderProfile> get sponsoredProviders => _results.sponsoredProviders;

  List<ProviderProfile> get organicProviders => _results.organicProviders;

  bool get hasSponsored => _results.sponsoredProviders.isNotEmpty;

  int get totalCount => _results.totalCount;

  bool get isLoading => _isLoading;

  bool get hasError => _error != null;

  Object? get error => _error;

  /// True only after a completed search, so the empty state never flashes
  /// before the first load.
  bool get isEmpty => _hasLoadedOnce && !_isLoading && _results.isEmpty;

  bool get isSampleData => _results.isSampleData;

  /// Applies a new query and reloads.
  Future<void> search(ProviderQuery query) async {
    _query = query;
    await refresh();
  }

  /// Re-runs the current query, e.g. after pulling to refresh.
  Future<void> refresh() async {
    final ProviderQuery? query = _query;
    if (query == null) return;

    final int id = ++_requestId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final ProviderSearchResults results = await _repository.search(query);
      if (id != _requestId) return;
      _results = results;
      _hasLoadedOnce = true;
    } on Object catch (error) {
      if (id != _requestId) return;
      _error = error;
      _results = const ProviderSearchResults.empty();
      _hasLoadedOnce = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Records a profile view. Fire-and-forget: analytics must never block or
  /// break navigation.
  Future<void> recordProfileView(String providerId) async {
    final ProviderQuery? query = _query;
    try {
      await _engagement.record(
        providerId: providerId,
        type: EngagementEventType.profileView,
        cityId: query?.cityId,
        localityId: query?.localityId,
      );
    } on Object {
      // Intentionally swallowed.
    }
  }

  /// Clears filters but keeps the location and the text query.
  Future<void> clearFilters() async {
    final ProviderQuery? query = _query;
    if (query == null) return;
    await search(query.cleared());
  }
}
