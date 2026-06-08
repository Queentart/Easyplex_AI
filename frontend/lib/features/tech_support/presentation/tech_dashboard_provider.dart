import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inquiry/domain/inquiry_model.dart';
import '../../inquiry/presentation/inquiry_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Tech Support home dashboard — aggregation layer
/// ─────────────────────────────────────────────────────────────────────────
///
/// This file holds NO data layer of its own: it re-derives small dashboard
/// view-models from the EXISTING inquiry / license providers
/// (`inquiryListProvider`, `licenseListProvider`). Each card watches one of
/// these so it carries its own AsyncValue (independent loading / error / retry).
///
/// Infra / system metrics have no backend endpoint yet, so they are served as
/// clearly-labelled MOCK data from [techInfraMockProvider] (see `// MOCK:`).

/// Open-ticket summary derived from the inquiry list (open + in_progress).
class TicketSummary {
  const TicketSummary({required this.openCount, required this.recent});

  /// Count of tickets still needing attention (open + in_progress).
  final int openCount;

  /// Up to a handful of the most recent unresolved tickets for the preview list.
  final List<Inquiry> recent;
}

/// Filter args for the open-ticket feed. Status filtering is applied client-side
/// so a single unfiltered fetch backs both the count and the preview list.
const InquiryListArgs _ticketArgs = InquiryListArgs();

/// Open-ticket summary for card (1). Watches [inquiryListProvider] so it inherits
/// its loading / error states; transforms the result into a [TicketSummary].
final techTicketSummaryProvider = Provider<AsyncValue<TicketSummary>>((ref) {
  final async = ref.watch(inquiryListProvider(_ticketArgs));
  return async.whenData((items) {
    final unresolved = items
        .where((i) =>
            i.status == InquiryStatus.open.code ||
            i.status == InquiryStatus.inProgress.code)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return TicketSummary(
      openCount: unresolved.length,
      recent: unresolved.take(5).toList(),
    );
  });
});

/// Re-fetches the inquiry list backing the ticket card (called from the UI).
void refreshTechTickets(WidgetRef ref) =>
    ref.invalidate(inquiryListProvider(_ticketArgs));

/// License summary derived from the license list.
class LicenseSummary {
  const LicenseSummary({
    required this.total,
    required this.activeCount,
    required this.expiringSoon,
  });

  final int total;
  final int activeCount;

  /// Active licenses whose [SoftwareLicense.expiresAt] falls within
  /// [expiringWindowDays] from now (soonest first).
  final List<SoftwareLicense> expiringSoon;
}

/// Licenses expiring within this many days count as "만료 임박".
const int expiringWindowDays = 30;

/// License summary for card (2). Watches [licenseListProvider] and buckets the
/// records into total / active / expiring-soon.
final techLicenseSummaryProvider = Provider<AsyncValue<LicenseSummary>>((ref) {
  final async = ref.watch(licenseListProvider);
  return async.whenData((items) {
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: expiringWindowDays));
    final expiring = items
        .where((l) =>
            l.status == LicenseStatus.active.code &&
            l.expiresAt != null &&
            l.expiresAt!.isAfter(now) &&
            l.expiresAt!.isBefore(horizon))
        .toList()
      ..sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));
    final active =
        items.where((l) => l.status == LicenseStatus.active.code).length;
    return LicenseSummary(
      total: items.length,
      activeCount: active,
      expiringSoon: expiring,
    );
  });
});

/// Re-fetches the license list backing the license card (called from the UI).
void refreshTechLicenses(WidgetRef ref) => ref.invalidate(licenseListProvider);

/// ─────────────────────────────────────────────────────────────────────────
/// Infra / system metrics — MOCK (no backend endpoint yet)
/// ─────────────────────────────────────────────────────────────────────────

/// A single mocked infra gauge (CPU / memory / etc.).
///
/// MOCK: there is no `/metrics` endpoint yet. These values exist purely to
/// demonstrate the infra card layout and MUST be replaced with a real provider
/// once the monitoring API lands.
class InfraGauge {
  const InfraGauge({
    required this.label,
    required this.valueLabel,
    required this.ratio,
    required this.warning,
  });

  final String label;
  final String valueLabel;

  /// 0.0–1.0 fill for the progress bar.
  final double ratio;

  /// True when the gauge is in a warning band (drives the bar color).
  final bool warning;
}

/// Aggregated mocked infra snapshot for card (3).
class InfraMetrics {
  const InfraMetrics({
    required this.gauges,
    required this.uptimeLabel,
    required this.queueDepth,
  });

  final List<InfraGauge> gauges;
  final String uptimeLabel;
  final int queueDepth;
}

/// MOCK: static demo infra metrics. No network call — returned synchronously so
/// the card renders the "데모" badge without a spinner. Swap this provider for a
/// real `FutureProvider` against the monitoring API when it exists.
final techInfraMockProvider = Provider<InfraMetrics>((ref) {
  // MOCK: hardcoded demo values, clearly flagged in the UI with a "데모" label.
  const mockCpuRatio = 0.42;
  const mockMemoryRatio = 0.67;
  const mockDiskRatio = 0.58;
  const mockQueueDepth = 3;
  return const InfraMetrics(
    gauges: [
      InfraGauge(
        label: 'CPU 사용률',
        valueLabel: '42%',
        ratio: mockCpuRatio,
        warning: false,
      ),
      InfraGauge(
        label: '메모리 사용률',
        valueLabel: '67%',
        ratio: mockMemoryRatio,
        warning: false,
      ),
      InfraGauge(
        label: '디스크 사용률',
        valueLabel: '58%',
        ratio: mockDiskRatio,
        warning: false,
      ),
    ],
    uptimeLabel: '99.96% (30일)',
    queueDepth: mockQueueDepth,
  );
});
