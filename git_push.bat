@echo off
title Git Auto Push (_brain_OAGBUDGET)
color 0E

cls
echo =======================================================
echo.
echo    [ Git Auto Commit, Pull ^& Push : _brain_OAGBUDGET ]
echo.
echo =======================================================

:: Navigate to the repository directory
cd /d "%~dp0"

:: Fetch latest info from origin before checking status
echo.
echo [*] Fetching latest info from origin...
git fetch

:: Get current branch
FOR /F "tokens=*" %%g IN ('git branch --show-current') do (SET CURRENT_BRANCH=%%g)

echo.
echo =======================================================
echo [*] Target Repository: _brain_OAGBUDGET
echo [*] Current Branch: %CURRENT_BRANCH%
echo =======================================================
echo [*] Changes detected:
git status -s -b
echo =======================================================
echo.
echo ** REMINDER: Please use Conventional Commits format **
echo Types: feat, fix, docs, refactor, chore, test, style
echo Format: ^<type^>[scope]: ^<description^>
echo Example: docs(roadmap): update phase 1 timeline
echo =======================================================
echo.

set /p commit_msg="Enter commit message: "

if "%commit_msg%"=="" (
    echo.
    echo [!] Commit message cannot be empty. Push aborted.
    pause
    exit /b
)

echo.
set "ai_coauthor="
set /p ai_coauthor="Add Co-Authored-By footer for AI (Gemini 3 Pro)? (y/n) [Default: n]: "

echo.
echo =======================================================
echo [*] Available Local Branches:
git branch
echo =======================================================
echo.

set "target_branch="
set /p target_branch="Enter branch to push to (Press Enter to use [%CURRENT_BRANCH%]): "
if "%target_branch%"=="" set target_branch=%CURRENT_BRANCH%

echo.
echo [*] Adding changes (git add .)...
git add .

echo.
if /I "%ai_coauthor%"=="y" (
    echo [*] Committing changes with AI Co-Authored-By footer...
    git commit -m "%commit_msg%" -m "" -m "Co-Authored-By: Gemini 3 Pro (High) <noreply@google.com>"
) else (
    echo [*] Committing changes...
    git commit -m "%commit_msg%"
)

echo.
echo [*] Pulling latest changes from origin/%target_branch%...
git pull origin %target_branch%

if %errorlevel% neq 0 (
    echo.
    echo [!] ====================================================================
    echo [!] ERROR: Pull failed! You might have Merge Conflicts.
    echo [!] Please resolve the conflicts manually in your code editor.
    echo [!] After resolving, commit the changes and then run 'git push' manually.
    echo [!] ====================================================================
    pause
    exit /b
)

echo.
echo [*] Pushing to origin/%target_branch%...
git push origin %target_branch%

echo.
echo =======================================================
echo [*] Push Complete!
pause
