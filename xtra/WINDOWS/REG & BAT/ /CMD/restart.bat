@echo off

title restart
cls
color 1

echo 1 = 30 sec
echo 2 = 1 min
echo 3 = 5 min
echo 4 = 10 min
echo 5 = 20 min
echo 6 = 30 min

set/p option= choose one time for restart:

if %option%== 1 shutdown -r -t 30
if %option%== 2 shutdown -r -t 60
if %option%== 3 shutdown -r -t 300
if %option%== 4 shutdown -r -t 600
if %option%== 5 shutdown -r -t 1200
if %option%== 6 shutdown -r -t 1800
if %option%== 0 shutdown -a



