import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inquiry_repository.dart';
import '../domain/cohort_filter_spec.dart';
import '../domain/inquiry_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Inquiry list (filter-aware)
/// ─────────────────────────────────────────────────────────────────────────

/// Arguments identifying which inquiry list to load. An empty filter set loads
/// everything the caller is allowed to see.
class InquiryListArgs {
  const InquiryListArgs({
    this.status,
    this.type,
    this.priority,
    this.assignedToMe = false,
  });

  final String? status;
  final String? type;
  final String? priority;
  final bool assignedToMe;

  @override
  bool operator ==(Object other) =>
      other is InquiryListArgs &&
      other.status == status &&
      other.type == type &&
      other.priority == priority &&
      other.assignedToMe == assignedToMe;

  @override
  int get hashCode => Object.hash(status, type, priority, assignedToMe);
}

/// Pagination/load-more metadata published alongside [inquiryListProvider] so
/// the list screen can drive "더 보기" / infinite scroll. Kept separate from the
/// list payload so [inquiryListProvider] keeps returning a plain
/// `List<Inquiry>` for the dashboard summary consumers that share its cache.
class InquiryListMeta {
  const InquiryListMeta({
    this.loadedPage = 1,
    this.loadedCount = 0,
    this.total = 0,
    this.isLoadingMore = false,
  });

  /// The highest page index already fetched and appended.
  final int loadedPage;

  /// How many rows are accumulated so far (== `state.value.length`).
  final int loadedCount;

  /// Total rows the backend reports for this filter set (from `meta.total`).
  final int total;

  /// True while a [InquiryListNotifier.loadMore] call is in flight, so the
  /// screen shows a footer spinner without flipping the whole list to loading.
  final bool isLoadingMore;

  /// Whether more rows remain on the server beyond what is loaded.
  bool get hasMore => loadedCount < total;

  InquiryListMeta copyWith({
    int? loadedPage,
    int? loadedCount,
    int? total,
    bool? isLoadingMore,
  }) {
    return InquiryListMeta(
      loadedPage: loadedPage ?? this.loadedPage,
      loadedCount: loadedCount ?? this.loadedCount,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Loads inquiries for the given filter set (newest first), accumulating pages
/// so that "전체" is a true superset of every status. The backend caps each
/// request at [_pageSize] rows; [loadMore] appends the next page until
/// `meta.total` is reached.
///
/// The notifier's value stays a plain `List<Inquiry>` (every row loaded so far)
/// for backward compatibility with the dashboard summaries that watch this
/// provider. Pagination/load-more bookkeeping is published separately via
/// [inquiryListMetaProvider].
///
/// Family argument is captured in [args] by the provider factory — Riverpod
/// 3.x non-codegen notifiers don't receive the argument in [build].
class InquiryListNotifier extends AsyncNotifier<List<Inquiry>> {
  InquiryListNotifier(this.args);

  final InquiryListArgs args;

  /// Page size per request. The backend enforces its own max; we ask for the
  /// largest sensible page so most lists load in one round-trip, and still fall
  /// back to [loadMore] when `meta.total` exceeds what came back.
  static const int _pageSize = 100;

  /// Pagination bookkeeping mirrored to [inquiryListMetaProvider] after each
  /// fetch so the screen can render "더 보기" / a footer spinner.
  InquiryListMeta _meta = const InquiryListMeta();

  void _publishMeta() =>
      ref.read(inquiryListMetaProvider(args).notifier).set(_meta);

  @override
  Future<List<Inquiry>> build() => _fetchFirstPage();

  Future<List<Inquiry>> _fetchFirstPage() async {
    final page = await ref.read(inquiryRepositoryProvider).listInquiries(
          status: args.status,
          type: args.type,
          priority: args.priority,
          assignedToMe: args.assignedToMe,
          page: 1,
          size: _pageSize,
        );
    _meta = InquiryListMeta(
      loadedPage: page.pagination.page,
      loadedCount: page.items.length,
      total: page.pagination.total,
    );
    _publishMeta();
    return page.items;
  }

  /// Resets to page 1, replacing the accumulated list.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchFirstPage);
  }

  /// Fetches the next page and appends it to the current list. No-op when there
  /// is no data yet, when everything is already loaded, or when a load is
  /// already in flight. Failures are swallowed (the already-loaded rows stay
  /// visible); the next scroll/tap retries.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !_meta.hasMore || _meta.isLoadingMore) return;

    _meta = _meta.copyWith(isLoadingMore: true);
    _publishMeta();
    try {
      final next = await ref.read(inquiryRepositoryProvider).listInquiries(
            status: args.status,
            type: args.type,
            priority: args.priority,
            assignedToMe: args.assignedToMe,
            page: _meta.loadedPage + 1,
            size: _pageSize,
          );
      // Re-read in case refresh() ran while we awaited.
      final latest = state.value ?? current;
      final merged = [...latest, ...next.items];
      _meta = _meta.copyWith(
        loadedPage: next.pagination.page,
        loadedCount: merged.length,
        total: next.pagination.total,
        isLoadingMore: false,
      );
      state = AsyncData(merged);
      _publishMeta();
    } catch (_) {
      _meta = _meta.copyWith(isLoadingMore: false);
      _publishMeta();
    }
  }
}

final inquiryListProvider = AsyncNotifierProvider.family<InquiryListNotifier,
    List<Inquiry>, InquiryListArgs>(
  InquiryListNotifier.new,
);

/// Holds the [InquiryListMeta] for a given [InquiryListArgs], written by
/// [InquiryListNotifier] and watched by the list screen. Plain mutable holder —
/// the notifier is the single writer.
class InquiryListMetaNotifier extends Notifier<InquiryListMeta> {
  InquiryListMetaNotifier(this.args);

  final InquiryListArgs args;

  @override
  InquiryListMeta build() => const InquiryListMeta();

  void set(InquiryListMeta meta) => state = meta;
}

final inquiryListMetaProvider = NotifierProvider.family<InquiryListMetaNotifier,
    InquiryListMeta, InquiryListArgs>(
  InquiryListMetaNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Single inquiry detail
/// ─────────────────────────────────────────────────────────────────────────

/// Loads + mutates a single inquiry. Status / assignee / close actions update
/// the cached value optimistically where the server response is authoritative.
class InquiryDetailNotifier extends AsyncNotifier<Inquiry> {
  InquiryDetailNotifier(this.inquiryId);

  final int inquiryId;

  @override
  Future<Inquiry> build() => _fetch();

  Future<Inquiry> _fetch() =>
      ref.read(inquiryRepositoryProvider).getInquiry(inquiryId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Patches status / assignee / priority then stores the server result.
  /// Throws [InquiryException] on failure so the caller can surface it.
  ///
  /// Named `applyUpdate` to avoid clashing with [AsyncNotifier.update].
  Future<void> applyUpdate({
    String? status,
    int? assignedTo,
    String? priority,
  }) async {
    final updated = await ref.read(inquiryRepositoryProvider).updateInquiry(
          inquiryId,
          status: status,
          assignedTo: assignedTo,
          priority: priority,
        );
    state = AsyncData(updated);
  }

  /// Closes the inquiry and stores the server result.
  Future<void> close() async {
    final updated =
        await ref.read(inquiryRepositoryProvider).closeInquiry(inquiryId);
    state = AsyncData(updated);
  }
}

final inquiryDetailProvider = AsyncNotifierProvider.family<
    InquiryDetailNotifier, Inquiry, int>(
  InquiryDetailNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Inquiry message thread (REST; WS chat is F5)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads + appends messages for an inquiry. Sending posts via REST then
/// refreshes the thread (manual refresh model until WebSocket lands in F5).
class InquiryMessagesNotifier extends AsyncNotifier<List<InquiryMessage>> {
  InquiryMessagesNotifier(this.inquiryId);

  final int inquiryId;

  @override
  Future<List<InquiryMessage>> build() => _fetch();

  Future<List<InquiryMessage>> _fetch() =>
      ref.read(inquiryRepositoryProvider).listMessages(inquiryId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Sends a message then appends the server-confirmed message to the thread
  /// (no full reload, so the view stays put). Throws on failure.
  Future<void> send(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final message = await ref.read(inquiryRepositoryProvider).addMessage(
          inquiryId: inquiryId,
          content: trimmed,
        );
    final current = state.value ?? const <InquiryMessage>[];
    state = AsyncData([...current, message]);
  }
}

final inquiryMessagesProvider = AsyncNotifierProvider.family<
    InquiryMessagesNotifier, List<InquiryMessage>, int>(
  InquiryMessagesNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Compose / submit an inquiry
/// ─────────────────────────────────────────────────────────────────────────

/// Form state for the inquiry-create screen.
class InquiryFormState {
  const InquiryFormState({
    this.type = InquiryType.technical,
    this.title = '',
    this.content = '',
    this.priority = InquiryPriority.normal,
    this.isSubmitting = false,
    this.error,
    this.created,
  });

  final InquiryType type;
  final String title;
  final String content;
  final InquiryPriority priority;
  final bool isSubmitting;
  final String? error;

  /// Non-null once the inquiry is created (drives navigation away from the
  /// form).
  final Inquiry? created;

  bool get isValid => title.trim().isNotEmpty && content.trim().isNotEmpty;

  InquiryFormState copyWith({
    InquiryType? type,
    String? title,
    String? content,
    InquiryPriority? priority,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    Inquiry? created,
  }) {
    return InquiryFormState(
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      created: created ?? this.created,
    );
  }
}

/// Drives the inquiry-compose form.
class InquiryFormNotifier extends Notifier<InquiryFormState> {
  @override
  InquiryFormState build() => const InquiryFormState();

  void setType(InquiryType v) => state = state.copyWith(type: v);
  void setPriority(InquiryPriority v) => state = state.copyWith(priority: v);
  void setTitle(String v) => state = state.copyWith(title: v, clearError: true);
  void setContent(String v) =>
      state = state.copyWith(content: v, clearError: true);

  /// Submits the inquiry. Prevents double submission via
  /// [InquiryFormState.isSubmitting]. On success sets [InquiryFormState.created]
  /// so the screen can navigate.
  Future<void> submit() async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final inquiry = await ref.read(inquiryRepositoryProvider).createInquiry(
            type: state.type.code,
            title: state.title.trim(),
            content: state.content.trim(),
            priority: state.priority.code,
          );
      state = state.copyWith(isSubmitting: false, created: inquiry);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final inquiryFormProvider =
    NotifierProvider<InquiryFormNotifier, InquiryFormState>(
  InquiryFormNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// License list (Tech Support / Operations)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads software licenses for the caller's institution (newest first).
class LicenseListNotifier extends AsyncNotifier<List<SoftwareLicense>> {
  @override
  Future<List<SoftwareLicense>> build() => _fetch();

  Future<List<SoftwareLicense>> _fetch() async {
    final page = await ref.read(inquiryRepositoryProvider).listLicenses();
    return page.items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Creates a license then reloads the list. Throws [InquiryException] on
  /// failure (e.g. 403 for tech_support) so the caller can surface it.
  Future<void> create({
    required String serviceName,
    required String licenseKey,
    DateTime? issuedAt,
    DateTime? expiresAt,
    int? seatCount,
    String? notes,
  }) async {
    await ref.read(inquiryRepositoryProvider).createLicense(
          serviceName: serviceName,
          licenseKey: licenseKey,
          issuedAt: issuedAt,
          expiresAt: expiresAt,
          seatCount: seatCount,
          notes: notes,
        );
    await refresh();
  }
}

final licenseListProvider =
    AsyncNotifierProvider<LicenseListNotifier, List<SoftwareLicense>>(
  LicenseListNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// In-screen cohort filter (ops/tech ticket list, 2nd-level)
/// ─────────────────────────────────────────────────────────────────────────

/// Holds the operator's in-screen cohort-filter expression, keyed by the list's
/// [basePath] (`/ops/issues` vs `/tech/issues`) so the two areas keep separate
/// filters. It defaults to [CohortFilterSpec.none] ("전체 기수"); the operator
/// opts in to a single/multi/range/open-ended expression via the filter dialog
/// — see [CohortFilterSpec].
///
/// It deliberately does NOT pre-fill from the global nav cohort
/// ([selectedCohortProvider]): doing so hid inquiries whose `cohort_id` didn't
/// match the header selection (e.g. staff-created inquiries with `cohort_id`
/// NULL), making "전체" look broken, and a later global cohort change wiped the
/// operator's in-screen override. The cohort filter is now an explicit operator
/// action only.
///
/// NOTE: filtering happens client-side over the loaded pages because the backend
/// `GET /inquiries/` exposes no `cohort_id` query param (each `InquiryOut` does
/// carry `cohort_id`, which is what we match on).
class InquiryCohortFilterNotifier
    extends Notifier<CohortFilterSpec> {
  InquiryCohortFilterNotifier(this.basePath);

  final String basePath;

  @override
  CohortFilterSpec build() {
    // Default to "전체 기수"; the operator opts in via the filter dialog.
    return CohortFilterSpec.none;
  }

  /// Applies a raw operator expression (e.g. `1,2,5-7`, `5+`, empty = all).
  void apply(String expression) =>
      state = CohortFilterSpec.parse(expression);

  /// Resets to "전체 기수".
  void clear() => state = CohortFilterSpec.none;
}

final inquiryCohortFilterProvider = NotifierProvider.family<
    InquiryCohortFilterNotifier, CohortFilterSpec, String>(
  InquiryCohortFilterNotifier.new,
);
