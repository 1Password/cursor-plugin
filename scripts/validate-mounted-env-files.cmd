@echo off
REM On Windows only: tell Cursor to allow the shell command (1Password Environments are not supported here).
REM The hook command omits a file extension, on Windows the OS finds this .cmd file for you.
REM On Mac/Linux the same hook name runs the Bash script next to this file instead.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& { $null = [Console]::In.ReadToEnd(); $m = '1Password Environments local .env validation is only supported on macOS and Linux. Validation was skipped.'; @{ permission = 'allow'; agent_message = $m; user_message = $m } | ConvertTo-Json -Compress }"

exit /b 0
