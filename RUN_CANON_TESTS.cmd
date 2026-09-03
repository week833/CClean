@echo off
setlocal EnableExtensions DisableDelayedExpansion
for %%I in ("%~dp0.") do set "REPO_ROOT=%%~fI"
set "TEST_ROOT=%REPO_ROOT%\scripts\dstock_canon\tests"
if not exist "%TEST_ROOT%" (
  echo [ERROR] Contract test directory is missing: %TEST_ROOT%
  set "RC=2"
  goto :finish
)
set "PYTHON=%REPO_ROOT%\.venv\Scripts\python.exe"
if not exist "%PYTHON%" set "PYTHON=python"
set "PYTHONDONTWRITEBYTECODE=1"
set "PYTHONPATH=%REPO_ROOT%\scripts"
"%PYTHON%" -B -m unittest discover -s "%TEST_ROOT%" -t "%REPO_ROOT%\scripts" -p "test_*.py"
set "RC=%ERRORLEVEL%"
if "%RC%"=="0" (
  echo [OK] dstock_canon contract tests completed.
) else (
  echo [ERROR] dstock_canon contract tests failed with exit code %RC%.
)
:finish
if "%NO_PAUSE%"=="1" goto :done
if /I "%CMDCMDLINE%"=="%ComSpec%" goto :done
pause
:done
endlocal & exit /b %RC%
