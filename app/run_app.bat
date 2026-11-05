@echo off
REM ==========================================================================================
REM  WFP Chad - Data merging dashboard (R Shiny)
REM  Double-click this file: the application opens in your web browser.
REM  Keep this window open while using the app; close it to stop the application.
REM ==========================================================================================
setlocal
chcp 65001 >nul
cd /d "%~dp0"
title WFP Chad data merging dashboard

REM --- Find R ---
set "RSCRIPT="
for /f "delims=" %%R in ('where Rscript 2^>nul') do if not defined RSCRIPT set "RSCRIPT=%%R"
if not defined RSCRIPT (
    for /d %%D in ("%ProgramFiles%\R\R-*" "%LOCALAPPDATA%\Programs\R\R-*") do (
        if exist "%%~D\bin\Rscript.exe" set "RSCRIPT=%%~D\bin\Rscript.exe"
    )
)
if not defined RSCRIPT (
    echo.
    echo R was not found on this computer.
    echo Install R from https://cran.r-project.org/bin/windows/base/ and run this file again.
    pause
    exit /b 1
)

REM --- Check the app data (prepared before sharing, aggregates only) ---
if not exist "data\manifest.json" goto nodata
if not exist "data\indicators_by_round.csv" goto nodata

REM --- Packages (missing ones are installed automatically on first run) ---
"%RSCRIPT%" install_packages.R
if errorlevel 1 (
    echo.
    echo FAILED to install the R packages. Check your internet connection and try again.
    pause
    exit /b 1
)

REM --- Launch ---
REM This window serves the app to this computer only, so no login is asked (a server requires one).
set "WFP_CBA_LOCAL=1"
echo.
echo Opening the application in your browser...
echo Close this window to stop the application.
echo.
"%RSCRIPT%" -e "shiny::runApp('.', launch.browser = TRUE)"
pause
exit /b 0

:nodata
echo.
echo The "data" folder of the application is missing or incomplete.
echo If you have the source files, run:  Rscript prepare_app_data.R
echo Otherwise, ask the sender for the complete application folder (including "data").
pause
exit /b 1
