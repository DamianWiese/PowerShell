<#
.SYNOPSIS
 Collects information about the Managed Metadata Service Applicatoin to compare against support boundaries
 
.DESCRIPTION
 Collects information about the Managed Metadata Service Applicatoin to compare against support boundaries. Currently checks:
 1) Total number of items in a term store
 2) Total number of term sets in a term store
 3) Total number of terms in a term set

 Note: Site Collection scoped term sets are excluded from this check

.EXAMPLE
 .\Get-xMMDSupportBoundaryReport.ps1 -OutputFolder C:\temp\

 .EXAMPLE
 .\Get-xMMDSupportBoundaryReport.ps1 | Out-GridView
 
.PARAMETER OutputFolder
The director for where to store the report, in the format C:\temp. If this parameter is not specified this cmdlet will return an array with the results

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
### Version History #####
12/28/2017 - Support for checking Total number of items in a term store, Total number of term sets in a term store, Total number of terms in a term set

#>

#Script parameters
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputFolder
)

#Load SharePoint Snapin
Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

#Set Boundary Variables (https://technet.microsoft.com/library/mt493258(v=office.16).aspx#termstore)
$maxTermSets = 1000
$maxTermsInSet = 30000
$maxItemsInStore = 1000000

#Fixup output folder format
if($outputfolder -and !$OutputFolder.EndsWith("\"))
{
    $OutputFolder = $OutputFolder+"\"
}

#Get reference to Central Administration Site Collection
$ca = (Get-SPWebApplication -IncludeCentralAdministration | ? { $_.IsAdministrationWebApplication -eq $true}).Sites[0]

#Generate MMD session using Central Admin Site Collection
$mmdSession = Get-SPTaxonomySession -Site $ca

#Initialize output variable
$output = @()

Write-Host "$($mmdSession.termstores.count) term stores identified" -ForegroundColor Cyan
ForEach ($termstore in $mmdSession.TermStores)
{
    Write-Host "Analyzing Term Store $($termstore.name)" -ForegroundColor Cyan
    $numtermsets = 0
    $numItemsInStore = 0

    ForEach ($group in $termstore.Groups)
    {
        IF(!$group.IsSiteCollectionGroup)
        {
            ForEach ($termSet in $group.TermSets)
            {
                $output += New-Object PSObject -Property @{
                    TermStore = $termstore.name
                    TermGroup = $group.Name
                    TermSet = $termSet.Name
                    TermCount = $termSet.Terms.Count
                }
                $numtermsets ++ #Increment the counter for number of termsets in a given termstore
                $numItemsInStore += $termSet.Terms.Count #add the number of terms to the total term store items
                $numItemsInStore ++ #increment the number of items by one for each term set


                If ($termset.terms.Count -gt $maxTermsInSet)
                {
                    Write-Warning "Term set $($termSet.name) in group $($group.name) has $($termset.terms.Count) terms, which is unsupported"
                }
            }
        
        }

    }
#Report on exceeded support limits
If ($numtermsets -gt $maxTermSets)
{
    Write-Warning "Term store $($termstore.name) has $numtermsets termsets, which is unsupported"
}
if ($numItemsInStore-gt $maxItemsInStore) 
{
    Write-Warning "Term store $($termstore.name) has $numItemsInStore items, which is unsupported"
}

if ($outputfolder)
{
    $outputfilename = "$outputfolder"+"MMDReport_$($termstore.name.replace(' ',''))_$(Get-Date -Format mmddhhmmss).csv"
    $output | Export-CSV -Path $outputfilename -NoTypeInformation
    Write-Host "Report saved to $outputfilename"
}
else
{
    Return $output
}
}
