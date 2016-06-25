param(
	[String]$_ftpUrl,
	[String]$_ftpUser,
	[String]$_ftpPassword
)
#Add-Type -AssemblyName System.Net
#[reflection.assembly]::LoadWithPartialName( "System.Net" )

function GetRequest(
	[String]$ftpUrl,
	[String]$ftpUser,
	[String]$ftpPassword,
	[String]$ftpMethod)
{
	$request = [System.Net.FtpWebRequest]::Create("ftp://$ftpUrl")
	$request = [System.Net.FtpWebRequest]$request
	$request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPassword);
	$request.UseBinary = $true
	$request.UsePassive = $true
	$request.Method = $ftpMethod

	return $request
}

function ReadResponse([System.Net.FtpWebRequest]$request)
{
	$response = $request.GetResponse()
	$reader = New-Object System.IO.StreamReader($response.GetResponseStream())
	Write-Host $reader.ReadLine() 

	$reader.Close();
	$response.Close();
}

function Find-Files(
	[String]$ftpUrl = $_ftpUrl,
	[String]$ftpUser = $_ftpUser,
	[String]$ftpPassword = $_ftpPassword,
	[string]$query,
	[string]$startPath = ""
)
{
	$method = ([System.Net.WebRequestMethods+Ftp]::ListDirectory)
	
	Write-Host "Scanning Path:"$startPath
	$ftpFullPath = $ftpUrl
	if(!([string]::IsNullOrWhiteSpace($startPath)))
	{
		$ftpFullPath = $ftpFullPath + "/" + $startPath
	}

	$directories = New-Object System.Collections.ArrayList
	$files = New-Object System.Collections.ArrayList
	$fileNames = New-Object System.Collections.ArrayList
	

	$request = GetRequest $ftpFullPath $ftpUser $ftpPassword $method
	$response = $request.GetResponse()
	$reader = New-Object System.IO.StreamReader($response.GetResponseStream())

	while(!($reader.EndOfStream))
	{
		$line = $reader.ReadLine()
		if($line.StartsWith("d"))
		{
			[void]$directories.Add($line)
		}
		else
		{
			[void]$files.Add($line)
		}
	}
	$reader.Close();
	$response.Close();	

	#################################################################
	#
	#		   scanning directories not currently supported
	#
	#################################################################
	##go into each directory and see if we can find any files there
	#foreach($directory in $directories)
	#{
	#	$currentDirectory = ""
	#	$parts = $directory.Split(' ');
	#	#$parts
	#	if(!([string]::IsNullOrWhiteSpace($startPath)))
	#	{
	#		$currentDirectory = $startPath + "/"
	#	}
	#	$currentDirectory = $currentDirectory + $parts[$parts.Length - 1]

	#	$foundFiles = [System.Collections.ArrayList]$(FindFiles $ftpUrl $ftpUser $ftpPassword $query $currentDirectory)
	#	if($foundFiles -ne $null -and $foundFiles.Count -gt 0 )
	#	{
	#		#Write-Host "Found Files: "$foundFiles

	#		[void]$fileNames.AddRange($foundFiles)
	#	}
 
	#}

	#build the full file names
	$regexPattern = "^" + [System.Text.RegularExpressions.Regex]::Escape($query).Replace("\*", ".*").Replace("\?", ".").Replace("\(", "(").Replace("\)", ")").Replace("\|", "|") + "$"
	#Write-Host $regexPattern

	foreach($file in $files)
	{
		$fullPath = ""
		if(!([string]::IsNullOrWhiteSpace($startPath)))
		{
			$fullPath = $startPath + "/"
		}
		#Write-Host $file
		$parts = $file.Split('/');
		$fileName = $parts[$parts.Length - 1]
		$fullPath = $fullPath + $fileName
		#Write-Host "File loop fullPath:"$fullPath

		#see if file matches query
		if(!([string]::IsNullOrWhiteSpace($query)))
		{
			if([System.Text.RegularExpressions.Regex]::IsMatch($fileName, $regexPattern))
			{
				[void]$fileNames.Add($fullPath) 
			}
		}
		else
		{
			[void]$fileNames.Add($fullPath) 
		}
	}
	return ,$fileNames

}
Set-Alias ftpFind Find-Files -Scope global

function Get-File(
	[String]$ftpUrl = $_ftpUrl,
	[String]$ftpUser = $_ftpUser,
	[String]$ftpPassword = $_ftpPassword,
	[string]$ftpFilePath = "",
	[string]$localFilePath = ""
)
{
	$method = ([System.Net.WebRequestMethods+Ftp]::DownloadFile)
	$ftpFullPath = $ftpUrl + "/" + $ftpFilePath

	$request = GetRequest $ftpFullPath $ftpUser $ftpPassword $method
	$response = $request.GetResponse()
	$stream = $response.GetResponseStream()

	$parts = $ftpFilePath.Split('/')

	$s = $null
	#$localFile = $(Resolve-Path '../xml/').ToString()+$parts[$parts.Length-1]
	if(!($localFilePath.EndsWith("\")))
	{
		$localFilePath = $localFilePath+"\"
	}
	$localFile = $localFilePath+$parts[$parts.Length-1]
	
	try
	{
		$s = [System.IO.File]::Create($localFile)
		$stream.CopyTo($s)
	}
	finally
	{
		if($s -ne $null)
		{
			$s.Dispose()
		}
		$stream.Dispose()
		$response.Close()
	}

	return $localFile
}
Set-Alias ftpDl Get-File -Scope global

function Get-FileSize(
	[String]$ftpUrl = $_ftpUrl,
	[String]$ftpUser = $_ftpUser,
	[String]$ftpPassword = $_ftpPassword,
	[string]$ftpFilePath = ""
)
{
	$method = ([System.Net.WebRequestMethods+Ftp]::GetFileSize)
	$ftpFullPath = $ftpUrl + "/" + $ftpFilePath

	$request = GetRequest $ftpFullPath $ftpUser $ftpPassword $method
	$response = [System.Net.FtpWebResponse]$request.GetResponse()

	$fileSize = $response.ContentLength

	$response.Close()

	return $fileSize
}
Set-Alias ftpFileSize Get-FileSize -Scope global

function Get-TimeStamp(
	[String]$ftpUrl = $_ftpUrl,
	[String]$ftpUser = $_ftpUser,
	[String]$ftpPassword = $_ftpPassword,
	[string]$ftpFilePath = ""
)
{
	$method = ([System.Net.WebRequestMethods+Ftp]::GetDateTimestamp)
	$ftpFullPath = $ftpUrl + "/" + $ftpFilePath

	$request = GetRequest $ftpFullPath $ftpUser $ftpPassword $method
	$response = [System.Net.FtpWebResponse]$request.GetResponse()

	$timeStamp = $response.LastModified

	$response.Close()

	return $timeStamp
}
Set-Alias ftpTimeStamp Get-TimeStamp -Scope global
