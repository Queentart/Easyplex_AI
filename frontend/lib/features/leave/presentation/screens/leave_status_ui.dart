import '../../../../shared/widgets/status_chip.dart';
import '../../domain/leave_model.dart';

/// Resolves the [StatusChip] tone + Korean label for a leave-request status.
///
/// Centralised so the list and detail screens stay visually consistent and
/// nothing hardcodes colors (tones map onto design-system tokens inside
/// [StatusChip]).
({String label, StatusTone tone}) leaveStatusUi(LeaveStatus status) {
  return switch (status) {
    LeaveStatus.pending => (label: '대기', tone: StatusTone.warning),
    LeaveStatus.approved => (label: '승인', tone: StatusTone.success),
    LeaveStatus.rejected => (label: '반려', tone: StatusTone.danger),
    LeaveStatus.canceled => (label: '취소', tone: StatusTone.neutral),
  };
}
