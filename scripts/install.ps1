# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Zoey and contributors

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$InstallRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Assert-InstallCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-CanonicalAbsolutePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Assert-InstallCondition (-not [string]::IsNullOrWhiteSpace($Path)) "$Label is empty."
    Assert-InstallCondition ($Path.IndexOf([char]0) -lt 0 -and -not $Path.Contains('"')) "$Label contains an unsupported character."
    Assert-InstallCondition ([IO.Path]::IsPathRooted($Path)) "$Label must be an absolute path."
    try {
        return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    } catch {
        throw "$Label is not a valid Windows path: $($_.Exception.Message)"
    }
}

function Assert-NoExistingReparsePoint {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $current = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrWhiteSpace($current)) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            Assert-InstallCondition (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "$Label crosses a reparse point: $current"
        }

        $parent = [IO.Directory]::GetParent($current)
        if ($null -eq $parent -or [string]::Equals($parent.FullName, $current, [StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $current = $parent.FullName
    }
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = $null
    $sha256 = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $sha256 = [Security.Cryptography.SHA256]::Create()
        return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-', '')
    } finally {
        if ($null -ne $sha256) { $sha256.Dispose() }
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

function New-RestrictedDirectoryAcl {
    param([Parameter(Mandatory = $true)][Security.Principal.SecurityIdentifier]$OwnerSid)

    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetOwner($OwnerSid)
    $acl.SetAccessRuleProtection($true, $false)
    $inheritance = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagation = [Security.AccessControl.PropagationFlags]::None
    foreach ($sidText in @($OwnerSid.Value, 'S-1-5-18', 'S-1-5-32-544')) {
        $sid = New-Object Security.Principal.SecurityIdentifier($sidText)
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
            $sid,
            [Security.AccessControl.FileSystemRights]::FullControl,
            $inheritance,
            $propagation,
            [Security.AccessControl.AccessControlType]::Allow
        )
        $null = $acl.AddAccessRule($rule)
    }
    return $acl
}

function New-RestrictedFileAcl {
    param([Parameter(Mandatory = $true)][Security.Principal.SecurityIdentifier]$OwnerSid)

    $acl = New-Object Security.AccessControl.FileSecurity
    $acl.SetOwner($OwnerSid)
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sidText in @($OwnerSid.Value, 'S-1-5-18', 'S-1-5-32-544')) {
        $sid = New-Object Security.Principal.SecurityIdentifier($sidText)
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
            $sid,
            [Security.AccessControl.FileSystemRights]::FullControl,
            [Security.AccessControl.AccessControlType]::Allow
        )
        $null = $acl.AddAccessRule($rule)
    }
    return $acl
}

function Set-RestrictedDirectoryAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][Security.Principal.SecurityIdentifier]$OwnerSid
    )

    Set-Acl -LiteralPath $Path -AclObject (New-RestrictedDirectoryAcl -OwnerSid $OwnerSid)
}

function Set-RestrictedFileAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][Security.Principal.SecurityIdentifier]$OwnerSid
    )

    Set-Acl -LiteralPath $Path -AclObject (New-RestrictedFileAcl -OwnerSid $OwnerSid)
}

function Assert-RestrictedAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][Security.Principal.SecurityIdentifier]$OwnerSid
    )

    $acl = Get-Acl -LiteralPath $Path
    Assert-InstallCondition ($acl.AreAccessRulesProtected) "ACL inheritance is still enabled: $Path"
    $owner = (New-Object Security.Principal.NTAccount($acl.Owner)).Translate([Security.Principal.SecurityIdentifier]).Value
    Assert-InstallCondition ([string]::Equals($owner, $OwnerSid.Value, [StringComparison]::OrdinalIgnoreCase)) "Unexpected owner on installed path: $Path"

    $allowedSids = @($OwnerSid.Value, 'S-1-5-18', 'S-1-5-32-544')
    $seenAllowSids = @{}
    foreach ($rule in $acl.Access) {
        if ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow) {
            $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
            Assert-InstallCondition ($allowedSids -contains $sid) "Unexpected allowed ACL identity $sid on $Path"
            $seenAllowSids[$sid] = $true
        }
    }
    foreach ($sid in $allowedSids) {
        Assert-InstallCondition $seenAllowSids.ContainsKey($sid) "Required ACL identity $sid is missing on $Path"
    }
}

function Remove-OwnedStagingDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$StagePath,
        [Parameter(Mandatory = $true)][string]$RootPath
    )

    if (-not (Test-Path -LiteralPath $StagePath)) {
        return
    }

    $canonicalStage = [IO.Path]::GetFullPath($StagePath)
    $expectedPrefix = [IO.Path]::GetFullPath($RootPath).TrimEnd('\') + '\.staging-'
    Assert-InstallCondition $canonicalStage.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase) 'Refusing to clean an unexpected staging path.'
    $stageItem = Get-Item -LiteralPath $canonicalStage -Force
    Assert-InstallCondition ($stageItem.PSIsContainer -and (($stageItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0)) 'Refusing to clean a staging path that is not a regular directory.'

    $allowedStageNames = @('LICENSE', 'PROVIDER-NOTICE.md', 'release-manifest.json', 'server.ps1')
    foreach ($item in @(Get-ChildItem -LiteralPath $canonicalStage -Force)) {
        Assert-InstallCondition (-not $item.PSIsContainer -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) -and ($allowedStageNames -ccontains $item.Name)) "Refusing to clean an unexpected staging item: $($item.FullName)"
        Remove-Item -LiteralPath $item.FullName -Force
    }
    Remove-Item -LiteralPath $canonicalStage -Force
}

if ($PSVersionTable.PSEdition -cne 'Desktop' -or
    $PSVersionTable.PSVersion.Major -ne 5 -or
    $PSVersionTable.PSVersion.Minor -lt 1) {
    throw 'The installer must run in Windows PowerShell 5.1 (powershell.exe), not PowerShell 7 (pwsh.exe).'
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this installer from a normal, non-administrator terminal.'
}
$currentUserSid = $identity.User

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$packageRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDirectory '..')).Path
$manifestPath = Join-Path $packageRoot 'release-manifest.json'
Assert-InstallCondition (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'release-manifest.json is missing.'
Assert-NoExistingReparsePoint -Path $packageRoot -Label 'Package root'
Assert-NoExistingReparsePoint -Path $manifestPath -Label 'Release manifest'

try {
    $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
} catch {
    throw "release-manifest.json is not valid JSON: $($_.Exception.Message)"
}

$version = [string]$manifest.version
$relativeServerPath = [string]$manifest.server.path
$expectedServerHash = [string]$manifest.server.sha256
Assert-InstallCondition ([int]$manifest.schema_version -eq 1) 'Manifest schema version is unsupported.'
Assert-InstallCondition ([string]$manifest.name -ceq 'safe-web-search') 'Manifest package name is unexpected.'
Assert-InstallCondition ($version -cmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z') 'Manifest version is not a simple semantic version.'
Assert-InstallCondition ($relativeServerPath -ceq 'src/server.ps1') 'Manifest server path is unexpected.'
Assert-InstallCondition ($expectedServerHash -cmatch '\A[0-9A-F]{64}\z') 'Manifest server SHA-256 is invalid.'

$sourceServerPath = Join-Path $packageRoot 'src\server.ps1'
$sourceLicensePath = Join-Path $packageRoot 'LICENSE'
$sourceProviderNoticePath = Join-Path $packageRoot 'PROVIDER-NOTICE.md'
foreach ($requiredPath in @($sourceServerPath, $sourceLicensePath, $sourceProviderNoticePath)) {
    Assert-InstallCondition (Test-Path -LiteralPath $requiredPath -PathType Leaf) "Required package file is missing: $requiredPath"
    Assert-NoExistingReparsePoint -Path $requiredPath -Label 'Package source'
}
$actualSourceHash = Get-Sha256Hex -Path $sourceServerPath
Assert-InstallCondition ($actualSourceHash -ceq $expectedServerHash) "Server hash does not match the release manifest. Expected $expectedServerHash; got $actualSourceHash."

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    Assert-InstallCondition (-not [string]::IsNullOrWhiteSpace($localAppData)) 'Windows did not provide a Local AppData path.'
    $InstallRoot = Join-Path $localAppData 'Programs\SafeWebSearchMCP'
}

$canonicalInstallRoot = Get-CanonicalAbsolutePath -Path $InstallRoot -Label 'InstallRoot'
$pathRoot = [IO.Path]::GetPathRoot($canonicalInstallRoot).TrimEnd('\')
Assert-InstallCondition (-not [string]::Equals($canonicalInstallRoot.TrimEnd('\'), $pathRoot, [StringComparison]::OrdinalIgnoreCase)) 'InstallRoot cannot be a drive root.'
Assert-NoExistingReparsePoint -Path $canonicalInstallRoot -Label 'InstallRoot'

$packagePrefix = $packageRoot.TrimEnd('\') + '\'
Assert-InstallCondition (-not [string]::Equals($canonicalInstallRoot, $packageRoot, [StringComparison]::OrdinalIgnoreCase) -and
    -not $canonicalInstallRoot.StartsWith($packagePrefix, [StringComparison]::OrdinalIgnoreCase)) 'InstallRoot cannot be the package directory or one of its children.'

$targetDirectory = Join-Path $canonicalInstallRoot $version
$targetServerPath = Join-Path $targetDirectory 'server.ps1'
$expectedTargetNames = @('LICENSE', 'PROVIDER-NOTICE.md', 'release-manifest.json', 'server.ps1')

if (Test-Path -LiteralPath $targetDirectory) {
    Assert-NoExistingReparsePoint -Path $targetDirectory -Label 'Existing installation'
    $targetItem = Get-Item -LiteralPath $targetDirectory -Force
    Assert-InstallCondition $targetItem.PSIsContainer 'The version target exists but is not a directory.'
    $actualNames = @(Get-ChildItem -LiteralPath $targetDirectory -Force | ForEach-Object { $_.Name } | Sort-Object)
    $expectedNames = @($expectedTargetNames | Sort-Object)
    Assert-InstallCondition (($actualNames -join "`n") -ceq ($expectedNames -join "`n")) 'The existing version directory contains missing or unexpected items; refusing to replace it.'
    Assert-InstallCondition ((Get-Sha256Hex -Path $targetServerPath) -ceq $expectedServerHash) 'The existing installed server has a different hash; refusing to overwrite it.'
    Assert-RestrictedAcl -Path $targetDirectory -OwnerSid $currentUserSid
    foreach ($name in $expectedTargetNames) {
        $existingFile = Join-Path $targetDirectory $name
        Assert-NoExistingReparsePoint -Path $existingFile -Label 'Existing installed file'
        Assert-RestrictedAcl -Path $existingFile -OwnerSid $currentUserSid
    }

    [pscustomobject]@{
        Status = 'Already installed and verified'
        Version = $version
        ServerPath = $targetServerPath.Replace('\', '/')
        NativeServerPath = $targetServerPath
        SHA256 = $expectedServerHash
        AlreadyInstalled = $true
    }
    return
}

$plannedResult = [pscustomobject]@{
    Status = if ($WhatIfPreference) { 'Planned only' } else { 'Installed and verified' }
    Version = $version
    ServerPath = $targetServerPath.Replace('\', '/')
    NativeServerPath = $targetServerPath
    SHA256 = $expectedServerHash
    AlreadyInstalled = $false
}

if (-not $PSCmdlet.ShouldProcess($targetDirectory, "Install Safe Web Search MCP $version")) {
    $plannedResult
    return
}

$stageDirectory = Join-Path $canonicalInstallRoot ('.staging-' + [Guid]::NewGuid().ToString('N'))
try {
    if (-not (Test-Path -LiteralPath $canonicalInstallRoot)) {
        $null = New-Item -ItemType Directory -Path $canonicalInstallRoot
    }
    Assert-NoExistingReparsePoint -Path $canonicalInstallRoot -Label 'InstallRoot after creation'
    Set-RestrictedDirectoryAcl -Path $canonicalInstallRoot -OwnerSid $currentUserSid
    Assert-RestrictedAcl -Path $canonicalInstallRoot -OwnerSid $currentUserSid

    Assert-InstallCondition (-not (Test-Path -LiteralPath $stageDirectory)) 'A generated staging path already exists.'
    $null = New-Item -ItemType Directory -Path $stageDirectory
    Set-RestrictedDirectoryAcl -Path $stageDirectory -OwnerSid $currentUserSid

    Copy-Item -LiteralPath $sourceServerPath -Destination (Join-Path $stageDirectory 'server.ps1')
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stageDirectory 'release-manifest.json')
    Copy-Item -LiteralPath $sourceLicensePath -Destination (Join-Path $stageDirectory 'LICENSE')
    Copy-Item -LiteralPath $sourceProviderNoticePath -Destination (Join-Path $stageDirectory 'PROVIDER-NOTICE.md')

    foreach ($name in $expectedTargetNames) {
        $stagedFile = Join-Path $stageDirectory $name
        Set-RestrictedFileAcl -Path $stagedFile -OwnerSid $currentUserSid
        Assert-RestrictedAcl -Path $stagedFile -OwnerSid $currentUserSid
    }
    Assert-InstallCondition ((Get-Sha256Hex -Path (Join-Path $stageDirectory 'server.ps1')) -ceq $expectedServerHash) 'Staged server hash verification failed.'
    Assert-InstallCondition (-not (Test-Path -LiteralPath $targetDirectory)) 'The target appeared during installation; refusing to overwrite it.'

    [IO.Directory]::Move($stageDirectory, $targetDirectory)
    Assert-NoExistingReparsePoint -Path $targetDirectory -Label 'Installed version'
    Assert-RestrictedAcl -Path $targetDirectory -OwnerSid $currentUserSid
    foreach ($name in $expectedTargetNames) {
        $installedFile = Join-Path $targetDirectory $name
        Assert-NoExistingReparsePoint -Path $installedFile -Label 'Installed file'
        Assert-RestrictedAcl -Path $installedFile -OwnerSid $currentUserSid
    }
    Assert-InstallCondition ((Get-Sha256Hex -Path $targetServerPath) -ceq $expectedServerHash) 'Installed server hash verification failed.'
} catch {
    if (Test-Path -LiteralPath $stageDirectory) {
        Remove-OwnedStagingDirectory -StagePath $stageDirectory -RootPath $canonicalInstallRoot
    }
    throw
}

$plannedResult
