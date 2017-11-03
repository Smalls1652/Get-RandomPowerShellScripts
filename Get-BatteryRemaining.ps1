function Get-BatteryRemaining
{
    <#

.SYNOPSIS
This script gathers information about battery power on a macOS machine and outputs it into the console.

.DESCRIPTION
This script gathers information about battery power on a macOS machine and outputs it into the console. It uses pmset as the data source for battery data.

.EXAMPLE
Get-BatteryRemaining

#>
    begin
    {
        $pmsetOut = (pmset -g batt).Split(";")
    }

    process
    {
        $powerObj = @{"Source" = $pmsetOut[0].Trim("Now drawing from").Trim("'") ; "Status" = (Get-Culture).TextInfo.ToTitleCase($pmsetOut[2].Trim()) ; "Remaining" =  $pmsetOut[3].Trim(" remaining present: true")}
    
        return [pscustomobject]$powerObj | Select-Object -Property "Source","Status","Remaining" | Format-Table -AutoSize
    }
}