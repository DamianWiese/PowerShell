<#
.SYNOPSIS
 Lists all site collections that have an AD group as either the primary or secondary owner
 
.DESCRIPTION
 Lists all site collections that have an AD group as either the primary or secondary owner

.EXAMPLE
.\Get-xADGroupSiteOwners.ps1 -ScanWholeFarm
.\Get-xADGroupSiteOwners.ps1 -ScanWholeFarm | Export-CSV -Path C:\temp\ADSiteOwners.csv -NoTypeInformation
 
.\Get-xADGroupSiteOwners.ps1 -ContentDatabase WSS_Content 
.\Get-xADGroupSiteOwners.ps1 -ContentDatabase WSS_Content | Export-CSV -Path C:\temp\ADSiteOwners.csv -NoTypeInformation

.\Get-xADGroupSiteOwners.ps1 -WebApplication https://sp.contoso.com
.\Get-xADGroupSiteOwners.ps1 -WebApplication https://sp.contoso.com | Export-CSV -Path C:\temp\ADSiteOwners.csv -NoTypeInformation

 
.PARAMETER ContentDatabase
Scans the specified content database

.PARAMETER $WebApplication
Scans the specificed web application

.PARAMETER $ScanWholeFarm
Scans the entire farm
 
.NOTES
This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree:
(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded
(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and 
(iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.

#>

<#
## VERSION HISTORY ##
V1.0 Created 9/27/2018

## CONTRIBUTORS ##
Damian Wiese - dawiese@microsoft.com
#>

#Script parameters
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false, ParameterSetName="ContentDatabase")]
    [ValidateNotNullOrEmpty()]
    [string] $ContentDatabase,

    [Parameter(Mandatory = $false, ParameterSetName="WebApplication")]
    [ValidateNotNullOrEmpty()]
    [string] $WebApplication,

    [Parameter(Mandatory = $false, ParameterSetName="Farm")]
    [ValidateNotNullOrEmpty()]
    [switch] $ScanWholeFarm

)

#Import module of helper functions
Add-PSSnapin Microsoft.SharePoint.PowerShell

#Script code goes here
If ($ContentDatabase)
    {
        $sites = Get-SPSite -Limit All -ContentDatabase $ContentDatabase | ?{$_.Owner.UserLogin -like "c:0+.w|*" -or $_.SecondaryContact.UserLogin -like "c:0+.w|*"}
    }
ElseIF ($WebApplication)
    {
        $sites =Get-SPSite -Limit All -WebApplication $WebApplication | ?{$_.Owner.UserLogin -like "c:0+.w|*" -or $_.SecondaryContact.UserLogin -like "c:0+.w|*"}
    }
ElseIF ($ScanWholeFarm)
    {
        $sites = Get-SPSite -Limit All | ?{$_.Owner.UserLogin -like "c:0+.w|*" -or $_.SecondaryContact.UserLogin -like "c:0+.w|*"} 
    }

$output = $sites | Select URL, `
@{Expression={$_.Owner.DisplayName};;Label="PrimaryOwner"}, `
@{Expression={$_.Owner.UserLogin -like "c:0+.w|*"};Label="PrimaryOwnerIsGroup"}, `
@{Expression={$_.SecondaryContact.DisplayName};;Label="SecondaryContact"}, `
@{Expression={$_.SecondaryContact.UserLogin -like "c:0+.w|*"};Label="SecondaryContactIsGroup"}

Return $output
