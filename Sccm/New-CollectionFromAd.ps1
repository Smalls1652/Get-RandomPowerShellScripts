
<#PSScriptInfo

.VERSION 0.1

.GUID d6ca5076-f3c4-4c11-b674-4a3e5a8f352c

.AUTHOR Tim Small

.COMPANYNAME Smalls.Online

.COPYRIGHT 2019

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES ActiveDirectory

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<#
.SYNOPSIS
    Create collection from AD Organizational Unit.
.DESCRIPTION
    Create a device collection from an AD Organizational Unit with a membership query rule pointing to the OU path.
.EXAMPLE
    PS C:\> New-CollectionFromAd.ps1 -InputObject (Get-ADOrganizationalUnit -Filter "name -eq 'Staff Computers'") -SiteCode "ABC"
    Creates a device collection for OU Staff Computers on site ABC.
.PARAMETER InputObject
    Data returned from cmdlet 'Get-ADOrganizationalUnit'. Must be one object in the input.
.PARAMETER SiteCode
    The site code to apply the collection to.
.PARAMETER CollectionName
    Sets the collection to another name other than the OU name.
.NOTES
    Requires ActiveDirectory (RSAT) and ConfigurationManager (From the AdminConsole install) modules.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)][Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]$InputObject,
    [Parameter(Mandatory = $true)][string]$SiteCode,
    [string]$CollectionName
)

begin {
    function GenerateQueryName {
        param(
            $SplitDn
        )
    
        $DcObjs = $SplitDn | Where-Object { $_ -like "DC*" }
    
        $Dc = $DcObjs -replace "DC=" -join "."
    
        $OuObjs = $SplitDn | Where-Object { $_ -like "OU*" }
    
        [array]::Reverse($OuObjs)
    
        $FullDnQuery = "$($Dc)"
        foreach ($Obj in $OuObjs) {
            $FullDnQuery += "/$($Obj -replace 'OU=')"
        }
    
        return $FullDnQuery
    }
    
    if (!(Get-Module -Name "ConfigurationManager")) {
        Write-Verbose "Loading Sccm Module..."
        $null = Import-Module "$(${env:ProgramFiles(x86)})\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1" -Verbose:$false
    }
    
    Write-Verbose "Setting location to specified Sccm site drive, '$($SiteCode):\'."
    try {
        Set-Location -Path "$($SiteCode):\" -ErrorAction Stop -Verbose:$false
    }
    catch {

        $FoundSiteCodes = Get-PSDrive -PSProvider "CMSite" | Select-Object -ExpandProperty "SiteCode"

        if ($FoundSiteCodes) {
            $ExceptionMessage = [Exception]::new("Failed to set location to $($SiteCode). Possible site codes: $($FoundSiteCodes -join ', ')")
        }
        else {
            $ExceptionMessage = [Exception]::new("Failed to set location to $($SiteCode). No site codes were found.")
        }

        $LocationSetError = [System.Management.Automation.ErrorRecord]::new(
            $ExceptionMessage,
            "Site.SetDriveError",
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $SiteCode
        )

        $PSCmdlet.ThrowTerminatingError($LocationSetError)
    }

    if (!($CollectionName)) {
        $CollectionName = $InputObject.Name
    }
    Write-Verbose "Collection Name set to: $($CollectionName)."

    if (Get-CMCollection -Name $CollectionName -Verbose:$false) {

        $CollectionNameExistsError = [System.Management.Automation.ErrorRecord]::new(
            [Exception]::new("A collection with the name '$($CollectionName)' already exists."),
            "Site.CollectionAlreadyExists",
            [System.Management.Automation.ErrorCategory]::InvalidData,
            $CollectionName
        )

        Set-Location -Path "C:"

        $PSCmdlet.ThrowTerminatingError($CollectionNameExistsError)
    }
}

process {

    if ($PSCmdlet.ShouldProcess($CollectionName, "Create Collection")) {

        $CollectionArgs = @{
            "Name"                   = $CollectionName;
            "CollectionType"         = "Device";
            "LimitingCollectionName" = "All Systems"
        }

        Write-Verbose "Creating collection..."
        $CreatedCollection = New-CMCollection @CollectionArgs -Verbose:$false

        Write-Verbose "Generating query rule for dynamic memebership..."
        $InputDn = $InputObject.DistinguishedName.Split(",")
        $QueryRule = GenerateQueryName -SplitDn $InputDn

        $MembershipRules = @{
            "Collection"      = $CreatedCollection;
            "RuleName"        = "$($InputObject.Name) OU";
            "QueryExpression" = "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.SystemOUName = ""$($QueryRule.ToUpper())"""
        }

        Write-Verbose "Adding membership query rules to collection..."
        Add-CMDeviceCollectionQueryMembershipRule @MembershipRules -Verbose:$false

        Write-Verbose "Forcing collection to update..."
        Invoke-CMCollectionUpdate -InputObject $CreatedCollection -Verbose:$false
    }
}

end {
    Write-Verbose "Setting location back to original directory..."
    Set-Location -Path "C:"
    Write-Verbose "Collection for OU, $($InputObject.Name), created as collection name '$($CollectionName)'."

    return New-Object -TypeName psobject -Property @{
        "OuName"         = $InputObject.Name;
        "OuPath"         = $InputObject.DistinguishedName;
        "CollectionName" = $CollectionName;
        "OnSite"         = $SiteCode;
        "IsCreated"      = $true
    }
}