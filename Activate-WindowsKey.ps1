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
