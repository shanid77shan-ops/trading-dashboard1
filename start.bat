@echo off
echo Starting AI Trading Dashboard...

:: Start backend in a new window
start "Backend API" cmd /k "cd /d %~dp0 && python api.py"

:: Wait a moment for backend to start
timeout /t 2 /nobreak > nul

:: Start frontend in a new window
start "Frontend" cmd /k "cd /d %~dp0 && npm start"

echo Done! Opening in a few seconds...
