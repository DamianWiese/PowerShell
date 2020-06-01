<#
.SYNOPSIS
 Gets a list of SharePoint databases and key properties for database administrators
 
.DESCRIPTION
 Gets a list of SharePoint databases and key properties for database administrators:
 Farm name,
 SQLServer name,
 Database name,
 SharePoint database type,
 Web application url (content databases only),
 Backup size as calculated by SharePoint

.EXAMPLE
Get-SPDatabaseReport.ps1 -OutputFolder C:\temp
 
.PARAMETER OutputFolder
Folder for output CSV file

.NOTES
This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree:
(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded
(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and 
(iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.

#>

#Script parameters
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputFolder
)

Add-PSSnapin Microsoft.SharePoint.PowerShell

#Fix up the output folder format
if (!($OutputFolder[-1] -eq "\"))
    {
        Write-Verbose "Appending trailing backslash to folder name"
        $OutputFolder = $OutputFolder+"\"
    }

#Test output path
if(Test-Path $OutputFolder)
    {
        Write-Verbose "Folder $OutputFolder exists"
    }
    else
    {
        Throw "Folder $OutputFolder does not exist"
    }

#Create output file
$timestamp = (Get-Date -Format yymmdd_hhmmss)
ForEach ($e in $extensions) { $ext += $e+"_" }
$farm = (Get-SPFarm).name
$output = "{0}DatabaseReport__{1}_{2}.csv" -f $OutputFolder, $farm, $timestamp
Write-Verbose "Output will be written to $output"

Get-SPDatabase | Select `
@{Name="Farm";Expression={$farm}}, `
@{Name="DatabaseName";Expression={$_.Name}}, `
@{Name="SQLServer";Expression={If ($_.server.address) {$_.Server.address.split("=")[-1]} else {$_.server}}}, `
@{Name="DatabaseType";Expression={$_.TypeName.split(".")[-1]}}, `
@{Name="WebApplication";Expression={$_.WebApplication.url}}, `
MultiSubnetFailover, `
AvailabilityGroup, `
@{Name = "BackupSizeRequiredGB";Expression={[math]::Round(($_.DiskSizeRequired/1GB),3)}}`
| Export-CSV $Output -NoTypeInformation

