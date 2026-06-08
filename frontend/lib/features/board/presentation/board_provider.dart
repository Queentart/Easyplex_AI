import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cohort_filter.dart';
import '../../../core/providers.dart';
import '../data/board_repository.dart';
import '../domain/board_model.dart';

/// True for staff roles (operations / instructors). Staff users carry no
/// `users.cohort_id` (operations have none; instructors' cohorts live in the
/// `instructor_cohorts` join), so the backend's default board scoping —
/// `cohort_id IS NULL OR cohort_id == current_user.cohort_id` — only returns
/// institution-wide boards for them. To see a cohort's (cohort-scoped) boards
/// they must pass an explicit `cohort_id`, which we source from the global nav
/// cohort filter ([selectedCohortProvider]).
bool _isStaffRole(String? role) => role == 'admin_ops' || role == 'instructor';

/// Resolves the `cohort_id` query param to send to `listBoards` for the current
/// user. Staff pass the globally-selected cohort (may be null = 기수 전체, in
/// which case the backend returns only institution-wide boards). Students pass
/// null so the backend keeps using their own cohort.
int? _cohortScopeFor(Ref ref) {
  final role = ref.watch(currentUserProvider)?.role;
  if (!_isStaffRole(role)) return null;
  return ref.watch(selectedCohortProvider);
}

/// True when the current user is staff (operations / instructor) viewing
/// "기수 전체" (no cohort selected in the global nav filter). In that mode the
/// backend can only scope a single cohort per request, so we fan out one
/// `listBoards` call per role-scoped cohort and MERGE the results, grouped by
/// cohort (see [groupedBoardListProvider] / [groupedBoardManagementProvider]).
bool _isStaffAllCohorts(Ref ref) {
  final role = ref.watch(currentUserProvider)?.role;
  return _isStaffRole(role) && ref.watch(selectedCohortProvider) == null;
}

/// ─────────────────────────────────────────────────────────────────────────
/// Grouped (cross-cohort aggregated) boards
/// ─────────────────────────────────────────────────────────────────────────

/// A labelled section of boards in the grouped/aggregated views.
///
/// When staff browse with "기수 전체" selected, the community + management
/// screens show one [BoardGroup] per role-scoped cohort (header = the cohort
/// name) plus a single shared [institutionTitle] group for institution-wide
/// (null-cohort) boards, which the backend returns under every cohort query and
/// would otherwise be duplicated.
class BoardGroup {
  const BoardGroup({
    required this.title,
    required this.boards,
    this.isInstitution = false,
  });

  /// Header label, e.g. `"1기"` or [institutionTitle].
  final String title;
  final List<Board> boards;

  /// True for the de-duplicated institution-wide ("기수 전체") group.
  final bool isInstitution;

  static const institutionTitle = '기수 전체';
}

/// Caches a single cohort's board fetch so the per-cohort fan-out (and the two
/// grouped views) reuse one network call per cohort rather than refetching.
final _boardsByCohortProvider =
    FutureProvider.family<List<Board>, int>((ref, cohortId) {
  return ref.watch(boardRepositoryProvider).listBoards(cohortId: cohortId);
});

/// Builds the grouped, cross-cohort board list for staff viewing "기수 전체".
///
/// Fetches each role-scoped cohort's boards (operations → all institution
/// cohorts; instructor → assigned cohorts) via [_boardsByCohortProvider], then
/// partitions the results: cohort-scoped boards go under their cohort's group,
/// while institution-wide (null-cohort) boards — returned under EVERY cohort
/// query — are de-duplicated into a single leading [BoardGroup.institutionTitle]
/// group. Errors/loading from any dependency propagate through the AsyncValue.
Future<List<BoardGroup>> _buildBoardGroups(Ref ref) async {
  final options = await ref.watch(cohortOptionsProvider.future);

  // Institution-wide boards (cohort_id == null), de-duplicated across cohorts.
  final institutionBoards = <int, Board>{};
  final cohortGroups = <BoardGroup>[];

  for (final option in options) {
    final boards = await ref.watch(_boardsByCohortProvider(option.id).future);
    final scoped = <Board>[];
    for (final board in boards) {
      if (board.cohortId == null) {
        institutionBoards.putIfAbsent(board.id, () => board);
      } else if (board.cohortId == option.id) {
        scoped.add(board);
      }
      // Boards whose cohortId is non-null but != option.id are ignored here;
      // they'll be attributed to their own cohort's query.
    }
    if (scoped.isNotEmpty) {
      cohortGroups.add(BoardGroup(title: option.name, boards: scoped));
    }
  }

  return [
    if (institutionBoards.isNotEmpty)
      BoardGroup(
        title: BoardGroup.institutionTitle,
        boards: institutionBoards.values.toList(),
        isInstitution: true,
      ),
    ...cohortGroups,
  ];
}

/// Grouped board list for the community screen. When staff view "기수 전체" it
/// aggregates across cohorts (see [_buildBoardGroups]); otherwise it wraps the
/// single-scope [boardListProvider] result in one unlabeled group so the screen
/// can render both modes uniformly.
final groupedBoardListProvider = FutureProvider<List<BoardGroup>>((ref) async {
  if (_isStaffAllCohorts(ref)) {
    return _buildBoardGroups(ref);
  }
  final boards = await ref.watch(boardListProvider.future);
  return [BoardGroup(title: '', boards: boards)];
});

/// Grouped board list for the management screen. Same aggregation as
/// [groupedBoardListProvider] but sourced so management mutations (which
/// refresh [boardManagementProvider]) keep the single-cohort view authoritative.
final groupedBoardManagementProvider =
    FutureProvider<List<BoardGroup>>((ref) async {
  if (_isStaffAllCohorts(ref)) {
    return _buildBoardGroups(ref);
  }
  final boards = await ref.watch(boardManagementProvider.future);
  return [BoardGroup(title: '', boards: boards)];
});

/// Invalidates the per-cohort board cache so the next grouped read refetches.
/// Called after a management mutation so the aggregated view reflects changes.
void invalidateGroupedBoards(Ref ref) {
  ref.invalidate(_boardsByCohortProvider);
}

/// ─────────────────────────────────────────────────────────────────────────
/// Boards (community entry tabs)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the boards visible to the current user. The community screen renders
/// one tab per board.
///
/// For staff (operations / instructors) the list is scoped to the globally
/// selected cohort ([selectedCohortProvider]); switching that nav cohort
/// rebuilds this provider. Students keep backend-default (own-cohort) scoping.
class BoardListNotifier extends AsyncNotifier<List<Board>> {
  @override
  Future<List<Board>> build() {
    // Watch the resolved scope so a nav-cohort change rebuilds the list.
    final cohortId = _cohortScopeFor(ref);
    return _fetch(cohortId);
  }

  Future<List<Board>> _fetch(int? cohortId) =>
      ref.read(boardRepositoryProvider).listBoards(cohortId: cohortId);

  Future<void> refresh() async {
    final cohortId = _cohortScopeFor(ref);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(cohortId));
  }
}

final boardListProvider =
    AsyncNotifierProvider<BoardListNotifier, List<Board>>(
  BoardListNotifier.new,
);

/// Notice-only board list, derived from [boardListProvider] by keeping boards
/// whose free-form `type` is `notice`. Powers the dedicated 공지사항 tab so it
/// shows ONLY notice content, separate from the general 커뮤니티 tab. Reuses the
/// same fetch (no extra network call) and inherits its loading/error states.
final noticeBoardListProvider = FutureProvider<List<Board>>((ref) async {
  final boards = await ref.watch(boardListProvider.future);
  return boards.where((b) => b.type == 'notice').toList();
});

/// ─────────────────────────────────────────────────────────────────────────
/// Posts within a board (search-aware)
/// ─────────────────────────────────────────────────────────────────────────

/// Arguments identifying which post list to load.
class PostListArgs {
  const PostListArgs({required this.boardId, this.search});

  final int boardId;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is PostListArgs &&
      other.boardId == boardId &&
      other.search == search;

  @override
  int get hashCode => Object.hash(boardId, search);
}

/// Loads posts for a board (pinned first, server-ordered).
///
/// Family argument is captured in [args] by the provider factory — Riverpod
/// 3.x non-codegen notifiers don't receive the argument in [build].
class PostListNotifier extends AsyncNotifier<List<Post>> {
  PostListNotifier(this.args);

  final PostListArgs args;

  @override
  Future<List<Post>> build() => _fetch();

  Future<List<Post>> _fetch() async {
    final page = await ref.read(boardRepositoryProvider).listPosts(
          boardId: args.boardId,
          search: args.search,
        );
    return page.posts;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Optimistically drops [postId] from the list (used after a delete on the
  /// detail screen so the list reflects the change without a round-trip).
  void removeLocally(int postId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((p) => p.id != postId).toList());
  }
}

final postListProvider = AsyncNotifierProvider.family<PostListNotifier,
    List<Post>, PostListArgs>(
  PostListNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Single post detail
/// ─────────────────────────────────────────────────────────────────────────

/// Loads a single post by id (and bumps its view count server-side).
final postDetailProvider =
    FutureProvider.family.autoDispose<Post, int>((ref, postId) async {
  return ref.read(boardRepositoryProvider).getPost(postId);
});

/// ─────────────────────────────────────────────────────────────────────────
/// Comments for a post
/// ─────────────────────────────────────────────────────────────────────────

/// Loads + mutates the comment thread for a post, with optimistic removal.
class CommentListNotifier extends AsyncNotifier<List<Comment>> {
  CommentListNotifier(this.postId);

  final int postId;

  @override
  Future<List<Comment>> build() => _fetch();

  Future<List<Comment>> _fetch() =>
      ref.read(boardRepositoryProvider).listComments(postId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Posts a comment then refreshes the thread. Throws [BoardException] on
  /// failure so the caller can surface it.
  Future<void> add({
    required String content,
    bool isAnonymous = false,
  }) async {
    await ref.read(boardRepositoryProvider).createComment(
          postId: postId,
          content: content,
          isAnonymous: isAnonymous,
        );
    await refresh();
  }

  /// Edits a comment's content then refreshes the thread. Throws
  /// [BoardException] on failure so the caller can surface it.
  Future<void> edit(int commentId, String content) async {
    await ref.read(boardRepositoryProvider).updateComment(commentId, content);
    await refresh();
  }

  /// Deletes a comment, optimistically removing it from the thread first.
  Future<void> remove(int commentId) async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncData(previous.where((c) => c.id != commentId).toList());
    }
    try {
      await ref.read(boardRepositoryProvider).deleteComment(commentId);
    } catch (e) {
      // Roll back on failure so the UI stays truthful.
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}

final commentListProvider = AsyncNotifierProvider.family<CommentListNotifier,
    List<Comment>, int>(
  CommentListNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Compose / submit a post
/// ─────────────────────────────────────────────────────────────────────────

/// Form state for the post-write screen.
class PostFormState {
  const PostFormState({
    this.title = '',
    this.content = '',
    this.isAnonymous = false,
    this.isPrivate = false,
    this.attachments = const [],
    this.isSubmitting = false,
    this.isUploading = false,
    this.error,
    this.created,
    this.editingPostId,
  });

  final String title;
  final String content;
  final bool isAnonymous;
  final bool isPrivate;
  final List<PostAttachment> attachments;
  final bool isSubmitting;
  final bool isUploading;
  final String? error;

  /// Non-null once the post is created/updated (drives navigation away from
  /// the form).
  final Post? created;

  /// When non-null the form is editing an existing post (PATCH) rather than
  /// composing a new one (POST).
  final int? editingPostId;

  bool get isEditing => editingPostId != null;
  bool get isValid => title.trim().isNotEmpty && content.trim().isNotEmpty;
  bool get isBusy => isSubmitting || isUploading;

  PostFormState copyWith({
    String? title,
    String? content,
    bool? isAnonymous,
    bool? isPrivate,
    List<PostAttachment>? attachments,
    bool? isSubmitting,
    bool? isUploading,
    String? error,
    bool clearError = false,
    Post? created,
    int? editingPostId,
  }) {
    return PostFormState(
      title: title ?? this.title,
      content: content ?? this.content,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isPrivate: isPrivate ?? this.isPrivate,
      attachments: attachments ?? this.attachments,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
      created: created ?? this.created,
      editingPostId: editingPostId ?? this.editingPostId,
    );
  }
}

/// Drives the post-compose form for a given board (captured in [boardId]).
class PostFormNotifier extends Notifier<PostFormState> {
  PostFormNotifier(this.boardId);

  final int boardId;

  @override
  PostFormState build() => const PostFormState();

  /// Seeds the form from an existing [post] so the write screen can be reused
  /// in edit mode. Anonymity/private flags are immutable after creation, so the
  /// edit form only changes title/content/attachments.
  void loadForEdit(Post post) {
    state = PostFormState(
      title: post.title,
      content: post.content,
      isAnonymous: post.isAnonymous,
      isPrivate: post.isPrivate,
      attachments: post.attachments,
      editingPostId: post.id,
    );
  }

  void setTitle(String v) => state = state.copyWith(title: v, clearError: true);
  void setContent(String v) =>
      state = state.copyWith(content: v, clearError: true);
  void setAnonymous(bool v) => state = state.copyWith(isAnonymous: v);
  void setPrivate(bool v) => state = state.copyWith(isPrivate: v);

  /// Adds an already-resolved attachment.
  void addAttachment(PostAttachment attachment) {
    state = state.copyWith(
      attachments: [...state.attachments, attachment],
    );
  }

  void removeAttachment(String fileKey) {
    state = state.copyWith(
      attachments:
          state.attachments.where((a) => a.fileKey != fileKey).toList(),
    );
  }

  /// Uploads [bytes] via presign → S3, then registers the resulting attachment.
  /// Surfaces errors through [PostFormState.error] rather than throwing.
  Future<void> uploadAttachment({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    state = state.copyWith(isUploading: true, clearError: true);
    try {
      final repo = ref.read(boardRepositoryProvider);
      final presign = await repo.presignPostAttachment(
        fileName: fileName,
        contentType: contentType,
      );
      await repo.uploadToPresignedUrl(
        uploadUrl: presign.uploadUrl,
        bytes: bytes,
        contentType: contentType,
      );
      state = state.copyWith(
        isUploading: false,
        attachments: [
          ...state.attachments,
          PostAttachment(
            fileKey: presign.fileKey,
            fileName: fileName,
            contentType: contentType,
            size: bytes.length,
          ),
        ],
      );
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
    }
  }

  /// Submits the post. Prevents double submission via
  /// [PostFormState.isSubmitting]. Creates (POST) or, when [PostFormState.isEditing]
  /// is set, updates (PATCH). On success sets [PostFormState.created] so the
  /// screen can navigate.
  Future<void> submit() async {
    if (!state.isValid || state.isBusy) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = ref.read(boardRepositoryProvider);
      final Post post;
      final editingId = state.editingPostId;
      if (editingId != null) {
        post = await repo.updatePost(
          editingId,
          title: state.title.trim(),
          content: state.content.trim(),
          attachments: state.attachments,
        );
      } else {
        post = await repo.createPost(
          boardId: boardId,
          title: state.title.trim(),
          content: state.content.trim(),
          isAnonymous: state.isAnonymous,
          isPrivate: state.isPrivate,
          attachments: state.attachments,
        );
      }
      state = state.copyWith(isSubmitting: false, created: post);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final postFormProvider =
    NotifierProvider.family<PostFormNotifier, PostFormState, int>(
  PostFormNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Cohort range parsing + batch-create support (board target cohorts)
/// ─────────────────────────────────────────────────────────────────────────

/// One resolved cohort the creator wants a board for: the cohort id plus a
/// user-facing label used to prefix the board name.
class BoardCohortTarget {
  const BoardCohortTarget({required this.cohortId, required this.cohortName});

  final int cohortId;
  final String cohortName;
}

/// Outcome of parsing a printer-page-style cohort range (e.g. `"1,2,5-7"`).
///
/// [numbers] are the distinct cohort *numbers* the user typed (ascending,
/// de-duplicated). [invalidTokens] are tokens that couldn't be parsed at all
/// (e.g. `"a"`, `"3-"`); the dialog surfaces them so the user can fix typos.
class CohortRange {
  const CohortRange({required this.numbers, required this.invalidTokens});

  final List<int> numbers;
  final List<String> invalidTokens;

  bool get isEmpty => numbers.isEmpty;
  bool get hasInvalid => invalidTokens.isNotEmpty;
}

/// Parses a printer-page-style cohort range string into distinct, ordered
/// cohort numbers.
///
/// Accepts comma/space-separated single numbers and `a-b` ranges, e.g.
/// `"1,2,5-7"` → `[1, 2, 5, 6, 7]`. Reversed ranges (`"7-5"`) are normalized.
/// Each unparseable token is collected into [CohortRange.invalidTokens] rather
/// than aborting, so a single typo doesn't discard the rest. Ranges are capped
/// at a sane span to avoid accidental huge expansions.
CohortRange parseCohortRange(String raw) {
  const maxSpan = 200; // guardrail against e.g. "1-99999"
  final numbers = <int>{};
  final invalid = <String>[];

  for (final part in raw.split(RegExp(r'[,\s]+'))) {
    final token = part.trim();
    if (token.isEmpty) continue;

    if (token.contains('-')) {
      final bounds = token.split('-');
      if (bounds.length != 2) {
        invalid.add(token);
        continue;
      }
      final a = int.tryParse(bounds[0].trim());
      final b = int.tryParse(bounds[1].trim());
      if (a == null || b == null || a < 1 || b < 1) {
        invalid.add(token);
        continue;
      }
      final lo = a <= b ? a : b;
      final hi = a <= b ? b : a;
      if (hi - lo > maxSpan) {
        invalid.add(token);
        continue;
      }
      for (var n = lo; n <= hi; n++) {
        numbers.add(n);
      }
    } else {
      final n = int.tryParse(token);
      if (n == null || n < 1) {
        invalid.add(token);
        continue;
      }
      numbers.add(n);
    }
  }

  final sorted = numbers.toList()..sort();
  return CohortRange(numbers: sorted, invalidTokens: invalid);
}

/// A single board that failed to create during a batch run.
class BatchCreateFailure {
  const BatchCreateFailure({required this.target, required this.message});

  final BoardCohortTarget target;
  final String message;
}

/// Summary of a [BoardManagementNotifier.createBatch] run.
class BatchCreateResult {
  const BatchCreateResult({required this.created, required this.failures});

  final List<Board> created;
  final List<BatchCreateFailure> failures;

  int get createdCount => created.length;
  int get failureCount => failures.length;
  bool get allSucceeded => failures.isEmpty;
}

/// ─────────────────────────────────────────────────────────────────────────
/// Board management (운영팀 · 강사)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads + mutates the full board list for the management screen. Create /
/// update / delete each re-fetch so the table stays authoritative; the
/// student-facing [boardListProvider] is invalidated alongside so its tabs
/// pick up the change on next view.
class BoardManagementNotifier extends AsyncNotifier<List<Board>> {
  @override
  Future<List<Board>> build() {
    // Staff-only screen: scope to the globally selected cohort so the table
    // shows that cohort's boards. Watching rebuilds on a nav-cohort change.
    final cohortId = _cohortScopeFor(ref);
    return _fetch(cohortId);
  }

  Future<List<Board>> _fetch(int? cohortId) =>
      ref.read(boardRepositoryProvider).listBoards(cohortId: cohortId);

  Future<void> refresh() async {
    final cohortId = _cohortScopeFor(ref);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(cohortId));
  }

  void _invalidateStudentList() {
    ref.invalidate(boardListProvider);
    // The grouped/aggregated views read a per-cohort cache; drop it so the
    // "기수 전체" community + management lists pick up the mutation.
    invalidateGroupedBoards(ref);
  }

  /// Creates a board, then refreshes. Throws [BoardException] on failure so the
  /// dialog can surface it without leaving a half-applied UI.
  Future<Board> create({
    required String name,
    required String type,
    int? cohortId,
    String? description,
    bool allowAnonymous = false,
    bool allowPrivatePost = false,
    String visibility = 'cohort',
  }) async {
    final board = await ref.read(boardRepositoryProvider).createBoard(
          name: name,
          type: type,
          cohortId: cohortId,
          description: description,
          allowAnonymous: allowAnonymous,
          allowPrivatePost: allowPrivatePost,
          visibility: visibility,
        );
    await refresh();
    _invalidateStudentList();
    return board;
  }

  /// Batch-creates one board per [targets] entry, then refreshes once.
  ///
  /// The backend models a board as belonging to a SINGLE cohort (`cohort_id`),
  /// so a multi/range cohort selection from the create dialog is fanned out into
  /// one `POST /boards/` per cohort. Each board's name is prefixed with its
  /// cohort label (e.g. `[1기] 자유게시판`) so the boards stay distinguishable.
  ///
  /// Returns a [BatchCreateResult] summarizing successes and per-target
  /// failures; it never throws for a partial failure so the dialog can report
  /// "x개 생성, y개 실패" without losing the boards that did succeed. A failure to
  /// refresh afterwards is swallowed (the created boards still exist).
  Future<BatchCreateResult> createBatch({
    required List<BoardCohortTarget> targets,
    required String baseName,
    required String type,
    String? description,
    bool allowAnonymous = false,
    bool allowPrivatePost = false,
  }) async {
    final repo = ref.read(boardRepositoryProvider);
    final created = <Board>[];
    final failures = <BatchCreateFailure>[];

    for (final target in targets) {
      final name = '[${target.cohortName}] $baseName';
      try {
        final board = await repo.createBoard(
          name: name,
          type: type,
          cohortId: target.cohortId,
          description: description,
          allowAnonymous: allowAnonymous,
          allowPrivatePost: allowPrivatePost,
          visibility: 'cohort',
        );
        created.add(board);
      } on BoardException catch (e) {
        failures.add(BatchCreateFailure(target: target, message: e.message));
      }
    }

    if (created.isNotEmpty) {
      await refresh();
      _invalidateStudentList();
    }
    return BatchCreateResult(created: created, failures: failures);
  }

  /// Updates a board, then refreshes.
  Future<Board> edit(
    int boardId, {
    String? name,
    String? description,
    bool? allowAnonymous,
    bool? allowPrivatePost,
    String? visibility,
  }) async {
    final board = await ref.read(boardRepositoryProvider).updateBoard(
          boardId,
          name: name,
          description: description,
          allowAnonymous: allowAnonymous,
          allowPrivatePost: allowPrivatePost,
          visibility: visibility,
        );
    await refresh();
    _invalidateStudentList();
    return board;
  }

  /// Deletes a board, optimistically removing it from the table first and
  /// rolling back on failure.
  Future<void> remove(int boardId) async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncData(previous.where((b) => b.id != boardId).toList());
    }
    try {
      await ref.read(boardRepositoryProvider).deleteBoard(boardId);
      _invalidateStudentList();
    } catch (e) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}

final boardManagementProvider =
    AsyncNotifierProvider<BoardManagementNotifier, List<Board>>(
  BoardManagementNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Post management actions (pin / author-identity reveal)
/// ─────────────────────────────────────────────────────────────────────────

/// Stateless action helper for the post-detail management controls. It calls
/// the repository and invalidates the affected providers so the detail + the
/// originating board list both refresh. Errors propagate as [BoardException].
class PostManager {
  PostManager(this.ref);

  final Ref ref;

  /// Toggles the pinned state of [post] (운영팀 · 강사). Refreshes the detail and
  /// the board's post list so the pin badge + ordering update.
  Future<Post> togglePin(Post post) async {
    final updated = await ref
        .read(boardRepositoryProvider)
        .pinPost(post.id, pinned: !post.isPinned);
    ref.invalidate(postDetailProvider(post.id));
    ref
        .read(postListProvider(PostListArgs(boardId: post.boardId)).notifier)
        .refresh();
    return updated;
  }

  /// Reveals the real author of an anonymous [postId] via the audited endpoint
  /// (운영팀 only). [reason] must be non-empty and is logged server-side.
  Future<AuthorIdentity> revealAuthor(int postId, String reason) {
    return ref.read(boardRepositoryProvider).getAuthorIdentity(postId, reason);
  }
}

final postManagerProvider = Provider<PostManager>(PostManager.new);
