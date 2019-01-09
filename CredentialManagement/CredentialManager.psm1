<#
.SYNOPSIS
Creates a new credential in Windows' PasswordVault.

.DESCRIPTION
Creates a new credential in Windows' PasswordVault for secure storage.

.PARAMETER Resource
The name of the resource you want to save the credential under.

.PARAMETER Credential
Pass a PSCredential object.

.EXAMPLE
New-VaultCredential -Resource "Service Account" -Credential (Get-Credential)

.NOTES
The purpose of saving your credentials to the PasswordVault is that it's a more secure storage system compared to saving credentials to the local disk. Certificate-based authentication is still a more preferred method, but this is a secondary alternative.
#>

function New-VaultCredential {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)][String]$Resource,
        [PSCredential]$Credential
    )

    if (!(Get-Credential)) { #If no credential is provided, prompt.
        $Credential = (Get-Credential)
    }

    $ScriptBlock = {
        [cmdletbinding()]
        param(
            [String]$Resource,
            [PSCredential]$Credential
        )
        $ErrorActionPreference = "SilentlyContinue"
        [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType = WindowsRuntime] | Out-Null #Load in PasswordVault assemblies.

        $PasswordVault = New-Object Windows.Security.Credentials.PasswordVault #Create a PasswordVault object.

        try {
            $VaultEntry = New-Object Windows.Security.Credentials.PasswordCredential($Resource, $Credential.UserName, $Credential.GetNetworkCredential().Password)

            $PasswordVault.Add($VaultEntry) | Out-Null

            return (New-Object -TypeName psobject -Property @{
                    "UserName" = $Credential.UserName;
                    "Success"  = $true

                })
        }
        catch {
            return (New-Object -TypeName psobject -Property @{
                    "UserName" = $Credential.UserName;
                    "Success"  = $false

                })
        }

    }

    $AddCredJob = Start-Job -Name "PV-AddCred" -ArgumentList @($Resource, $Credential) -ScriptBlock $ScriptBlock

    Wait-Job -Job $AddCredJob | Out-Null

    $return = Receive-Job -Job $AddCredJob

    Remove-Job $AddCredJob

    return $return | Select-Object -Property "UserName", "Success"
}

<#
.SYNOPSIS
Remove items from Windows' PasswordVault.

.DESCRIPTION
Remove items from Windows' PasswordVault. Asks to remove the item before removal.

.PARAMETER Resource
The resource that you want to delete items from.

.EXAMPLE
Remove-VaultCredential -Resource "Service Accounts"

.NOTES
The purpose of saving your credentials to the PasswordVault is that it's a more secure storage system compared to saving credentials to the local disk. Certificate-based authentication is still a more preferred method, but this is a secondary alternative.
#>

function Remove-VaultCredential {
    [cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory = $true)][String]$Resource
    )

    $GetItemsScript = {
        [cmdletbinding()]
        param(
            [String]$Resource
        )
        $ErrorActionPreference = "SilentlyContinue"
        [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType = WindowsRuntime] | Out-Null

        $PasswordVault = New-Object Windows.Security.Credentials.PasswordVault

        try {
            $ResourcesByItemName = $PasswordVault.FindAllByResource($Resource)
            return $ResourcesByItemName
        }
        catch {
            Write-Output "No entries found for $($ItemName)."
        }

    }

    $RemoveItemScript = {
        [cmdletbinding()]
        param(
            $Item
        )
        $ErrorActionPreference = "SilentlyContinue"
        [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType = WindowsRuntime] | Out-Null

        $PasswordVault = New-Object Windows.Security.Credentials.PasswordVault

        $PasswordCredential = $PasswordVault.FindAllByResource($Item.Resource) | Where-Object -Property "UserName" -eq $Item.UserName
        $PasswordCredential.RetrievePassword()

        try {
            $PasswordVault.Remove($PasswordCredential)
            return (New-Object -TypeName psobject -Property @{
                    "UserName" = $Item.UserName;
                    "Success"  = $true
                })
        }
        catch {
            return (New-Object -TypeName psobject -Property @{
                    "UserName" = $Item.UserName;
                    "Success"  = $false
                })
        }

    }

    $GetItems = Start-Job -Name "PV-GetItems" -ArgumentList $Resource -ScriptBlock $GetItemsScript

    Wait-Job -Job $GetItems | Out-Null

    $AllItems = Receive-Job -Job $GetItems

    Remove-Job -Job $GetItems -Force

    $removeJobs = @()
    foreach ($item in $AllItems) {
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Are you sure you want to delete the credential '$($item.UserName)' from '$($item.Resource)?")) {
            $removeJobs += Start-Job -Name "PV-RemoveItem" -ArgumentList $item -ScriptBlock $RemoveItemScript
        }
    }

    Wait-Job -Job $removeJobs | Out-Null

    $return = Receive-Job -Job $removeJobs

    Remove-Job -Job $removeJobs -Force

    return $return | Select-Object -Property "UserName", "Success"
}

<#
.SYNOPSIS
Get an item from Windows' PasswordVault.

.DESCRIPTION
Get an item from Windows' PasswordVault.

.PARAMETER Resource
The resource that you want to get an item from.

.PARAMETER UserName
If more than one UserName is stored under a resource, use this to specify a UserName.

.EXAMPLE
Get-VaultCredential -Resource "Service Accounts" -UserName "example\jldoe123"

.NOTES
The purpose of saving your credentials to the PasswordVault is that it's a more secure storage system compared to saving credentials to the local disk. Certificate-based authentication is still a more preferred method, but this is a secondary alternative.
#>

function Get-VaultCredential {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)][String]$Resource,
        [String]$UserName
    )
    $ScriptBlock = {
        [cmdletbinding()]
        param(
            [String]$Resource
        )
        $ErrorActionPreference = "SilentlyContinue"
        [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType = WindowsRuntime] | Out-Null

        $PasswordVault = New-Object Windows.Security.Credentials.PasswordVault

        try {
            $ResourcesByItemName = $PasswordVault.FindAllByResource($Resource)

            $returnData = @()
            foreach ($r in $ResourcesByItemName) {
                $r.RetrievePassword()
                $UserName = $r.UserName
                $returnData += [System.Management.Automation.PSCredential]::new($UserName, (ConvertTo-SecureString $r.Password -AsPlainText -Force))
            }

            return $returnData
        }
        catch {
            return (New-Object -TypeName psobject -Property @{
                    "UserName" = "N/A";
                    "Data"     = $false
                })
        }

    }

    Write-Verbose "Starting job..."

    #Had to utilize Invoke-Command as a job over Start-Job in order for the result to return.
    $GetCredJob = Invoke-Command -ArgumentList $Resource -ScriptBlock $ScriptBlock -AsJob -ComputerName $env:COMPUTERNAME

    Write-Verbose "Waiting for job to complete..."

    Wait-Job -Job $GetCredJob | Out-Null

    $return = Receive-Job -Job $GetCredJob

    Remove-Job -Job $GetCredJob -Force

    Write-Verbose "Job complete and removed."

    $NoReturn = $false

    if ($return | Select-Object -ExpandProperty "Data" -ErrorAction SilentlyContinue) {
        Write-Verbose "Job returned a $false data. Setting `$noReturn to $false"
        $NoReturn = $true
    }

    if ($UserName) {
        $return = $return | Where-Object -Property "UserName" -eq $UserName
    }

    $returnCount = ($return | Measure-Object).Count
    Write-Verbose "`$returnCount returned $($returnCount)."

    if ($UserName -and ($returnCount -eq 0)) {
        $return = $null
        Write-Verbose "A username was provided, but nothing returned back."
    }

    if ($return -and $NoReturn) {
        Write-Error "Nothing was found for the item."
    }
    elseif ($return -and $UserName -and ($returnCount -ne 0)) {
        return [System.Management.Automation.PSCredential]::new($return.UserName, $return.Password)
    }
    elseif ($return -and $returnCount -eq 1) {
        return [System.Management.Automation.PSCredential]::new($return.UserName, $return.Password)
    }
    else {
        Write-Error "A username was provided, but nothing returned back."
    }
}