#requires -Version 5.1
#requires -Modules ActiveDirectory
<#
.SYNOPSIS
  Imports AD users from CSV in an idempotent way.

.DESCRIPTION
  Expected business columns from RP-02:
    - NOM
    - Prenom
    - OU cible
    - Groupe de securite
    - Adresse e-mail

  Extra accepted columns:
    - SamAccountName (optional, generated if missing)
    - Password (optional, falls back to -DefaultPassword)

  The script creates missing users, updates key attributes when needed,
  adds missing group memberships, and writes an execution report.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [string]$DefaultDomainSuffix,

    [Parameter(Mandatory = $true)]
    [string]$DefaultOU,

    [Parameter(Mandatory = $true)]
    [string]$DefaultGroup,

    [Parameter(Mandatory = $true)]
    [string]$DefaultPassword,

    [char]$Delimiter = ';',

    [string]$ReportPath = (Join-Path -Path $PSScriptRoot -ChildPath ("reports\import-users-{0}.csv" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
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

function ConvertTo-AsciiSlug {
    param([Parameter(Mandatory = $true)][string]$Value)

    $normalized = $Value.Normalize([Text.NormalizationForm]::FormD)
    $chars = New-Object System.Collections.Generic.List[char]
    foreach ($char in $normalized.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$chars.Add($char)
        }
    }

    $plain = (-join $chars).Normalize([Text.NormalizationForm]::FormC).ToLowerInvariant()
    $plain = [regex]::Replace($plain, '[^a-z0-9\.-]', '')
    return $plain
}

function Build-SamAccountName {
    param(
        [Parameter(Mandatory = $true)][string]$Prenom,
        [Parameter(Mandatory = $true)][string]$Nom
    )

    $base = "{0}.{1}" -f (ConvertTo-AsciiSlug -Value $Prenom), (ConvertTo-AsciiSlug -Value $Nom)
    $base = $base.Trim('.')
    if ($base.Length -eq 0) {
        throw "Unable to build SamAccountName from Prenom/NOM values."
    }

    if ($base.Length -gt 20) {
        $base = $base.Substring(0, 20)
    }

    return $base
}

Import-Module ActiveDirectory -ErrorAction Stop

$rows = @(Import-Csv -Path $CsvPath -Delimiter $Delimiter)
if ($rows.Count -eq 0) {
    throw "CSV '$CsvPath' is empty."
}

$report = New-Object System.Collections.Generic.List[object]
$seenSam = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)

for ($i = 0; $i -lt $rows.Count; $i++) {
    $line = $i + 2
    $row = $rows[$i]
    $sam = $null

    try {
        $details = New-Object System.Collections.Generic.List[string]

        $nom = Get-ColumnValue -Row $row -Candidates @('NOM', 'Nom', 'Surname', 'LastName')
        $prenom = Get-ColumnValue -Row $row -Candidates @('Prenom', 'Prenom', 'GivenName', 'FirstName')
        $ou = Get-ColumnValue -Row $row -Candidates @('OU cible', 'OUCible', 'OU', 'TargetOU')
        $groupName = Get-ColumnValue -Row $row -Candidates @('Groupe de securite', 'GroupeSecurite', 'Groupe', 'Group')
        $email = Get-ColumnValue -Row $row -Candidates @('Adresse e-mail', 'AdresseEmail', 'Email', 'Mail')
        $samFromCsv = Get-ColumnValue -Row $row -Candidates @('SamAccountName', 'Login', 'Identifiant')
        $password = Get-ColumnValue -Row $row -Candidates @('Password', 'MotDePasse')

        if (-not $nom -or -not $prenom) {
            throw "Line ${line}: NOM and Prenom are required."
        }

        $sam = if ($samFromCsv) { $samFromCsv } else { Build-SamAccountName -Prenom $prenom -Nom $nom }
        if (-not $seenSam.Add($sam)) {
            throw "Line ${line}: duplicate SamAccountName '$sam' in CSV."
        }

        $targetOu = if ($ou) { $ou } else { $DefaultOU }
        $targetGroup = if ($groupName) { $groupName } else { $DefaultGroup }
        $targetPassword = if ($password) { $password } else { $DefaultPassword }
        $upn = if ($email -and $email.Contains('@')) { $email } else { "$sam@$DefaultDomainSuffix" }
        $displayName = "$prenom $nom"

        $user = Get-ADUser -Identity $sam -Properties GivenName, Surname, DisplayName, EmailAddress, DistinguishedName -ErrorAction SilentlyContinue

        if ($null -eq $user) {
            if ($PSCmdlet.ShouldProcess($sam, "Create user")) {
                New-ADUser `
                    -SamAccountName $sam `
                    -Name $displayName `
                    -GivenName $prenom `
                    -Surname $nom `
                    -DisplayName $displayName `
                    -UserPrincipalName $upn `
                    -Path $targetOu `
                    -Enabled $true `
                    -AccountPassword (ConvertTo-SecureString -AsPlainText $targetPassword -Force) `
                    -ChangePasswordAtLogon $true `
                    -EmailAddress $email `
                    -ErrorAction Stop
            }
            $details.Add("CreatedUser")
        }
        else {
            $setParams = @{ Identity = $user.DistinguishedName }

            if ($user.GivenName -ne $prenom) { $setParams['GivenName'] = $prenom; $details.Add("UpdatedGivenName") }
            if ($user.Surname -ne $nom) { $setParams['Surname'] = $nom; $details.Add("UpdatedSurname") }
            if ($user.DisplayName -ne $displayName) { $setParams['DisplayName'] = $displayName; $details.Add("UpdatedDisplayName") }
            if ($email -and $user.EmailAddress -ne $email) { $setParams['EmailAddress'] = $email; $details.Add("UpdatedEmail") }
            if ($setParams.Keys.Count -gt 1) {
                if ($PSCmdlet.ShouldProcess($sam, "Update user attributes")) {
                    Set-ADUser @setParams -ErrorAction Stop
                }
            }

            if ($targetOu -and ($user.DistinguishedName -notlike "*,$targetOu")) {
                if ($PSCmdlet.ShouldProcess($sam, "Move to OU '$targetOu'")) {
                    Move-ADObject -Identity $user.DistinguishedName -TargetPath $targetOu -ErrorAction Stop
                }
                $details.Add("MovedOU")
            }
        }

        if ($targetGroup) {
            $groupMembers = @(Get-ADGroupMember -Identity $targetGroup -Recursive -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName)
            if ($groupMembers -notcontains $sam) {
                if ($PSCmdlet.ShouldProcess($sam, "Add to group '$targetGroup'")) {
                    Add-ADGroupMember -Identity $targetGroup -Members $sam -ErrorAction Stop
                }
                $details.Add("AddedToGroup:$targetGroup")
            }
        }

        $action = if ($details.Count -gt 0) { "Updated" } else { "Unchanged" }
        if ($details -contains "CreatedUser") { $action = "Created" }

        $report.Add([PSCustomObject]@{
            Timestamp      = (Get-Date).ToString("s")
            SamAccountName = $sam
            Action         = $action
            Details        = ($details -join ", ")
            Success        = $true
            Error          = ""
        })
    }
    catch {
        $report.Add([PSCustomObject]@{
            Timestamp      = (Get-Date).ToString("s")
            SamAccountName = if ($sam) { $sam } else { "<unknown>" }
            Action         = "Error"
            Details        = ""
            Success        = $false
            Error          = $_.Exception.Message
        })
    }
}

$reportDir = Split-Path -Path $ReportPath -Parent
if ($reportDir -and -not (Test-Path -Path $reportDir -PathType Container)) {
    New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
}

$report | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8

[PSCustomObject]@{
    Total      = $report.Count
    Created    = @($report | Where-Object Action -eq 'Created').Count
    Updated    = @($report | Where-Object Action -eq 'Updated').Count
    Unchanged  = @($report | Where-Object Action -eq 'Unchanged').Count
    Failed     = @($report | Where-Object Success -eq $false).Count
    ReportPath = $ReportPath
}
