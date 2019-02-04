[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Path
)

function convertFileSize {
    param(
        $bytes
    )

    if ($bytes -lt 1MB) {
        return "$([Math]::Round($bytes / 1KB, 2)) KB"
    }
    elseif ($bytes -lt 1GB) {
        return "$([Math]::Round($bytes / 1MB, 2)) MB"
    }
    elseif ($bytes -lt 1TB) {
        return "$([Math]::Round($bytes / 1GB, 2)) GB"
    }
}

#Load in the WebClient object and create a temporary file to download to.
$Downloader = New-Object -TypeName System.Net.WebClient
$TmpFile = New-TemporaryFile

try {

    #Start the download by using WebClient.DownloadFileTaskAsync, since this lets us show progress on screen.
    $FileDownload = $Downloader.DownloadFileTaskAsync($Url, $TmpFile)

    #Register the event from WebClient.DownloadProgressChanged to monitor download progress.
    Register-ObjectEvent -InputObject $Downloader -EventName DownloadProgressChanged -SourceIdentifier WebClient.DownloadProgressChanged | Out-Null

    #Wait two seconds for the registration to fully complete
    Start-Sleep -Seconds 2

    #While the download is showing as not complete, we keep looping to get event data.
    while (!($FileDownload.IsCompleted)) {
        $EventData = Get-Event -SourceIdentifier WebClient.DownloadProgressChanged | Select-Object -ExpandProperty "SourceEventArgs"

        $ReceivedData = ($EventData | Select-Object -ExpandProperty "BytesReceived" -Last 1)
        $TotalToReceive = ($EventData | Select-Object -ExpandProperty "TotalBytesToReceive" -Last 1)
        $TotalPercent = $EventData | Select-Object -ExpandProperty "ProgressPercentage" -Last 1

        Write-Progress -Activity "Downloading File" -Status "Percent Complete: $($TotalPercent)%" -CurrentOperation "Downloaded $(convertFileSize -bytes $ReceivedData) / $(convertFileSize -bytes $TotalToReceive)" -PercentComplete $TotalPercent
    }
}
finally {
    #Cleanup tasks
    Write-Progress -Activity "Downloading File" -Completed
    Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged

    $Downloader.CancelAsync()

    if ($FileDownload.IsCompleted) {
        #If the download was finished without termination, then we move the file.
        Move-Item -Path $TmpFile -Destination $Path -Force
    }
    else {
        #If the download was terminated, we remove the file.
        Remove-Item -Path $TmpFile -Force
    }

    $Downloader.Dispose()
}