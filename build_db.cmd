@echo off
del /p TIMETABLE.FDB
"C:\Program Files\Firebird\bin\isql.exe" -b -i timetable.sql
pause