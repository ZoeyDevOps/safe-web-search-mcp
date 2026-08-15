# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Zoey and contributors

[CmdletBinding()]
param(
    [switch]$SkipOfflineTests,
    # Skips both checks that drive scripts\install.ps1: the setup preview in
    # tests\setup-lm-studio-offline.ps1 and the access-control suite in
    # tests\install-root-acl.ps1. They are one switch because they share one
    # precondition - the installer refuses to run elevated, so neither can be
    # exercised from an elevated session - and one reason to skip. An ephemeral
    # CI runner is elevated and is discarded when the job ends, so neither check
    # says anything there about installing on a real workstation. Everything
    # else, including the full offline protocol suite and the manifest hash
    # check, still runs. Leave this switch off on a normal, non-elevated
    # workstation: that is the only place these two run at all, in CI or
    # anywhere else.
    [switch]$SkipInstallerChecks
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

# Fail on elevation now rather than after the offline suite has run. Both
# installer checks call scripts\install.ps1, which refuses an elevated session
# by design, so an elevated run of this script is already decided - reporting it
# in a second, with the way out, beats reporting it in minutes.
if (-not $SkipOfflineTests -and -not $SkipInstallerChecks) {
    $validationIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $validationPrincipal = New-Object Security.Principal.WindowsPrincipal($validationIdentity)
    if ($validationPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This session is elevated, so the installer checks cannot run: scripts\install.ps1 refuses to start with administrator rights. Re-run from a normal, non-administrator terminal to cover the installer, or pass -SkipInstallerChecks to run everything else and leave it uncovered.'
    }
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$packageRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDirectory '..')).Path
$manifestPath = Join-Path $packageRoot 'release-manifest.json'
$serverPath = Join-Path $packageRoot 'src\server.ps1'
$testPath = Join-Path $packageRoot 'tests\run-offline.ps1'
$setupTestPath = Join-Path $packageRoot 'tests\setup-lm-studio-offline.ps1'
$aclTestPath = Join-Path $packageRoot 'tests\install-root-acl.ps1'
$installerPath = Join-Path $packageRoot 'scripts\install.ps1'
$lmStudioSetupPath = Join-Path $packageRoot 'scripts\setup-lm-studio.ps1'
$lmStudioLauncherPath = Join-Path $packageRoot 'Install for LM Studio.cmd'
$attributesPath = Join-Path $packageRoot '.gitattributes'

Assert-Valid (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'release-manifest.json is missing.'
Assert-Valid (Test-Path -LiteralPath $serverPath -PathType Leaf) 'src\server.ps1 is missing.'
Assert-Valid (Test-Path -LiteralPath $testPath -PathType Leaf) 'tests\run-offline.ps1 is missing.'
Assert-Valid (Test-Path -LiteralPath $setupTestPath -PathType Leaf) 'tests\setup-lm-studio-offline.ps1 is missing.'
Assert-Valid (Test-Path -LiteralPath $aclTestPath -PathType Leaf) 'tests\install-root-acl.ps1 is missing.'
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

# Only LM Studio is a verified host. The other templates ship as conventional
# local-stdio formats that nothing exercises, so their contents are asserted here
# instead of being left to inspection: an edit that quietly changed an executable
# path, an argument, or the placeholder in an untested template would otherwise
# reach users through the one category no test covers.
$reviewedShellPath = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$reviewedArguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File')
$templateFiles = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'configs') -File -Filter '*.template.json')
Assert-Valid ($templateFiles.Count -eq 4) "Expected four host configuration templates in configs; found $($templateFiles.Count)."

foreach ($templateFile in $templateFiles) {
    $templateName = $templateFile.Name
    $template = [IO.File]::ReadAllText($templateFile.FullName) | ConvertFrom-Json

    # VS Code declares servers with an explicit stdio type; the rest use the
    # conventional mcpServers object.
    $isVsCode = $templateName -ceq 'vscode.template.json'
    $containerName = if ($isVsCode) { 'servers' } else { 'mcpServers' }
    Assert-Valid (@($template.PSObject.Properties.Name) -ccontains $containerName) "$templateName does not declare a '$containerName' object."
    $serverNames = @($template.$containerName.PSObject.Properties.Name)
    Assert-Valid ($serverNames.Count -eq 1 -and $serverNames[0] -ceq 'safe-web-search') "$templateName must declare exactly one server named safe-web-search."
    $entry = $template.$containerName.'safe-web-search'
    $entryFields = @($entry.PSObject.Properties.Name)

    Assert-Valid ($entryFields -ccontains 'command') "$templateName declares no command."
    Assert-Valid ([string]$entry.command -ceq $reviewedShellPath) "$templateName does not call the reviewed Windows PowerShell 5.1 executable."

    if ($isVsCode) {
        Assert-Valid ($entryFields -ccontains 'type') "$templateName must declare a transport type."
        Assert-Valid ([string]$entry.type -ceq 'stdio') "$templateName must declare the stdio transport."
    }

    Assert-Valid ($entryFields -ccontains 'args') "$templateName declares no argument list."
    $templateArguments = @($entry.args)
    Assert-Valid ($templateArguments.Count -eq ($reviewedArguments.Count + 1)) "$templateName must pass the $($reviewedArguments.Count) reviewed arguments and one server path; found $($templateArguments.Count)."
    for ($argumentIndex = 0; $argumentIndex -lt $reviewedArguments.Count; $argumentIndex++) {
        Assert-Valid ([string]$templateArguments[$argumentIndex] -ceq $reviewedArguments[$argumentIndex]) "$templateName argument $argumentIndex must be $($reviewedArguments[$argumentIndex])."
    }
    $templateServerPath = [string]$templateArguments[$reviewedArguments.Count]
    Assert-Valid ($templateServerPath -cmatch 'REPLACE_WITH_ABSOLUTE_PATH') "$templateName must keep the REPLACE_WITH_ABSOLUTE_PATH placeholder so no local path ships."
    Assert-Valid ($templateServerPath -cmatch 'src/server\.ps1\z') "$templateName must point at src/server.ps1."

    # Only the verified host's format carries a timeout, and the checklist
    # forbids inventing one for hosts that may ignore it, so absence is asserted
    # as deliberately as presence.
    $hasTimeout = $entryFields -ccontains 'timeout'
    if ($templateName -ceq 'lm-studio.template.json') {
        Assert-Valid $hasTimeout 'lm-studio.template.json must set a timeout.'
        Assert-Valid ([int]$entry.timeout -ge 15000) 'lm-studio.template.json must allow the host at least 15 seconds.'
    } else {
        Assert-Valid (-not $hasTimeout) "$templateName must not set a timeout; only the verified host's format carries one."
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
    if ($SkipInstallerChecks) {
        Write-Output 'SKIP: installer checks omitted. The LM Studio setup preview and the install-root ACL suite both require a non-elevated workstation, and neither is covered anywhere else.'
    } else {
        & $setupTestPath
        & $aclTestPath
    }
}

Write-Output "PASS: package version 1.0.0 validated; server SHA-256 $actualServerHash."
