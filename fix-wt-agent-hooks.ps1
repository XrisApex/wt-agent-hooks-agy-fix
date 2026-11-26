$ErrorActionPreference = 'Stop'

$pluginDir = Join-Path $env:USERPROFILE '.gemini\config\plugins\wt-agent-hooks'
$hooksFile = Join-Path $pluginDir 'hooks.json'
$cmdFile   = Join-Path $pluginDir 'wt-hook.cmd'

if (-not (Test-Path $hooksFile)) {
    Write-Error "hooks.json not found at: $hooksFile"
    exit 1
}

# Clear Read-Only if previously set
Set-ItemProperty -Path $hooksFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue

# Write lightweight cmd wrapper:
# 1) "< nul" feeds EOF so wtcli.exe exits immediately instead of hanging on stdin
# 2) Avoids cmd.exe quote-stripping and powershell.exe ~1.7s cold-start overhead
$cmdContent = @"
@echo off
wtcli.exe agent-hook --cli-source antigravity --event %1 < nul > nul 2>&1
if "%1"=="agent.tool.starting" (echo {"decision":"allow"}) else (echo {})
exit /b 0
"@
[IO.File]::WriteAllText($cmdFile, $cmdContent, [Text.Encoding]::ASCII)

$json = Get-Content -Path $hooksFile -Raw | ConvertFrom-Json
$hooks = $json.'wt-agent-hooks'
if ($hooks.PreInvocation) {
    $hooks.PreInvocation[0].command = "$cmdFile agent.prompt.submit"
}
if ($hooks.PreToolUse) {
    $hooks.PreToolUse[0].hooks[0].command = "$cmdFile agent.tool.starting"
}
if ($hooks.Stop) {
    $hooks.Stop[0].command = "$cmdFile agent.stop"
}

[IO.File]::WriteAllText($hooksFile, ($json | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))

# Lock Read-Only to prevent Intelligent Terminal from overwriting the fix
Set-ItemProperty -Path $hooksFile -Name IsReadOnly -Value $true

# Verify via cmd.exe just as agy does
$testOut = cmd.exe /c "$cmdFile agent.tool.starting"
Write-Output "Verified cmd.exe output: $testOut"