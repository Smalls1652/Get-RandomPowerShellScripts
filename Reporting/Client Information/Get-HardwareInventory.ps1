[CmdletBinding()]
param(
    [int]$BatchSize = 25,
    [pscredential]$Credential
)

$compInfo_ScriptBlock = {
    param(
        $Computer,
        $Credential
    )
    try {
        $CompSys = Get-WmiObject -Class "win32_computersystem" -Credential $Credential -ComputerName $Computer.Name -ErrorAction SilentlyContinue -Property * | Select-Object -Property *

        if ($CompSys) {
            return New-Object -TypeName psobject -Property @{
                "ComputerName" = $Computer.Name;
                "Make"         = $CompSys.Manufacturer;
                "Model"        = $CompSys.Model;
                "IPv4Address"  = $Computer.IPv4Address
            }
        }
        else {
            return New-Object -TypeName psobject -Property @{
                "ComputerName" = $Computer.Name;
                "Make"         = "No Return";
                "Model"        = "No Return";
                "IPv4Address"  = $Computer.IPv4Address
            }
        }
    }
    catch {
        return New-Object -TypeName psobject -Property @{
            "ComputerName" = $Computer.Name;
            "Make"         = "No Return";
            "Model"        = "No Return";
            "IPv4Address"  = $Computer.IPv4Address
        }
    }
}
Write-Progress -Id 1 -Activity "Gathering Computers" -Status "Progress" -CurrentOperation "Gathering computer objects from AD..." -PercentComplete 0

$DomainComputers = Get-ADComputer -Filter "OperatingSystem -notlike '*Server*'" -Properties * | Where-Object -Property "IPv4Address" -ne $null

Write-Progress -Id 1 -Activity "Gathering Computers" -Completed

$i = 1
$z = 1
$compCount = $DomainComputers | Measure-Object | Select-Object -ExpandProperty "Count"

$gatherJobs = @()
$returnData = @()

foreach ($Computer in $DomainComputers) {
    Write-Progress -Id 2 -Activity "Creating Jobs" -Status "Progress [$($z)/$($compCount)]:" -CurrentOperation "Creating job for $($Computer.Name)..." -PercentComplete ($z / $compCount * 100)

    $gatherJobs += Start-Job -Name "$($Computer.Name)-GatherJob" -ScriptBlock $compInfo_ScriptBlock -ArgumentList $Computer, $Credential
    $i++
    $z++

    if (($i -eq $BatchSize) -or ($z -eq $compCount)) {

        while ($gatherJobs | Get-Job | Where-Object -Property "State" -eq "Running" ) {
            $jobsComplete = $gatherJobs | Get-Job | Where-Object -Property "State" -eq "Completed" | Measure-Object | Select-Object -ExpandProperty "Count"
            $jobsTotal = $gatherJobs | Get-Job | Measure-Object | Select-Object -ExpandProperty "Count"
        
            Write-Progress -Id 3 -Activity "Running Job Batch" -Status "Progress [$($jobsComplete)/$($jobsTotal)]:" -CurrentOperation "Waiting for batch of jobs to complete..." -PercentComplete ($jobsComplete / $jobsTotal * 100)
        
            Start-Sleep -Seconds 2
        }

        $returnData += Receive-Job -Job $gatherJobs
        Remove-Job -Job $gatherJobs -Force | Out-Null

        $i = 1
        $gatherJobs = @()
        
        Write-Progress -Id 3 -Activity "Running Job Batch" -Completed

    }
}

Write-Progress -Id 2 -Activity "Creating Jobs" -Completed

return $returnData | Select-Object -Property "ComputerName", "Make", "Model", "IPv4Address"