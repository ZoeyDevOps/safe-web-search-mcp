# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Zoey and contributors

[CmdletBinding()]
param(
    [switch]$SkipOfflineTests
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Assert-Valid {
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
    throw 'Package validation must run in Windows PowerShell 5.1 (powershell.exe), not PowerShell 7 (pwsh.exe).'
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$packageRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDirectory '..')).Path
$manifestPath = Join-Path $packageRoot 'release-manifest.json'
$serverPath = Join-Path $packageRoot 'src\server.ps1'
$testPath = Join-Path $packageRoot 'tests\run-offline.ps1'
$setupTestPath = Join-Path $packageRoot 'tests\setup-lm-studio-offline.ps1'
$installerPath = Join-Path $packageRoot 'scripts\install.ps1'
$lmStudioSetupPath = Join-Path $packageRoot 'scripts\setup-lm-studio.ps1'
$lmStudioLauncherPath = Join-Path $packageRoot 'Install for LM Studio.cmd'
$attributesPath = Join-Path $packageRoot '.gitattributes'

Assert-Valid (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'release-manifest.json is missing.'
Assert-Valid (Test-Path -LiteralPath $serverPath -PathType Leaf) 'src\server.ps1 is missing.'
Assert-Valid (Test-Path -LiteralPath $testPath -PathType Leaf) 'tests\run-offline.ps1 is missing.'
Assert-Valid (Test-Path -LiteralPath $setupTestPath -PathType Leaf) 'tests\setup-lm-studio-offline.ps1 is missing.'
Assert-Valid (Test-Path -LiteralPath $installerPath -PathType Leaf) 'scripts\install.ps1 is missing.'
Assert-Valid (Test-Path -LiteralPath $lmStudioSetupPath -PathType Leaf) 'scripts\setup-lm-studio.ps1 is missing.'
Assert-Valid (Test-Path -LiteralPath $lmStudioLauncherPath -PathType Leaf) 'Install for LM Studio.cmd is missing.'
Assert-Valid (Test-Path -LiteralPath $attributesPath -PathType Leaf) '.gitattributes is missing.'

try {
    $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
} catch {
    throw "release-manifest.json is not valid JSON: $($_.Exception.Message)"
}

Assert-Valid ([int]$manifest.schema_version -eq 1) 'Unsupported release manifest schema.'
Assert-Valid ([string]$manifest.name -ceq 'safe-web-search') 'Manifest package name is incorrect.'
Assert-Valid ([string]$manifest.version -ceq '1.0.0') 'Manifest version must be 1.0.0.'
Assert-Valid ([string]$manifest.minimum_windows_powershell -ceq '5.1') 'Manifest Windows PowerShell minimum must be 5.1.'
Assert-Valid ([string]$manifest.server.path -ceq 'src/server.ps1') 'Manifest server path must be exactly src/server.ps1.'
Assert-Valid ([string]$manifest.server.sha256 -cmatch '\A[0-9A-F]{64}\z') 'Manifest server SHA-256 must be 64 uppercase hexadecimal characters.'
$protocolVersions = @($manifest.supported_protocol_versions)
Assert-Valid ($protocolVersions.Count -eq 2) 'Manifest must contain exactly two supported MCP protocol versions.'
Assert-Valid ([string]$protocolVersions[0] -ceq '2025-11-25') 'Manifest primary MCP protocol version is incorrect.'
Assert-Valid ([string]$protocolVersions[1] -ceq '2025-06-18') 'Manifest fallback MCP protocol version is incorrect.'

$actualServerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $serverPath).Hash
Assert-Valid ($actualServerHash -ceq [string]$manifest.server.sha256) "Server SHA-256 mismatch. Expected $($manifest.server.sha256); got $actualServerHash."

$serverSource = [IO.File]::ReadAllText($serverPath)
Assert-Valid ($serverSource.IndexOf([char]0) -lt 0) 'Server source contains a NUL character.'
Assert-Valid (-not ($serverSource.ToCharArray() | Where-Object { [int]$_ -gt 127 } | Select-Object -First 1)) 'Server source must remain ASCII-safe for deterministic Windows PowerShell 5.1 decoding.'
Assert-Valid ($serverSource -cmatch "(?m)^# SPDX-License-Identifier: MIT\r?$") 'Server source has no SPDX license identifier.'
Assert-Valid ($serverSource -cmatch '(?m)^\$script:ServerName = ''safe-web-search''\r?$') 'Server name declaration changed or is missing.'
Assert-Valid ($serverSource -cmatch '(?m)^\$script:ServerVersion = ''1\.0\.0''\r?$') 'Server version declaration does not match the manifest.'
Assert-Valid ([regex]::Matches($serverSource, [regex]::Escape('https://html.duckduckgo.com/html/')).Count -eq 1) 'The fixed DuckDuckGo HTTPS endpoint must occur exactly once.'
Assert-Valid ($serverSource -cmatch '(?m)^\$handler\.AllowAutoRedirect = \$false\r?$') 'Redirect blocking is missing.'
Assert-Valid ($serverSource -cmatch '(?m)^\$handler\.UseCookies = \$false\r?$') 'Cookie blocking is missing.'
Assert-Valid ($serverSource -cmatch '(?m)^\$handler\.UseProxy = \$true\r?$') 'Windows proxy-policy handling is missing.'
Assert-Valid ($serverSource -cmatch '(?m)^\$script:SupportedProtocolVersions = @\(''2025-11-25'', ''2025-06-18''\)\r?$') 'Server protocol version list does not match the manifest.'
Assert-Valid ($serverSource -notmatch 'local LM Studio integration') 'The server artifact contains an app-specific User-Agent.'
Assert-Valid ($serverSource -cmatch "SafeWebSearchMCP/1\.0\.0 \(\+local MCP server\)") 'Server User-Agent does not match the manifest version or host-neutral label.'

$attributesSource = [IO.File]::ReadAllText($attributesPath)
Assert-Valid ($attributesSource -cmatch '(?m)^src/server\.ps1 -text -eol\r?$') 'src/server.ps1 must be exempt from line-ending conversion so its release hash remains stable.'
Assert-Valid ($attributesSource -cmatch '(?m)^\*\.cmd text eol=crlf\r?$') 'Windows command launchers must use CRLF line endings in checkouts.'

$launcherSource = [IO.File]::ReadAllText($lmStudioLauncherPath)
Assert-Valid ($launcherSource.IndexOf([char]0) -lt 0) 'LM Studio launcher contains a NUL character.'
Assert-Valid (-not ($launcherSource.ToCharArray() | Where-Object { [int]$_ -gt 127 } | Select-Object -First 1)) 'LM Studio launcher must remain ASCII.'
Assert-Valid ($launcherSource -cmatch '(?m)^REM SPDX-License-Identifier: MIT\r?$') 'LM Studio launcher has no SPDX license identifier.'
Assert-Valid ($launcherSource -cmatch [regex]::Escape('"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0scripts\setup-lm-studio.ps1"')) 'LM Studio launcher does not call the packaged setup script through Windows PowerShell 5.1.'
Assert-Valid ($launcherSource -notmatch '(?i)https?://|\bcurl\b|\bbitsadmin\b|\bcertutil\b|\bInvoke-WebRequest\b|\bInvoke-RestMethod\b') 'LM Studio launcher contains a network or download primitive.'

$forbiddenServerPatterns = @(
    '(?i)\bInvoke-Expression\b',
    '(?i)\bInvoke-WebRequest\b',
    '(?i)\bInvoke-RestMethod\b',
    '(?i)\bStart-Process\b',
    '(?i)System\.Net\.WebClient',
    '(?i)\bDownloadString\b',
    '(?i)\bDownloadFile\b',
    '(?i)\bcmd\.exe\b',
    '(?i)\bwscript\.exe\b',
    '(?i)\bcscript\.exe\b'
)
foreach ($pattern in $forbiddenServerPatterns) {
    Assert-Valid ($serverSource -notmatch $pattern) "Forbidden execution or download primitive found in server source: $pattern"
}

$allPowerShellFiles = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter '*.ps1')
Assert-Valid ($allPowerShellFiles.Count -ge 6) 'Expected server, validator, installer, setup, and test PowerShell files are not all present.'
foreach ($file in $allPowerShellFiles) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    Assert-Valid (@($parseErrors).Count -eq 0) "PowerShell parser errors found in $($file.FullName): $(@($parseErrors | ForEach-Object { $_.Message }) -join '; ')"
    $fileText = [IO.File]::ReadAllText($file.FullName)
    Assert-Valid ($fileText.IndexOf([char]0) -lt 0) "NUL character found in $($file.FullName)."
    Assert-Valid (-not ($fileText.ToCharArray() | Where-Object { [int]$_ -gt 127 } | Select-Object -First 1)) "Non-ASCII source found in $($file.FullName); Windows PowerShell 5.1 decoding would be ambiguous without a BOM."
    Assert-Valid ($fileText -cmatch '(?m)^# SPDX-License-Identifier: MIT\r?$') "SPDX license identifier missing from $($file.FullName)."
}

$jsonFiles = @(
    Get-Item -LiteralPath $manifestPath
    Get-ChildItem -LiteralPath (Join-Path $packageRoot 'configs') -File -Filter '*.json' -ErrorAction SilentlyContinue
)
foreach ($jsonFile in $jsonFiles) {
    try {
        $null = [IO.File]::ReadAllText($jsonFile.FullName) | ConvertFrom-Json
    } catch {
        throw "JSON validation failed for $($jsonFile.FullName): $($_.Exception.Message)"
    }
}

$integrityItems = @(
    Get-Item -LiteralPath $packageRoot
    Get-ChildItem -LiteralPath $packageRoot -Recurse -Force
)
foreach ($item in $integrityItems) {
    Assert-Valid (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Reparse point found in package: $($item.FullName)"
    if (-not $item.PSIsContainer) {
        $alternateStreams = @(Get-Item -LiteralPath $item.FullName -Stream * -ErrorAction Stop | Where-Object { $_.Stream -cne ':$DATA' })
        Assert-Valid ($alternateStreams.Count -eq 0) "Alternate data stream found on package file: $($item.FullName)"
    }
}

if (-not $SkipOfflineTests) {
    & $testPath -ServerPath $serverPath
    & $setupTestPath
}

Write-Output "PASS: package version 1.0.0 validated; server SHA-256 $actualServerHash."
