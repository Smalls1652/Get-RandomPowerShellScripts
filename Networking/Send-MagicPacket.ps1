<#
.SYNOPSIS
    Send a magic packet to a MAC address.
.DESCRIPTION
    Generates a magic packet to wake up a computer, identified by the MAC address, across the network.

.PARAMETER MACAddress
    The MAC address of the computer.

.PARAMETER IPBroadcast
    The broadcast address of the network.

.PARAMETER UDPPort
    The UDP port to send the magic packet to.

.EXAMPLE
    PS > ./Send-MagicPacket.ps1 -MACAddress "AB:CD:EF:12:34:56"

.EXAMPLE
    PS > ./Send-MagicPacket.ps1 -MACAddress "AB-CD-EF-12-34-56" -IPBroadcast "192.168.12.255"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MACAddress,
    [string]$IPBroadcast = "255.255.255.255",
    [int]$UDPPort = 9
)

begin {
    $UDP = New-Object -TypeName System.Net.Sockets.UdpClient

    $MacOctets = $MACAddress.Split(":").Split("-")

    if ($MacOctets.Count -ne 6) {
        Write-Error -Message "The MAC address does not contain the right amound of octets." -Category InvalidData -RecommendedAction "Check the MAC address supplied." -TargetObject $MACAddress -ErrorAction Stop
    }

    $Bytes = @()

    for ($i = 1; $i -le 6; $i++) {
        $Bytes += [byte]255
    }

    for ($i = 1; $i -le 16; $i++) {
        foreach ($Octet in $MacOctets) {
            try {
                $Bytes += [System.Convert]::ToByte($Octet, 16)
            }
            catch [Exception] {
                $ErrorDetails = $_

                switch ($ErrorDetails.FullyQualifiedErrorId) {
                    "FormatException" {
                        Write-Error -Exception "FormatException" -Message "The octect '$($Octet)' contains an invalid character in the string." -Category InvalidData -ErrorId "FormatException" -TargetObject $Octet -ErrorAction Stop
                    }
                    Default {
                        Write-Error $ErrorDetails -ErrorAction Stop
                    }
                }
            }
        }
    }
}

process {

    [byte[]]$MagicPacket = $Bytes

    try {
        $UDP.Connect($IPBroadcast, $UDPPort)
        $UDP.Send($MagicPacket, $MagicPacket.Length)
    }
    catch [Exception] {
        $ErrorDetails = $_
        switch ($ErrorDetails.FullyQualifiedErrorId) {
            "ObjectDisposedException" { 
                Write-Error -Exception "ObjectDisposedException" -ErrorId "ObjectDisposedException" -Message "The UDPClient object's connection was closed." -Category CloseError -TargetObject $UDP -ErrorAction Stop
            }
            "ArgumentOutOfRangeException" {
                Write-Error -Exception "ArgumentOutOfRangeException" -ErrorId "ArgumentOutOfRangeException" -Message "UDP port is not within the valid port range." -Category ProtocolError -TargetObject $UDP -ErrorAction Stop
            }
            "SocketException" {
                Write-Error -Exception "SocketException" -ErrorId "SocketException" -Message "There was an error accessing the socket." -Category ResourceUnavailable -TargetObject $UDP -ErrorAction Stop
            }
            "ArgumentNullException" {
                Write-Error -Exception "ArgumentNullException" -ErrorId "ArgumentNullException" -Message "The magic packet data is null." -Category InvalidData -TargetObject $UDP -ErrorAction Stop
            }
            Default {
                Write-Error $ErrorDetails -ErrorAction Stop
            }
        }
    }

}

end {
    $UDP.Close()

    return New-Object -TypeName psobject -Property @{
        "MAC Address" = $MACAddress;
        "Broadcast" = $IPBroadcast;
        "Success" = $true
    }
}