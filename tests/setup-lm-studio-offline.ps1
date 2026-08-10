# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Zoey and contributors

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Assert-TestCondition {
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
    throw 'The LM Studio setup test requires Windows PowerShell 5.1.'
}

$testDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$packageRoot = (Resolve-Path -LiteralPath (Join-Path $testDirectory '..')).Path
$setupPath = Join-Path $packageRoot 'scripts\setup-lm-studio.ps1'
Assert-TestCondition (Test-Path -LiteralPath $setupPath -PathType Leaf) 'scripts/setup-lm-studio.ps1 is missing.'

$plannedInstallRoot = Join-Path ([IO.Path]::GetTempPath()) ('SafeWebSearchMCP-setup-test-' + [Guid]::NewGuid().ToString('N'))
Assert-TestCondition (-not (Test-Path -LiteralPath $plannedInstallRoot)) 'Generated test install root unexpectedly exists.'

$setupResult = $null
foreach ($item in @(& $setupPath -InstallRoot $plannedInstallRoot -NoLaunch -WhatIf)) {
    if ($null -ne $item -and $null -ne $item.PSObject.Properties['LMStudioDeepLink']) {
        $setupResult = $item
    }
}

Assert-TestCondition ($null -ne $setupResult) 'Setup preview did not return an LM Studio deeplink.'
Assert-TestCondition (-not (Test-Path -LiteralPath $plannedInstallRoot)) 'Setup preview wrote to the filesystem.'
Assert-TestCondition ([string]$setupResult.Status -ceq 'Preview only; nothing was installed or opened') 'Setup preview status is incorrect.'

$deepLinkPrefix = 'lmstudio://add_mcp?name=safe-web-search&config='
$deepLink = [string]$setupResult.LMStudioDeepLink
Assert-TestCondition $deepLink.StartsWith($deepLinkPrefix, [StringComparison]::Ordinal) 'LM Studio deeplink prefix is incorrect.'

$encodedConfig = $deepLink.Substring($deepLinkPrefix.Length)
$configBase64 = [Uri]::UnescapeDataString($encodedConfig)
try {
    $configJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($configBase64))
    $config = $configJson | ConvertFrom-Json
} catch {
    throw "LM Studio deeplink configuration could not be decoded: $($_.Exception.Message)"
}

$expectedPowerShellPath = Join-Path $PSHOME 'powershell.exe'
$expectedServerPath = Join-Path (Join-Path $plannedInstallRoot '1.0.0') 'server.ps1'
Assert-TestCondition ([string]$config.command -ceq $expectedPowerShellPath) 'LM Studio command is not the current Windows PowerShell 5.1 executable.'
Assert-TestCondition ([int]$config.timeout -eq 15000) 'LM Studio timeout is not 15000 milliseconds.'
$arguments = @($config.args)
Assert-TestCondition ($arguments.Count -eq 7) 'LM Studio argument count is incorrect.'
Assert-TestCondition ([string]$arguments[0] -ceq '-NoLogo') 'LM Studio arguments omit -NoLogo.'
Assert-TestCondition ([string]$arguments[1] -ceq '-NoProfile') 'LM Studio arguments omit -NoProfile.'
Assert-TestCondition ([string]$arguments[2] -ceq '-NonInteractive') 'LM Studio arguments omit -NonInteractive.'
Assert-TestCondition ([string]$arguments[3] -ceq '-ExecutionPolicy') 'LM Studio arguments omit -ExecutionPolicy.'
Assert-TestCondition ([string]$arguments[4] -ceq 'Bypass') 'LM Studio execution-policy value is incorrect.'
Assert-TestCondition ([string]$arguments[5] -ceq '-File') 'LM Studio arguments omit -File.'
Assert-TestCondition ([string]$arguments[6] -ceq $expectedServerPath) 'LM Studio server path does not point to the planned verified installation.'
Assert-TestCondition ([string]$setupResult.ConfigurationJson -ceq $configJson) 'Returned configuration JSON does not match the deeplink payload.'

Write-Output 'PASS: LM Studio setup preview produced a valid local deeplink without writes or network access.'
