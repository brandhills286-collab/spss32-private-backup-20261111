# Reassemble the downloaded ZIP parts. This script does not restore any system files.
# Place release-parts.json and all named parts in one directory, then run:
#   .\Join-Backup.ps1
#   .\Join-Backup.ps1 -Directory 'D:\Downloads\SPSS32'
[CmdletBinding()]
param(
    [string]$Directory = $PSScriptRoot,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ExpectedLength {
    param($Value, [string]$Label)
    if ($null -eq $Value) { throw "Missing byte count: $Label" }
    try {
        $number = [decimal]$Value
        if ($number -lt 0 -or $number -gt [long]::MaxValue -or [decimal]::Truncate($number) -ne $number) {
            throw 'Not a non-negative Int64.'
        }
        return [long]$number
    } catch { throw "Invalid byte count: $Label" }
}

function Get-ExpectedHash {
    param($Value, [string]$Label)
    if ($Value -isnot [string] -or $Value -notmatch '^[0-9a-fA-F]{64}$') {
        throw "Invalid SHA256: $Label"
    }
    return $Value.ToLowerInvariant()
}

function Get-StreamHash {
    param([System.IO.Stream]$Stream)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hasher.ComputeHash($Stream)).Replace('-', '').ToLowerInvariant() }
    finally { $hasher.Dispose() }
}

function Assert-LeafName {
    param($Name, [string]$Label)
    if ($Name -isnot [string] -or [string]::IsNullOrWhiteSpace($Name) -or
        [IO.Path]::IsPathRooted($Name) -or $Name -match '[\\/:]' -or
        $Name -in @('.', '..') -or [IO.Path]::GetFileName($Name) -ne $Name -or
        $Name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $Name.EndsWith('.') -or $Name.EndsWith(' ')) {
        throw "Expected a plain filename in manifest: $Label"
    }
}

if ([string]::IsNullOrWhiteSpace($Directory)) {
    $Directory = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $Directory = [IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
    }
}
$directoryPath = [IO.Path]::GetFullPath($Directory)
if (-not [IO.Directory]::Exists($directoryPath)) { throw "Input directory does not exist: $directoryPath" }
$manifestPath = [IO.Path]::Combine($directoryPath, 'release-parts.json')
if (-not [IO.File]::Exists($manifestPath)) { throw "Missing manifest: $manifestPath" }
$manifest = [IO.File]::ReadAllText($manifestPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
Assert-LeafName $manifest.archive.name 'archive.name'
$archiveBytes = Get-ExpectedLength $manifest.archive.bytes 'archive.bytes'
$archiveHash = Get-ExpectedHash $manifest.archive.sha256 'archive.sha256'
$manifestParts = @($manifest.parts)
if ($manifestParts.Count -eq 0) { throw 'Manifest contains no parts.' }

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = [IO.Path]::Combine($directoryPath, 'SPSS32_Backup_20261111.zip')
} elseif (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = [IO.Path]::Combine($directoryPath, $OutputPath)
}
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$partialPath = $outputFullPath + '.partial'
if (-not [IO.Directory]::Exists([IO.Path]::GetDirectoryName($outputFullPath))) {
    throw "Output parent directory does not exist: $outputFullPath"
}
$protectedPaths = @($manifestPath)
$partRows = @()
$seenNames = @{}
[decimal]$totalBytes = 0
foreach ($part in $manifestParts) {
    Assert-LeafName $part.name 'parts[].name'
    if ($seenNames.ContainsKey($part.name)) { throw "Duplicate part name: $($part.name)" }
    $seenNames[$part.name] = $true
    $partPath = [IO.Path]::GetFullPath([IO.Path]::Combine($directoryPath, $part.name))
    $partBytes = Get-ExpectedLength $part.bytes $part.name
    $partHash = Get-ExpectedHash $part.sha256 $part.name
    $protectedPaths += $partPath
    if (-not [IO.File]::Exists($partPath)) { throw "Missing part: $partPath" }
    if ((Get-Item -LiteralPath $partPath).Length -ne $partBytes) { throw "Part size mismatch: $partPath" }
    $partRows += [pscustomobject]@{ Name = $part.name; Path = $partPath; Bytes = $partBytes; SHA256 = $partHash }
    $totalBytes += $partBytes
}
if ($totalBytes -ne $archiveBytes) { throw 'Sum of part sizes does not match archive.bytes.' }
foreach ($protectedPath in $protectedPaths) {
    if ([string]::Equals($protectedPath, $outputFullPath, [StringComparison]::OrdinalIgnoreCase) -or
        [string]::Equals($protectedPath, $partialPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Output or partial file overlaps an input: $protectedPath"
    }
}
foreach ($candidatePath in @($outputFullPath, $partialPath)) {
    if ([IO.File]::Exists($candidatePath) -or [IO.Directory]::Exists($candidatePath)) {
        throw "Refusing to overwrite existing path: $candidatePath"
    }
}

$outputStream = $null
$createdPartial = $false
try {
    # CreateNew and File.Move both reject an existing destination, including races.
    $outputStream = [IO.FileStream]::new($partialPath, [IO.FileMode]::CreateNew,
        [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4194304, [IO.FileOptions]::SequentialScan)
    $createdPartial = $true
    foreach ($partRow in $partRows) {
        # Keep the same input handle open for hash verification and copying.
        # FileShare.Read prevents another writer changing this part during the copy.
        $inputStream = [IO.FileStream]::new($partRow.Path, [IO.FileMode]::Open,
            [IO.FileAccess]::Read, [IO.FileShare]::Read, 4194304, [IO.FileOptions]::SequentialScan)
        try {
            if ($inputStream.Length -ne $partRow.Bytes) { throw "Part size changed: $($partRow.Name)" }
            if ((Get-StreamHash $inputStream) -ne $partRow.SHA256) { throw "Part SHA256 mismatch: $($partRow.Name)" }
            $inputStream.Position = 0
            $inputStream.CopyTo($outputStream, 4194304)
            Write-Host "Verified and joined: $($partRow.Name)"
        } finally { $inputStream.Dispose() }
    }
    $outputStream.Flush($true)
    if ($outputStream.Length -ne $archiveBytes) { throw 'Merged archive size mismatch.' }
    $outputStream.Position = 0
    $actualHash = Get-StreamHash $outputStream
    if ($actualHash -ne $archiveHash) { throw 'Merged archive SHA256 mismatch.' }
    $outputStream.Dispose()
    $outputStream = $null
    [IO.File]::Move($partialPath, $outputFullPath)
    Write-Host "Verified ZIP ready: $outputFullPath"
    [pscustomobject]@{ OutputPath = $outputFullPath; Bytes = $archiveBytes; SHA256 = $actualHash; Status = 'PASS' }
} catch {
    if ($null -ne $outputStream) { $outputStream.Dispose(); $outputStream = $null }
    if ($createdPartial -and [IO.File]::Exists($partialPath)) {
        throw "$($_.Exception.Message) Incomplete file retained at: $partialPath"
    }
    throw
} finally {
    if ($null -ne $outputStream) { $outputStream.Dispose() }
}
