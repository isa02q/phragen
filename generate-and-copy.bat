@echo off

phragen.exe %* | clip

powershell -NoProfile -WindowStyle Hidden -Command ^
  "Start-Sleep -Seconds 30;" ^
  "Add-Type -AssemblyName System.Windows.Forms;" ^
  "[System.Windows.Forms.Clipboard]::Clear()"
