@echo off
echo Starting local server at http://localhost:8080/app/visualizer.html
cd /d "%~dp0"
python -m http.server 8080
pause