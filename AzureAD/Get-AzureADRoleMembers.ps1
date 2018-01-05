<#
.SYNOPSIS
 Gets a list of all AzureAD Administrator roles and the members of those roles
 
.DESCRIPTION
 Gets a list of all AzureAD Administrator roles and the members of those roles

.EXAMPLE
 .\Get-AzureADRoleMembers.ps1 | Out-GridView
 
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
1/4/2018 - Script created

## CONTRIBUTORS ##
Damian Wiese - dawiese@microsoft.com
#>

#Script parameters
[CmdletBinding()]
param
(
)

###### FUNCTIONS #####
Function Test-AzureADModule 
{
    Write-Verbose "Checking for Azure AD Module"
    if(!(Get-Command Connect-AzureAD -ErrorAction SilentlyContinue))
    {
        Write-Verbose "Azure AD module not installed, prompting user for installation"
        Write-Warning "AzureAD Module is not installed"
        Write-Host "To install for all users run the following from an elevated PowerShell window: Install-Module AzureAD"
        Write-Host "Would you like to install the AzureAD Module for the current user? (Y/N)"
        $response = (Read-Host).ToUpper()
        if($response -eq "Y")
        {
            Install-Module AzureAD -Scope CurrentUser
            Write-Host "Azure AD Module Installed"
            return $true
        }
        else
        {
            Write-Host "AzureAd Module is not installed, terminating"
            return $false
        }


    }
    elseif(Get-Command Connect-AzureAD -ErrorAction SilentlyContinue)
        {
            Write-Verbose "AzureAD module already installed"
            return $true
        }
}

###### MAIN SCRIPT #####

#Test for AzureAD Module
if(!(Test-AzureADModule)){exit}

#Connect to AzureAD
$connection = Connect-AzureAD
if(!($connection))
{
    Write-Warning "Connection to AzureAD failed, terminating"
    exit
}

$rolemembers = @()
ForEach ($role in Get-AzureADDirectoryRole)
{
    ForEach ($member in (Get-AzureADDirectoryRoleMember -ObjectId $role.ObjectID))
    {
        $rolemembers += New-Object PSObject -Property @{
            Role = $role.displayname
            DisplayName = $member.displayname
            UserPrincipalName = $member.UserPrincipalName
        }
        
    }
}

return $rolemembers

