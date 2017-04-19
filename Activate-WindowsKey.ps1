Function Activate-WindowsKey {
    <#
	.SYNOPSIS
		This function allows you to activate a machine.
	
    .DESCRIPTION
		This function allows you to activate a machine. It uses WMI, rather than CIM for compatability purposes with machines still running PowerShell 2.0.
	
	.EXAMPLE
        Activate-WindowsKey

        Activates the local machine with the provided product key.
		
	.EXAMPLE
        Activate-WindowsKey -ComputerName Example1

        Activates the remote machine with the provided product key.

    .EXAMPLE
        Activate-WindowsKey -ComputerName Example1,Example2,Example3
        
        Activates multiple remote machine with the provided product key.

	.PARAMETER ComputerName
		The computer name that you would like to retieve information from.

    .PARAMETER ProductKey
        The product key you want to use to activate Windows with.
	
	#>
    [cmdletbinding()]

    param(
    [Parameter(ValueFromPipeline = $true,ValueFromPipelineByPropertyName=$True)][string[]]$ComputerName = $env:COMPUTERNAME
    [Parameter(Mandatory = $true)][string]$ProductKey #= "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX" 
                                                          #If you want a key by default, uncomment the line above this one and replace with your own key.
    )
    Process {
        
        Write-Output "Sending activation info to $ComputerName"
        foreach ($comp in $ComputerName)
        {
            try
            {
                $ComputerAct = Get-WmiObject -query "select * from SoftwareLicensingService" -ComputerName $comp -ErrorAction Stop
                $ComputerAct.InstallProductKey($ProductKey) | Out-Null
                $ComputerAct.RefreshLicenseStatus() | Out-Null

                Invoke-WmiMethod -Class "win32_process" -Name "create" -ArgumentList "C:\windows\system32\cmd.exe /C cscript //B c:\windows\system32\slmgr.vbs /ato" -ComputerName $comp | Out-Null
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
