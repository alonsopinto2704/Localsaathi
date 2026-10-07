import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';

LatLng _latLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

/// OpenStreetMap tiles plus the attribution their licence (ODbL) requires.
///
// ponytail: OSM's public tile servers allow light use only. Before real
// traffic, point [tileUrl] at a commercial host (MapTiler, Stadia, Mapbox) and
// keep the attribution its terms require.
class _OsmLayers {
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String copyrightUrl = 'https://www.openstreetmap.org/copyright';

  static List<Widget> layers({List<Widget> overlays = const <Widget>[]}) =>
      <Widget>[
        TileLayer(
          urlTemplate: tileUrl,
          // OSM's tile policy requires an identifying user agent.
          userAgentPackageName: 'com.localsaathi.app',
        ),
        ...overlays,
        SimpleAttributionWidget(
          source: const Text('OpenStreetMap contributors'),
          onTap: () => launchUrl(Uri.parse(copyrightUrl)),
        ),
      ];
}

/// The teal pin used for every provider marker.
class ProviderMapPin extends StatelessWidget {
  const ProviderMapPin({super.key, this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Icon(
      Icons.location_on,
      size: selected ? 46 : 40,
      color: selected ? theme.colorScheme.secondary : theme.colorScheme.primary,
      shadows: const <Shadow>[
        Shadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
      ],
    );
  }
}

Marker _pinMarker(GeoPoint point, {bool selected = false, VoidCallback? onTap}) =>
    Marker(
      point: _latLng(point),
      width: 48,
      height: 48,
      // The pin's tip, not its middle, sits on the coordinate.
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: onTap,
        child: ProviderMapPin(selected: selected),
      ),
    );

/// Opens turn-by-turn directions in the device's maps app (or the browser).
Future<void> openDirections(GeoPoint point) => launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${point.latitude},${point.longitude}',
      ),
      mode: LaunchMode.externalApplication,
    );

/// Where a provider works, for every provider.
///
/// * With an opted-in business pin: the exact pin and "Get directions".
/// * Without one: shaded circles over their base locality and service areas,
///   so customers see where they work without anyone's home being revealed.
class ProviderLocationMap extends StatelessWidget {
  const ProviderLocationMap({
    super.key,
    required this.exact,
    required this.baseArea,
    this.otherAreas = const <GeoPoint>[],
    required this.baseAreaName,
  });

  /// The opted-in business pin, if any.
  final GeoPoint? exact;

  /// Centre of the provider's base locality.
  final GeoPoint baseArea;

  /// Centres of the other localities they serve.
  final List<GeoPoint> otherAreas;
  final String baseAreaName;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final GeoPoint? pin = exact;
    final Color primary = theme.colorScheme.primary;

    final List<LatLng> extent = <LatLng>[
      if (pin != null) _latLng(pin) else _latLng(baseArea),
      if (pin == null) ...otherAreas.map(_latLng),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: extent.first,
                initialZoom: pin != null ? 15.5 : 13.5,
                initialCameraFit: extent.length > 1
                    ? CameraFit.coordinates(
                        coordinates: extent,
                        padding: const EdgeInsets.all(48),
                        maxZoom: 14,
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.scrollWheelZoom,
                ),
              ),
              children: _OsmLayers.layers(
                overlays: <Widget>[
                  if (pin != null)
                    MarkerLayer(markers: <Marker>[_pinMarker(pin)])
                  else
                    CircleLayer(
                      circles: <CircleMarker>[
                        for (final GeoPoint area in otherAreas)
                          CircleMarker(
                            point: _latLng(area),
                            radius: 700,
                            useRadiusInMeter: true,
                            color: primary.withValues(alpha: 0.10),
                            borderColor: primary.withValues(alpha: 0.35),
                            borderStrokeWidth: 1,
                          ),
                        CircleMarker(
                          point: _latLng(baseArea),
                          radius: 900,
                          useRadiusInMeter: true,
                          color: primary.withValues(alpha: 0.22),
                          borderColor: primary,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          pin != null
              ? strings.mapSharedByProvider
              : strings.approximateAreaNote(baseAreaName),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (pin != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => openDirections(pin),
            icon: const Icon(Icons.directions_outlined),
            label: Text(strings.getDirections),
          ),
        ],
      ],
    );
  }
}

/// Lets a provider tap the map to place (or move) their business pin.
class MapLocationPicker extends StatelessWidget {
  const MapLocationPicker({
    super.key,
    required this.initialCentre,
    required this.value,
    required this.onChanged,
  });

  /// Where the map opens when there is no pin yet (the provider's locality).
  final GeoPoint initialCentre;
  final GeoPoint? value;
  final ValueChanged<GeoPoint> onChanged;

  @override
  Widget build(BuildContext context) {
    final GeoPoint? pin = value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _latLng(pin ?? initialCentre),
            initialZoom: pin == null ? 14.5 : 16,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (TapPosition _, LatLng p) =>
                onChanged(GeoPoint(p.latitude, p.longitude)),
          ),
          children: _OsmLayers.layers(
            overlays: <Widget>[
              if (pin != null) MarkerLayer(markers: <Marker>[_pinMarker(pin)]),
            ],
          ),
        ),
      ),
    );
  }
}

/// One provider on the results map.
class MapListing {
  const MapListing({
    required this.provider,
    required this.subtitle,
    required this.onOpen,
  });

  final ProviderProfile provider;
  final String subtitle;
  final VoidCallback onOpen;
}

/// Search results on a map. Only providers who chose to show a location get
/// a pin; the caption says how many are list-only, so nobody is "missing".
class ProvidersMapView extends StatefulWidget {
  const ProvidersMapView({
    super.key,
    required this.listings,
    required this.fallbackCentre,
    required this.totalResults,
  });

  final List<MapListing> listings;
  final GeoPoint fallbackCentre;
  final int totalResults;

  @override
  State<ProvidersMapView> createState() => _ProvidersMapViewState();
}

class _ProvidersMapViewState extends State<ProvidersMapView> {
  MapListing? _selected;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final List<MapListing> pinned = widget.listings
        .where((MapListing l) => l.provider.mapLocation != null)
        .toList();
    final List<LatLng> points = <LatLng>[
      for (final MapListing l in pinned) _latLng(l.provider.mapLocation!),
    ];
    final MapListing? selected = _selected;

    return Stack(
      children: <Widget>[
        FlutterMap(
          options: MapOptions(
            initialCenter: _latLng(widget.fallbackCentre),
            initialZoom: 13,
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(64),
                    maxZoom: 15,
                  )
                : null,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (TapPosition _, LatLng __) =>
                setState(() => _selected = null),
          ),
          children: _OsmLayers.layers(
            overlays: <Widget>[
              MarkerLayer(
                markers: <Marker>[
                  for (final MapListing l in pinned)
                    _pinMarker(
                      l.provider.mapLocation!,
                      selected: identical(l, selected),
                      onTap: () => setState(() => _selected = l),
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: AppSpacing.md,
          left: AppSpacing.md,
          right: AppSpacing.md,
          child: Center(
            child: Material(
              color: theme.colorScheme.surface,
              elevation: 2,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + 2,
                ),
                child: Text(
                  strings.onMapCount(pinned.length, widget.totalResults),
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ),
          ),
        ),
        if (selected != null)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.xl,
            child: Material(
              color: theme.colorScheme.surface,
              elevation: 4,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                title: Text(selected.provider.displayName),
                subtitle: Text(selected.subtitle),
                trailing: FilledButton(
                  onPressed: selected.onOpen,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: Text(strings.viewProfile),
                ),
                onTap: selected.onOpen,
              ),
            ),
          ),
      ],
    );
  }
}
