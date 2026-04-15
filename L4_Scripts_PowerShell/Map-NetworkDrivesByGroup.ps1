#requires -Version 5.1
<#
.SYNOPSIS
  Maps network drives dynamically according to AD group membership.

.DESCRIPTION
  Reads mappings from JSON file and applies idempotent mapping logic:
  - If user is authorized and mapping is missing or incorrect: map drive.
  - If user is not authorized and -Enforce is used: unmap drive.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath "DriveMappings.sample.json"),

    [switch]$Enforce,

    [switch]$Persistent,

    [string]$LogPath = (Join-Path -Path $PSScriptRoot -ChildPath ("logs\drive-map-{0}-{1}.log" -f $env:USERNAME, (Get-Date -Format "yyyyMMdd-HHmmss")))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-ParentDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    $dir = Split-Path -Path $Path -Parent
    if ($dir -and -not (Test-Path -Path $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Level = "INFO"
    )

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level.ToUpperInvariant(), $Message
    Add-Content -Path $LogPath -Value $line
}

function Get-TokenGroups {
    $set = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()

    foreach ($sid in $identity.Groups) {
        try {
            $name = $sid.Translate([System.Security.Principal.NTAccount]).Value
            [void]$set.Add($name)
            $short = ($name -split "\\")[-1]
            if ($short) { [void]$set.Add($short) }
        }
        catch { }
    }

    return $set
}

function Resolve-TemplatePath {
    param([Parameter(Mandatory = $true)][string]$Template)
    return $Template.Replace("%USERNAME%", $env:USERNAME).Replace("%USERDOMAIN%", $env:USERDOMAIN)
}

function Get-CurrentMappingPath {
    param([Parameter(Mandatory = $true)][string]$DriveLetter)
    $local = "$DriveLetter`:"

    if (Get-Command Get-SmbMapping -ErrorAction SilentlyContinue) {
        $smb = Get-SmbMapping -LocalPath $local -ErrorAction SilentlyContinue
        if ($smb) { return [string]$smb.RemotePath }
    }

    $drive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
    if ($drive) {
        if ($drive.DisplayRoot) { return [string]$drive.DisplayRoot }
        return [string]$drive.Root
    }

    return $null
}

function Remove-Mapping {
    param([Parameter(Mandatory = $true)][string]$DriveLetter)
    $local = "$DriveLetter`:"

    if (Get-Command Get-SmbMapping -ErrorAction SilentlyContinue) {
        $smb = Get-SmbMapping -LocalPath $local -ErrorAction SilentlyContinue
        if ($smb -and $PSCmdlet.ShouldProcess($local, "Remove SMB mapping")) {
            Remove-SmbMapping -LocalPath $local -Force -UpdateProfile -ErrorAction Stop
        }
    }

    $drive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
    if ($drive -and $PSCmdlet.ShouldProcess($local, "Remove PSDrive mapping")) {
        Remove-PSDrive -Name $DriveLetter -Force -ErrorAction Stop
    }
}

function Add-Mapping {
    param(
        [Parameter(Mandatory = $true)][string]$DriveLetter,
        [Parameter(Mandatory = $true)][string]$RemotePath,
        [Parameter(Mandatory = $true)][bool]$Persist
    )

    $local = "$DriveLetter`:"
    if ($Persist -and (Get-Command New-SmbMapping -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($local, "Create SMB mapping to $RemotePath")) {
            New-SmbMapping -LocalPath $local -RemotePath $RemotePath -Persistent $true -ErrorAction Stop | Out-Null
        }
        return
    }

    if ($PSCmdlet.ShouldProcess($local, "Create PSDrive mapping to $RemotePath")) {
        if ($Persist) {
            New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $RemotePath -Persist -Scope Global -ErrorAction Stop | Out-Null
        }
        else {
            New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $RemotePath -Scope Global -ErrorAction Stop | Out-Null
        }
    }
}

function Test-Authorized {
    param(
        [Parameter(Mandatory = $true)][string[]]$AuthorizedGroups,
        [Parameter(Mandatory = $true)][System.Collections.Generic.HashSet[string]]$TokenGroups
    )

    if ($AuthorizedGroups.Count -eq 0) { return $true }

    foreach ($group in $AuthorizedGroups) {
        $g = [string]$group
        if ([string]::IsNullOrWhiteSpace($g)) { continue }
        $g = $g.Trim()
        if ($g -eq "*") { return $true }
        if ($TokenGroups.Contains($g)) { return $true }
        $short = ($g -split "\\")[-1]
        if ($short -and $TokenGroups.Contains($short)) { return $true }
    }

    return $false
}

Ensure-ParentDirectory -Path $LogPath
Write-Log -Message "Starting drive mapping for user $env:USERDOMAIN\$env:USERNAME."

if (-not (Test-Path -Path $ConfigPath -PathType Leaf)) {
    throw "Config file '$ConfigPath' not found."
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
if (-not $config.Mappings) {
    throw "Config file '$ConfigPath' must contain a Mappings array."
}

$tokenGroups = Get-TokenGroups
$result = New-Object System.Collections.Generic.List[object]

foreach ($mapping in $config.Mappings) {
    try {
        $drive = ([string]$mapping.DriveLetter).Trim().TrimEnd(":").ToUpperInvariant()
        if ($drive -notmatch "^[A-Z]$") {
            throw "Invalid drive letter '$($mapping.DriveLetter)'."
        }

        $targetPath = Resolve-TemplatePath -Template ([string]$mapping.Path)
        if ([string]::IsNullOrWhiteSpace($targetPath)) {
            throw "Empty path for drive '$drive'."
        }

        $groups = @()
        if ($mapping.PSObject.Properties.Name -contains "Groups" -and $mapping.Groups) {
            $groups = @($mapping.Groups | ForEach-Object { [string]$_ })
        }

        $authorized = Test-Authorized -AuthorizedGroups $groups -TokenGroups $tokenGroups
        $currentPath = Get-CurrentMappingPath -DriveLetter $drive

        if ($authorized) {
            if ($currentPath -and ($currentPath.TrimEnd("\") -ieq $targetPath.TrimEnd("\"))) {
                Write-Log -Message "Drive $drive`: already mapped to $targetPath."
                $result.Add([PSCustomObject]@{ DriveLetter = $drive; Action = "Unchanged"; TargetPath = $targetPath; Success = $true; Error = "" })
                continue
            }

            if ($currentPath) {
                Remove-Mapping -DriveLetter $drive
                Write-Log -Message "Removed old mapping for $drive`: $currentPath."
            }

            Add-Mapping -DriveLetter $drive -RemotePath $targetPath -Persist $Persistent.IsPresent
            Write-Log -Message "Mapped $drive`: $targetPath."
            $result.Add([PSCustomObject]@{ DriveLetter = $drive; Action = "Mapped"; TargetPath = $targetPath; Success = $true; Error = "" })
        }
        else {
            if ($Enforce.IsPresent -and $currentPath) {
                Remove-Mapping -DriveLetter $drive
                Write-Log -Message "Unmapped $drive`: unauthorized user."
                $result.Add([PSCustomObject]@{ DriveLetter = $drive; Action = "Unmapped"; TargetPath = ""; Success = $true; Error = "" })
            }
            else {
                Write-Log -Message "Skipped $drive`: unauthorized user."
                $result.Add([PSCustomObject]@{ DriveLetter = $drive; Action = "Skipped"; TargetPath = ""; Success = $true; Error = "" })
            }
        }
    }
    catch {
        Write-Log -Level "ERROR" -Message "Drive '$($mapping.DriveLetter)' failed: $($_.Exception.Message)"
        $result.Add([PSCustomObject]@{
            DriveLetter = [string]$mapping.DriveLetter
            Action      = "Error"
            TargetPath  = [string]$mapping.Path
            Success     = $false
            Error       = $_.Exception.Message
        })
    }
}

[PSCustomObject]@{
    Total    = $result.Count
    Mapped   = @($result | Where-Object Action -eq 'Mapped').Count
    Unmapped = @($result | Where-Object Action -eq 'Unmapped').Count
    Failed   = @($result | Where-Object Success -eq $false).Count
    LogPath  = $LogPath
}
