"""
Demo seed — augments cohort id=1 with realistic data so the role dashboards
(Operations / Tech / Instructor / Student) show meaningful content.

Idempotent: every section guards on a unique marker (email, natural key, or
a count) and upserts / skips rather than duplicating. Safe to run repeatedly.

Run:
    .venv\\Scripts\\python.exe scripts\\seed_demo.py

Reuses the async-session + bcrypt hashing patterns from seed_dev.py and does
NOT touch the original 4 accounts created there.

Human-readable content (titles, names, reasons, messages) is Korean because it
is real app data; code/comments are English.
"""
import asyncio
import sys
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path

# backend/ on sys.path so app.* imports resolve.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import async_session_factory
from app.core.security import hash_password
from app.models.assignment import Assignment, Submission
from app.models.attendance import AttendanceRecord
from app.models.auth import User
from app.models.board import Board, ChatChannel, Comment, Post
from app.models.class_ import Class, MentoringLog
from app.models.inquiry import Inquiry, InquiryMessage, SoftwareLicense
from app.models.leave import LeaveRequest
from app.models.notification import Notification
from app.models.organization import Cohort, Institution, InstructorCohort

INSTITUTION_ID = 1
COHORT_ID = 1
KST = timezone(timedelta(hours=9))

DEMO_STUDENTS = [
    ("student2@dongaai.com", "박지민"),
    ("student3@dongaai.com", "최서연"),
    ("student4@dongaai.com", "정도윤"),
    ("student5@dongaai.com", "강하은"),
    ("student6@dongaai.com", "윤지호"),
    ("student7@dongaai.com", "임채원"),
]
STUDENT_PASSWORD = "Student1234!"


def aware(d: date, hour: int, minute: int = 0) -> datetime:
    """Build a tz-aware (KST) datetime from a date + time."""
    return datetime(d.year, d.month, d.day, hour, minute, tzinfo=KST)


async def get_existing(db: AsyncSession, model, **filters):
    stmt = select(model)
    for k, v in filters.items():
        stmt = stmt.where(getattr(model, k) == v)
    return (await db.execute(stmt.limit(1))).scalar_one_or_none()


async def seed_students(db: AsyncSession, inst_id: int) -> tuple[list[User], int]:
    """Create demo students assigned to cohort 1 (idempotent on email)."""
    students: list[User] = []
    inserted = 0
    for email, name in DEMO_STUDENTS:
        existing = await get_existing(db, User, email=email, institution_id=inst_id)
        if existing:
            students.append(existing)
            continue
        user = User(
            institution_id=inst_id,
            cohort_id=COHORT_ID,
            email=email,
            password_hash=hash_password(STUDENT_PASSWORD),
            name=name,
            role="student",
            is_active=True,
        )
        db.add(user)
        students.append(user)
        inserted += 1
    await db.flush()
    return students, inserted


async def assign_instructor(db: AsyncSession, instructor: User, admin: User) -> None:
    """Link the existing instructor to cohort 1 (idempotent)."""
    existing = await get_existing(
        db, InstructorCohort, instructor_id=instructor.id, cohort_id=COHORT_ID
    )
    if existing:
        return
    db.add(
        InstructorCohort(
            instructor_id=instructor.id,
            cohort_id=COHORT_ID,
            assigned_by=admin.id,
        )
    )
    await db.flush()


async def seed_attendance(db: AsyncSession, students: list[User]) -> int:
    """~3 weeks of weekday attendance with a realistic status mix.

    Idempotent via the (user_id, date) unique constraint — we skip any
    (user, date) already present.
    """
    today = date.today()
    # Build 15 most-recent weekdays (~3 weeks).
    weekdays: list[date] = []
    d = today
    while len(weekdays) < 15:
        if d.weekday() < 5:  # Mon-Fri
            weekdays.append(d)
        d -= timedelta(days=1)
    weekdays.reverse()

    inserted = 0
    # Deterministic per-student/day pattern so re-runs are stable.
    for s_idx, student in enumerate(students):
        for d_idx, day in enumerate(weekdays):
            key = (s_idx * 31 + d_idx) % 20
            if key == 0:
                kind, ci, co, late, early, note = (
                    "absent", None, None, None, None, "무단 결석",
                )
            elif key in (1, 2):
                kind, ci, co, late, early, note = (
                    "late", aware(day, 9, 25), aware(day, 18, 0), 25, None, "지각",
                )
            elif key == 3:
                kind, ci, co, late, early, note = (
                    "early_leave", aware(day, 9, 0), aware(day, 15, 30),
                    None, 150, "조퇴 (개인 사유)",
                )
            else:
                kind, ci, co, late, early, note = (
                    "present", aware(day, 8, 55), aware(day, 18, 0), None, None, None,
                )

            existing = await get_existing(
                db, AttendanceRecord, user_id=student.id, date=day
            )
            if existing:
                continue
            db.add(
                AttendanceRecord(
                    cohort_id=COHORT_ID,
                    user_id=student.id,
                    date=day,
                    check_in_at=ci,
                    check_out_at=co,
                    type=kind,
                    late_minutes=late,
                    early_leave_minutes=early,
                    import_source="manual",
                    note=note,
                )
            )
            inserted += 1
    await db.flush()
    return inserted


async def seed_assignments(
    db: AsyncSession, students: list[User], instructor: User
) -> tuple[int, int]:
    """4 assignments (past / soon / 2 future) + a subset of submissions."""
    today = date.today()
    specs = [
        ("[1주차] Python 기초 실습 제출",
         "변수, 조건문, 반복문을 활용한 미니 프로그램을 작성하여 제출하세요.",
         aware(today - timedelta(days=4), 23, 59), 100, "closed"),
        ("[2주차] 데이터 분석 과제",
         "주어진 CSV 데이터를 pandas로 분석하고 인사이트를 정리하세요.",
         aware(today + timedelta(days=1), 23, 59), 100, "open"),
        ("[3주차] 머신러닝 모델 구현",
         "scikit-learn으로 분류 모델을 학습시키고 성능을 평가하세요.",
         aware(today + timedelta(days=7), 23, 59), 100, "open"),
        ("[최종] 프로젝트 기획서 제출",
         "팀별 최종 프로젝트의 기획서를 작성하여 제출하세요.",
         aware(today + timedelta(days=14), 23, 59), 100, "open"),
    ]

    assignments: list[Assignment] = []
    a_inserted = 0
    for title, desc, due, max_score, status in specs:
        existing = await get_existing(db, Assignment, title=title, cohort_id=COHORT_ID)
        if existing:
            assignments.append(existing)
            continue
        a = Assignment(
            cohort_id=COHORT_ID,
            created_by=instructor.id,
            title=title,
            description=desc,
            due_date=due,
            allow_late_submission=True,
            max_score=max_score,
            status=status,
        )
        db.add(a)
        assignments.append(a)
        a_inserted += 1
    await db.flush()

    # Submissions only for the past-due assignment (assignments[0]).
    # Mix: graded, plain submitted, and missing (some students skip).
    past = assignments[0]
    sub_specs = [
        # (student_index, content, score, status)
        (0, "1주차 실습 과제 제출합니다. 깃허브 링크 포함.", 92, "reviewed"),
        (1, "조건문/반복문 예제 모두 구현했습니다.", 85, "reviewed"),
        (2, "제출합니다. 일부 미완성 부분 있습니다.", None, "submitted"),
        (3, "늦었지만 제출합니다.", 70, "reviewed"),
        # students[4], students[5] intentionally missing.
    ]
    s_inserted = 0
    for s_idx, content, score, status in sub_specs:
        if s_idx >= len(students):
            continue
        student = students[s_idx]
        existing = await get_existing(
            db, Submission, assignment_id=past.id, student_id=student.id
        )
        if existing:
            continue
        db.add(
            Submission(
                assignment_id=past.id,
                student_id=student.id,
                content=content,
                submitted_at=aware(today - timedelta(days=5), 22, 0),
                is_late=False,
                score=score,
                status=status,
            )
        )
        s_inserted += 1
    await db.flush()
    return a_inserted, s_inserted


async def seed_boards(
    db: AsyncSession, students: list[User], instructor: User, admin: User
) -> tuple[int, int, int]:
    """1-2 boards + ~6 posts (1 anonymous, 1 pinned) + a few comments."""
    board_specs = [
        ("질문 게시판", "question", "수업 관련 자유 질문 게시판입니다.", True),
        ("공지사항", "notice", "운영팀 공지 게시판입니다.", False),
    ]
    boards: list[Board] = []
    b_inserted = 0
    for name, btype, desc, anon in board_specs:
        existing = await get_existing(db, Board, name=name, cohort_id=COHORT_ID)
        if existing:
            boards.append(existing)
            continue
        b = Board(
            cohort_id=COHORT_ID,
            name=name,
            type=btype,
            description=desc,
            allow_anonymous=anon,
            allow_private_post=anon,
            visibility="cohort",
            created_by=admin.id if btype == "notice" else instructor.id,
        )
        db.add(b)
        boards.append(b)
        b_inserted += 1
    await db.flush()

    q_board, notice_board = boards[0], boards[1]
    # (board, author_id, title, content, anonymous, pinned)
    post_specs = [
        (notice_board, admin.id, "[필독] 2026 1기 오리엔테이션 안내",
         "3월 2일 오전 10시 본관 강의실에서 오리엔테이션을 진행합니다.", False, True),
        (q_board, instructor.id, "과제 제출 방식 안내",
         "과제는 깃허브 링크와 함께 제출해 주세요.", False, False),
        (q_board, students[0].id, "pandas 설치 오류 질문입니다",
         "pip install 시 오류가 발생합니다. 해결 방법이 궁금합니다.", False, False),
        (q_board, students[1].id, "조퇴 신청은 어디서 하나요?",
         "조퇴 신청 메뉴 위치를 알려주세요.", True, False),  # anonymous
        (q_board, students[2].id, "스터디 모집합니다",
         "주말 알고리즘 스터디 함께 하실 분 구합니다.", False, False),
        (q_board, students[3].id, "강의 자료 다운로드 문의",
         "지난 수업 자료는 어디서 받을 수 있나요?", False, False),
    ]
    posts: list[Post] = []
    p_inserted = 0
    for board, author_id, title, content, anon, pinned in post_specs:
        existing = await get_existing(db, Post, title=title, board_id=board.id)
        if existing:
            posts.append(existing)
            continue
        p = Post(
            board_id=board.id,
            author_id=author_id,
            title=title,
            content=content,
            is_anonymous=anon,
            is_pinned=pinned,
        )
        db.add(p)
        posts.append(p)
        p_inserted += 1
    await db.flush()

    # A few comments on the pandas-error post (posts[2]).
    comment_specs = [
        (posts[2], instructor.id, "가상환경을 활성화한 뒤 다시 시도해 보세요.", False),
        (posts[2], students[1].id, "저도 같은 오류였는데 파이썬 버전 문제였어요.", False),
        (posts[3], instructor.id, "좌측 메뉴 '조퇴 신청'에서 가능합니다.", False),
    ]
    c_inserted = 0
    for post, author_id, content, anon in comment_specs:
        # Guard on (post_id, author_id, content) to avoid dup on re-run.
        stmt = (
            select(Comment)
            .where(Comment.post_id == post.id)
            .where(Comment.author_id == author_id)
            .where(Comment.content == content)
            .limit(1)
        )
        if (await db.execute(stmt)).scalar_one_or_none():
            continue
        db.add(
            Comment(
                post_id=post.id,
                author_id=author_id,
                content=content,
                is_anonymous=anon,
            )
        )
        c_inserted += 1
    await db.flush()
    return b_inserted, p_inserted, c_inserted


async def seed_leave_requests(
    db: AsyncSession, students: list[User], instructor: User
) -> int:
    today = date.today()
    specs = [
        (students[0].id, "early_leave", today + timedelta(days=2), time(15, 0),
         "병원 진료 예약으로 조퇴를 신청합니다.", "pending", None, None),
        (students[1].id, "medical", today - timedelta(days=3), None,
         "독감으로 인한 병가를 신청합니다.", "approved", instructor.id,
         "진단서 확인 완료. 승인합니다."),
    ]
    inserted = 0
    for sid, ltype, tdate, stime, reason, status, rev_by, rev_comment in specs:
        existing = await get_existing(
            db, LeaveRequest, student_id=sid, target_date=tdate, type=ltype
        )
        if existing:
            continue
        lr = LeaveRequest(
            cohort_id=COHORT_ID,
            student_id=sid,
            type=ltype,
            target_date=tdate,
            start_time=stime,
            reason=reason,
            status=status,
            reviewed_by=rev_by,
            reviewed_at=aware(today - timedelta(days=2), 10, 0) if rev_by else None,
            review_comment=rev_comment,
        )
        db.add(lr)
        inserted += 1
    await db.flush()
    return inserted


async def seed_inquiries(
    db: AsyncSession, students: list[User], tech: User, admin: User
) -> tuple[int, int]:
    today = date.today()
    # (author, type, title, content, status, priority, assigned_to)
    specs = [
        (students[0].id, "tech_support", "Zoom 접속이 안 됩니다",
         "수업 시간에 Zoom 링크 클릭 시 오류가 발생합니다.",
         "in_progress", "high", tech.id),
        (students[1].id, "support_fund", "훈련장려금 지급 문의",
         "이번 달 훈련장려금이 입금되지 않았습니다.",
         "open", "urgent", None),
        (students[2].id, "attendance", "출결 정정 요청",
         "지난주 출석했는데 결석으로 처리되어 있습니다.",
         "resolved", "normal", admin.id),
    ]
    inquiries: list[Inquiry] = []
    i_inserted = 0
    for author_id, itype, title, content, status, priority, assigned in specs:
        existing = await get_existing(
            db, Inquiry, title=title, author_id=author_id
        )
        if existing:
            inquiries.append(existing)
            continue
        inq = Inquiry(
            cohort_id=COHORT_ID,
            author_id=author_id,
            type=itype,
            title=title,
            content=content,
            status=status,
            priority=priority,
            assigned_to=assigned,
            resolved_at=aware(today - timedelta(days=1), 16, 0)
            if status == "resolved" else None,
        )
        db.add(inq)
        inquiries.append(inq)
        i_inserted += 1
    await db.flush()

    # A couple of messages on the first (tech) inquiry.
    msg_specs = [
        (inquiries[0], students[0].id, "오류 화면 캡처도 첨부했습니다."),
        (inquiries[0], tech.id, "확인 중입니다. 브라우저 캐시를 삭제 후 다시 시도해 주세요."),
    ]
    m_inserted = 0
    for inq, sender_id, content in msg_specs:
        stmt = (
            select(InquiryMessage)
            .where(InquiryMessage.inquiry_id == inq.id)
            .where(InquiryMessage.sender_id == sender_id)
            .where(InquiryMessage.content == content)
            .limit(1)
        )
        if (await db.execute(stmt)).scalar_one_or_none():
            continue
        db.add(
            InquiryMessage(
                inquiry_id=inq.id,
                sender_id=sender_id,
                content=content,
            )
        )
        m_inserted += 1
    await db.flush()
    return i_inserted, m_inserted


async def seed_licenses(db: AsyncSession, admin: User) -> int:
    """2 software licenses (one expiring soon). encrypted_key/key_iv are BYTEA
    NOT NULL — demo uses placeholder bytes (no real encryption needed)."""
    today = date.today()
    specs = [
        ("ChatGPT Team", today - timedelta(days=300),
         today + timedelta(days=10), 30, "active", "월 구독, 곧 만료 예정"),
        ("GitHub Copilot", today - timedelta(days=60),
         today + timedelta(days=305), 50, "active", "연간 라이선스"),
    ]
    inserted = 0
    for name, issued, expires, seats, status, notes in specs:
        existing = await get_existing(db, SoftwareLicense, service_name=name,
                                      institution_id=INSTITUTION_ID)
        if existing:
            continue
        db.add(
            SoftwareLicense(
                institution_id=INSTITUTION_ID,
                service_name=name,
                encrypted_key=b"DEMO_ENCRYPTED_KEY_PLACEHOLDER",
                key_iv=b"DEMO_IV_16BYTES_",
                issued_at=issued,
                expires_at=expires,
                seat_count=seats,
                status=status,
                notes=notes,
                created_by=admin.id,
            )
        )
        inserted += 1
    await db.flush()
    return inserted


async def seed_mentoring(
    db: AsyncSession, students: list[User], instructor: User
) -> int:
    today = date.today()
    specs = [
        (students[0].id, today - timedelta(days=7),
         "진로 상담 진행. 데이터 엔지니어 직무에 관심.",
         "다음 멘토링까지 관련 포트폴리오 1건 준비하기로 함."),
        (students[4].id, today - timedelta(days=3),
         "최근 출석률 저하 관련 면담. 개인 사정 청취.",
         "주 1회 체크인 진행 예정."),
    ]
    inserted = 0
    for sid, sdate, content, follow in specs:
        existing = await get_existing(
            db, MentoringLog, student_id=sid, session_date=sdate,
            instructor_id=instructor.id
        )
        if existing:
            continue
        db.add(
            MentoringLog(
                cohort_id=COHORT_ID,
                instructor_id=instructor.id,
                student_id=sid,
                session_date=sdate,
                content=content,
                follow_up=follow,
            )
        )
        inserted += 1
    await db.flush()
    return inserted


async def seed_classes(db: AsyncSession, instructor: User) -> int:
    today = date.today()
    specs = [
        ("머신러닝 기초 - 분류 모델", today, time(10, 0), time(13, 0),
         "본관 301호", "scheduled"),
        ("데이터 시각화 실습", today + timedelta(days=2), time(14, 0),
         time(17, 0), "본관 302호", "scheduled"),
    ]
    inserted = 0
    for title, cdate, start, end, loc, status in specs:
        existing = await get_existing(
            db, Class, title=title, cohort_id=COHORT_ID, date=cdate
        )
        if existing:
            continue
        db.add(
            Class(
                cohort_id=COHORT_ID,
                instructor_id=instructor.id,
                title=title,
                date=cdate,
                start_time=start,
                end_time=end,
                location=loc,
                status=status,
            )
        )
        inserted += 1
    await db.flush()
    return inserted


async def seed_notifications(
    db: AsyncSession, students: list[User], admin: User, orig_student: User | None
) -> int:
    # (user_id, type, title, content, is_read)
    specs = [
        (students[0].id, "assignment_created", "새 과제가 등록되었습니다",
         "[2주차] 데이터 분석 과제가 등록되었습니다. 마감 임박!", False),
        (students[0].id, "feedback_received", "과제 피드백이 도착했습니다",
         "[1주차] Python 기초 실습 과제 채점이 완료되었습니다. (92점)", True),
        (students[1].id, "leave_approved", "조퇴 신청이 승인되었습니다",
         "병가 신청이 승인되었습니다.", False),
        (admin.id, "system", "신규 문의가 접수되었습니다",
         "긴급 우선순위 문의가 1건 접수되었습니다. (훈련장려금 지급 문의)", False),
        (admin.id, "attendance_warning", "출석 경고 대상 발생",
         "결석 누적 수강생이 발생했습니다. 확인이 필요합니다.", False),
    ]
    if orig_student is not None:
        specs.append(
            (orig_student.id, "assignment_created", "새 과제가 등록되었습니다",
             "[3주차] 머신러닝 모델 구현 과제가 등록되었습니다.", False)
        )
    inserted = 0
    for uid, ntype, title, content, is_read in specs:
        stmt = (
            select(Notification)
            .where(Notification.user_id == uid)
            .where(Notification.title == title)
            .where(Notification.content == content)
            .limit(1)
        )
        if (await db.execute(stmt)).scalar_one_or_none():
            continue
        db.add(
            Notification(
                user_id=uid,
                type=ntype,
                title=title,
                content=content,
                is_read=is_read,
                read_at=datetime.now(KST) if is_read else None,
            )
        )
        inserted += 1
    await db.flush()
    return inserted


async def seed_chat_channels(db: AsyncSession, inst_id: int) -> int:
    # (name, type) — cohort-scoped live chat channels. There is no in-app
    # create-channel endpoint yet, so these are seeded for the demo.
    specs = [
        ("1기 전체 채팅", "cohort"),
        ("머신러닝 기초 - 수업 채팅", "class"),
        ("자유 잡담방", "free"),
    ]
    inserted = 0
    for name, ctype in specs:
        existing = await get_existing(
            db, ChatChannel, name=name, cohort_id=COHORT_ID
        )
        if existing:
            continue
        db.add(
            ChatChannel(
                institution_id=inst_id,
                cohort_id=COHORT_ID,
                name=name,
                type=ctype,
                is_active=True,
            )
        )
        inserted += 1
    await db.flush()
    return inserted


async def seed() -> None:
    async with async_session_factory() as db:
        # Preconditions: seed_dev.py must have run (institution + 4 accounts).
        institution = await get_existing(db, Institution, id=INSTITUTION_ID)
        cohort = await get_existing(db, Cohort, id=COHORT_ID)
        if institution is None or cohort is None:
            print("  [ABORT] base data missing. Run seed_dev.py first.")
            return

        admin = await get_existing(db, User, email="admin@dongaai.com")
        instructor = await get_existing(db, User, email="instructor@dongaai.com")
        tech = await get_existing(db, User, email="tech@dongaai.com")
        orig_student = await get_existing(db, User, email="student@dongaai.com")
        if not (admin and instructor and tech):
            print("  [ABORT] base accounts missing. Run seed_dev.py first.")
            return

        # Ensure original student belongs to cohort 1 so its dashboard has data.
        if orig_student and orig_student.cohort_id != COHORT_ID:
            orig_student.cohort_id = COHORT_ID
            await db.flush()

        demo_students, stu_ins = await seed_students(db, institution.id)
        await assign_instructor(db, instructor, admin)

        # Include original student in attendance so its dashboard shows data.
        attendance_students = list(demo_students)
        if orig_student:
            attendance_students = [orig_student] + demo_students

        att = await seed_attendance(db, attendance_students)
        a_ins, s_ins = await seed_assignments(db, demo_students, instructor)
        b_ins, p_ins, c_ins = await seed_boards(db, demo_students, instructor, admin)
        leave_ins = await seed_leave_requests(db, demo_students, instructor)
        inq_ins, msg_ins = await seed_inquiries(db, demo_students, tech, admin)
        lic_ins = await seed_licenses(db, admin)
        ment_ins = await seed_mentoring(db, demo_students, instructor)
        cls_ins = await seed_classes(db, instructor)
        chat_ins = await seed_chat_channels(db, institution.id)
        notif_ins = await seed_notifications(db, demo_students, admin, orig_student)

        await db.commit()

        print("  Demo seed complete. Rows inserted this run:")
        print(f"    users (students)      : {stu_ins}")
        print(f"    attendance_records    : {att}")
        print(f"    assignments           : {a_ins}")
        print(f"    submissions           : {s_ins}")
        print(f"    boards                : {b_ins}")
        print(f"    posts                 : {p_ins}")
        print(f"    comments              : {c_ins}")
        print(f"    leave_requests        : {leave_ins}")
        print(f"    inquiries             : {inq_ins}")
        print(f"    inquiry_messages      : {msg_ins}")
        print(f"    software_licenses     : {lic_ins}")
        print(f"    mentoring_logs        : {ment_ins}")
        print(f"    classes               : {cls_ins}")
        print(f"    notifications         : {notif_ins}")

        # Print absolute totals for cohort 1 as a sanity / idempotency check.
        await print_totals(db)


async def print_totals(db: AsyncSession) -> None:
    student_count = (
        await db.execute(
            select(func.count())
            .select_from(User)
            .where(User.role == "student")
            .where(User.cohort_id == COHORT_ID)
        )
    ).scalar_one()
    counts = {
        "students(cohort1)": student_count,
        "attendance_records": await _count(db, AttendanceRecord),
        "assignments": await _count(db, Assignment, cohort_id=COHORT_ID),
        "submissions": await _count(db, Submission),
        "boards": await _count(db, Board, cohort_id=COHORT_ID),
        "posts": await _count(db, Post),
        "comments": await _count(db, Comment),
        "leave_requests": await _count(db, LeaveRequest),
        "inquiries": await _count(db, Inquiry),
        "inquiry_messages": await _count(db, InquiryMessage),
        "software_licenses": await _count(db, SoftwareLicense),
        "mentoring_logs": await _count(db, MentoringLog),
        "classes": await _count(db, Class),
        "chat_channels": await _count(db, ChatChannel, cohort_id=COHORT_ID),
        "notifications": await _count(db, Notification),
        "instructor_cohorts": await _count(db, InstructorCohort),
    }
    print("\n  Current DB totals (after run):")
    for k, v in counts.items():
        print(f"    {k:22s}: {v}")


async def _count(db: AsyncSession, model, **filters) -> int:
    stmt = select(func.count()).select_from(model)
    for k, v in filters.items():
        stmt = stmt.where(getattr(model, k) == v)
    return (await db.execute(stmt)).scalar_one()


if __name__ == "__main__":
    asyncio.run(seed())
