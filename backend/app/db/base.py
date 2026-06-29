# 이 파일은 Alembic의 env.py에서 모든 모델을 한 번에 import하기 위한 진입점입니다.
# Base 객체와 프로젝트 내 모든 모델들을 이곳에서 명시적으로 import 해두어야, 
# Alembic이 메타데이터를 올바르게 인식하고 마이그레이션 스크립트를 생성합니다.

from app.db.base_class import Base

from app.models.auth import User
from app.models.student import Student
from app.models.attendance import Attendance
from app.models.assignment import Assignment, AssignmentVector
from app.models.counseling import CounselingLog
from app.models.executive import DashboardMetric, AuditLog
from app.models.equipment import Equipment
from app.models.tech_task import TechTask
from app.models.instructor_models import CourseMaterial, TrainingLog, MentoringLog, ChatMessage
from app.models.faq import FAQItem
from app.models.ops import OpsTicket
from app.models.tech_support_chat import TechTicket, TechMessage
from app.models.announcement import Announcement
from app.models.curriculum import CurriculumStep
from app.models.notification import Notification
from app.models.intranet_message import IntranetMessage