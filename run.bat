@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM ============================================================
REM  Easyplex AI - One-shot local run script (Windows)
REM  Brings up DB/Redis/MinIO, sets up the backend, then
REM  launches FastAPI + Flutter web. Just double-click this.
REM ============================================================

set "ROOT=%~dp0"
set "BACKEND=%ROOT%backend"
set "FRONTEND=%ROOT%frontend"

title Easyplex AI - Local Run

echo.
echo  ====================================================
echo   Easyplex AI Platform - Local Run
echo  ====================================================
echo.

REM --- [1/7] Docker check -------------------------------------------------
echo  [1/7] Checking Docker...
docker info > nul 2>&1
if errorlevel 1 (
    echo.
    echo  [ERROR] Docker Desktop is not running.
    echo          Start Docker Desktop and run this again.
    echo.
    pause
    exit /b 1
)
echo         OK

REM --- [2/7] Infra containers (PostgreSQL / Redis / MinIO) ----------------
echo  [2/7] Starting containers (PostgreSQL / Redis / MinIO)...
cd /d "%BACKEND%"
docker compose up -d
if errorlevel 1 (
    echo  [ERROR] docker compose up failed.
    pause
    exit /b 1
)

REM --- [3/7] Wait for PostgreSQL ------------------------------------------
echo  [3/7] Waiting for PostgreSQL...
set "RETRY=0"
:wait_db
docker compose exec -T db pg_isready -U dev -d dongaai_dev > nul 2>&1
if errorlevel 1 (
    set /a RETRY+=1
    if !RETRY! geq 24 (
        echo  [ERROR] PostgreSQL not ready after 120s.
        docker compose ps
        pause
        exit /b 1
    )
    timeout /t 5 /nobreak > nul
    goto wait_db
)
echo         Ready

REM --- [4/7] .env (copy dev defaults on first run) ------------------------
echo  [4/7] Checking .env...
if not exist "%BACKEND%\.env" (
    copy "%BACKEND%\.env.dev" "%BACKEND%\.env" > nul
    echo         Created .env from .env.dev  (local dev defaults)
) else (
    echo         Using existing .env
)

REM --- [5/7] Python venv + deps -------------------------------------------
echo  [5/7] Setting up Python venv...
if not exist "%BACKEND%\.venv\Scripts\python.exe" (
    echo         Creating venv...
    py -m venv "%BACKEND%\.venv" 2>nul || python -m venv "%BACKEND%\.venv"
    if errorlevel 1 (
        echo  [ERROR] venv creation failed. Install Python 3.11+ first.
        pause
        exit /b 1
    )
    call "%BACKEND%\.venv\Scripts\activate.bat"
    echo         Installing packages...
    pip install -q -r "%BACKEND%\requirements.txt"
) else (
    call "%BACKEND%\.venv\Scripts\activate.bat"
    echo         Using existing venv
)

REM --- [6/7] DB migrate + seed -------------------------------------------
echo  [6/7] Running Alembic migrations...
cd /d "%BACKEND%"
alembic upgrade head
if errorlevel 1 (
    echo  [ERROR] Migration failed. Check DB connection and .env.
    pause
    exit /b 1
)
echo         Seeding initial data...
python "%BACKEND%\scripts\seed_dev.py"

REM --- [7/7] Launch servers ----------------------------------------------
echo  [7/7] Launching servers...

REM Free port 8000 if taken, then start FastAPI WITHOUT --reload
REM (reload is unstable on Windows and can crash the worker).
powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"
start "FastAPI Backend" cmd /k "cd /d ""%BACKEND%"" && call .venv\Scripts\activate.bat && uvicorn app.main:app --host 0.0.0.0 --port 8000"

if exist "%FRONTEND%\pubspec.yaml" (
    powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"
    start "Flutter Frontend" cmd /k "cd /d ""%FRONTEND%"" && flutter run -d chrome --web-port 3000"
) else (
    echo  [INFO] No Flutter project at %FRONTEND% - skipping frontend.
)

echo.
echo  ====================================================
echo   Ready! Open:
echo    API      : http://localhost:8000
echo    API Docs : http://localhost:8000/docs
echo    MinIO    : http://localhost:9001  (minioadmin / minioadmin)
if exist "%FRONTEND%\pubspec.yaml" (
    echo    Flutter  : http://localhost:3000
)
echo  ====================================================
echo.
echo  Close the opened windows to stop the servers.
echo  To stop containers:  cd backend ^&^& docker compose down
echo.
pause
endlocal
