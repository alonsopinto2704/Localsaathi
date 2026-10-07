import '../models/moderation.dart';

/// Customer reports about listings.
///
/// Customers can report but never edit. Reviewing reports needs moderation
/// tools that are outside this build; the queue is modelled so the backend has
/// somewhere to put them.
abstract class ReportRepository {
  Future<Report> submit({
    required String providerId,
    required ReportReason reason,
    String? details,
    String? reporterPhoneE164,
  });

  /// Reports filed from this device, so the UI can show "already reported".
  Future<List<Report>> myReports();

  Future<bool> hasReported(String providerId);

  /// Moderation queue. Owner/back-office only in production; present here so
  /// the data shape is real even without an admin dashboard.
  Future<List<Report>> queue({ReportStatus? status});
}
