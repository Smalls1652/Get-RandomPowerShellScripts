function Get-LoggedOn
{

<#
	.SYNOPSIS
		This function allows you to get the current logged on user for a machine.
    
    .DESCRIPTION
         This function allows you to get the current logged on user for a machine. It uses WMI, rather than CIM for compatability purposes with machines still running PowerShell 2.0.

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
	
#>

[OutputType([pscustomobject])]
[cmdletbinding()]

param(
[Parameter(ValueFromPipeline = $true,ValueFromPipelineByPropertyName=$True)][string[]]$ComputerName = $env:COMPUTERNAME
)

Begin { 

Write-Verbose "Grabbing user account logged in."
$ErrorActionPreference = 'Stop'
}

Process {

foreach ($comp in $ComputerName)
{
    try
    {
        $loggedOn = Get-WmiObject -Class win32_computersystem -ComputerName $comp | Select-Object -ExpandProperty UserName
        $output = @{ "ComputerName" = $comp; UserName = if (!$loggedOn) { $false } Else { $loggedOn } }
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