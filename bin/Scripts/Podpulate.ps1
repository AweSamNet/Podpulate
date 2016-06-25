param(
	[String]$ftpUrl,
	[String]$ftpUser,
	[String]$ftpPassword,
	[String]$startPath
)
if (Get-Module -Name Podpulate) {
	Remove-Module Podpulate
}

Import-Module (Resolve-Path('./Modules/Podpulate.psm1')) -ArgumentList $ftpUrl, $ftpUser, $ftpPassword

Podpulate -startPath $startPath