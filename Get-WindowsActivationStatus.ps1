function Get-WindowsActivationStatus
{

<#
	.SYNOPSIS
		This function allows you to get the activation status of a machine.
	
    .DESCRIPTION
		This function allows you to get the activation status of a machine. It uses WMI, rather than CIM for compatability purposes with machines still running PowerShell 2.0.
	
	.EXAMPLE
        Get-WindowsActivationStatus

        To return the Windows Activation status of the local machine.
		
	.EXAMPLE
        Get-WindowsActivationStatus -ComputerName Example1

        To return the Windows Activation status of a remote machine.

    .EXAMPLE
        Get-WindowsActivationStatus -ComputerName Example1,Example2,Example3
        
        To return the Windows Activation status of multiple remote machines.

	.PARAMETER ComputerName
		The computer name that you would like to retieve information from.
	
	#>

[OutputType([pscustomobject])]
[cmdletbinding()]

param(
[Parameter(ValueFromPipeline = $true,ValueFromPipelineByPropertyName=$True)][string[]]$ComputerName = $env:COMPUTERNAME
)

Begin { 

Write-Verbose "Starting Windows Activation check."
$ErrorActionPreference = 'Stop'
}

Process {

foreach ($comp in $ComputerName)
{
    try
    {
        $licensed = Get-WmiObject -Class SoftwareLicensingProduct -ComputerName $comp -ErrorAction Stop | Where-Object -Property "ApplicationID" -eq "55c92734-d682-4d71-983e-d6ec3f16059f" | Where-Object -Property "licensestatus" -eq 1
        $output = @{ "ComputerName" = $comp }

        #Start logic test to see if Windows is licensed or not.
        if (!$licensed) #Not licensed
        {
            $output.Licensed = $false
            Write-Verbose "$comp is not activated."
        }
        else #Licensed
        {
            $output.Licensed = $true
            Write-Verbose "$comp is activated."
        }
        [PSCustomObject]$output
    }
    catch [Exception]
    {
        $errorException = $_.Exception.Message
        Write-Warning "$comp failed with error message:`n$errorException"
        continue
    }


}

}

}