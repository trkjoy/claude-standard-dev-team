@echo off
REM 启动器：绕过 PowerShell ExecutionPolicy 限制运行 update.ps1
REM .cmd 不受 PowerShell 执行策略管辖，-ExecutionPolicy Bypass 仅对本次进程生效，不改系统全局设置。
REM 用法：.\scripts\update.cmd  [项目目录]
REM   例：.\scripts\update.cmd                    （升级当前目录所在项目）
REM       .\scripts\update.cmd D:\path\to\project （升级指定项目）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1" %*
