@echo off

@REM Author: Fuwei Chin <fuweichin@gmail.com>

setlocal

set __DIRNAME=%~dp0
set __BASENAME=%~n0

if [%1]==[--help] (
  echo Usage:
  echo %__BASENAME% --help                                      # show help message
  echo %__BASENAME% --start                                     # start the vm ^(power on^)
  echo %__BASENAME% --shutdown                                  # shutdown the vm ^(power off^)
  echo %__BASENAME% --check                                     # test connection to ssh
  echo %__BASENAME% [--cd ^<DIR^>]                                # open terminal window
  echo %__BASENAME% [--cd ^<DIR^>] run ^<COMMAND^> [...ARGS]        # run command and exit
  goto end
)

if exist "%__DIRNAME%\%__BASENAME%-setenv.bat" (
  call "%__DIRNAME%\%__BASENAME%-setenv.bat"
) else (
  if not defined VBOXMANAGE_EXCUTABLE (
    echo Env var VBOXMANAGE_EXCUTABLE is not defined
    echo Maybe you missed file %__BASENAME%-setenv.bat which contains variables
    exit /b 1
  )
)

if not defined VBOXMANAGE_EXCUTABLE (
  echo Env var VBOXMANAGE_EXCUTABLE is not defined
  exit /b 1
)
if not exist "%VBOXMANAGE_EXCUTABLE%" (
  echo Env var VBOXMANAGE_EXCUTABLE is not found
  exit /b 2
)
if not defined VM_NAME (
  echo Env var VM_NAME is not defined
  exit /b 1
)
if not defined SSH_EXECUTABLE (
  echo Env var SSH_EXECUTABLE is not defined
  exit /b 1
)
if not exist "%SSH_EXECUTABLE%" (
  echo Env var SSH_EXECUTABLE is not found
  exit /b 2
)
set SSH_ARGS=%SSH_OPTS%
set SSH_TEST_ARGS=-o BatchMode=yes -o StrictHostKeyChecking=no
if defined SSH_PORT (
  set SSH_ARGS=%SSH_ARGS% -p %SSH_PORT%
  set SSH_TEST_ARGS=%SSH_TEST_ARGS% -p %SSH_PORT%
) else (
  set SSH_PORT=22
)
if not defined SSH_HOST (
  echo Env var SSH_HOST is not defined
  exit /b 1
)
if not defined SSH_USER (
  echo Env var SSH_USER is not defined
  exit /b 1
)
set SSH_ARGS=%SSH_ARGS% %SSH_USER%@%SSH_HOST%
set SSH_TEST_ARGS=%SSH_TEST_ARGS% %SSH_USER%@%SSH_HOST%

if [%1]==[--start] (
  "%VBOXMANAGE_EXCUTABLE%" startvm "%VM_NAME%" --type headless
  goto end
)
if [%1]==[--shutdown] (
  "%VBOXMANAGE_EXCUTABLE%" controlvm "%VM_NAME%" poweroff
  goto end
)
if [%1]==[--check] (
  "%SSH_EXECUTABLE%" -o ConnectTimeout=1 -o ConnectionAttempts=1 %SSH_TEST_ARGS% "echo 'Connection is OK'; exit 0"
  exit /b %ERRORLEVEL%
)

"%VBOXMANAGE_EXCUTABLE%" list runningvms | findstr /c:"%VM_NAME%" > NUL
if errorlevel 1 (
  "%VBOXMANAGE_EXCUTABLE%" startvm "%VM_NAME%" --type headless
  timeout %VM_BOOT_ESTIMATED_SECONDS%
  goto test_ssh_connection
)
goto main

:test_ssh_connection
  "%SSH_EXECUTABLE%" -q -o ConnectTimeout=1 -o ConnectionAttempts=5 %SSH_TEST_ARGS% "exit 0"
  if errorlevel 255 (
    echo Failed to connect to %SSH_HOST%:%SSH_PORT%, please try again later.
    exit /b 255
  )
  goto main

:main
  if [%1]==[] (
    goto run_no_command
  )
  if [%1]==[--cd] (
    set CDPATH=%~2
    goto cdpath_shift_shift
  )
  if [%1]==[run] (
    goto command_begin
  )
  echo Invalid command-line, use '%~n0 --help' to see usage details
  exit /b 1

:cdpath_shift_shift
  shift
  shift
  goto cdpath_transform

:cdpath_transform
  if "%CDPATH:~0,1%"=="/" (
    set LC_CDPATH=%CDPATH%
    goto run
  )
  if "%CDPATH%"=="~" (
    set LC_CDPATH=~
    goto run
  )
  set DRIVELETTER=%CDPATH:~0,1%
  call :to_lowcase DRIVELETTER
  set LC_CDPATH=%CDPATH:~2%
  set LC_CDPATH=%LC_CDPATH:\=/%
  set LC_CDPATH=/mnt/%DRIVELETTER%%LC_CDPATH%
  goto run

:to_lowcase
  for %%i in ("A=a" "B=b" "C=c" "D=d" "E=e" "F=f" "G=g" "H=h" "I=i" "J=j" "K=k" "L=l" "M=m" "N=n" "O=o" "P=p" "Q=q" "R=r" "S=s" "T=t" "U=u" "V=v" "W=w" "X=x" "Y=y" "Z=z") do call set "%1=%%%1:%%~i%%"
  goto :EOF

:run
  if [%1]==[run] (
    goto command_begin
  )
  goto run_no_command

:command_begin
  shift
  if [%1]==[] (
    goto run_with_command
  )
  set COMMAND=%1
  shift
  goto command_append

:command_append
  if [%1]==[] (
    goto run_with_command
  )
  set COMMAND=%COMMAND% %1
  shift
  goto command_append

:run_with_command
  if defined LC_CDPATH (
    "%SSH_EXECUTABLE%" -o SendEnv=LC_CDPATH -t %SSH_ARGS% %COMMAND%
  ) else (
    "%SSH_EXECUTABLE%" -t %SSH_ARGS% %COMMAND%
  )
  goto end

:run_no_command
  if defined LC_CDPATH (
    "%SSH_EXECUTABLE%" -o SendEnv=LC_CDPATH %SSH_ARGS%
  ) else (
    "%SSH_EXECUTABLE%" %SSH_ARGS%
  )
  goto end

:end
  endlocal
