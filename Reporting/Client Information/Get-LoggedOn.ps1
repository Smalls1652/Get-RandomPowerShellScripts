<#PSScriptInfo

.VERSION 19.5.7

.GUID e71290ae-d605-4ee6-88f4-c70f86ca9385

.AUTHOR Tim Small

.COMPANYNAME Smalls.Online

.COPYRIGHT 2019

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<#
.SYNOPSIS
    Get the current logged on user for a machine.
    
.DESCRIPTION
    This function allows you to get the current logged on user for a machine remotely.

.EXAMPLE
    Get-LoggedOn

    To return the logged on username of the local machine.
		
.EXAMPLE
    Get-LoggedOn -ComputerName Example1

    To return the logged on username of a remote machine.

.EXAMPLE
    Get-LoggedOn -ComputerName Example1,Example2,Example3

    To return the logged on username of multiple remote machines.

.PARAMETER ComputerName
    The computer name that you would like to retieve information from.
        
.PARAMETER Credential
    Credentials to access WMI on the remote computer.	
#>
[cmdletbinding()]

param(
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)][string[]]$ComputerName = $env:COMPUTERNAME,
    [pscredential]$Credential
)

begin {

    $GetLoggedOnScriptBlock = {
        param(
            [string]$Computer,
            [pscredential]$Credential
        )
        $WmiSplat = @{
            "Class"        = "win32_computersystem";
            "ComputerName" = $Computer
        }

        if ($Credential) {
            $WmiSplat.Add("Credential", $Credential)
        }

        try {
            $WmiQuery = Get-WmiObject @WmiSplat -ErrorAction Stop
            New-Object -TypeName "pscustomobject" -Property @{
                "ComputerName" = $Computer;
                "UserName"     = $WmiQuery.UserName
            }
        }
        catch {
            $ErrorDetails = $PSItem

            switch ($ErrorDetails.FullyQualifiedErrorId) {
                "GetWMICOMException,Microsoft.PowerShell.Commands.GetWmiObjectCommand" {
                    Write-Warning "$($Computer) - Connection timed out."
                    New-Object -TypeName "pscustomobject" -Property @{
                        "ComputerName" = $Computer;
                        "UserName"     = "N/A (Reason: Timeout)"
                    }
                }
                default {
                    Write-Warning "$($Computer) - $($ErrorDetails.Exception.Message)"
                    New-Object -TypeName "pscustomobject" -Property @{
                        "ComputerName" = $Computer;
                        "UserName"     = "N/A (Reason: $($ErrorDetails.Exception.Message))"
                    }
                }
            }
        }
    }
}

process {

    $ScriptJobs = @()
    foreach ($Computer in $ComputerName) {
        
        $ScriptJobs += Start-Job -Name "Get-LoggedOn" -ScriptBlock $GetLoggedOnScriptBlock -ArgumentList $Computer, $Credential
        
    }

    $null = Wait-Job -Job $ScriptJobs

    $return = @()
    $JobData = Receive-Job -Job $ScriptJobs

    foreach ($d in $JobData) {
        $return += New-Object -TypeName "pscustomobject" -Property @{
            "ComputerName" = $d.ComputerName;
            "UserName"     = $d.UserName
        }
    }


}

end {

    return $return

}