<#
.SYNOPSIS
 Iterates all SharePoint document libraries for files with the extensions provided.
 
.DESCRIPTION
 Output is a CSV that contains the full SPList URL and the number of items found

.EXAMPLE
 Get-xSPFIleTypeReport.ps1 -extensions "docx", "pptx" -OutputFolder C:\Temp -ScanFullFarm

.EXAMPLE
 Get-xSPFIleTypeReport.ps1 -extensions "docx" -OutputFolder C:\Temp -WebApplicationURL https://hhroot.contoso.co/

.EXAMPLE
 Get-xSPFIleTypeReport.ps1 -extensions "docx" -OutputFolder C:\Temp -SPSiteURL https://sharepoint.contoso.co/sites/intranet

 
.PARAMETER ScanFullFarm
Specific -ScanFullFarm to scan the entire farm

.PARAMETER WebApplicationURL
To scan a single web application, provide a full SPWebApplicationURL

.PARAMETER SPSiteURL
To scan a single site provide a full SPSite URL

.PARAMETER Extensions
An array of extensions to scan for in the format "docx" or "docx", "xlsx"

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
    [Parameter(Mandatory = $false, ParameterSetName='FarmScoped')]
    [switch] $ScanFullFarm,
    
    [CmdletBinding()]
    [Parameter(Mandatory = $false, ParameterSetName='WebApppScoped')]
    [ValidateNotNullOrEmpty()]
    [string] $WebApplicationURL,

    [Parameter(Mandatory = $false, ParameterSetName='SPSiteScoped')]
    [ValidateNotNullOrEmpty()]
    [string] $SPSiteURL,

    [ValidateNotNullOrEmpty()]
    [array] $Extensions,
    
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

#Convert array of extentions into lowercase
Write-Verbose "Convering extensions to lowercase"
$filetypes = @()
ForEach ($i in $extensions)
    {
        $filetypes += $i.ToLower()
    }
$extensions = $filetypes

#Create output file name
$timestamp = (Get-Date -Format yymmdd_hhmmss)
ForEach ($e in $extensions) { $ext += $e+"_" }
$output = "{0}SPFileTypeReport_{1}_{2}.csv" -f $OutputFolder, $ext, $timestamp
Write-Verbose "Output will be written to $output"

#Create output file and populate with CSV headers
Add-Content -Value "ListURL, NumberOfMatchingItems" -Path $output

#If the WebApplicationURL is specified, get the single web app
if ($WebApplicationURL)
    {
        $spwebapp = Get-SPWebApplication -Identity $WebApplicationURL
        Write-Verbose "WebApplicationURL parameter used, found web application $($wa.url)"
    }

#Get site collections for the targeted scope
if ($SPSiteURL)
    {
        $SPSite = Get-SPSite -Identity $SPSiteURL
        Write-Verbose "SPSiteURL parameter used, found site $($spsite.url)"
    }
    elseif ($spwebapp)
    {
        Write-Verbose "Getting all site collections in web application $($spwebapp.url)"
        $SPSite = Get-SPSite -WebApplication $spwebapp -Limit all
    }
    else
    {
        Write-Verbose "Getting all site collections in farm"
        $SPSite = Get-SPSite -limit all
    }
Write-Verbose "Found $($SPSIte.count) site collections"
#Iterate through the sites(s) and check individual list items
$sitecounter = 0
ForEach ($site in $SPSite)
    {
        $starttime = Get-Date
        $sitecounter ++
        Write-Progress -Activity "Scanning site collections" -PercentComplete $(($sitecounter/$($SPSite.count))*100) -Id 1
        Write-Verbose "Scanning site $($site.url)"
        $webs = Get-SPWeb -Site $site -Limit all
        $webcounter = 0
        ForEach ($web in $webs)
            {
                
                $webcounter ++
                Write-Progress -Activity "Scanning sub sites in site $($site.url)" -PercentComplete $(($webcounter/$($webs.count))*100) -id 2 -ParentId 1
                $lists = $web.lists | ?{$_.basetype -eq "DocumentLibrary"}
                
                $listcounter = 0
                ForEach ($list in $lists)
                    {
                        $listcounter ++
                        Write-Progress -Activity "Scanning document libraries in SPWeb $($web.url)" -PercentComplete $(($listcounter/$($lists.count))*100) -id 3 -ParentId 2
                        $founditemcount = 0
                        $listurl = "{0}/{1}" -f $web.Url, $list.Title
                        $items = $list.Items | Select URL
                        ForEach ($item in $items)
                            {
                                if($extensions.Contains($item.url.Split(".")[-1].tolower()))
                                    {
                                        $founditemcount ++
                                    }
                            }
                            if ($founditemcount -gt 0)
                            {
                                #$message = "List {0} contains {1} items that match the criteria" -f $listurl, $founditemcount
                                Add-Content -Value "$listurl, $founditemcount" -Path $Output
                            }
            
                    }
        $web.dispose()
        
    }
    $site.dispose()
    $endtime = Get-Date
    $duration = $endtime - $starttime
    Write-Output "Site collection $($site.url) scan completed in $($duration.Hours):$($duration.Minutes):$($duration.Seconds):$($duration.Milliseconds)"
   
    }
        

