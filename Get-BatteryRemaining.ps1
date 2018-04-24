function Get-BatteryRemaining {
    <#

.SYNOPSIS
This script gathers information about battery power on a macOS machine and outputs it into the console.

.DESCRIPTION
This script gathers information about battery power on a macOS machine and outputs it into the console. It uses pmset as the data source for battery data.

.EXAMPLE
Get-BatteryRemaining

#>

    param(
        [switch]$BasicOutput
    )

    begin {
        $pmsetOut = (pmset -g batt).Split(";")
    }

    process {
        $powerObj = @{"Source" = $pmsetOut[0].Trim("Now drawing from").Trim("'") ; "Status" = (Get-Culture).TextInfo.ToTitleCase($pmsetOut[2].Trim()) ; "Remaining" = $pmsetOut[3].Trim(" remaining present: true")}

        if ($powerObj.Remaining -eq "(no estimate)" -or $powerObj.Remaining -eq "ot ch" -or $powerObj.Remaining -eq "0:00") {
            Write-Warning "Charging source recently changed. Battery time still calculating."
        }
        else {
            if ($BasicOutput) {

                $hoursRemain = $powerObj.Remaining.split(":")[0]
                [int32]$minutesRemain = $powerObj.Remaining.split(":")[1]

                [string]$hourOut = $null
                [string]$minuteOut = $null

                if ($hoursRemain -ne "0") {
                    if ($hoursRemain -eq "1") {
                        $hourOut = "$hoursRemain hour"
                    }
                    else {
                        $hourOut = "$hoursRemain hours"
                    }
                }
                else {
                    $hourOut = $null
                }

                if ($minutesRemain -ne "0") {
                    if ($minutesRemain -eq "1") {
                        $minuteOut = "$minutesRemain minute"
                    }
                    else {
                        $minuteOut = "$minutesRemain minutes"
                    }
                }
                else {
                    $minuteOut = $null
                }

                if ($minuteOut -ne $null -and $hourOut -ne $null) {
                    return "There's an estimated $hourOut and $minuteOut remaining on your battery."
                }
                elseif ($minuteOut -ne $null -and $hourOut -eq $null) {
                    return "There's an estimated $minuteOut remaining on your battery."
                }
                elseif ($minuteOut -eq $null -and $hourOut -ne $null) {
                    return "There's an estimated $hourOut remaining on your battery."
                }

            }
            else {
                return [pscustomobject]$powerObj | Select-Object -Property "Source", "Status", "Remaining" | Format-Table -AutoSize
            }
        }
    }
}