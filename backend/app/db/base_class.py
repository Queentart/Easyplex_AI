from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    """
    모든 SQLAlchemy 모델이 상속받을 기본 Base 클래스입니다.
    Alembic은 이 클래스의 metadata를 참조하여 마이그레이션을 생성합니다.
    """
    pass
