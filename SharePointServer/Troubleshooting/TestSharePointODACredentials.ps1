<#
.SYNOPSIS
 Validates the credential stored in Credential Manager for an On-Demand Assessment for SharePoint Server
 
.DESCRIPTION
 Validates the credential stored in Credential Manager for an On-Demand Assessment for SharePoint Server. Optionally you can initiate a remote Powershell session to the target SharePoint server

.EXAMPLE
 .\TestSharePointODACredentials.ps1 -TargetServerFQDN SP2019.contoso.com -DisplayPassword -TestConnection -Verbose

 .EXAMPLE
 .\TestSharePointODACredentials.ps1 -TargetServerFQDN SP2019.contoso.com -TestConnection -Verbose

 .EXAMPLE
 .\TestSharePointODACredentials.ps1 -TargetServerFQDN SP2019.contoso.com -DisplayPassword -TestConnection -Verbose
 
.PARAMETER TargetServerFQDN
The fully qualified domain name of the SharePoint server that has been configured as the data collection target

.PARAMETER DisplayPassword
Will display the password in plaintext, use with care

.PARAMETER TestConnection
Test a remote Powershell connection to the SharePoint server that has been configured as the data collection target using the stored credential. Requires TargetServerFQDN

.PARAMETER ApplicationName
The identifier for the credential in Credential Manager. In the GUI it is labeled as "Internet or network address"
 
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
6/12/2020 - Version 0.9

## CONTRIBUTORS ##
Damian Wiese - dawiese@microsoft.com
#>

#Requires -Module @{ModuleName="CredentialManager";ModuleVersion="2.0"}
# To install credential manager, from an elevated Powershell Window please run:
# Install-Module -Name CredentialManager

#region parameters
#Script parameters
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $TargetServerFQDN,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [switch] $DisplayPassword,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [switch] $TestConnection,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $ApplicationName = "Microsoft Assessment:SharePoint"
)
#endregion parameters

#region script 

#Get Credential from credential manager
$cred = Get-StoredCredential -Target $applicationName

#display user name
if ($cred)
{
    Write-Host "Credential found for application $("$applicationName")" -ForegroundColor Green
    Write-Host "UserName: $($cred.UserName)"
    if ($DisplayPassword)
    {
        $password = (new-object System.Net.NetworkCredential($cred.UserName, $cred.Password)).Password
        write-host "Password: $password"
    }
}elseif (!$cred)
{
    Write-Warning "Credential not found for application $("$applicationName")"
} 

#Print password to screen, not necessary, but useful if you want to doublecheck
#$username = $cred.UserName
$password = (new-object System.Net.NetworkCredential($cred.UserName, $cred.Password)).Password  

#Create PS Session using stored credential and test retrieving SharePoint information
If($TestConnection -and $cred)
{
    Write-Verbose "Creating remote PowerShell session with $($TargetServerFQDN)"
    $s = New-PSSession -ComputerName $TargetServerFQDN -Authentication CredSSP -Credential $cred

    Write-Verbose "Adding SharePoint snapin"
    Invoke-Command -Session $s -ScriptBlock { add-pssnapin Microsoft.SharePoint.PowerShell -ea 0 }
    Write-Verbose "Getting farm information"
    Invoke-Command -Session $s -ScriptBlock { get-spfarm | Format-Table DisplayName, BuildVersion -AutoSize}
    Write-Verbose "Getting content database information"
    Invoke-Command -Session $s -ScriptBlock { Get-SPContentDatabase | Format-Table Name, Server, Webapplication -AutoSize}

    #remove session
    Write-Verbose "Removing PSSession"
    $s | Remove-PSSession 
}
#endregion script