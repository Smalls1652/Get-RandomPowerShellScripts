Function Download-FiletoPath
{
	
	param (
		[Parameter(Mandatory = $true)]
		[string]$Download,
		[Parameter(Mandatory = $true)]
		[string]$Path
	)
	
	Begin
	{
		
		$webclient = New-Object System.Net.WebClient
		
	}
	
	Process
	{
		
		$webclient.DownloadFile($Download, $Path)
		
	}
}

Function Download-SPCImages
{
	param (
	[Parameter(Mandatory = $true)]
	[string]$Path
	)
	begin
	{
		#Generate random seed to bypass possible caching problems
		$seed = Get-Random
		
		#Create folders
		New-Item -Path "$Path\SPC" -ItemType Directory | Out-Null
		New-Item -Path "$Path\SPC\Day01" -ItemType Directory | Out-Null
		New-Item -Path "$Path\SPC\Day02" -ItemType Directory | Out-Null
		New-Item -Path "$Path\SPC\Day03" -ItemType Directory | Out-Null
		
		
		#Gathering Data for the SPC outlook pages
		$spc1 = Invoke-WebRequest -Uri "http://www.spc.noaa.gov/products/outlook/day1otlk.html?$seed"
		$spc2 = Invoke-WebRequest -Uri "http://www.spc.noaa.gov/products/outlook/day2otlk.html?$seed"
		$spc3 = Invoke-WebRequest -Uri "http://www.spc.noaa.gov/products/outlook/day3otlk.html?$seed"
		
		#Getting the simplified print version of the outlook pages
		$SpcDay1URL = (($spc1.ParsedHtml.getElementsByTagName("a") | Where-Object -Property "textContent" -eq "Print Version" | Select-Object -ExpandProperty "href").Trim("about:").Insert(0, "http://www.spc.noaa.gov/products/outlook/")) + "?$seed"
		$SpcDay2URL = (($spc2.ParsedHtml.getElementsByTagName("a") | Where-Object -Property "textContent" -eq "Print Version" | Select-Object -ExpandProperty "href").Trim("about:").Insert(0, "http://www.spc.noaa.gov/products/outlook/")) + "?$seed"
		$SpcDay3URL = (($spc3.ParsedHtml.getElementsByTagName("a") | Where-Object -Property "textContent" -eq "Print Version" | Select-Object -ExpandProperty "href").Trim("about:").Insert(0, "http://www.spc.noaa.gov/products/outlook/")) + "?$seed"
		
		#Loading the print version pages of the outlook pages into memory
		$spcDay1 = Invoke-WebRequest -Uri $spcDay1URL
		$spcDay2 = Invoke-WebRequest -Uri $spcDay2URL
		$spcDay3 = Invoke-WebRequest -Uri $spcDay3URL
	}
	
	Process
	{
		#SPC Day 1
		$spcDay1Text = $spcDay1.ParsedHtml.body.getElementsByTagName("pre") | Select-Object -ExpandProperty "outerText"
		$spcDay1imgs = $spcDay1.ParsedHtml.body.getElementsByTagName("img") | Select-Object -ExpandProperty "href" -Skip 2
		
		$spcDay1Text | Out-File -FilePath "$Path\SPC\Day01\Text.txt"
		
		$spcDay1full = @{ }
		foreach ($img in $spcDay1imgs)
		{
			$parseLink = $img.Trim("about:")
			$joinedLink = "http://www.spc.noaa.gov/products/outlook/$parseLink"
			$spcDay1full += @{ $parseLink = $joinedLink }
			Download-FiletoPath -Download $joinedLink -Path "$Path\SPC\Day01\$parseLink"
		}
		
		#SPC Day 2
		$spcDay2Text = $spcDay2.ParsedHtml.body.getElementsByTagName("pre") | Select-Object -ExpandProperty "outerText"
		$spcDay2imgs = $spcDay2.ParsedHtml.body.getElementsByTagName("img") | Select-Object -ExpandProperty "href" -Skip 2
		
		$spcDay2Text | Out-File -FilePath "$Path\SPC\Day02\Text.txt"
		
		$spcDay2full = @{ }
		foreach ($img in $spcDay2imgs)
		{
			$parseLink = $img.Trim("about:")
			$joinedLink = "http://www.spc.noaa.gov/products/outlook/$parseLink"
			$spcDay2full += @{ $parseLink = $joinedLink }
			Download-FiletoPath -Download $joinedLink -Path "$Path\SPC\Day02\$parseLink"
		}
		
		#SPC Day 3
		$spcDay3Text = $spcDay3.ParsedHtml.body.getElementsByTagName("pre") | Select-Object -ExpandProperty "outerText"
		$spcDay3imgs = $spcDay3.ParsedHtml.body.getElementsByTagName("img") | Select-Object -ExpandProperty "href" -Skip 2
		
		$spcDay3Text | Out-File -FilePath "$Path\SPC\Day03\Text.txt"
		
		$spcDay3full = @{ }
		foreach ($img in $spcDay3imgs)
		{
			$parseLink = $img.Trim("about:")
			$joinedLink = "http://www.spc.noaa.gov/products/outlook/$parseLink"
			$spcDay3full += @{ $parseLink = $joinedLink }
			Download-FiletoPath -Download $joinedLink -Path "$Path\SPC\Day03\$parseLink"
		}
	}
	
}

Function Download-WPCImages
{
	param (
		[Parameter(Mandatory = $true)]
		[string]$Path
	)
	begin
	{
		#Generate random seed to bypass possible caching problems
		$seed = Get-Random
		
		#Create folders
		New-Item -Path "$Path\WPC" -ItemType Directory | Out-Null
		
		#Gathering Data for the WPC Short Range Forecasts page.
		$wpc = Invoke-WebRequest -Uri "http://www.wpc.ncep.noaa.gov/basicwx/basicwx_ndfd.php?$seed"
		
		#Query the specific web elements we want.
		$wpcPage = $wpc.ParsedHtml.body.getElementsByTagName("img") | Where-Object -Property "alt" -like "Forecast valid *"
		
	}
	
	process
	{
		foreach ($forecast in $wpcPage)
		{
			$alt = $forecast | Select-Object -ExpandProperty "alt"
			$image = "http://www.wpc.ncep.noaa.gov/basicwx/" + ($forecast | Select-Object -ExpandProperty "nameProp") + "?$seed"
			Download-FiletoPath -Download $image -Path "$Path\WPC\$alt.gif"
		}
	}
}


$curDateTime = Get-Date -Format "MM-dd-yyyy_HH-mm"
New-Item -Path "$env:USERPROFILE\NOAA\$curDateTime" -ItemType Directory

Download-SPCImages -Path "$env:USERPROFILE\NOAA\$curDateTime"
Download-WPCImages -Path "$env:USERPROFILE\NOAA\$curDateTime"
