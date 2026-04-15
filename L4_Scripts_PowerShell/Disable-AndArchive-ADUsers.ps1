#requires -Version 5.1
#requires -Modules ActiveDirectory
<#
.SYNOPSIS
  Disables and archives AD users, with RGPD retention purge support.

.DESCRIPTION
  Mode A (default): archive users from CSV identities or SearchBase OU list.
    - Disable account
    - Move account to Archive OU
    - Set account expiration at (today + RetentionDays)
    - Tag description with PurgeAfter=yyyy-MM-dd

  Mode B (-PurgeExpired): delete archived users whose retention date is reached.

  Idempotent behavior:
    - already disabled users are not changed again
    - users already in archive OU are not moved again
    - already tagged users are not re-tagged unless date changed
#>
[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = "Archive")]
param(
    [Parameter(ParameterSetName = "Archive")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter(ParameterSetName = "Archive")]
    [string[]]$SearchBase,

    [Parameter(ParameterSetName = "Archive")]
    [string]$SearchFilter = "*",

    [Parameter(Mandatory = $true)]
    [string]$ArchiveOU,

    [int]$RetentionDays = 365,

    [char]$Delimiter = ';',

    [Parameter(ParameterSetName = "Purge", Mandatory = $true)]
    [switch]$PurgeExpired,

    [string]$ReportPath = (Join-Path -Path $PSScriptRoot -ChildPath ("reports\archive-users-{0}.csv" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ColumnValue {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Row,
        [Parameter(Mandatory = $true)][string[]]$Candidates
    )

    foreach ($name in $Candidates) {
        if ($Row.PSObject.Properties.Name -contains $name) {
            $raw = [string]$Row.$name
            if ($null -eq $raw) { continue }
            $trimmed = $raw.Trim()
            if ($trimmed.Length -eq 0) { continue }
            return $trimmed
        }
    }

    return $null
}

function Get-TargetsFromCsv {
    param([Parameter(Mandatory = $true)][string]$Path)

    $rows = @(Import-Csv -Path $Path -Delimiter $Delimiter)
    $targets = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $rows.Count; $i++) {
        $line = $i + 2
        $row = $rows[$i]
        $id = Get-ColumnValue -Row $row -Candidates @('SamAccountName', 'Identifiant', 'Login', 'UserPrincipalName', 'DistinguishedName')
        if (-not $id) {
            throw "Line ${line}: missing identity column."
        }
        $targets.Add($id)
    }

    return @($targets | Select-Object -Unique)
}

function Resolve-PurgeDate {
    param(
        [datetime]$AccountExpirationDate,
        [string]$Description
    )

    if ($AccountExpirationDate) {
        return $AccountExpirationDate.Date
    }

    if ($Description -match 'PurgeAfter=(\d{4}-\d{2}-\d{2})') {
        return [datetime]::ParseExact($Matches[1], "yyyy-MM-dd", [cultureinfo]::InvariantCulture)
    }

    return $null
}

Import-Module ActiveDirectory -ErrorAction Stop

$report = New-Object System.Collections.Generic.List[object]
$today = (Get-Date).Date

if ($PurgeExpired.IsPresent) {
    $archivedUsers = @(Get-ADUser -Filter * -SearchBase $ArchiveOU -Properties AccountExpirationDate, Description, Enabled -ErrorAction Stop)

    foreach ($user in $archivedUsers) {
        try {
            $purgeDate = Resolve-PurgeDate -AccountExpirationDate $user.AccountExpirationDate -Description $user.Description
            if (-not $purgeDate) {
                $report.Add([PSCustomObject]@{
                    Timestamp      = (Get-Date).ToString("s")
                    SamAccountName = $user.SamAccountName
                    Action         = "SkippedNoPurgeDate"
                    Details        = ""
                    Success        = $true
                    Error          = ""
                })
                continue
            }

            if ($purgeDate -le $today) {
                if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Delete archived account")) {
                    Remove-ADUser -Identity $user.DistinguishedName -Confirm:$false -ErrorAction Stop
                }
                $report.Add([PSCustomObject]@{
                    Timestamp      = (Get-Date).ToString("s")
                    SamAccountName = $user.SamAccountName
                    Action         = "Deleted"
                    Details        = "PurgeDate=$($purgeDate.ToString('yyyy-MM-dd'))"
                    Success        = $true
                    Error          = ""
                })
            }
            else {
                $report.Add([PSCustomObject]@{
                    Timestamp      = (Get-Date).ToString("s")
                    SamAccountName = $user.SamAccountName
                    Action         = "PendingRetention"
                    Details        = "PurgeDate=$($purgeDate.ToString('yyyy-MM-dd'))"
                    Success        = $true
                    Error          = ""
                })
            }
        }
        catch {
            $report.Add([PSCustomObject]@{
                Timestamp      = (Get-Date).ToString("s")
                SamAccountName = $user.SamAccountName
                Action         = "Error"
                Details        = ""
                Success        = $false
                Error          = $_.Exception.Message
            })
        }
    }
}
else {
    $targets = @()
    if ($CsvPath) {
        $targets = Get-TargetsFromCsv -Path $CsvPath
    }
    elseif ($SearchBase -and $SearchBase.Count -gt 0) {
        $list = New-Object System.Collections.Generic.List[string]
        foreach ($base in $SearchBase) {
            $users = @(Get-ADUser -Filter $SearchFilter -SearchBase $base -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName)
            foreach ($sam in $users) { [void]$list.Add($sam) }
        }
        $targets = @($list | Select-Object -Unique)
    }
    else {
        throw "Archive mode requires -CsvPath or -SearchBase."
    }

    $purgeDate = $today.AddDays($RetentionDays)
    $purgeTag = "PurgeAfter={0}" -f $purgeDate.ToString("yyyy-MM-dd")

    foreach ($id in $targets) {
        try {
            $details = New-Object System.Collections.Generic.List[string]
            $user = Get-ADUser -Identity $id -Properties Enabled, DistinguishedName, Description, AccountExpirationDate -ErrorAction Stop

            if ($user.Enabled) {
                if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Disable account")) {
                    Disable-ADAccount -Identity $user.DistinguishedName -ErrorAction Stop
                }
                $details.Add("Disabled")
            }

            if ($user.DistinguishedName -notlike "*,$ArchiveOU") {
                if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Move to archive OU")) {
                    Move-ADObject -Identity $user.DistinguishedName -TargetPath $ArchiveOU -ErrorAction Stop
                }
                $details.Add("MovedToArchiveOU")
                $user = Get-ADUser -Identity $id -Properties Description, AccountExpirationDate -ErrorAction Stop
            }

            $currentDescription = [string]$user.Description
            if ($currentDescription -notmatch 'PurgeAfter=\d{4}-\d{2}-\d{2}' -or $currentDescription -notmatch [regex]::Escape($purgeTag)) {
                $newDescription = if ([string]::IsNullOrWhiteSpace($currentDescription)) { $purgeTag } else { "$currentDescription | $purgeTag" }
                if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Set purge tag")) {
                    Set-ADUser -Identity $user.DistinguishedName -Description $newDescription -ErrorAction Stop
                }
                $details.Add("TaggedPurgeDate")
            }

            $currentExp = $user.AccountExpirationDate
            $needsExpUpdate = $true
            if ($currentExp) {
                $needsExpUpdate = ($currentExp.Date -ne $purgeDate.Date)
            }
            if ($needsExpUpdate) {
                if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Set account expiration")) {
                    Set-ADAccountExpiration -Identity $user.DistinguishedName -DateTime $purgeDate -ErrorAction Stop
                }
                $details.Add("SetExpiration:$($purgeDate.ToString('yyyy-MM-dd'))")
            }

            $action = if ($details.Count -gt 0) { "Updated" } else { "Unchanged" }
            $report.Add([PSCustomObject]@{
                Timestamp      = (Get-Date).ToString("s")
                SamAccountName = $user.SamAccountName
                Action         = $action
                Details        = ($details -join ", ")
                Success        = $true
                Error          = ""
            })
        }
        catch {
            $report.Add([PSCustomObject]@{
                Timestamp      = (Get-Date).ToString("s")
                SamAccountName = $id
                Action         = "Error"
                Details        = ""
                Success        = $false
                Error          = $_.Exception.Message
            })
        }
    }
}

$reportDir = Split-Path -Path $ReportPath -Parent
if ($reportDir -and -not (Test-Path -Path $reportDir -PathType Container)) {
    New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
}

$report | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8

[PSCustomObject]@{
    Total      = $report.Count
    Updated    = @($report | Where-Object Action -eq 'Updated').Count
    Deleted    = @($report | Where-Object Action -eq 'Deleted').Count
    Unchanged  = @($report | Where-Object Action -eq 'Unchanged').Count
    Failed     = @($report | Where-Object Success -eq $false).Count
    ReportPath = $ReportPath
}
