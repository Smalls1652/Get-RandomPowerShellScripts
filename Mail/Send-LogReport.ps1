[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$To,
    [Parameter(Mandatory = $true)][string]$From,
    [Parameter(Mandatory = $true)][string]$SMTPServer,
    [Parameter(Mandatory = $true)][string]$Subject,
    [string]$MessageDetails,
    [Parameter(Mandatory = $true)][string]$LogDataFile,
    [Parameter(Mandatory = $true)][pscredential]$EmailCredential
)

if (Test-Path -Path $LogDataFile)
{
    $LogFileContent = Get-Content -Path $LogDataFile

    $EmailBody = "<html><body>"
    $EmailBody += "<div id=`"header`"><h3>$($Subject)</h3></div>"
    if ($MessageDetails) {
        $EmailBody += "<div id=`"extraDetails`"><p>$($MessageDetails)</p></div>"
    }
    $EmailBody += "<div id=`"logFile`"><code>$($LogFileContent -join '<br />')</code></div>"
    $EmailBody += "<div id=`"footer`"><p>(This email was auto-generated with a PowerShell script and was invoked from $($env:ComputerName).)</p></div>"
    $EmailBody += "</body></html>"

    Send-MailMessage -To $To -From $From -BodyAsHtml -Body $EmailBody -Subject $Subject -SmtpServer $SMTPServer -UseSsl -Port 587 -Credential $EmailCredential
}