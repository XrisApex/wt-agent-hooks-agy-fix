$ErrorActionPreference = 'Stop'

$hooksFile = Join-Path $env:USERPROFILE '.gemini\config\plugins\wt-agent-hooks\hooks.json'
if (-not (Test-Path $hooksFile)) {
    Write-Error "hooks.json not found at: $hooksFile"
    exit 1
}

# Clear Read-Only if previously set
Set-ItemProperty -Path $hooksFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue

# Encode PowerShell script as UTF-16LE Base64 so cmd.exe cannot strip quotes or split pipes
$psScript = 'try { $null = & wtcli.exe agent-hook --cli-source antigravity --event agent.tool.starting 2>$null } catch {}; [Console]::Out.WriteLine(''{"decision":"allow"}''); exit 0'
$b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($psScript))

$json = Get-Content -Path $hooksFile -Raw | ConvertFrom-Json
$json.'wt-agent-hooks'.PreToolUse[0].hooks[0].command = "powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand $b64"
$json | ConvertTo-Json -Depth 10 | Set-Content -Path $hooksFile -Encoding UTF8

# Lock Read-Only to prevent Intelligent Terminal from overwriting the fix
Set-ItemProperty -Path $hooksFile -Name IsReadOnly -Value $true

# Verify via cmd.exe just as agy does
$testOut = cmd.exe /c $json.'wt-agent-hooks'.PreToolUse[0].hooks[0].command
Write-Output "Verified cmd.exe output: $testOut"
