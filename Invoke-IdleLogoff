param (
	[int]$Timeout = 15
)

function Get-IdleTime
{
	Add-Type @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace PInvoke.Win32 {

    public static class UserInput {

        [DllImport("user32.dll", SetLastError=false)]
        private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

        [StructLayout(LayoutKind.Sequential)]
        private struct LASTINPUTINFO {
            public uint cbSize;
            public int dwTime;
        }

        public static DateTime LastInput {
            get {
                DateTime bootTime = DateTime.UtcNow.AddMilliseconds(-Environment.TickCount);
                DateTime lastInput = bootTime.AddMilliseconds(LastInputTicks);
                return lastInput;
            }
        }

        public static TimeSpan IdleTime {
            get {
                return DateTime.UtcNow.Subtract(LastInput);
            }
        }

        public static int LastInputTicks {
            get {
                LASTINPUTINFO lii = new LASTINPUTINFO();
                lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
                GetLastInputInfo(ref lii);
                return lii.dwTime;
            }
        }
    }
}
'@
	
	return [PInvoke.Win32.UserInput]::IdleTime
	
}

function Check-IdleTime
{
	
	param (
		[int]$IdleTime,
		[int]$IdleLimit
		
	)
	
	process
	{
		if ($IdleTime -ge $IdleLimit)
		{
			return $true
		}
		else
		{
			return $false	
		}
	}
	
}

function Get-LockscreenStatus
{
	try
	{
		$username = Get-WmiObject -Class "win32_ComputerSystem" | Select-Object -ExpandProperty "username"
	}
	catch
	{
		return $false
	}
	
	try
	{
		if ((Get-Process logonui -ErrorAction Stop) -and ($username))
		{
			return $true
		}
	}
	catch
	{
		if ($username)
		{
			return $false
		}
	}
}

function Get-LockscreenTime
{
	try
	{
		return Get-Process logonui -ErrorAction Stop | Select-Object -ExpandProperty "StartTime"
	}
	catch
	{
		return $false
	}
}

Write-Output "Timeout set to $Timeout minutes."

$i = 0

while ($i -eq 0)
{
	$UserIdleTime = Get-IdleTime
	$UserLockStatus = Get-LockscreenStatus
	
	if ($UserLockStatus -eq $false)
	{
		If ((Check-IdleTime -IdleTime $UserIdleTime.Minutes -IdleLimit $Timeout) -eq $true)
		{
			Write-Output "Computer has been inactive."
			shutdown -l -f
		}
		else
		{
			$idlemins = $UserIdleTime.Minutes
			$idlesecs = $UserIdleTime.Seconds
			Write-Output "Computer has been active. (Inactive: $idlemins minutes and $idlesecs seconds)"
			Start-Sleep -Seconds 15
		}
	}
	else
	{
		$userLockScreenTime = Get-LockscreenTime
		$curTime = Get-Date
		
		$logoffTime = $userLockScreenTime.AddHours(1)
		
		if ($curTime -ge $logoffTime)
		{
			Write-Output "Computer has been inactive on the lockscreen."
			shutdown -l -f
		}
		else
		{
			Write-Output "Computer is currently locked. IdleLogoff will continue at $logoffTime"
			Start-Sleep -Seconds 15
		}
	}
}
