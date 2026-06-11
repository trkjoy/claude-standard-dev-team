@echo off
REM 启动器：绕过 PowerShell ExecutionPolicy 限制运行 install.ps1
REM .cmd 不受 PowerShell 执行策略管辖，-ExecutionPolicy Bypass 仅对本次进程生效，不改系统全局设置。
REM 用法：.\scripts\install.cmd  [平台]  [知识库模式]
REM   例：.\scripts\install.cmd           （交互式，默认 Claude Code）
REM       .\scripts\install.cmd claude 1  （指定平台与知识库模式）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
