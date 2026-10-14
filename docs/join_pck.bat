@echo off
cd /d "%~dp0"
copy /b index.pck.part00+index.pck.part01 index.pck
del index.pck.part00 index.pck.part01
echo DONE - index.pck created
pause
