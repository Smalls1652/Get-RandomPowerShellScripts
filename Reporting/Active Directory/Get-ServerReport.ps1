[cmdletbinding()]
param(
    [String]$OS,
    [pscredential]$Credential
)

$ADSearch = Get-ADComputer -Filter "operatingsystem -like '$($OS)*'" -Properties *

$ScriptBlock = {
    [cmdletbinding()]
    param(
        $ServerInfo,
        [pscredential]$Cred
    )
    $Roles = @("Active Directory Certificate Services", "Active Directory Domain Services", "Active Directory Federation Services", "Active Directory Lightweight Directory Services", "Active Directory Rights Management Services", "Device Health Attestation", "DHCP Server", "DNS Server", "Fax Server", "File and Storage Services", "Host Guardian Service", "Hyper-V", "MultiPoint Services", "Network Policy and Access Services", "Print and Document Services", "Remote Access", "Remote Desktop Services", "Volume Activation Services", "Web Server (IIS)", "Windows Deployment Services", "Windows Server Essentials Experience", "Windows Server Update Services")

    $returnObject = New-Object -TypeName psobject
    $MatchedRoles = @()

    if ($ServerInfo.IPv4Address) {
        $ServerIP = $ServerInfo.IPv4Address

        if ($ServerInfo.OperatingSystem -like "Windows Server 2008*") {
            try {
                $RoleList = Get-WmiObject -Class "win32_ServerFeature" -ComputerName $ServerInfo.Name -Credential $Cred -ErrorAction SilentlyContinue | Where-Object -Property "ParentID" -eq 0 | Select-Object -Property "Name"
    
                $MatchedRoles += $RoleList.Name | ForEach-Object { if ($Roles -contains "$($_.ToString())") { $_ } }
            }
            catch {
                $MatchedRoles = "Not Reachable"
            }
        }
        else {
            $MatchedRoles += Invoke-Command -ComputerName $ServerInfo.Name -Credential $Cred -ScriptBlock { Get-WindowsFeature | Where-Object { $_."Installed" -eq $true -and $_."FeatureType" -eq "Role" } | Select-Object -Property "DisplayName" | Sort-Object -ExpandProperty "DisplayName" }
        }

        if (!($MatchedRoles)) {
            $MatchedRoles = "No Roles"
        }
    } 
    else { 
        $ServerIP = "N/A"
        $MatchedRoles = "Not Reachable"
    }

    Add-Member -InputObject $returnObject -MemberType NoteProperty -Name "ComputerName" -Value $ServerInfo.Name
    Add-Member -InputObject $returnObject -MemberType NoteProperty -Name "IPAddress" -Value $ServerIP
    Add-Member -InputObject $returnObject -MemberType NoteProperty -Name "Roles" -Value $MatchedRoles
    Add-Member -InputObject $returnObject -MemberType NoteProperty -Name "More Data" -Value $ServerInfo

    Write-Output $returnObject
}

$Jobs = @()
$i = 1
foreach ($Server in $ADSearch) {

    Write-Verbose "Starting job for $($Server.Name) ($($i)/$($ADSearch.Count))..."
    $Jobs += Start-Job -Name "$($Server.Name) Role Gather" -ScriptBlock $ScriptBlock -ArgumentList $Server, $Credential
        
    $i++
}

Write-Verbose "Now waiting for jobs to complete..."
Wait-Job -Job $Jobs | Out-Null

$outputData = Get-Job | Receive-Job | Select-Object -Property "ComputerName", "IPAddress", "Roles", "More Data"

Get-Job | Remove-Job

return $outputData