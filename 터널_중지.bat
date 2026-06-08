@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================================
echo   동아AI랩 데모 서버 중지
echo ============================================================
echo.
echo 터널은 '터널_시작' 창을 닫으면 종료됩니다.
echo 이 스크립트는 Docker 컨테이너를 내립니다. (DB 데이터는 보존됩니다)
echo.

docker compose -f docker-compose.prod.yml --env-file .env.prod down

echo.
echo 완료. 다시 켜려면  터널_시작.bat  을 실행하세요.
pause
