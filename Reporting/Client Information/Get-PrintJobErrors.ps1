function Get-PrintJobErrors
{

<#
	.SYNOPSIS
		This function allows you to get the status of a machine's print spooler to see if it's erroring out or not.
	
    .DESCRIPTION
		This function allows you to get the status of a machine's print spooler to see if it's erroring out or not. It uses WMI, rather than CIM for compatability purposes with machines still running PowerShell 2.0.
	
	.EXAMPLE
        Get-PrintJobErrors

        To return the print spooler status of the local machine.

	.EXAMPLE
        Get-PrintJobErrors -ComputerName Example1

        To return the print spooler status of a remote machine.

    .EXAMPLE
        Get-PrintJobErrors -ComputerName Example1,Example2,Example3

        To return the print spooler status of multiple remote machines.

	.PARAMETER ComputerName
		The computer name that you would like to retieve information from.
	
	#>

[OutputType([pscustomobject])]
[cmdletbinding()]

param(
[Parameter(ValueFromPipeline = $true,ValueFromPipelineByPropertyName=$True)][string[]]$ComputerName = $env:COMPUTERNAME
)

Begin {
$ErrorActionPreference = 'Stop'
}

Process {

    foreach ($comp in $ComputerName)
    {
    try
    {
        $printers = Get-WMIObject Win32_PerfFormattedData_Spooler_PrintQueue -ComputerName $comp | Select Name, Jobs, JobErrors | Where-Object -Property "Name" -eq "_Total"
        
        $output = @{ "ComputerName" = $comp; "Jobs" = $printers.Jobs }

        #Start the logic test for if there are any errors or not
        if ($printers.JobErrors -eq 0) #No errors
        {
            $output.Error = $false
            Write-Verbose "$comp has no print spooler errors."
        }
        else #An error has been found
        {     
            $output.Error = $true
            Write-Verbose "$comp has printer spooler has errors."
        }

        [pscustomobject]$output | Select-Object -Property ComputerName,Jobs,Error #Selecting the properties here only because it puts Error first in the object table.

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
