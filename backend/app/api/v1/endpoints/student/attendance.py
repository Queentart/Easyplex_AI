from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import Dict, Any
from datetime import date
from sqlalchemy.orm import selectinload

from app.api.deps import get_db, get_current_user
from app.models.auth import User
from app.models.student import Student
from app.models.attendance import Attendance, AttendanceStatus

router = APIRouter()

@router.get("/stats")
async def get_attendance_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    현재 로그인한 학생의 이번 달 출결 통계(지각, 결석, 조퇴, 출석률)를 반환합니다.
    """
    if current_user.role.value != "STUDENT":
        raise HTTPException(status_code=403, detail="학생만 조회 가능합니다.")

    # 1. 학생 정보 조회
    stmt = select(Student).where(Student.user_id == current_user.id)
    result = await db.execute(stmt)
    student = result.scalars().first()
    
    if not student:
        raise HTTPException(status_code=404, detail="학생 정보를 찾을 수 없습니다.")

    # 2. 이번 달 시작일/종료일 계산
    today = date.today()
    first_day = today.replace(day=1)
    
    # 3. 출결 데이터 카운트
    stmt = (
        select(Attendance.status, func.count(Attendance.id))
        .where(
            Attendance.student_id == student.id,
            Attendance.attendance_date >= first_day,
            Attendance.attendance_date <= today
        )
        .group_by(Attendance.status)
    )
    result = await db.execute(stmt)
    counts = dict(result.all())

    present = counts.get(AttendanceStatus.PRESENT, 0)
    lates = counts.get(AttendanceStatus.LATE, 0)
    absences = counts.get(AttendanceStatus.ABSENT, 0)
    early_leaves = counts.get(AttendanceStatus.EARLY_LEAVE, 0)
    excused = counts.get(AttendanceStatus.EXCUSED, 0)

    # 지각, 조퇴, 외출(Excused) 3번 = 결석 1번 (HRD-Net 기준 예시)
    # 여기서는 간단히 전체 출석 일수 대비 비율로 계산 (출석+결석+지각+조퇴+기타 = 총 수업일수)
    total_days = sum(counts.values())
    
    if total_days == 0:
        rate = 100
    else:
        # 간단한 참여율 계산 (PRESENT + LATE + EARLY_LEAVE 를 참여로 인정할지 여부)
        # 통상적으로 지각/조퇴도 참여로는 보지만, 페널티가 있을 수 있음.
        # 여기서는 단순히 결석이 아닌 경우 참여로 산정 (100 - 결석률)
        # 또는 (present + (lates+early_leaves)/2 ) / total_days 이런식으로 가능하지만
        # UI 표기를 위해 (총 일수 - 결석일수) / 총 일수 * 100
        attended = total_days - absences
        rate = int((attended / total_days) * 100)

    return {
        "lates": lates,
        "absences": absences,
        "earlyLeaves": early_leaves,
        "rate": rate
    }