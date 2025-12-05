@echo on
echo preventing . . . . .

REM Prevent sleep, hibernation, and display turn-off (AC power)
powercfg -change -standby-timeout-ac 0
powercfg -change -hibernate-timeout-ac 0
powercfg -change -monitor-timeout-ac 0

REM Prevent sleep, hibernation, and display turn-off (Battery power)
powercfg -change -standby-timeout-dc 0
powercfg -change -hibernate-timeout-dc 0
powercfg -change -monitor-timeout-dc 0

REM Wait for 4 hours (14400 seconds) without simulating key presses
timeout /t 3600 >nul

REM After 4 hours, start simulating a SHIFT key press every 59 seconds
REM Requires NirCmd (https://www.nirsoft.net/utils/nircmd.html) in the same folder
:loop
timeout /t 59 >nul
REM Uncomment the next line if you have nircmd.exe
REM nircmd sendkeypress shift
goto loop

REM To restore defaults, run:
REM powercfg -restoredefaultschemes 