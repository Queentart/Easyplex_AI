@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
REM 이 스크립트가 있는 폴더(=first/)로 이동
cd /d "%~dp0"

echo ============================================================
echo   동아AI랩 데모 서버 + Cloudflare 터널 시작
echo ============================================================
echo.

REM --- 0) Docker 실행 확인 -------------------------------------------------
docker info >nul 2>nul
if errorlevel 1 (
  echo [오류] Docker가 실행 중이 아닙니다. Docker Desktop을 먼저 켜고 다시 실행하세요.
  echo.
  pause
  exit /b 1
)

REM --- 1) 풀스택 컨테이너 기동 (이미 떠 있으면 그대로 유지) ----------------
echo [1/2] Docker 컨테이너 기동 중...
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
if errorlevel 1 (
  echo.
  echo [오류] 컨테이너 기동 실패. 위 메시지를 확인하세요.
  pause
  exit /b 1
)

echo.
echo [대기] 백엔드가 준비될 때까지 잠시 기다립니다... (약 10초)
timeout /t 10 /nobreak >nul

REM --- 2) cloudflared 경로 확인 (PATH -> winget Links 순) ------------------
set "CF=cloudflared"
where cloudflared >nul 2>nul
if errorlevel 1 (
  set "CF=%LOCALAPPDATA%\Microsoft\WinGet\Links\cloudflared.exe"
)
if not exist "!CF!" if "!CF!"=="cloudflared" goto :run
if not exist "!CF!" (
  echo [오류] cloudflared 를 찾을 수 없습니다. 설치 여부를 확인하세요:
  echo        winget install --id Cloudflare.cloudflared
  pause
  exit /b 1
)

:run
echo.
echo ============================================================
echo  [2/2] 터널을 엽니다.
echo  아래에 표시되는 https://....trycloudflare.com 주소를
echo  팀원에게 공유하세요.
echo.
echo  * 이 창을 닫으면 공유가 중단됩니다 (창을 켜둔 채로 두세요).
echo  * 끌 때 컨테이너까지 내리려면 같은 폴더의  터널_중지.bat  실행.
echo ============================================================
echo.
"!CF!" tunnel --url http://localhost:8080

endlocal
