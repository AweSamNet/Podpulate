param(
	[String]$_ftpUrl,
	[String]$_ftpUser,
	[String]$_ftpPassword
)
if (Get-Module -Name ftp) {
	Remove-Module ftp
}

Import-Module (Resolve-Path('Modules/ftp.psm1')) -ArgumentList $ftpUrl, $ftpUser, $ftpPassword

Add-Type -Path ..\Podpulate\bin\Release\AweSamNet.Podpulate.dll
#Add-Type -AssemblyName System.Net
#[reflection.assembly]::LoadWithPartialName( "System.Net" )

function PromptXmlIndex(
	$podcasts,
	[switch] $noCreate
)
{
	$index=0
	foreach($file in $podcasts)
	{
		Write-Host "[$index] " -ForegroundColor Yellow -NoNewline
		Write-Host $file
		$index = $index + 1
	}

	$maxValue = $podcasts.Count - 1

	if(!($noCreate))
	{
		Write-Host "[$($podcasts.Count)] " -ForegroundColor Yellow -NoNewline
		Write-Host "Create new"
		$maxValue = $maxValue + 1
	}

	while(!([double]::TryParse($selection,[ref]$index) -and $index -le $maxValue ))
	{
		Write-Host "Enter selection: " -ForegroundColor Green -NoNewline
		$selection = Read-Host 
	}

	return $index
}

function Start-Podpulate(
	[String]$ftpUrl=$_ftpUrl,
	[String]$ftpUser=$_ftpUser,
	[String]$ftpPassword=$_ftpPassword,
	[String]$startPath
)
{
	try
	{
		Write-Host "Searching for podcast xml files:"
		$matchingFiles = ftpFind $ftpUrl $ftpUser $ftpPassword "*.xml" $startPath

		Write-Host "Found the following possible podcast xml files. Select one:" -ForegroundColor Yellow 
		Write-Host ""

		$index = PromptXmlIndex $matchingFiles

		#get all podcast file names from ftp
		Write-Host "Searching for podcast files:"
		$podcasts = ftpFind $ftpUrl $ftpUser $ftpPassword "*.mp3" $startPath

		Write-Host "Found " -NoNewline
		Write-Host $podcasts.Count -ForegroundColor Green -NoNewline
		Write-Host " podcasts."
		$localPath = ""
		$localXmlPath = $(Resolve-Path '../xml/').ToString()
		$service = $null
		if($index -lt $matchingFiles.Count)
		{
			$localPath = ftpDl $ftpUrl $ftpUser $ftpPassword $matchingFiles[$index] $localXmlPath
			$service = [AweSamNet.Podpulate.PodpulateService]::Create($localPath)
		}
		else
		{
			$confirm = $false
			do
			{
				#get the filename the user wants.
				Write-Host "Enter the file name you want for the new xml file " -NoNewline
				Write-Host "[podcast.xml]" -ForegroundColor Green -NoNewline
				Write-Host ": " -NoNewline
				$fileName = $(Read-Host).Trim()

				if([String]::IsNullOrWhiteSpace($fileName))
				{
					$fileName = "podcast.xml"
				}
				elseif(!($fileName.EndsWith(".xml")))
				{
					$fileName = $fileName+".xml"
				}

				$localPath = $localXmlPath+$fileName

				Write-Host "The filename will be '" -NoNewline
				Write-Host $localPath -ForegroundColor Yellow -NoNewline
				Write-Host "'. "
				Write-Host "Is this ok? " -NoNewline
				Write-Host "[y]: " -ForegroundColor Green -NoNewline
				$confirmInput = $(Read-Host).Trim()

				if([string]::IsNullOrWhiteSpace($confirmInput) -or $confirmInput.ToLower() -eq "y")
				{
					$confirm = $true
				}
			} while($confirm -ne $true)

			Write-Host "Would you like to use all the same headers as another podcast? " -NoNewline
			Write-Host "[y]" -ForegroundColor Green -NoNewline
			Write-Host ": " -NoNewline
			$useOtherPodcastHeaders = $(Read-Host).Trim().ToLower()

			$service = [AweSamNet.Podpulate.PodpulateService]::Create()
			$service.Save($localPath)

			if([string]::IsNullOrWhiteSpace($useOtherPodcastHeaders) -or $useOtherPodcastHeaders -eq "y")
			{
				#load the xml file and get the headers
				$otherXmlIndex = PromptXmlIndex $matchingFiles -noCreate
				$localCopyPath = ftpDl $ftpUrl $ftpUser $ftpPassword $matchingFiles[$otherXmlIndex] $localXmlPath

				$service.LoadHeadersFromXml($localCopyPath)
			}
		}

		Write-Host "Podpulate can copy data from other podcast xml files into this one.  Would you like to use another podcast xml file's existing records whenever possible? " -NoNewline
		Write-Host "[y]" -ForegroundColor Green -NoNewline
		Write-Host ": " -NoNewline

		$useOtherPodcastItems = $(Read-Host).Trim()
			
		#see if we want to transfer podcast items
		if([string]::IsNullOrWhiteSpace($useOtherPodcastItems) -or $useOtherPodcastItems -eq "y")
		{
			#load the xml file and get the items
			$otherXmlIndex = PromptXmlIndex $matchingFiles -noCreate
			$localCopyPath = ftpDl $ftpUrl $ftpUser $ftpPassword $matchingFiles[$otherXmlIndex] $localXmlPath

			$service.LoadItemsFromXml($localCopyPath)
		}

		$allOrNew = $null
		do
		{
			Write-Host "Finally " -NoNewline -ForegroundColor Cyan
			Write-Host "one last question.  Would you like to populate only files newer than the newest entry or all files?"
			Write-Host "(All = " -NoNewline
			Write-Host "a" -NoNewline -ForegroundColor Yellow
			Write-Host ", New = " -NoNewline
			Write-Host "n" -NoNewline -ForegroundColor Yellow
			Write-Host ") " -NoNewline
			Write-Host "[n]" -ForegroundColor Green -NoNewline
			Write-Host ": " -NoNewline

			$allOrNew = $(Read-Host).Trim().ToLower()
			if([string]::IsNullOrWhiteSpace($allOrNew))
			{
				$allOrNew = "n"
			}
		} while ($allOrNew -ne "n" -and $allOrNew -ne "a")
		
		$existingPodcasts = 0
		$skippedOnlyNewer = 0
		$i = 0
		$newerPodcasts = New-Object System.Collections.ArrayList
		foreach($podcast in $podcasts)
		{
			Write-Progress -Activity "Processing podcasts:" -CurrentOperation "Scanning for: $podcast" -PercentComplete $((($i + 1) / $podcasts.Count) * 100) -Status "Skipped (existing): $existingPodcasts | Skipped (too old): $skippedOnlyNewer | Added: $($i - $existingPodcasts - $skippedOnlyNewer)"
			if($service.HasFile($podcast))
			{
				$existingPodcasts = $existingPodcasts + 1
			}
			else
			{
				$fileSize = ftpFileSize $ftpUrl $ftpUser $ftpPassword $podcasts[$i]
				#Write-Host "File size: " -NoNewline
				#Write-Host $fileSize -ForegroundColor Green
			 
				$timeStamp = ftpTimeStamp $ftpUrl $ftpUser $ftpPassword $podcasts[$i]
				if($allOrNew -eq "n")
				{
					if($service.IsNewer($timeStamp))
					{
						$hash = @{}
						$hash["url"] = $podcast
						$hash["fileSize"] = $fileSize
						$hash["timeStamp"] = $timeStamp

						[void]$newerPodcasts.Add($hash)
					}
					else
					{
						$skippedOnlyNewer = $skippedOnlyNewer + 1
					}
				}
				else 
				{
					#Write-Host "TimeStamp: " -NoNewline
					#Write-Host $timeStamp -ForegroundColor Green
					[void]$service.AddItem("http://www."+$podcasts[$i], $timeStamp, $fileSize, $false)
				}
			}
			$i = $i + 1
		}

		$i = 0
		foreach($podcast in $newerPodcasts)
		{
			#Write-Host "url: $($podcast.url), timeStamp: $($podcast.timeStamp), fileSize: $($podcast.fileSize)"
			Write-Progress -Activity "Processing podcasts:" -CurrentOperation "Adding new file: $podcast" -PercentComplete $((($i + 1) / $newerPodcasts.Count) * 100) -Status "Added: $i"
			[void]$service.AddItem("http://www."+$podcast.url, $podcast.timeStamp, $podcast.fileSize, $false)

			$i = $i + 1
		}

		$service.Save($localPath)

		Write-Host "This xml file has " -NoNewline
		Write-Host $existingPodcasts -NoNewline -ForegroundColor Green
		Write-Host " of" $podcasts.Count "podcasts already listed, and "
		Write-Host $($podcasts.Count - $existingPodcasts - $skippedOnlyNewer) -NoNewline -ForegroundColor Green
		Write-Host " podcasts were added."

		Write-Host ""
		Write-Host "Please make sure to go through the file " -NoNewline -ForegroundColor Yellow
		Write-Host $localPath -ForegroundColor Green -NoNewline
		Write-Host " and be sure to fill in any missing values." -ForegroundColor Yellow

		#Write-Host $service.ToString()
	}
	catch
	{
		Write-Error $_.Exception
	}
	finally{
		Read-Host "Close [Enter]"
	}
}

Set-Alias Podpulate Start-Podpulate -Scope global

