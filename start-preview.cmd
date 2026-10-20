@echo off
cd /d "%~dp0"
echo Open http://127.0.0.1:4173/ in your browser.
echo This serves static UI files only. No backend or database.
py -m http.server 4173 --bind 127.0.0.1 --directory dist
pause
