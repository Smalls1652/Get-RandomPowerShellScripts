[cmdletbinding()]
param(
    [string]$JSONPath,
    [string]$JSON,
    [string]$Title
)

if ($JSONPath) {
    $JsonString = (Get-Content -Path $JSONPath) -join "`n"
}
elseif ($JSON) {
    $JsonString = $JSON -join "`n"
}
else {
    throw {
        Write-Error "No input found."
    }
}

try {
    $JSONFileObject = $JsonString | ConvertFrom-Json
}
catch {
    Write-Error "There was an issue with the JSON."
}

$JSONProps = ($JSONFileObject | ForEach-Object { $_.psobject.Properties }).Name | Select-Object -Unique

$htmlObjects = @()
$modalObjects = @()
foreach ($item in $JSONFileObject) {

    if ((($item.psobject.Properties).Name | ForEach-Object { if ($JSONProps -contains "$($_)") { $true } } )) {
        $tableRow = "<tr>"
        foreach ($p in $item.psobject.Properties) {
            $id = -join ((65..90) + (97..122) | Get-Random -Count 10 | % {[char]$_})

            if ($p.TypeNameOfValue -eq "System.Management.Automation.PSCustomObject") {
                $objModal = ""
                foreach ($property in $p.Value.psobject.Properties) {
                    $objModal += "<tr>`n<th scope=""row"">$($property.Name)</th>`n<td>$($property.Value)</td>`n</tr>"
                }
                $tableRow += "`n<td><button type=""button"" class=""btn btn-primary"" data-toggle=""modal"" data-target=""#$($id)-Modal"">View</button></td>"
                $modalHTML = "<div class=""modal fade"" id=""$($id)-Modal"" tabindex=""-1"" role=""dialog"">
            <div class=""modal-dialog modal-xl"" role=""document"">
                <div class=""modal-content"">
                    <div class=""modal-header"">
                        <h5 class=""modal-title"" id=""exampleModalLabel"">$($p.Name)</h5>
                    </div>
                    <div class=""modal-body table-responsive"" style=""max-height: 45em;"">
                        <table class=""table"">
                            <thead>
                                <tr>
                                    <th scope=""col"">Property</th>
                                    <th scope=""col"">Data</th>
                                </tr>
                            </thead>
                            <tbody>
                            $($objModal)
                            </tbody>
                        </table>
                    </div>
                    <div class=""modal-footer"">
                        <button type=""button"" class=""btn btn-secondary"" data-dismiss=""modal"">Close</button>
                    </div>
                </div>
            </div>
        </div>"
        
                $modalObjects += $modalHTML
            }
            elseif ($p.TypeNameOfValue -like "System.Object*") {
                if ($p.Value.Count -gt 0) {
                    $obj = ""
                    foreach ($i in $p.Value) {
                        $obj += "<li class=""list-group-item bg-dark text-white"">$($i)</li>"
                    }
                    $tableRow += "`n<td><button type=""button"" class=""btn btn-primary"" data-toggle=""modal"" data-target=""#$($id)-Modal"">View</button></td>"
                    $modalHTML = "<div class=""modal fade"" id=""$($id)-Modal"" tabindex=""-1"" role=""dialog"">
            <div class=""modal-dialog modal-lg"" role=""document"">
                <div class=""modal-content"">
                    <div class=""modal-header"">
                        <h5 class=""modal-title"" id=""exampleModalLabel"">$($p.Name)</h5>
                    </div>
                    <div class=""modal-body"" style=""max-height: 45em; overflow-y: scroll;"">
                        <ul class=""list-group"">
                            $($obj)
                        </ul>
                    </div>
                    <div class=""modal-footer"">
                        <button type=""button"" class=""btn btn-secondary"" data-dismiss=""modal"">Close</button>
                    </div>
                </div>
            </div>
        </div>"
        
                    $modalObjects += $modalHTML
                }
                else {
                    $tableRow += "<td class=""text-danger"">Null</td>"
                }
            }
            elseif ($p.TypeNameOfValue -eq "System.String") {
                $tableRow += "<td>$($p.Value)</td>"
            }
            elseif ($p.TypeNameOfValue -like "System.Int*") {
                $tableRow += "<td class=""text-monospace"">$($p.Value)</td>"
            }
            elseif ($p.TypeNameOfValue -eq "System.Boolean") {
                if ($p.Value) {
                    $tableRow += "<td class=""text-primary"">True</td>"
                }
                else {
                    $tableRow += "<td class=""text-danger"">False</td>"
                }
            }
            else {
                try {
                    $tableRow += "<td>$($p.Value)</td>"
                }
                catch {
                    $tableRow += "<td class=""text-danger"">ERROR</td>"
                }
            }
        }

        $htmlObjects += $tableRow
    }
}

$tableColumns = ""

foreach ($item in $JSONProps) {
    $tableColumns += "<th scrope=""col"">$item</th>"
}

$FullHTML = "<!DOCTYPE html>
<html lang=""en"">

<head>
    <title>$($Title)</title>

    <meta name=""viewport"" content=""width=device-width, initial-scale=1, shrink-to-fit=no"">

    <link rel=""stylesheet"" href=""https://stackpath.bootstrapcdn.com/bootstrap/4.2.1/css/bootstrap.min.css"" integrity=""sha384-GJzZqFGwb1QTTN6wy59ffF1BuGJpLSa9DkKMp0DgiMDm4iYMj70gZWKYbI706tWS""
        crossorigin=""anonymous"">
</head>

<body class=""bg-dark"">
    <div class=""container p-2"">
        <nav class=""navbar navbar-light rounded"" style=""background-color: #e3f2fd; height: 4em;"">
            <span class=""navbar-brand display-1""><h4>$($Title)</h4></span>
        </nav>
    </div>

    <div class=""container-fluid p-4"">
        <div class=""row"">
            <div class=""mx-auto"" style=""min-width: 35em;"">
                <div class=""card border border-secondary rounded"">
                    <div class=""card-header bg-primary pb-1""><h5 class=""text-white"">Output</h5></div>
                    <div class=""card-body bg-light table-responsive"">
                        <table class=""table table-striped table-hover table-bordered"">
                            <thead>
                                <tr>
                                    $($tableColumns)
                                </tr>
                            </thead>
                            <tbody>
                            $($htmlObjects)
                            </tbody>
                        </table>    
                    </div>
                </div>
            </div>
        </div>
        $($modalObjects)
    </div>

    <div class=""container p-2"">
        <div class=""row pt-3 pb-2"">
            <div class=""col-6 mx-auto"">
                <div class=""card"">
                    <div class=""card-body text-muted pb-1"">
                        <p>This page was generated using a PowerShell script.</p>
                        <p><button type=""button"" class=""btn btn-primary"" data-toggle=""modal"" data-target=""#JSON-Modal"">Click here to view the input JSON file</button></p>
                    </div>
                </div>
            </div>
            <div class=""modal fade"" id=""JSON-Modal"" tabindex=""-1"" role=""dialog"">
                    <div class=""modal-dialog modal-lg"" role=""document"">
                        <div class=""modal-content"">
                            <div class=""modal-header"">
                                <h5 class=""modal-title"" id=""exampleModalLabel"">JSON File</h5>
                            </div>
                            <div class=""modal-body"">
                            <textarea class=""form-control"" style=""height: 45em;"" readonly>$($JsonString)</textarea>
                            </div>
                            <div class=""modal-footer"">
                                <button type=""button"" class=""btn btn-secondary"" data-dismiss=""modal"">Close</button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

    <script src=""https://code.jquery.com/jquery-3.3.1.slim.min.js"" integrity=""sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo""
        crossorigin=""anonymous""></script>
    <script src=""https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.6/umd/popper.min.js"" integrity=""sha384-wHAiFfRlMFy6i5SRaxvfOCifBUQy1xHdJ/yoi7FRNXMRBu5WHdZYu1hA6ZOblgut""
        crossorigin=""anonymous""></script>
    <script src=""https://stackpath.bootstrapcdn.com/bootstrap/4.2.1/js/bootstrap.min.js"" integrity=""sha384-B0UglyR+jN6CkvvICOB2joaf5I4l3gm9GU6Hc1og6Ls7i6U/mkkaduKaBhlAXv9k""
        crossorigin=""anonymous""></script>
</body>

</html>"

return $FullHTML
