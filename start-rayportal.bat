@echo off
setlocal

cd /d "%~dp0"

set "RAYPORTAL_JAVA_HOME=C:\Program Files\Java\jdk-25.0.4"
if not exist "%RAYPORTAL_JAVA_HOME%\bin\java.exe" (
    echo [RayPortal] Java 25 was not found.
    echo Expected: %RAYPORTAL_JAVA_HOME%
    pause
    exit /b 1
)

set "JAVA_HOME=%RAYPORTAL_JAVA_HOME%"
call "%~dp0gradlew.bat" runClient --no-daemon
set "RAYPORTAL_EXIT_CODE=%ERRORLEVEL%"

echo.
if "%RAYPORTAL_EXIT_CODE%"=="0" (
    echo [RayPortal] Client exited normally.
) else (
    echo [RayPortal] Client exited with code %RAYPORTAL_EXIT_CODE%.
)
pause

exit /b %RAYPORTAL_EXIT_CODE%
