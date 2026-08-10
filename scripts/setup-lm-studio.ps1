# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Zoey and contributors

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [string]$InstallRoot,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Assert-SetupCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

if ($PSVersionTable.PSEdition -cne 'Desktop' -or
    $PSVersionTable.PSVersion.Major -ne 5 -or
    $PSVersionTable.PSVersion.Minor -lt 1) {
    throw 'LM Studio setup must run in Windows PowerShell 5.1 (powershell.exe), not PowerShell 7 (pwsh.exe).'
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$installerPath = Join-Path $scriptDirectory 'install.ps1'
Assert-SetupCondition (Test-Path -LiteralPath $installerPath -PathType Leaf) 'scripts/install.ps1 is missing.'

$installArguments = @{}
if ($PSBoundParameters.ContainsKey('InstallRoot')) {
    $installArguments['InstallRoot'] = $InstallRoot
}
if ($WhatIfPreference) {
    $installArguments['WhatIf'] = $true
}

$installResult = $null
foreach ($item in @(& $installerPath @installArguments)) {
    if ($null -ne $item -and $null -ne $item.PSObject.Properties['NativeServerPath']) {
        $installResult = $item
    }
}
Assert-SetupCondition ($null -ne $installResult) 'The local installer did not return an installed server path.'

$powershellPath = Join-Path $PSHOME 'powershell.exe'
Assert-SetupCondition ([IO.Path]::IsPathRooted($powershellPath)) 'Windows PowerShell returned a non-absolute executable path.'
Assert-SetupCondition (Test-Path -LiteralPath $powershellPath -PathType Leaf) "Windows PowerShell executable not found: $powershellPath"

$serverPath = [IO.Path]::GetFullPath([string]$installResult.NativeServerPath)
$lmStudioConfig = [ordered]@{
    command = $powershellPath
    args = @(
        '-NoLogo'
        '-NoProfile'
        '-NonInteractive'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $serverPath
    )
    timeout = 15000
}

$configJson = $lmStudioConfig | ConvertTo-Json -Depth 5 -Compress
$utf8 = New-Object System.Text.UTF8Encoding($false)
$configBase64 = [Convert]::ToBase64String($utf8.GetBytes($configJson))
$deepLink = 'lmstudio://add_mcp?name=safe-web-search&config=' + [Uri]::EscapeDataString($configBase64)

$previewOnly = [bool]$WhatIfPreference
if ($previewOnly -or $NoLaunch) {
    [pscustomobject]@{
        Status = if ($previewOnly) { 'Preview only; nothing was installed or opened' } else { 'Installed and verified; LM Studio was not opened' }
        Version = [string]$installResult.Version
        ServerPath = $serverPath
        SHA256 = [string]$installResult.SHA256
        LMStudioDeepLink = $deepLink
        ConfigurationJson = $configJson
    }
    return
}

if (-not $PSCmdlet.ShouldProcess('LM Studio', 'Open the Add MCP Server confirmation for safe-web-search')) {
    return
}

try {
    Start-Process -FilePath $deepLink -ErrorAction Stop
} catch {
    throw "The server was installed and verified, but the LM Studio confirmation could not be opened. Run this script again with -NoLaunch to print the local install link. Details: $($_.Exception.Message)"
}

[pscustomobject]@{
    Status = 'Installed and verified; LM Studio confirmation opened'
    Version = [string]$installResult.Version
    ServerPath = $serverPath
    SHA256 = [string]$installResult.SHA256
    NextStep = 'Review the command in LM Studio, add the server, and keep per-search approval enabled.'
}
