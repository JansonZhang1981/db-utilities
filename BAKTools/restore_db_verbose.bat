@echo off
setlocal EnableDelayedExpansion

@REM Set parameters
@SET root=%~dp0
@CALL %root%\preferences.bat

@REM get target server and database name
@REM set svr to the name of your machine
@SET svr=%svr% 
@SET /p db= Enter target database name: 
@SET db1='%db%'
@SET bak= %1
@SET bak=%bak:"='%
for /f "tokens=* delims= " %%a in ("%bak%") do set bak=%%a
@SET bak=N%bak%

@REM check whether input file is a .bak
@SET ext=%bak:~-5,4%
if /i %ext% EQU .bak goto continue
@echo.       
@echo .... NOT A .BAK FILE!
@echo. 
@echo Press any key to exit and try another file.
pause>nul
exit

:continue
@REM check whether database exists and make sure user wants to overwrite it
@echo.         
@echo .... CHECKING WHETHER DATABASE EXISTS
@echo.     
sqlcmd -U %sa% -P %pwd% -S %svr% -i %root%\queries\exists.sql -v dbname=%db1% bak_file="%bak%" -o %root%\logs\exists.log
type %root%\logs\exists.log
pause>nul

@REM run restore query
@echo.      
@echo .... BEGINNING RESTORE NOW
@echo.     
sqlcmd -U %sa% -P %pwd% -S %svr% -i %root%\queries\restore_db.sql -v dbname=%db1% bak_file="%bak%" mdf_path="%mdf%" ldf_path="%ldf%" -o %root%\logs\log.log
type %root%\logs\log.log
@echo.

@REM run three queries
@echo ..............................................................
@echo.  
@echo .... RUNNING POST-RESTORE QUERIES
@echo.     
@echo .... QUERY 1
@echo.     
sqlcmd -U %sa% -P %pwd% -S %svr% -i %root%\queries\sp_change_users_login.sql -d %db% -o %root%\logs\users.log
type %root%\logs\users.log
@echo.     
@echo .... QUERY 2
@echo.     
sqlcmd -U %sa% -P %pwd% -S %svr% -i %root%\queries\sp_grantdbaccess.sql -d %db% -o %root%\logs\access.log
type %root%\logs\access.log
@echo.     
@echo .... QUERY 3
@echo.     
sqlcmd -U %sa% -P %pwd% -S %svr% -i %root%\queries\sp_addrolemember.sql -d %db% -o %root%\logs\role.log
type %root%\logs\role.log
@echo.
@echo ..............................................................
@echo.       

@REM is it a customer database?
@REM :check_if_customer
@REM set /p cust= Restoring a customer database? [y/n] 
@REM if /i %cust% EQU y goto is_customer
@REM if /i %cust% EQU n goto restore_done
@REM invalid input
@REM echo "Choose y or n."
@REM echo.
@REM goto check_if_customer

	@REM  it's a customer db, so run customer queries
	@REM :is_customer
	@REM echo.     
	@REM echo .... RUNNING CUSTOMER RESTORE QUERIES
	@REM echo.     
	@REM sqlcmd -U %sa% -P %pwd% -S %svr% -i %root%\queries\customer_restore.sql -d %db% -o %root%\logs\customer.log
	@REM type %root%\logs\customer.log
	@REM echo.

@REM done running queries!
:restore_done
@echo.
@echo ..............................................................
@echo.    
@echo .... RESTORE PROCESS COMPLETE.
@echo.    
pause

:check_if_restart_services
@SET /p res= RESTART SQL AND IIS? [Y/N] 
if /i %res% EQU Y goto do_restart
if /i %res% EQU N goto end_of_script
@REM invalid input
@echo "Choose Y or N."
@echo.
goto check_if_restart_services

	@REM restart SQL server and IIS
	:do_restart
	@echo.     
	@echo .... RESTARTING SQL AND IIS
	@echo.     
	@echo STOPPING SQL SERVER
	net stop mssqlserver
	@echo STARTING SQL SERVER
	net start mssqlserver
	@echo STOPPING IIS.
	@echo STOPPING IIS/W3SVC
	net stop WAS /y
	@echo STARTING IIS/W3SVC
	net start W3SVC
	@echo.

:end_of_script
@echo DONE
pause