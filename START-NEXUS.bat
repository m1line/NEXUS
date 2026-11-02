@echo off
chcp 65001 >nul
cd /d "%~dp0backend"
if not exist ".env" (
  echo ERROR: backend\.env not found.
  echo Copy .env.example to .env and configure DATABASE_URL and SESSION_SECRET first.
  pause
  exit /b 1
)
if not exist "node_modules" (
  echo Installing server dependencies...
  call npm install
  if errorlevel 1 (echo npm install failed. Check that Node.js is installed and internet is available.& pause & exit /b 1)
)
echo Starting NEXUS Social...
call npm start
pause
