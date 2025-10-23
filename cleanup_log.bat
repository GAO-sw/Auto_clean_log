@echo off
setlocal enabledelayedexpansion

:menu
cls
echo =================================
echo    Folder-Specific Cleanup Tool
echo =================================
echo Current folder: %CD%
echo.
echo 1. Run cleanup with default settings (70%% folder-to-disk ratio)
echo 2. Run cleanup with custom ratio
echo 3. Exit
echo.
echo =================================
set /p choice="Please select (1-3): "  :: Main menu - user selects operation mode

if "%choice%"=="1" goto run_default
if "%choice%"=="2" goto run_custom
if "%choice%"=="3" goto exit_program

echo ERROR: Invalid choice! Please try again.
pause
goto menu

:run_default
call :main 70  :: Execute cleanup with default 70%% threshold
goto menu

:run_custom
set /p custom_ratio="Enter folder-to-disk ratio threshold (1-100%%): "  :: Get user-defined threshold
call :main !custom_ratio!  :: Execute cleanup with custom threshold
goto menu

:exit_program
echo INFO: Goodbye!  :: Exit the program
pause
exit /b 0

:GetFolderSize
:: total size current folder
set "folder_size=0"
set "line_count=0"

:: catch total line from directory listing to locate size line
for /f %%a in ('dir /a-d /s /w /-c "%current_folder%\*" 2^>nul ^| find /c /v ""') do set /a total_lines=%%a
set /a target_line=total_lines-3  ::2rd lines from end of directory output

:: catch size value and convert to MB
for /f "skip=%target_line% tokens=3" %%a in ('dir /a-d /s /w /-c "%current_folder%\*" 2^>nul') do (
    set "folder_size_bytes=%%a"
    set "folder_size_bytes=!folder_size_bytes: =!"  :: Remove spaces from numeric string
    set "folder_size_mb=!folder_size_bytes!"
    set /a "folder_size=!folder_size_mb:~0,-6!"  :: Truncate last 6 digits (convert bytes to MB)
    goto :eof
)
if "!folder_size!"=="" set "folder_size=0"  :: Handle empty folder case
exit /b 0

:GetDiskInfo
:: total size disk capacity
set "drive=%CD:~0,2%"  :: Extract drive letter (e.g., C:)
set "disk_total=0"

:: catch second line from fsutil output 
for /f "skip=1 tokens=2 delims=:(" %%a in ('fsutil volume diskfree %drive% 2^>nul') do (
    set "temp=%%a"
    set "temp=!temp: =!"  :: Remove spaces
    set "temp=!temp:,=!"   :: Remove commas from numeric string
    set "disk_total_bytes=!temp!"
    set /a "disk_total=!disk_total_bytes:~0,-6!"  :: Convert bytes to MB
    goto :eof
)
exit /b 0

:main
:: set folder backup,accept shreshold
setlocal enabledelayedexpansion
set "current_folder=." 
set "backup_folder=backup" 
set "threshold=%1"  

echo INFO: Current target folder: %CD%
if not exist "%backup_folder%" (
    echo INFO: Creating backup folder: %backup_folder%
    mkdir "%backup_folder%" >nul 2>&1  
)

echo INFO: Calculating folder size and disk capacity...
call :GetDiskInfo  :: Get total disk size
call :GetFolderSize  :: Get current folder size

echo INFO: Folder size: !folder_size! MB
echo INFO: Disk total capacity: !disk_total! MB

:: if sth wrong with disk size ，stop it
if !disk_total! equ 0 (
    echo ERROR: Cannot calculate folder ratio - disk info unavailable.
    pause
    exit /b 1
)

:: Calculate ratio percentage
set /a folder_ratio=folder_size * 100 / disk_total
echo INFO: Folder to disk ratio: !folder_ratio!%% (Threshold: !threshold!%%)

:: Skip cleanup when below threshold
if !folder_ratio! lss !threshold! (
    echo INFO: Folder ratio is below threshold. No cleanup needed.
    pause
    exit /b 0
)

:: Start cleanup process if threshold exceeded，sorted file list
echo WARNING: Folder ratio exceeds threshold. Starting cleanup...
dir "%current_folder%\*" /b /o:d /a-d > file_list.txt 2>nul  :: List files sorted by date (oldest first)

:: Count processable files 
set /a total_files=0
for /f %%F in (file_list.txt) do (
    if /i not "%%F"=="cleanup_log.bat" if /i not "%%F"=="file_list.txt" if /i not "%%F"=="%backup_folder%" (
        set /a total_files+=1
    )
)

:: Handle empty file list scenario
if !total_files! equ 0 (
    echo INFO: No files to process.
    del file_list.txt 2>nul
    pause
    exit /b 0
)

:: Archive file，until ratio below threshold
set /a files_archived=0
for /f "usebackq delims=" %%F in ("file_list.txt") do (
    :: Skip important/temp files
    if /i "%%F"=="cleanup_log.bat" (
        echo SKIP: System file - %%F
    ) else if /i "%%F"=="file_list.txt" (
        echo SKIP: Temporary file - %%F
    ) else if /i "%%F"=="%backup_folder%" (
        echo SKIP: Backup folder - %%F
    ) else (
        echo INFO: Archiving: %%F
        tar --lzma -cf "%backup_folder%\%%F.tar.lzma" "%%F" >nul 2>&1  :: Compress file to backup folder
        if !errorlevel! equ 0 (
            del "%%F" >nul 2>&1  :: Delete original file after successful compression
            set /a files_archived+=1
            echo INFO: Archived: %%F ^| Progress: !files_archived!/!total_files!
            call :GetFolderSize  :: Recalculate folder size after deletion
            set /a folder_ratio=folder_size * 100 / disk_total
            echo INFO: Updated folder ratio: !folder_ratio!%%
            if !folder_ratio! lss !threshold! (
                echo INFO: Folder ratio now below threshold. Stopping cleanup.
                goto cleanup_done  :: Exit loop early if target ratio achieved
            )
        ) else (
            echo ERROR: Failed to compress %%F. Skipping...
        )
    )
)

:cleanup_done
:: cleanup summary and temporary files
echo.
echo =================================
echo Cleanup Summary:
echo - Archived files: !files_archived!
echo - Final folder ratio: !folder_ratio!%%
echo =================================
del file_list.txt 2>nul  :: Remove temporary file list
pause
endlocal
exit /b 0
