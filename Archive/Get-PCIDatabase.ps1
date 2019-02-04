<#
	Created by Tim Small (Smalls)
	Github: https://github.com/Smalls1652
	Version: 1.0

	This script will no longer work due to PCIDatabase shutting down.
#>

Function Get-PCIDatabase
{
	<#
	.SYNOPSIS
		This function allows you to search a database to get information for unknown drivers in device manager.
	
    .DESCRIPTION
		This function allows you to search a database to get information for unknown drivers in device manager. You can search between the vendor, device, or the vendor and device. The PCI database is provided by http://pcidatabase.com.
	
	.EXAMPLE
        Get-PCIDatabase

        Get the whole list of devices.
		
	.EXAMPLE
        Get-PCIDatabase -Vendor "8086"

        Get a list of devices that match a vendor ID, such as 8086 which is Intel.
		
	.EXAMPLE
        Get-PCIDatabase -Device "2152"

        Get a list of devices that match a device ID, such as 2152 which is "Broadcom Bluetooth 2.1 USB Dongle".
	
	.EXAMPLE
        Get-PCIDatabase -Vendor "8086" -Device "0042"

        Get a list of devices that match a device ID and vendor ID, such as a vendor ID of 8086 and a device ID of 0042 which returns "Intel graphics","Intel Q57/H55 Clarkdale (Onboard on D2912-A1x)".

	.PARAMETER Vendor
		The vendor ID you are looking for.
	
	.PARAMETER Device
		The device ID you are looking for.
	
	#>
	
	[cmdletbinding()]
	param (
		[string]$Vendor,
		[string]$Device
	)
	
	Begin
	{
		#Initiate the web client to start downloads and generate a temperoary file name for the file downloaded.
		$webclient = New-Object System.Net.WebClient
		$Path = [System.IO.Path]::GetTempFileName()
	}
	
	Process
	{
		try
		{
			$webclient.DownloadFile("http://pcidatabase.com/reports.php?type=csv", $Path)
		}
		catch [Exception]
		{
			$errorException = $_.Exception.Message
			Write-Warning "Failed with error message:`n$errorException"
			continue
		}
		
		$pcidatabase = Import-Csv -Path $Path -Header "VendorID", "DeviceID", "Chipset", "Description" #Import the PCI database into a variable
		
		Remove-Item -Path $Path -Force -Recurse #Delete the temporary file created.
		
		if ($Vendor -and $Device) #If both the vendor and device switches are provided.
		{
			$pcidatabase | Where-Object { ($_.VendorID -like "*$Vendor*" -and $_.DeviceID -like "*$Device*") }
		}
		elseif ($Vendor) #If only the vendor switch is provided.
		{
			$pcidatabase | Where-Object -Property "VendorID" -Like "*$Vendor*"
		}
		elseif ($Device) #If only the device switch is provided.
		{
			$pcidatabase | Where-Object -Property "DeviceID" -Like "*$Device*"
		}
		else #No switches are provided.
		{
			$pcidatabase	
		}
	}
	
}