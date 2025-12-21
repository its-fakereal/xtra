@echo off
TITLE shutdown pc
cls
color 1

echo 1 = 30 sec
echo 2 = 1 min
echo 3 = 5  min
echo 4 = 10 min
echo 5 = 20 min
echo 6 = 30 min
echo 7 = 45 min
echo 8 = 1 hr

set/p option= choose one time for shutdown:

if %option%== 1 shutdown -s -t 30
if %option%== 2 shutdown -s -t 60
if %option%== 3 shutdown -s -t 300
if %option%== 4 shutdown -s -t 600
if %option%== 5 shutdown -s -t 1200
if %option%== 6 shutdown -s -t 1800
if %option%== 7 shutdown -s -t 2700
if %option%== 8 shutdown -s -t 3600
if %option%== 9 shutdown -s -t 8008
if %option%== 0 shutdown -a
