import 'package:flutter/material.dart';

import '../../domain/models/service_category.dart';

/// Resolves a category's `iconKey` to an icon.
///
/// Categories are data and therefore cannot carry an `IconData`; this mapping is
/// the single presentation-side lookup. An unknown key degrades to a neutral
/// icon rather than throwing, so adding a category on the backend can never
/// break the client.
IconData categoryIcon(String iconKey) {
  switch (iconKey) {
    case CategoryIconKeys.plumbing:
      return Icons.plumbing;
    case CategoryIconKeys.electrical:
      return Icons.electrical_services;
    case CategoryIconKeys.carpentry:
      return Icons.handyman;
    case CategoryIconKeys.painting:
      return Icons.format_paint;
    case CategoryIconKeys.masonry:
      return Icons.foundation;
    case CategoryIconKeys.appliance:
      return Icons.kitchen;
    case CategoryIconKeys.lock:
      return Icons.vpn_key;
    case CategoryIconKeys.cleaning:
      return Icons.cleaning_services;
    case CategoryIconKeys.pest:
      return Icons.pest_control;
    case CategoryIconKeys.labour:
      return Icons.groups;
    case CategoryIconKeys.mechanic:
      return Icons.two_wheeler;
    case CategoryIconKeys.towing:
      return Icons.local_shipping;
    case CategoryIconKeys.medical:
      return Icons.medical_services;
    case CategoryIconKeys.dental:
      return Icons.sentiment_satisfied_alt;
    case CategoryIconKeys.physio:
      return Icons.accessibility_new;
    case CategoryIconKeys.diagnostics:
      return Icons.biotech;
    case CategoryIconKeys.computer:
      return Icons.computer;
    case CategoryIconKeys.tutor:
      return Icons.school;
    case CategoryIconKeys.moving:
      return Icons.moving;
    case CategoryIconKeys.laundry:
      return Icons.local_laundry_service;
    case CategoryIconKeys.paediatric:
      return Icons.child_care;
    case CategoryIconKeys.network:
      return Icons.router;
    case CategoryIconKeys.beauty:
      return Icons.spa;
    case CategoryIconKeys.tailoring:
      return Icons.content_cut;
    case CategoryIconKeys.security:
      return Icons.shield;
    case CategoryIconKeys.driver:
      return Icons.directions_car;
    case CategoryIconKeys.gardening:
      return Icons.yard;
    case CategoryIconKeys.events:
      return Icons.celebration;
    default:
      return Icons.miscellaneous_services;
  }
}

/// Icon for a group. Groups reuse the same key space.
IconData serviceGroupIcon(String iconKey) => categoryIcon(iconKey);
