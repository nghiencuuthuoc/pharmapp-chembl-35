@echo off
setlocal

REM ==== EDIT THESE ====
set PGDATA=C:\pgdata
set DUMP=C:\path\to\chembl_35_rdkit_backup.dump
set PGUSER=%USERNAME%
set PGPORT=5432
REM ====================

chcp 65001 >nul

REM Start server (no-op if already running)
pg_ctl -D "%PGDATA%" -l "%PGDATA%\logfile" start
ping 127.0.0.1 -n 3 >nul

REM Create DB and restore
psql -h localhost -p %PGPORT% -U %PGUSER% -d postgres -c "DROP DATABASE IF EXISTS chembl_35;"
psql -h localhost -p %PGPORT% -U %PGUSER% -d postgres -c "CREATE DATABASE chembl_35 OWNER \"%PGUSER%\";"

pg_restore -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 --no-owner --no-privileges "%DUMP%"

REM Smoke tests
psql -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 -c "SELECT COUNT(*) AS molecules FROM molecule_dictionary;"
psql -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 -c "VACUUM ANALYZE;"

echo Done.
endlocal
pause
