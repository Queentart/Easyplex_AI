# Easyplex AI — 교육 운영 플랫폼

정부 출석 앱·Zoom·Discord를 대체하는 통합 교육 운영 플랫폼.
출결·수업·과제·게시판·채팅·AI 에이전트를 하나로 묶었습니다.

## 기술 스택

- **Frontend**: Flutter (Web + iOS/Android 단일 코드베이스) · go_router · Riverpod · dio
- **Backend**: Python FastAPI (async) · SQLAlchemy 2.0 · Alembic · Celery
- **DB / 인프라**: PostgreSQL 16 · Redis · MinIO(S3 호환)
- **AI**: LLM 기반 AI Agent

## 사용자 역할

| 역할 | 설명 |
|------|------|
| `admin_ops` | 운영팀 |
| `tech_support` | 기술지원팀 |
| `instructor` | 강사진 |
| `student` | 수강생 |

## 빠른 시작 (Windows)

사전 준비물:
- **Docker Desktop** (실행 중이어야 함)
- **Python 3.11+**
- **Flutter SDK** (프론트엔드 실행 시)

저장소 루트의 **`run.bat` 더블클릭** 한 번이면 끝납니다. 다음을 자동으로 처리합니다:

1. Docker 컨테이너 기동 (PostgreSQL / Redis / MinIO)
2. DB 준비 대기 → `.env` 자동 생성(`backend/.env.dev` 복사)
3. Python 가상환경 생성 + 패키지 설치
4. Alembic 마이그레이션 + 초기 데이터 시드
5. FastAPI 백엔드 + Flutter 웹 실행

> Chrome이 없으면 `run.bat` 안의 `-d chrome`을 `-d edge` 등으로 바꾸세요.

### 접속 주소

| 서비스 | URL |
|--------|-----|
| API | http://localhost:8000 |
| API 문서 (Swagger) | http://localhost:8000/docs |
| Flutter 웹 | http://localhost:3000 |
| MinIO 콘솔 | http://localhost:9001 (minioadmin / minioadmin) |

### 데모 계정 (시드 데이터)

| 역할 | 이메일 | 비밀번호 |
|------|--------|----------|
| 운영팀 | `admin@dongaai.com` | `Admin1234!` |
| 수강생 | `student@dongaai.com` | `Student1234!` |
| 강사 | `instructor@dongaai.com` | `Instr1234!` |
| 기술지원 | `tech@dongaai.com` | `Tech1234!` |

## 수동 실행 (run.bat 없이)

```bash
# 1) 인프라 기동
cd backend
docker compose up -d

# 2) 백엔드 (가상환경 + 의존성)
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
copy .env.dev .env              # macOS/Linux: cp .env.dev .env
alembic upgrade head
python scripts/seed_dev.py      # 초기 데이터(최초 1회)
uvicorn app.main:app --host 0.0.0.0 --port 8000

# 3) 프론트엔드
cd ../frontend
flutter pub get
flutter run -d chrome --web-port 3000
```

> Windows에서 `uvicorn --reload`는 워커 크래시를 유발할 수 있어 사용하지 않습니다.

## 프로덕션 / 데모 배포

단일 호스트 풀스택 배포는 `docker-compose.prod.yml`을 사용합니다 (nginx · api · worker · db · redis · minio).

```bash
copy .env.prod.example .env.prod          # SECRET_KEY / AES_SECRET_KEY 등 채우기
docker compose -f docker-compose.prod.yml --env-file .env.prod up --build
```

기본 웹 포트는 `8080`이며 UI와 `/api`를 같은 origin에서 제공합니다.
외부에 데모를 공유하려면 (Windows) `터널_시작.bat` 실행 — Cloudflare 터널이
`https://….trycloudflare.com` 주소를 출력합니다. 중지는 `터널_중지.bat`.

> `.env.prod`(실제 시크릿)는 저장소에 포함하지 않습니다. `.env.prod.example`만 템플릿으로 제공됩니다.

## 프로젝트 구조

```
.
├── run.bat                  # 올인원 로컬 실행 스크립트
├── backend/                 # FastAPI 백엔드
│   ├── app/
│   │   ├── api/v1/          # 도메인별 라우터
│   │   ├── schemas/         # Pydantic 스키마
│   │   ├── services/        # 비즈니스 로직
│   │   ├── models/          # SQLAlchemy ORM 모델
│   │   ├── workers/         # Celery 태스크
│   │   └── core/            # 설정·DB·보안·의존성
│   ├── alembic/             # DB 마이그레이션
│   ├── scripts/             # 시드 스크립트
│   └── docker-compose.yml   # PostgreSQL / Redis / MinIO
└── frontend/                # Flutter 앱 (Web + 모바일)
    └── lib/
        ├── core/            # 라우터·테마·API 클라이언트
        ├── shared/          # 공용 위젯·모델
        └── features/        # 기능별 화면 + 상태관리
```

## 환경 변수

- `backend/.env.dev` — 로컬 개발용 기본값(localhost 더미). `run.bat`이 `.env`로 복사합니다.
- 프로덕션 시크릿은 저장소에 포함하지 않습니다(`.env`, `.env.prod`는 git 제외).
