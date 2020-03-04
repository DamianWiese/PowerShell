<#
.SYNOPSIS
 Checks in all files in a specified siet collection
 
.DESCRIPTION
 Checks in all files in a specified siet collection

.EXAMPLE
 .\CheckInAllFilesForSiteCollection.ps1 -siteurl "http://sp2016/sites/CheckoutDemo" -message "File checked in for migration prep"
 
.PARAMETER siteurl
The url of the site collection where you want all files checked in

.PARAMETER message
The message you want to show in version history for why the file was checked in
 
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
v0.9 March 4, 2020

## CONTRIBUTORS ##
Damian Wiese - dawiese@microsoft.com
#>

Param (
$siteurl,
$message
)

####################
### Script Start ###
####################


Add-PSSnapin Microsoft.SharePoint.Powershell
$webs = (Get-SPSite -Identity $siteurl).allwebs
ForEach ($web in $webs)
{
    Checkin-AllWebFiles -SPWebUrl $web.url -CheckInMessage $message
}

### Find all document libraries for a given SPWeb and exclude system lists
Function Checkin-AllWebFiles
{
Param (
$SPWebUrl,
$CheckInMessage = "Checked in by Admin for Migration Prep"
)
Write-Host "Looking up web $SPWebUrl"
$web = Get-SPWeb $SPWebUrl
Write-Host "Found SPWeb $($web.url)"

$docLibs = $web.GetListsOfType("DocumentLibrary") | ?{$_.title -ne "Master Page Gallery" -and $_.title -ne "Site Assets" -and $_.title -ne "site pages"}
Write-Host "Found $($docLibs.Count) document libraries"
ForEach ($library in $docLibs)
{
    Write-Host "Processing Library $($library.Title)"
    $checkedOutItems = $library.Items | ?{$_.file.checkoutstatus -ne "None"}
    Write-Host "Found $($checkedOutItems.Count) checked out items"
        
    ForEach ($item in $checkedOutItems)
    {
        Write-Host "File $($item.file.Url) is checked out to $($item.file.checkedoutbyuser.displayname)"
        Write-Host "Checking in File $($item.file.Url)"
        $item.file.CheckIn($CheckInMessage)
    }
}
}

