import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../widgets/mock_demo_banner.dart';

/// Operations · 서버 로그 / 라이브 트레이스 (MOCK-ONLY).
///
/// Faithful to the `server_logs_live_traces_dashboard` Stitch mockup: a
/// terminal-style live log feed with INFO / WARN / ERROR level filter chips,
/// timestamps, source tags and a grep-style search box.
///
/// ── DATA SOURCE ────────────────────────────────────────────────────────────
/// EVERY log line is HARD-CODED demo data. There is no `/system/logs` endpoint
/// (nor a `WS /system/logs/ws` stream) yet. Filtering happens entirely
/// client-side over the in-memory `_mockLogs` list. See the repository seam at
/// the bottom of this file for the future wiring point. A visible "데모 데이터"
/// banner flags the mock state.
class ServerLogsScreen extends StatefulWidget {
  const ServerLogsScreen({super.key});

  static const String routePath = '/ops/logs';

  @override
  State<ServerLogsScreen> createState() => _ServerLogsScreenState();
}

class _ServerLogsScreenState extends State<ServerLogsScreen> {
  // Local-only filter state (no network).
  _LogLevel? _level; // null == 전체
  String _query = '';

  List<_LogEntry> get _filtered {
    return _mockLogs.where((e) {
      if (_level != null && e.level != _level) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final hit = e.message.toLowerCase().contains(q) ||
            e.source.toLowerCase().contains(q);
        if (!hit) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filtered;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.md),
          const MockDemoBanner(),
          const SizedBox(height: AppSpacing.lg),
          _FilterBar(
            level: _level,
            query: _query,
            onLevelChanged: (l) => setState(() => _level = l),
            onQueryChanged: (q) => setState(() => _query = q),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: EdgeInsets.zero,
            child: logs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: EmptyState(
                      title: '일치하는 로그가 없습니다',
                      description: '필터 또는 검색어를 변경해 보세요.',
                      icon: Icons.search_off_outlined,
                    ),
                  )
                : _LogTerminal(entries: logs),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('서버 로그 · 라이브 트레이스', style: AppTypography.headlineMd),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '실시간 시스템 진단과 AI 에이전트 실행 추적을 확인하세요.',
          style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Filter bar — level chips + grep search (local only)
/// ───────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.level,
    required this.query,
    required this.onLevelChanged,
    required this.onQueryChanged,
  });

  final _LogLevel? level;
  final String query;
  final ValueChanged<_LogLevel?> onLevelChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'grep 필터 (예: req_id, 에러 코드)',
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _LevelChip(
                label: '전체',
                selected: level == null,
                onSelected: () => onLevelChanged(null),
              ),
              for (final l in _LogLevel.values)
                _LevelChip(
                  label: l.label,
                  selected: level == l,
                  color: l.color,
                  onSelected: () => onLevelChanged(l),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: AppTypography.labelMd.copyWith(
        color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
      ),
      selectedColor: accent,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
        side: BorderSide(
          color: selected ? accent : AppColors.outlineVariant,
        ),
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Terminal-style log feed
/// ───────────────────────────────────────────────────────────────────────────

class _LogTerminal extends StatelessWidget {
  const _LogTerminal({required this.entries});

  final List<_LogEntry> entries;

  // Dark terminal palette (local constants; intentionally raw to read as a
  // console surface, distinct from the light app chrome).
  static const _bg = Color(0xFF111827);
  static const _bar = Color(0xFF0B1220);
  static const _muted = Color(0xFF6B7280);
  static const _text = Color(0xFFD1D5DB);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        color: _bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar with the traffic-light dots + LIVE indicator.
            Container(
              color: _bar,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const _Dot(Color(0xFFEF4444)),
                  const SizedBox(width: AppSpacing.xs),
                  const _Dot(Color(0xFFEAB308)),
                  const SizedBox(width: AppSpacing.xs),
                  const _Dot(Color(0xFF22C55E)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'syslog · tail -f',
                    style: AppTypography.labelSm.copyWith(color: _muted),
                  ),
                  const Spacer(),
                  const Icon(Icons.fiber_manual_record,
                      size: 12, color: Color(0xFF22C55E)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'LIVE',
                    style: AppTypography.labelSm
                        .copyWith(color: const Color(0xFF22C55E)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in entries) _LogLine(entry: e, textColor: _text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry, required this.textColor});

  final _LogEntry entry;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isError = entry.level == _LogLevel.error;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isError ? const Color(0x33B91C1C) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: isError
            ? const Border(left: BorderSide(color: Color(0xFFEF4444), width: 2))
            : null,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('[${entry.time}]',
              style: mono.copyWith(color: const Color(0xFF6B7280))),
          Text('[${entry.level.label}]',
              style: mono.copyWith(
                  color: entry.level.color, fontWeight: FontWeight.w600)),
          Text('[${entry.source}]',
              style: mono.copyWith(color: const Color(0xFF93C5FD))),
          Text(entry.message, style: mono.copyWith(color: textColor)),
        ],
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Mock log model + data
/// ───────────────────────────────────────────────────────────────────────────

enum _LogLevel { info, warn, error }

extension _LogLevelX on _LogLevel {
  String get label => switch (this) {
        _LogLevel.info => 'INFO',
        _LogLevel.warn => 'WARN',
        _LogLevel.error => 'ERROR',
      };

  Color get color => switch (this) {
        _LogLevel.info => const Color(0xFF2DD4BF), // teal
        _LogLevel.warn => const Color(0xFFFACC15), // amber
        _LogLevel.error => const Color(0xFFEF4444), // red
      };
}

typedef _LogEntry = ({String time, _LogLevel level, String source, String message});

// MOCK: server log / live-trace lines. No `/system/logs` endpoint yet.
const _mockLogs = <_LogEntry>[
  (time: '14:22:00', level: _LogLevel.info, source: 'System', message: 'Server initialized and listening on port 8000'),
  (time: '14:22:01', level: _LogLevel.info, source: 'FastAPI', message: 'GET /api/v1/attendance 200 OK - 42ms'),
  (time: '14:22:05', level: _LogLevel.info, source: 'LangGraph', message: 'Agent invoking tool: fetch_student_records() req-9081a'),
  (time: '14:22:06', level: _LogLevel.warn, source: 'Model_API', message: 'High latency detected from LLM endpoint (1200ms)'),
  (time: '14:22:08', level: _LogLevel.error, source: 'DB_Conn', message: 'Connection timeout on worker node 3'),
  (time: '14:22:10', level: _LogLevel.info, source: 'LangGraph', message: 'Tool execution completed successfully.'),
  (time: '14:22:14', level: _LogLevel.info, source: 'FastAPI', message: 'POST /api/v1/auth/refresh 200 OK - 18ms'),
  (time: '14:22:19', level: _LogLevel.warn, source: 'Scheduler', message: 'User sync job queued behind 2 running jobs'),
];

// ── REPOSITORY SEAM ──────────────────────────────────────────────────────────
// TODO(backend): replace `_mockLogs` with a real source once log endpoints
// exist, e.g.:
//
//   final repo = SystemLogsRepository(dio);
//   final page = await repo.getLogs(level: _level, query: _query); // GET /system/logs
//   // or subscribe to WS /system/logs/ws for the live tail.
//
// Move `_level` / `_query` into a Riverpod Notifier so the filter survives
// navigation, and stream new lines onto the terminal as they arrive.
