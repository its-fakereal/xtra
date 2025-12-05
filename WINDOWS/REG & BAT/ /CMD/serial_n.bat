@echo off
cls
color 1
powershell -Command wmic bios get serialnumber
pause