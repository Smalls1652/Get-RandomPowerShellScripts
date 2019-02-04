$DHCPServers = Get-DhcpServerInDC

foreach ($Server in $DHCPServers) {
    $FailoverServers = Get-DhcpServerv4Failover -Name $Server.DnsName

    $FailoverServers
}