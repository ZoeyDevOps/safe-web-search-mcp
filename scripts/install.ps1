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

    # This check is load-bearing twice over. It confirms what the installer just
    # wrote, and it is the sole evidence that a pre-existing InstallRoot belongs
    # to this installer rather than to the user's own data. A weak version of
    # this check would let an unrelated directory be adopted, so every field the
    # installer sets is compared, not just the identities.
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        $expectedInheritance = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
            [Security.AccessControl.InheritanceFlags]::ObjectInherit
    } else {
        $expectedInheritance = [Security.AccessControl.InheritanceFlags]::None
    }

    $acl = Get-Acl -LiteralPath $Path
    Assert-InstallCondition ($acl.AreAccessRulesProtected) "ACL inheritance is still enabled: $Path"
    $owner = (New-Object Security.Principal.NTAccount($acl.Owner)).Translate([Security.Principal.SecurityIdentifier]).Value
    Assert-InstallCondition ([string]::Equals($owner, $OwnerSid.Value, [StringComparison]::OrdinalIgnoreCase)) "Unexpected owner on installed path: $Path"

    $allowedSids = @($OwnerSid.Value, 'S-1-5-18', 'S-1-5-32-544')
    $seenAllowSids = @{}
    foreach ($rule in $acl.Access) {
        # A Deny entry, an inherited entry, reduced rights, or an unexpected
        # flag combination all mean this is not a directory this installer
        # created and left alone.
        Assert-InstallCondition (-not $rule.IsInherited) "Inherited ACL entry on a protected path: $Path"
        Assert-InstallCondition ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow) "Unexpected Deny ACL entry on $Path"
        $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
        Assert-InstallCondition ($allowedSids -contains $sid) "Unexpected allowed ACL identity $sid on $Path"
        Assert-InstallCondition (-not $seenAllowSids.ContainsKey($sid)) "Duplicate ACL entry for $sid on $Path"
        Assert-InstallCondition ($rule.FileSystemRights -eq [Security.AccessControl.FileSystemRights]::FullControl) "ACL entry for $sid on $Path does not grant exactly FullControl"
        Assert-InstallCondition ($rule.InheritanceFlags -eq $expectedInheritance) "ACL entry for $sid on $Path has unexpected inheritance flags"
        Assert-InstallCondition ($rule.PropagationFlags -eq [Security.AccessControl.PropagationFlags]::None) "ACL entry for $sid on $Path has unexpected propagation flags"
        $seenAllowSids[$sid] = $true
    }
    foreach ($sid in $allowedSids) {
        Assert-InstallCondition $seenAllowSids.ContainsKey($sid) "Required ACL identity $sid is missing on $Path"
    }
}

$script:InstallRootMarkerName = '.safe-web-search-install-root'
$script:VersionDirectoryPattern = '\A[0-9]+\.[0-9]+\.[0-9]+\z'

function Assert-InstallerOwnedRoot {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][Security.Principal.SecurityIdentifier]$OwnerSid,
        [Parameter(Mandatory = $true)][string[]]$ExpectedTargetNames
    )

    # Called for a root that already existed when this invocation started. The
    # installer must never repair, re-own, or re-permission such a directory:
    # the user may have pointed -InstallRoot at their own data. Either it is
    # already exactly what this installer creates, or the install is refused.
    $rootItem = Get-Item -LiteralPath $RootPath -Force
    Assert-InstallCondition $rootItem.PSIsContainer "InstallRoot exists but is not a directory: $RootPath"
    Assert-InstallCondition ((($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) -eq 0) "InstallRoot is a reparse point: $RootPath"
    Assert-RestrictedAcl -Path $RootPath -OwnerSid $OwnerSid

    $markerPath = Join-Path $RootPath $script:InstallRootMarkerName
    $hasMarker = Test-Path -LiteralPath $markerPath
    if ($hasMarker) {
        Assert-NoExistingReparsePoint -Path $markerPath -Label 'InstallRoot marker'
        $markerItem = Get-Item -LiteralPath $markerPath -Force
        Assert-InstallCondition (-not $markerItem.PSIsContainer) "InstallRoot marker is not a file: $markerPath"
        Assert-RestrictedAcl -Path $markerPath -OwnerSid $OwnerSid
    }

    # Whether or not a marker is present, the root must contain only things this
    # installer creates. A root written by an earlier version carries no marker,
    # so it is accepted on the strength of its contents instead; an unrelated
    # directory that happens to carry a matching ACL still fails here.
    $completeVersions = 0
    foreach ($child in @(Get-ChildItem -LiteralPath $RootPath -Force)) {
        if (-not $child.PSIsContainer) {
            Assert-InstallCondition ($child.Name -ceq $script:InstallRootMarkerName) "InstallRoot holds an unexpected file: $($child.FullName)"
            continue
        }
        Assert-InstallCondition ($child.Name -cmatch $script:VersionDirectoryPattern) "InstallRoot holds an unexpected directory: $($child.FullName)"
        Assert-InstallCondition ((($child.Attributes -band [IO.FileAttributes]::ReparsePoint)) -eq 0) "InstallRoot holds a reparse point: $($child.FullName)"
        $childNames = @(Get-ChildItem -LiteralPath $child.FullName -Force | ForEach-Object { $_.Name } | Sort-Object)
        $expectedNames = @($ExpectedTargetNames | Sort-Object)
        Assert-InstallCondition (($childNames -join "`n") -ceq ($expectedNames -join "`n")) "InstallRoot holds a version directory with unexpected contents: $($child.FullName)"
        Assert-RestrictedAcl -Path $child.FullName -OwnerSid $OwnerSid
        $completeVersions++
    }

    Assert-InstallCondition ($hasMarker -or $completeVersions -gt 0) "InstallRoot already exists and was not created by this installer. Choose a new dedicated directory, or remove this one yourself: $RootPath"
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
# A UNC destination is not supported. Ownership, inheritance, and reparse
# semantics on a remote share are the server's, not this machine's, so the
# checks below would not mean what they mean locally.
Assert-InstallCondition (-not $canonicalInstallRoot.StartsWith('\\')) 'InstallRoot cannot be a UNC path. Install to a local directory.'
Assert-NoExistingReparsePoint -Path $canonicalInstallRoot -Label 'InstallRoot'

$packagePrefix = $packageRoot.TrimEnd('\') + '\'
Assert-InstallCondition (-not [string]::Equals($canonicalInstallRoot, $packageRoot, [StringComparison]::OrdinalIgnoreCase) -and
    -not $canonicalInstallRoot.StartsWith($packagePrefix, [StringComparison]::OrdinalIgnoreCase)) 'InstallRoot cannot be the package directory or one of its children.'

$targetDirectory = Join-Path $canonicalInstallRoot $version
$targetServerPath = Join-Path $targetDirectory 'server.ps1'
$expectedTargetNames = @('LICENSE', 'PROVIDER-NOTICE.md', 'release-manifest.json', 'server.ps1')

# Whether the root already existed decides everything below. Only a directory
# this invocation creates may be given the restricted ACL; one that was already
# there must already carry it. Deciding this before ShouldProcess is what makes
# -WhatIf refuse an unsafe root rather than print a plan that could never be
# carried out safely, and it runs before the version-directory check so a valid
# version folder cannot vouch for a root that is not ours.
$rootExistedAtEntry = Test-Path -LiteralPath $canonicalInstallRoot
if ($rootExistedAtEntry) {
    Assert-InstallerOwnedRoot -RootPath $canonicalInstallRoot -OwnerSid $currentUserSid -ExpectedTargetNames $expectedTargetNames
}

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
    if ($rootExistedAtEntry) {
        # Re-verify immediately before staging. The window between the check
        # above and this point is small but real, and acting on a stale result
        # would mean writing into a directory that is no longer ours. Nothing
        # here writes to the root's own ACL.
        Assert-NoExistingReparsePoint -Path $canonicalInstallRoot -Label 'InstallRoot'
        Assert-InstallerOwnedRoot -RootPath $canonicalInstallRoot -OwnerSid $currentUserSid -ExpectedTargetNames $expectedTargetNames
    } else {
        # Only a directory created by this invocation is given the restricted
        # ACL. If anything appeared at the path in the meantime, abort rather
        # than adopt and harden whatever is now there.
        Assert-InstallCondition (-not (Test-Path -LiteralPath $canonicalInstallRoot)) 'InstallRoot appeared after it was found absent; refusing to adopt it.'
        $createdRoot = New-Item -ItemType Directory -Path $canonicalInstallRoot
        Assert-InstallCondition ($null -ne $createdRoot -and $createdRoot.PSIsContainer) 'Creating InstallRoot did not produce a directory.'
        Assert-InstallCondition ([string]::Equals(
            [IO.Path]::GetFullPath($createdRoot.FullName).TrimEnd('\'),
            $canonicalInstallRoot,
            [StringComparison]::OrdinalIgnoreCase)) 'Creating InstallRoot produced an unexpected path.'
        Assert-NoExistingReparsePoint -Path $canonicalInstallRoot -Label 'InstallRoot after creation'
        Set-RestrictedDirectoryAcl -Path $canonicalInstallRoot -OwnerSid $currentUserSid
        Assert-RestrictedAcl -Path $canonicalInstallRoot -OwnerSid $currentUserSid

        # Mark the root as this installer's, so a later run can tell its own
        # directory from one the user pointed it at.
        $markerPath = Join-Path $canonicalInstallRoot $script:InstallRootMarkerName
        Set-Content -LiteralPath $markerPath -Value 'safe-web-search install root' -Encoding ASCII
        Set-RestrictedFileAcl -Path $markerPath -OwnerSid $currentUserSid
        Assert-RestrictedAcl -Path $markerPath -OwnerSid $currentUserSid
    }

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
