param(
    [string[]]$ComputerName = $env:COMPUTERNAME,
    [string[]]$Logs,
    [datetime]$StartDate = (Get-Date).AddDays(-1),
    [datetime]$EndDate = (Get-Date),
    [int]$NumOfEvents,
    [string]$EntryType
)

<#
    This is a work in progress. I'm still working on it.
#>

$returnData = @{}

foreach ($computer in $ComputerName) {
    $gatheredData = @{}

    foreach ($log in $Logs) {

        if ($EntryType) {
            if ($NumOfEvents) {
                $data = Get-EventLog -ComputerName $computer -LogName $log -EntryType $EntryType -After $StartDate -Before $EndDate -Newest $NumOfEvents
            }
            else {
                $data = Get-EventLog -ComputerName $computer -LogName $log -EntryType $EntryType -After $StartDate -Before $EndDate
            }
        }
        else {
            if ($NumOfEvents) {
                $data = Get-EventLog -ComputerName $computer -LogName $log -After $StartDate -Before $EndDate -Newest $NumOfEvents
            }
            else {
                $data = Get-EventLog -ComputerName $computer -LogName $log -After $StartDate -Before $EndDate
            }
        }

        $gatheredData += @{$log = $data}

    }

    $returnData += @{$computer = $gatheredData}
}

return $returnData