# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Zoey and contributors

<#
.SYNOPSIS
    Proves that scripts\install.ps1 never rewrites permissions on a directory it
    did not create.

.DESCRIPTION
    This suite exists because the installer's dangerous operation is invisible in
    its output: replacing the ACL on a pre-existing InstallRoot silently removes
    inheritance and other principals' access from a directory the user may care
    about. Every assertion here is therefore a comparison of before and after
    state - SDDL, contents, and file hashes - rather than a check of what the
    installer said it did.

    It must run in Windows PowerShell 5.1 from a NON-ELEVATED account. The
    installer refuses to run elevated by design, so an elevated session cannot
    exercise the success path at all and this script will refuse to start.

    Test directories are created under the system temporary directory with GUID
    names. A directory is only removed after its exact path, object type, and
    reparse status have been re-verified. Directories belonging to a failed test
    are deliberately left in place for inspection; their paths are printed.
#>

[CmdletBinding()]
param(
    [switch]$KeepAll
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

if ($PSVersionTable.PSEdition -cne 'Desktop' -or
    $PSVersionTable.PSVersion.Major -ne 5 -or
    $PSVersionTable.PSVersion.Minor -lt 1) {
    throw 'Run this suite in Windows PowerShell 5.1 (powershell.exe), not PowerShell 7 (pwsh.exe).'
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'PRECONDITION NOT MET: this session is elevated. scripts\install.ps1 refuses to run elevated, so neither the refusal cases nor the success path can be exercised here. Re-run from a normal, non-administrator terminal. Do not record this run as a pass.'
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path (Split-Path -Parent $PSCommandPath) '..')).Path
$installerPath = Join-Path $repoRoot 'scripts\install.ps1'
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw "Installer not found at $installerPath"
}
$shell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$currentUserSid = $identity.User.Value

$script:Failures = New-Object Collections.ArrayList
$script:Retained = New-Object Collections.ArrayList
$script:Passes = 0

function Write-Case { param([string]$Name) Write-Output ''; Write-Output "CASE: $Name" }

function Assert-TestCondition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-TestDirectory {
    # A GUID name under TEMP keeps every test path unique and recognisable, so
    # cleanup can insist on the exact shape it expects before deleting anything.
    $path = Join-Path ([IO.Path]::GetTempPath()) ('swsmcp-test-' + [Guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $path
    return (Resolve-Path -LiteralPath $path).Path
}

function Get-PathSddl {
    param([string]$Path)
    return (Get-Acl -LiteralPath $Path).Sddl
}

function Add-RootAccessRule {
    # Adds one entry to a directory's DACL and changes nothing else.
    #
    # Get-Acl followed by Set-Acl cannot do this here. The installer gives the
    # root a protected DACL and an explicitly assigned owner, and writing that
    # descriptor back through Set-Acl asks Windows for SACL access, which
    # requires SeSecurityPrivilege. A non-elevated account does not hold that
    # privilege, so the call fails before the installer is ever re-run and the
    # case reports a privilege error instead of the refusal it exists to check.
    # Requesting the Access section alone scopes both the read and the write to
    # the DACL, leaving owner, group, and protection untouched.
    param(
        [string]$Path,
        [Security.AccessControl.FileSystemAccessRule]$Rule
    )
    $item = Get-Item -LiteralPath $Path -Force
    $acl = $item.GetAccessControl([Security.AccessControl.AccessControlSections]::Access)
    $acl.AddAccessRule($Rule)
    $item.SetAccessControl($acl)
}

function Get-TreeSnapshot {
    # Records enough to prove nothing changed: relative paths, file hashes, and
    # the SDDL of every object in the tree.
    param([string]$Path)
    $snapshot = [ordered]@{}
    $snapshot['.'] = Get-PathSddl -Path $Path
    foreach ($item in @(Get-ChildItem -LiteralPath $Path -Recurse -Force | Sort-Object FullName)) {
        $relative = $item.FullName.Substring($Path.Length).TrimStart('\')
        $entry = Get-PathSddl -Path $item.FullName
        if (-not $item.PSIsContainer) {
            $entry = $entry + '|' + (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash
        }
        $snapshot[$relative] = $entry
    }
    return $snapshot
}

function Assert-SnapshotUnchanged {
    param($Before, $After, [string]$Label)
    $beforeKeys = @($Before.Keys)
    $afterKeys = @($After.Keys)
    Assert-TestCondition (($beforeKeys -join '|') -ceq ($afterKeys -join '|')) "$Label - the set of paths changed. Before: $($beforeKeys -join ', '). After: $($afterKeys -join ', ')."
    foreach ($key in $beforeKeys) {
        Assert-TestCondition ($Before[$key] -ceq $After[$key]) "$Label - '$key' changed. Before: $($Before[$key]). After: $($After[$key])."
    }
}

function Invoke-Installer {
    <#
        Runs the real installer in a child process.

        Start-Process with redirected streams, not '2>&1': in Windows PowerShell
        5.1 redirecting a native command's stderr wraps each line in a
        NativeCommandError, which under 'Stop' aborts before the exit code can
        be read.
    #>
    param(
        [string]$InstallRoot,
        [switch]$WhatIf
    )
    $out = Join-Path ([IO.Path]::GetTempPath()) ('swsmcp-out-' + [Guid]::NewGuid().ToString('N') + '.txt')
    $err = Join-Path ([IO.Path]::GetTempPath()) ('swsmcp-err-' + [Guid]::NewGuid().ToString('N') + '.txt')
    $arguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', $installerPath, '-InstallRoot', $InstallRoot)
    if ($WhatIf) { $arguments += '-WhatIf' }
    try {
        $process = Start-Process -FilePath $shell -Wait -PassThru -NoNewWindow `
            -WorkingDirectory $repoRoot -ArgumentList $arguments `
            -RedirectStandardOutput $out -RedirectStandardError $err
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut   = [string](Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue)
            StdErr   = [string](Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue)
        }
    } finally {
        foreach ($stream in @($out, $err)) {
            if (Test-Path -LiteralPath $stream) { Remove-Item -LiteralPath $stream -Force }
        }
    }
}

function Assert-Refused {
    param($Result, [string]$Label)
    Assert-TestCondition ($Result.ExitCode -ne 0) "$Label - the installer exited 0; it should have refused. StdOut: $($Result.StdOut)"
}

function Clear-DenyRules {
    # Some cases plant a Deny entry to prove the installer refuses one. A Deny
    # naming Authenticated Users denies this account too, and Deny wins over
    # Allow, so the tree cannot be deleted while the entry stands. The account
    # running the suite owns these directories, and an owner keeps WRITE_DAC
    # whatever the DACL says, so rewriting the DACL still succeeds here.
    #
    # The root is processed first: removing the entry there also clears the
    # inherited copies on everything beneath it, which could not be removed
    # from the children directly.
    param([string]$Path)
    $targets = @(Get-Item -LiteralPath $Path -Force)
    $targets += @(Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue)
    foreach ($target in $targets) {
        try {
            $acl = $target.GetAccessControl([Security.AccessControl.AccessControlSections]::Access)
            $denied = @($acl.Access | Where-Object {
                $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Deny -and -not $_.IsInherited
            })
            if ($denied.Count -eq 0) { continue }
            foreach ($rule in $denied) { $null = $acl.RemoveAccessRuleSpecific($rule) }
            $target.SetAccessControl($acl)
        } catch {
            # Leave it for the retained-directory report rather than masking the
            # real failure with a cleanup error.
        }
    }
}

function Remove-TestDirectory {
    # Refuses to delete anything that is not the exact GUID-named test directory
    # this suite created.
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return }
    $canonical = (Resolve-Path -LiteralPath $Path).Path
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\swsmcp-test-'
    Assert-TestCondition ($canonical.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) "Refusing to remove a path outside the test area: $canonical"
    $item = Get-Item -LiteralPath $canonical -Force
    Assert-TestCondition ($item.PSIsContainer) "Refusing to remove a non-directory test path: $canonical"
    Assert-TestCondition ((($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) -eq 0) "Refusing to remove a reparse point: $canonical"
    # Only after the guards above have confirmed this is our own test directory.
    Clear-DenyRules -Path $canonical
    Remove-Item -LiteralPath $canonical -Recurse -Force
}

function Invoke-Case {
    param([string]$Name, [scriptblock]$Body)
    Write-Case -Name $Name
    $paths = New-Object Collections.ArrayList
    try {
        & $Body $paths
        Write-Output "  PASS"
        $script:Passes++
        if (-not $KeepAll) {
            foreach ($p in $paths) { Remove-TestDirectory -Path $p }
        } else {
            foreach ($p in $paths) { $null = $script:Retained.Add($p) }
        }
    } catch {
        Write-Output "  FAIL: $($_.Exception.Message)"
        $null = $script:Failures.Add("$Name`: $($_.Exception.Message)")
        foreach ($p in $paths) { $null = $script:Retained.Add($p) }
    }
}

Write-Output "Installer:      $installerPath"
Write-Output "Running as SID: $currentUserSid (non-elevated)"

# ---------------------------------------------------------------------------

Invoke-Case 'Pre-existing inherited-ACL root with a sentinel file is refused, unchanged' {
    param($paths)
    $root = New-TestDirectory; $null = $paths.Add($root)
    Set-Content -LiteralPath (Join-Path $root 'sentinel.txt') -Value 'user data' -Encoding ASCII
    $before = Get-TreeSnapshot -Path $root

    $result = Invoke-Installer -InstallRoot $root
    Assert-Refused -Result $result -Label 'inherited-ACL root'

    Assert-SnapshotUnchanged -Before $before -After (Get-TreeSnapshot -Path $root) -Label 'inherited-ACL root'
    Assert-TestCondition (-not (Test-Path -LiteralPath (Join-Path $root '1.0.0'))) 'A version directory was created under a refused root.'
    Assert-TestCondition (@(Get-ChildItem -LiteralPath $root -Force -Filter '.staging-*').Count -eq 0) 'A staging directory was left under a refused root.'
}

Invoke-Case 'Pre-existing inherited-ACL root under -WhatIf is refused, unchanged' {
    param($paths)
    $root = New-TestDirectory; $null = $paths.Add($root)
    Set-Content -LiteralPath (Join-Path $root 'sentinel.txt') -Value 'user data' -Encoding ASCII
    $before = Get-TreeSnapshot -Path $root

    $result = Invoke-Installer -InstallRoot $root -WhatIf
    Assert-Refused -Result $result -Label '-WhatIf on inherited-ACL root'

    Assert-SnapshotUnchanged -Before $before -After (Get-TreeSnapshot -Path $root) -Label '-WhatIf on inherited-ACL root'
}

Invoke-Case 'Unsafe root containing a plausible 1.0.0 directory is still refused' {
    param($paths)
    # The version directory must not be able to vouch for a root that is not
    # ours: root validation has to happen first.
    $root = New-TestDirectory; $null = $paths.Add($root)
    $version = Join-Path $root '1.0.0'
    $null = New-Item -ItemType Directory -Path $version
    $sourceByName = [ordered]@{
        'LICENSE'              = Join-Path $repoRoot 'LICENSE'
        'PROVIDER-NOTICE.md'   = Join-Path $repoRoot 'PROVIDER-NOTICE.md'
        'release-manifest.json' = Join-Path $repoRoot 'release-manifest.json'
        'server.ps1'           = Join-Path $repoRoot 'src\server.ps1'
    }
    foreach ($name in $sourceByName.Keys) {
        Copy-Item -LiteralPath $sourceByName[$name] -Destination (Join-Path $version $name)
    }
    $before = Get-TreeSnapshot -Path $root

    $result = Invoke-Installer -InstallRoot $root
    Assert-Refused -Result $result -Label 'unsafe root with plausible version directory'
    Assert-SnapshotUnchanged -Before $before -After (Get-TreeSnapshot -Path $root) -Label 'unsafe root with plausible version directory'
}

Invoke-Case 'A file supplied as InstallRoot is refused and left unchanged' {
    param($paths)
    $holder = New-TestDirectory; $null = $paths.Add($holder)
    $file = Join-Path $holder 'not-a-directory.txt'
    Set-Content -LiteralPath $file -Value 'user data' -Encoding ASCII
    $beforeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash
    $beforeSddl = Get-PathSddl -Path $file

    $result = Invoke-Installer -InstallRoot $file
    Assert-Refused -Result $result -Label 'file as InstallRoot'

    Assert-TestCondition ((Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash -ceq $beforeHash) 'The file supplied as InstallRoot was modified.'
    Assert-TestCondition ((Get-PathSddl -Path $file) -ceq $beforeSddl) 'The ACL of the file supplied as InstallRoot was modified.'
}

Invoke-Case 'Nonexistent root under -WhatIf stays nonexistent' {
    param($paths)
    $holder = New-TestDirectory; $null = $paths.Add($holder)
    $root = Join-Path $holder 'dedicated'
    $result = Invoke-Installer -InstallRoot $root -WhatIf
    Assert-TestCondition ($result.ExitCode -eq 0) "-WhatIf on a nonexistent root failed unexpectedly. StdErr: $($result.StdErr)"
    Assert-TestCondition (-not (Test-Path -LiteralPath $root)) '-WhatIf created the install root.'
}

Invoke-Case 'Real install into a nonexistent dedicated root succeeds and is well-formed' {
    param($paths)
    $holder = New-TestDirectory; $null = $paths.Add($holder)
    $root = Join-Path $holder 'dedicated'

    $result = Invoke-Installer -InstallRoot $root
    Assert-TestCondition ($result.ExitCode -eq 0) "Install into a new dedicated root failed. StdErr: $($result.StdErr)"

    Assert-TestCondition (Test-Path -LiteralPath $root) 'The install root was not created.'
    Assert-TestCondition (Test-Path -LiteralPath (Join-Path $root '.safe-web-search-install-root')) 'The installer-owned marker was not written.'
    $version = Join-Path $root '1.0.0'
    Assert-TestCondition (Test-Path -LiteralPath $version) 'The version directory was not created.'
    foreach ($name in @('LICENSE', 'PROVIDER-NOTICE.md', 'release-manifest.json', 'server.ps1')) {
        Assert-TestCondition (Test-Path -LiteralPath (Join-Path $version $name) -PathType Leaf) "Installed file missing: $name"
    }
    $manifest = Get-Content -LiteralPath (Join-Path $repoRoot 'release-manifest.json') -Raw | ConvertFrom-Json
    $installedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $version 'server.ps1')).Hash
    Assert-TestCondition ($installedHash -ceq ([string]$manifest.server.sha256)) 'The installed server hash does not match the manifest.'
    Assert-TestCondition (@(Get-ChildItem -LiteralPath $root -Force -Filter '.staging-*').Count -eq 0) 'A staging directory was left behind after a successful install.'

    $rootAcl = Get-Acl -LiteralPath $root
    Assert-TestCondition ($rootAcl.AreAccessRulesProtected) 'The created root did not have inheritance disabled.'
    $null = $paths.Add($root)
}

Invoke-Case 'Re-running against an installer-owned root is idempotent' {
    param($paths)
    $holder = New-TestDirectory; $null = $paths.Add($holder)
    $root = Join-Path $holder 'dedicated'

    $first = Invoke-Installer -InstallRoot $root
    Assert-TestCondition ($first.ExitCode -eq 0) "First install failed. StdErr: $($first.StdErr)"
    $before = Get-TreeSnapshot -Path $root

    $second = Invoke-Installer -InstallRoot $root
    Assert-TestCondition ($second.ExitCode -eq 0) "Re-install against an installer-owned root failed. StdErr: $($second.StdErr)"
    Assert-TestCondition ($second.StdOut -match 'Already installed') "Re-install did not report an already-installed result. StdOut: $($second.StdOut)"
    Assert-SnapshotUnchanged -Before $before -After (Get-TreeSnapshot -Path $root) -Label 'idempotent re-install'
}

Invoke-Case 'An unexpected Allow identity on an otherwise-correct root is refused, not normalized' {
    param($paths)
    $holder = New-TestDirectory; $null = $paths.Add($holder)
    $root = Join-Path $holder 'dedicated'
    $first = Invoke-Installer -InstallRoot $root
    Assert-TestCondition ($first.ExitCode -eq 0) "Setup install failed. StdErr: $($first.StdErr)"

    # Add Authenticated Users. The installer must refuse this root rather than
    # silently repairing the ACL back to its expected shape.
    $rule = New-Object Security.AccessControl.FileSystemAccessRule(
        (New-Object Security.Principal.SecurityIdentifier('S-1-5-11')),
        [Security.AccessControl.FileSystemRights]::ReadAndExecute,
        ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit),
        [Security.AccessControl.PropagationFlags]::None,
        [Security.AccessControl.AccessControlType]::Allow)
    Add-RootAccessRule -Path $root -Rule $rule
    $before = Get-TreeSnapshot -Path $root

    # Remove the version directory so the installer takes the install path
    # rather than the already-installed early return.
    Remove-Item -LiteralPath (Join-Path $root '1.0.0') -Recurse -Force
    $beforeAfterRemoval = Get-TreeSnapshot -Path $root

    $result = Invoke-Installer -InstallRoot $root
    Assert-Refused -Result $result -Label 'root with an extra Allow identity'
    Assert-SnapshotUnchanged -Before $beforeAfterRemoval -After (Get-TreeSnapshot -Path $root) -Label 'root with an extra Allow identity'
}

Invoke-Case 'A Deny entry on an otherwise-correct root is refused' {
    param($paths)
    $holder = New-TestDirectory; $null = $paths.Add($holder)
    $root = Join-Path $holder 'dedicated'
    $first = Invoke-Installer -InstallRoot $root
    Assert-TestCondition ($first.ExitCode -eq 0) "Setup install failed. StdErr: $($first.StdErr)"
    Remove-Item -LiteralPath (Join-Path $root '1.0.0') -Recurse -Force

    $rule = New-Object Security.AccessControl.FileSystemAccessRule(
        (New-Object Security.Principal.SecurityIdentifier('S-1-5-11')),
        [Security.AccessControl.FileSystemRights]::Write,
        ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit),
        [Security.AccessControl.PropagationFlags]::None,
        [Security.AccessControl.AccessControlType]::Deny)
    Add-RootAccessRule -Path $root -Rule $rule
    $before = Get-TreeSnapshot -Path $root

    $result = Invoke-Installer -InstallRoot $root
    Assert-Refused -Result $result -Label 'root with a Deny entry'
    Assert-SnapshotUnchanged -Before $before -After (Get-TreeSnapshot -Path $root) -Label 'root with a Deny entry'
}

Invoke-Case 'An unexpected foreign file in an installer-owned root is refused' {
    param($paths)
    $holder = New-TestDirectory; $null = $paths.Add($holder)
    $root = Join-Path $holder 'dedicated'
    $first = Invoke-Installer -InstallRoot $root
    Assert-TestCondition ($first.ExitCode -eq 0) "Setup install failed. StdErr: $($first.StdErr)"
    Remove-Item -LiteralPath (Join-Path $root '1.0.0') -Recurse -Force
    Set-Content -LiteralPath (Join-Path $root 'unrelated.txt') -Value 'not ours' -Encoding ASCII
    $before = Get-TreeSnapshot -Path $root

    $result = Invoke-Installer -InstallRoot $root
    Assert-Refused -Result $result -Label 'installer root holding a foreign file'
    Assert-SnapshotUnchanged -Before $before -After (Get-TreeSnapshot -Path $root) -Label 'installer root holding a foreign file'
}

Invoke-Case 'A UNC InstallRoot is refused' {
    param($paths)
    $result = Invoke-Installer -InstallRoot '\\localhost\C$\swsmcp-should-not-be-used'
    Assert-Refused -Result $result -Label 'UNC InstallRoot'
}

# ---------------------------------------------------------------------------

Write-Output ''
Write-Output '================ SUMMARY ================'
Write-Output "Passed: $($script:Passes)"
Write-Output "Failed: $($script:Failures.Count)"
if ($script:Retained.Count -gt 0) {
    Write-Output ''
    Write-Output 'Retained test directories (not deleted, inspect these):'
    foreach ($p in $script:Retained) { Write-Output "  $p" }
}
if ($script:Failures.Count -gt 0) {
    Write-Output ''
    foreach ($f in $script:Failures) { Write-Output "FAILED: $f" }
    throw "$($script:Failures.Count) installer ACL safety test(s) failed."
}
Write-Output ''
Write-Output 'All installer ACL safety tests passed.'
