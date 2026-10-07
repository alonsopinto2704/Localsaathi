import '../../domain/models/provider.dart';

/// Approximate centre points of launch-market localities (public geography,
/// rounded to ~100 m). Used only to centre the map picker on a provider's own
/// area and to place the fictional demo listings; real pins always come from
/// the provider.
///
/// A locality missing here falls back to its city centre.
const Map<String, GeoPoint> localityCentres = <String, GeoPoint>{
  'mh-mumbai-andheri-east': GeoPoint(19.1136, 72.8697),
  'mh-mumbai-andheri-west': GeoPoint(19.1364, 72.8296),
  'mh-mumbai-bandra-east': GeoPoint(19.0610, 72.8490),
  'mh-mumbai-bandra-west': GeoPoint(19.0596, 72.8295),
  'mh-mumbai-bhandup': GeoPoint(19.1440, 72.9360),
  'mh-mumbai-borivali-east': GeoPoint(19.2290, 72.8670),
  'mh-mumbai-borivali-west': GeoPoint(19.2307, 72.8510),
  'mh-mumbai-byculla': GeoPoint(18.9790, 72.8330),
  'mh-mumbai-charni-road': GeoPoint(18.9520, 72.8180),
  'mh-mumbai-chembur': GeoPoint(19.0522, 72.9005),
  'mh-mumbai-churchgate': GeoPoint(18.9350, 72.8270),
  'mh-mumbai-colaba': GeoPoint(18.9067, 72.8147),
  'mh-mumbai-dadar-east': GeoPoint(19.0180, 72.8480),
  'mh-mumbai-dadar-west': GeoPoint(19.0200, 72.8400),
  'mh-mumbai-dahisar': GeoPoint(19.2502, 72.8592),
  'mh-mumbai-fort': GeoPoint(18.9338, 72.8356),
  'mh-mumbai-ghatkopar': GeoPoint(19.0860, 72.9081),
  'mh-mumbai-goregaon': GeoPoint(19.1663, 72.8526),
  'mh-mumbai-jogeshwari': GeoPoint(19.1350, 72.8490),
  'mh-mumbai-juhu': GeoPoint(19.1075, 72.8263),
  'mh-mumbai-kandivali': GeoPoint(19.2047, 72.8517),
  'mh-mumbai-kanjurmarg': GeoPoint(19.1290, 72.9320),
  'mh-mumbai-khar': GeoPoint(19.0700, 72.8370),
  'mh-mumbai-kurla': GeoPoint(19.0728, 72.8826),
  'mh-mumbai-lower-parel': GeoPoint(18.9980, 72.8300),
  'mh-mumbai-mahim': GeoPoint(19.0400, 72.8400),
  'mh-mumbai-malabar-hill': GeoPoint(18.9550, 72.8030),
  'mh-mumbai-malad': GeoPoint(19.1874, 72.8484),
  'mh-mumbai-mankhurd': GeoPoint(19.0480, 72.9320),
  'mh-mumbai-marine-lines': GeoPoint(18.9440, 72.8230),
  'mh-mumbai-matunga': GeoPoint(19.0270, 72.8570),
  'mh-mumbai-mazgaon': GeoPoint(18.9660, 72.8440),
  'mh-mumbai-mulund': GeoPoint(19.1726, 72.9425),
  'mh-mumbai-parel': GeoPoint(19.0000, 72.8410),
  'mh-mumbai-powai': GeoPoint(19.1176, 72.9060),
  'mh-mumbai-prabhadevi': GeoPoint(19.0160, 72.8290),
  'mh-mumbai-santacruz': GeoPoint(19.0806, 72.8411),
  'mh-mumbai-sion': GeoPoint(19.0390, 72.8619),
  'mh-mumbai-vikhroli': GeoPoint(19.1110, 72.9280),
  'mh-mumbai-vile-parle': GeoPoint(19.0990, 72.8440),
  'mh-mumbai-wadala': GeoPoint(19.0170, 72.8650),
  'mh-mumbai-wadala-sewri': GeoPoint(19.0000, 72.8580),
  'mh-mumbai-worli': GeoPoint(19.0176, 72.8162),
};

const Map<String, GeoPoint> cityCentres = <String, GeoPoint>{
  'mh-mumbai': GeoPoint(19.0760, 72.8777),
};

/// Best map centre for a locality: its own centre, else its city's, else
/// Mumbai (the launch market).
GeoPoint centreFor({required String localityId, required String cityId}) =>
    localityCentres[localityId] ??
    cityCentres[cityId] ??
    cityCentres['mh-mumbai']!;
