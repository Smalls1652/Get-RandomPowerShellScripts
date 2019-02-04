function Delete-AllPrintJobs
{

<#
	.SYNOPSIS
		This function allows you to delete all of the print jobs.
	
    .DESCRIPTION
		This function allows you to delete all of the print jobs. It also allows for an additional use of resetting the print spooler service. It uses WMI, rather than CIM for compatability purposes with machines still running PowerShell 2.0.
	
	.EXAMPLE
        Delete-AllPrintJobs

        To delete all of the print jobs on the local machine.

    .EXAMPLE
        Delete-AllPrintJobs -ResetSpooler

        To delete all of the print jobs and reset the print spooler service on the local machine.

	.EXAMPLE
        Delete-AllPrintJobs -ComputerName Example1

        To delete all of the print jobs on a remote machine.

    .EXAMPLE
        Delete-AllPrintJobs -ComputerName Example1 -ResetSpooler

        To delete all of the print jobs and reset the print spooler service on a remote machine.

    .EXAMPLE
        Delete-AllPrintJobs -ComputerName Example1,Example2,Example3

        To delete all of the print jobs on multiple remote machines.

	.PARAMETER ComputerName
		The computer name that you would like to retieve information from.
    
    .PARAMETER ResetSpooler
        To reset the print spooler service, use this switch.
	
	#>

[OutputType([pscustomobject])]
[cmdletbinding()]

param(
[Parameter(ValueFromPipeline = $true,ValueFromPipelineByPropertyName=$True)][string[]]$ComputerName = $env:COMPUTERNAME,
[switch]$ResetSpooler
)

Begin {
$ErrorActionPreference = 'Stop'
}

Process {

    foreach ($comp in $ComputerName)
    {
    try
    {
        $printers = Get-WMIObject Win32_Printer -ComputerName $comp

        foreach ($printer in $printers)
        {
            $output = @{ "ComputerName" = $comp; "Printer" = $printer.Name }
            $return = $printer.CancelAllJobs()
            
            if ($return.ReturnValue -eq 0)
            {
                $output.Success = $true
            }
            else
            {
                $output.Success = $false
            }
            
            [pscustomobject]$output | Select-Object -Property ComputerName,Printer,Success #Selecting the properties here only because it puts Error first in the object table.

        }

        if ($ResetSpooler)
        {
            (Get-WmiObject -Class win32_Service -ComputerName $comp | Where-Object -Property "Name" -EQ "Spooler").StopService() | Out-Null
            (Get-WmiObject -Class win32_Service -ComputerName $comp | Where-Object -Property "Name" -EQ "Spooler").StartService() | Out-Null
        }

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
