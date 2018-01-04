<#
.SYNOPSIS
 Returns a Microsoft Graph Reporting API report for an Office365 Tenant 
 
.DESCRIPTION
 Using an native App registered in Azure AD and an authorized Office 365 admin this script calls the Microsoft Graph Reporting API
 and returns the desired report type as a system.array object. The types of reports available are documented at https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/report

.EXAMPLE
.\Get-Office365Report.ps1 `
    -TenantName "Contoso" `
    -ClientID df4d5697-2465-49e3-90b1-d029e609e335" `
    -RedirectURI "urn:foo" ` `
    -WorkLoad Tenant `
    -ReportType getOffice365ActivationCounts `
    -Period D180 `
    -Date 2017-12-25 `
    -Verbose

.EXAMPLE
.\Get-Office365Report.ps1 `
    -TenantName "Contoso" `
    -ClientID "47fff52d-5a35-46bd-a70f-d135d5e4641f" `
    -ClientSecret "nPoQa4rgd4FHMu5qoTge5QuXKz3KAiNwwersoXLRkWKk=" `
    -WorkLoad SharePoint `
    -ReportType getSharePointSiteUsageDetail  `
    -Period D180 `
    -Date 2017-12-25 `
    -Verbose

.PARAMETER TenantName
Tenant name in the format contoso.onmicrosoft.com

.PARAMETER ClientID
AppID for the App registered in AzureAD for the purpose of accessing the reporting API

.PARAMETER RedirectURI
ReplyURL for the App registered in AzureAD for the purpose of accessing the reporting API

.PARAMETER ClientSecret
Client key/secret when using a web app registered in AzureAD

.PARAMETER WorKload
Service in Office365 for which to provide report options. Used to provide a usable parameter set for the ReportType parameter

.PARAMETER ReportType
Report to retrieve see details at https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/report.
This script does not currently support the following script types:
getMailboxUsageUserDetail
getOffice365GroupsActivityUserDetail
getOneDriveUsageUserDetail
getSharePointSiteUsageUserDetail
getYammerGroupsActivityUserDetail

.PARAMETER Period
Time period for the report in days. Allowed values: D7,D30,D90,D180
Period is not supported for reports starting with getOffice365Activations and will be ignored

.PARAMETER Date
Specifies the day to a view of the users that performed an activity on that day. Must have a format of YYYY-MM-DD.
Only available for the last 30 days and is ignored unless view type is Detail
Date is not supported for the following report types: "getMailboxUsage*","getOffice365Activations*", "getSfbOrganizerActivity*" and will be ignored

.OUTPUTS
Returns an system.array object that is a representation of a Microsoft Graph API Report Object

.NOTES
To register the App (ClientID)
1) Login to Portal.Azure.Com
2) Navigate to "Azure Active Directory" > "App Registrations"
3) Click "New Application Registration"
4) Give your application a friendly name, Select application type "native", and enter a redirect URL i the format urn:foo and click create
5) Click on the App > Required Permissions
6) Click Add and select the "Microsoft Graph" API
7) Grant the App the "Read All Usage Reports" permission
8) Copy the Application ID and use that for ClientID parameter in this script
9) Copy the Redirect URI and use that for the RedirectURI parameter in this script

This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree:
(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded
(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and 
(iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
#>

<#
Contributors:
Zak Belmaachi - https://github.com/zakbelmaachi
Damian Wiese - https://blog.damianwiese.com


Version History:
## 4/18/2017 ##
Intial release

## 10/26/2017 ##
Updated script to use indivdiual APIs for each view as per documentation update (https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/report#changes-to-the-reports-apis).
This script does not currently support the following report types types:
getMailboxUsageUserDetail
getOffice365GroupsActivityUserDetail
getOneDriveUsageUserDetail
getSharePointSiteUsageUserDetail
getYammerGroupsActivityUserDetail

## 10/30/2017 ##
Updated script for new report names noted in documentation 10/26
OLD                                  --> NEW
getMailboxUsageUserDetail            --> getMailboxUsageDetail
getOneDriveUsageUserDetail           --> getOneDriveUsageAccountDetail
getSharePointSiteUsageUserDetail     --> getSharePointSiteUsageDetail
getYammerGroupsActivityUserDetail    --> getYammerGroupsActivityDetail
getOffice365GroupsActivityUserDetail --> getOffice365GroupsActivityDetail

## 1/2/1018 ##
1) Updated to support ADAL V3, which now requires interactive credential prompt and supports MFA
2) Removed credential parameter since we always prompt with ADAL V3

## 1/3/2018 ##
1) Added support for AzureAD web app with client secret
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    $TenantName,

    [Parameter(Mandatory=$true)]
    $ClientID,

    [Parameter(Mandatory=$true, ParameterSetName="NativeApp")]
    $RedirectURI,

    [Parameter(Mandatory=$true, ParameterSetName="WebApp")]
    $ClientSecret,
     
    [Parameter(Mandatory=$true,Position=2)]
    [ValidateSet(
    "Exchange",
    "Groups",
    "OneDrive",
    "SharePoint",
    "Skype",
    "Tenant",
    "Yammer"
    )]
    $WorkLoad,  

    [Parameter(Mandatory=$false,Position=3)]
    [ValidateSet(
    "D7",
    "D30",
    "D90",
    "D180")]
    $Period,

    [Parameter(Mandatory=$false,Position=5)]
    $Date,

    [Parameter(Mandatory=$false,Position=4)]
    [PSCredential]$Credential

)
DynamicParam {
            # Set the dynamic parameters' name
            $ParameterName = 'ReportType'
            
            # Create the dictionary 
            $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

            # Create the collection of attributes
            $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            
            # Create and set the parameters' attributes
            $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute.Mandatory = $true
            $ParameterAttribute.Position = 1

            # Add the attributes to the attributes collection
            $AttributeCollection.Add($ParameterAttribute)

            # Generate and set the ValidateSet
            If ($Workload -eq "Exchange"){$arrSet = @("EmailActivity","getEmailActivityUserDetail","getEmailActivityCounts","getEmailActivityUserCounts","getEmailAppUsageUserDetail","getEmailAppUsageAppsUserCounts","getEmailAppUsageUserCounts","getEmailAppUsageVersionsUserCounts","getMailboxUsageDetail","getMailboxUsageMailboxCounts","getMailboxUsageQuotaMailboxStatusCounts","getMailboxUsageStorage")}
            If ($Workload -eq "Groups"){$arrSet = @("getOffice365GroupsActivityDetail","getOffice365GroupsActivityCounts","getOffice365GroupsActivityGroupCounts","getOffice365GroupsActivityStorage","getOffice365GroupsActivityFileCounts")}
            If ($Workload -eq "OneDrive"){$arrSet = @("getOneDriveActivityUserDetail","getOneDriveActivityUserCounts","getOneDriveActivityFileCounts","getOneDriveUsageAccountDetail","getOneDriveUsageAccountCounts","getOneDriveUsageFileCounts","getOneDriveUsageStorage")}
            If ($Workload -eq "SharePoint"){$arrSet = @("getSharePointActivityUserDetail","getSharePointActivityFileCounts","getSharePointActivityUserCounts","getSharePointActivityPages","getSharePointSiteUsageDetail","getSharePointSiteUsageFileCounts","getSharePointSiteUsageSiteCounts","getSharePointSiteUsageStorage","getSharePointSiteUsagePages")}
            If ($Workload -eq "Skype"){$arrSet = @("getSkypeForBusinessActivityUserDetail","getSkypeForBusinessActivityCounts","getSkypeForBusinessActivityUserCounts","getSkypeForBusinessDeviceUsageUserDetail","getSkypeForBusinessDeviceUsageDistributionUserCounts","getSkypeForBusinessDeviceUsageUserCounts","getSkypeForBusinessOrganizerActivityCounts","getSkypeForBusinessOrganizerActivityUserCounts","getSkypeForBusinessOrganizerActivityMinuteCounts","getSkypeForBusinessParticipantActivityCounts","getSkypeForBusinessParticipantActivityUserCounts","getSkypeForBusinessParticipantActivityMinuteCounts","getSkypeForBusinessPeerToPeerActivityCounts","getSkypeForBusinessPeerToPeerActivityUserCounts","getSkypeForBusinessPeerToPeerActivityMinuteCounts")}
            If ($Workload -eq "Tenant"){$arrSet = @("getOffice365ActivationsUserDetail","getOffice365ActivationCounts","getOffice365ActivationsUserCounts","getOffice365ActiveUserDetail","getOffice365ActiveUserCounts","getOffice365ServicesUserCounts")}
            If ($Workload -eq "Yammer"){$arrSet = @("getYammerActivityUserDetail","getYammerActivityCounts","getYammerActivityUserCounts","getYammerDeviceUsageUserDetail","getYammerDeviceUsageDistributionUserCounts","getYammerDeviceUsageUserCounts","getYammerGroupsActivityDetail","getYammerGroupsActivityGroupCounts","getYammerGroupsActivityCounts")}
            

            #$arrSet = Get-ChildItem -Path .\ -Directory | Select-Object -ExpandProperty FullName
            $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)

            # Add the ValidateSet to the attributes collection
            $AttributeCollection.Add($ValidateSetAttribute)

            # Create and return the dynamic parameter
            $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
            $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
            return $RuntimeParameterDictionary
    }

Begin {
    # Bind the parameter to a friendly variable
    $Report = $PsBoundParameters[$ParameterName]
}

#Start the loading of the rest of the script
Process{

function Get-AuthTokenWithCreds
{
<#
.SYNOPSIS
Gets an OAuth token for use with the Microsoft Graph API using ADAL v3.17.3
 
.DESCRIPTION
Gets an OAuth token for use with the Microsoft Graph API using ADAL v3.17.3

.EXAMPLE
Get-AuthToken `
-TenantName "contoso" `
-clientId "74f0e6c8-0a8e-4a9c-9e0e-4c8223013eb9" `
-redirecturi "urn:ietf:wg:oauth:2.0:oob" `
-resourceAppIdURI "https://graph.microsoft.com"
 
.PARAMETER TentantName
Tenant name in the format

.PARAMETER clientID
The clientID or AppID of the native app created in AzureAD to grant access to the reporting API

.Parameter redirecturi
The replyURL of the native app created in AzureAD to grant access to the reporting API

.Parameter resourceAppIDURI
protocol and hostname for the endpoint you are accessing. For the Graph API enter "https://graph.microsoft.com"
 
.NOTES
Supports Azure Active Direction Authentication Library V3.17.3

#>

### Version History
# 1/2/2018 - Created to handle ADAL V3

<# RESOURCES
https://www.nuget.org/packages/Microsoft.IdentityModel.Clients.ActiveDirectory/3.17.3

#>

        param
        (
                [Parameter(Mandatory=$true)]
                $TenantName,
              
                [Parameter(Mandatory=$true)]
                $clientId,
              
                [Parameter(Mandatory=$true)]
                $redirecturi,

                [Parameter(Mandatory=$true)]
                $resourceAppIdURI
        )
        
        #Build the path for the DLLs that we need
        $libraryfolder = "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.IdentityModel.Clients.ActiveDirectory.3.17.3\lib\net45"
        $adal = "{0}\Microsoft.IdentityModel.Clients.ActiveDirectory.dll" -f $libraryfolder

        #Attempt to load the assemblies. Without these we cannot continue so we need the user to stop and take an action
        Try
            {
                [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
            }
        Catch
            {
                #ADAL NuGet Package is not installed, please open an elevated PowerSHell prompt and run the following
                Write-Warning "Unable to load ADAL assemblies"
                Write-Host "Please open an elevated PowerSHell prompt and run the following"
                Write-Host "Install-PackageProvider -Name Nuget"  -ForegroundColor Cyan
                Write-Host "Register-PackageSource -Name Nuget -Location https://www.nuget.org/api/v2 -ProviderName Nuget" -ForegroundColor Cyan
                Write-Host "Install-Package -Source Nuget -Name Microsoft.IdentityModel.Clients.ActiveDirectory -RequiredVersion 3.17.3" -ForegroundColor Cyan
            }
       
        #Build the logon URL with the tenant name
        $authority = "https://login.microsoftonline.com/$TenantName.onmicrosoft.com"
        Write-Verbose "Logon Authority: $authority"

        #Create platform parameters to prompt for user credentials each time
        $PlaformParameter = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Always"
        
        Try
            {
                #Build the auth context and get the result
                Write-Verbose "Creating AuthContext"
                $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
                $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $clientId, $redirecturi, $PlaformParameter)

            }
        Catch [System.Management.Automation.MethodInvocationException]
            {
                #The first that the the user runs this, they must open an interactive window to grant permissions to the app
                If ($error[0].Exception.Message -like "*Send an interactive authorization request for this user and resource*")
                    {
                        Write-Warning "The app has not been granted permissions by the user. Opening an interactive prompt to grant permissions"
                        $authResult = $authContext.AcquireToken($resourceAppIdURI, $clientId,$redirectUri, "Always") #Always prompt for user credentials so we don't use Windows Integrated Auth
                    }
                Else
                    {
                        Throw
                    }
            }
           
       
        #Return the authentication token
        #Note this returns the entire result object, to get just the token you will need to use $authResult.Result
        return $authResult
}

function Get-AuthTokenWithClientSecret
{
<#
.SYNOPSIS
Gets an OAuth token for use with the Microsoft Graph API using ADAL v3.17.3
 
.DESCRIPTION
Gets an OAuth token for use with the Microsoft Graph API using ADAL v3.17.3

.EXAMPLE
GetAuthTokenWithClientSecret.ps1 `
-TenantName "contoso" `
-clientId "74f0e6c8-0a8e-4a9c-9e0e-4c8223013eb9" `
-clientSecret ""
-resourceAppIdURI "https://graph.microsoft.com"
 
.PARAMETER TentantName
Tenant name in the format

.PARAMETER clientID
The clientID or AppID of the web app created in AzureAD to grant access to the reporting API

.Parameter clientsecret
The key/client secret of the web app created in AzureAD to grant access to the reporting API

.Parameter resourceAppIDURI
protocol and hostname for the endpoint you are accessing. For the Graph API enter "https://graph.microsoft.com"
 
.NOTES
Supports Azure Active Direction Authentication Library V3.17.3

#>

### Version History
# 1/3/2018 - Created to handle ADAL V3, thank you Zak Belmaachi for assistance with client secret authentication!

<# RESOURCES
https://www.nuget.org/packages/Microsoft.IdentityModel.Clients.ActiveDirectory/3.17.3
https://docs.microsoft.com/en-us/dotnet/api/microsoft.identitymodel.clients.activedirectory.authenticationcontext.acquiretokenasync?view=azure-dotnet
https://docs.microsoft.com/en-us/dotnet/api/microsoft.identitymodel.clients.activedirectory.promptbehavior?view=azure-dotnet
#>

        param
        (
                [Parameter(Mandatory=$true)]
                $TenantName,
              
                [Parameter(Mandatory=$true)]
                $clientId,
              
                [Parameter(Mandatory=$true)]
                $clientsecret,

                [Parameter(Mandatory=$true)]
                $resourceAppIdURI
        )
        
        #Build the path for the DLLs that we need
        $libraryfolder = "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.IdentityModel.Clients.ActiveDirectory.3.17.3\lib\net45"
        $adal = "{0}\Microsoft.IdentityModel.Clients.ActiveDirectory.dll" -f $libraryfolder

        #Attempt to load the assemblies. Without these we cannot continue so we need the user to stop and take an action
        Try
            {
                [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
            }
        Catch
            {
                #ADAL NuGet Package is not installed, please open an elevated PowerShell prompt and run the following
                Write-Warning "Unable to load ADAL assemblies"
                Write-Host "Please open an elevated PowerSHell prompt and run the following"
                Write-Host "Install-PackageProvider -Name Nuget"  -ForegroundColor Cyan
                Write-Host "Register-PackageSource -Name Nuget -Location https://www.nuget.org/api/v2 -ProviderName Nuget" -ForegroundColor Cyan
                Write-Host "Install-Package -Source Nuget -Name Microsoft.IdentityModel.Clients.ActiveDirectory -RequiredVersion 3.17.3" -ForegroundColor Cyan
            }
       
        #Build the logon URL with the tenant name
        $authority = "https://login.microsoftonline.com/$TenantName.onmicrosoft.com"
        Write-Verbose "Logon Authority: $authority"


        #Build the auth context and get the result
        Write-Verbose "Creating AuthContext"
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
        Write-Verbose "Creating AD UserCredential Object"
        $clientCredential = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential" -ArgumentList $clientId, $clientSecret

        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $clientCredential)

        #Return the authentication token
        #Note this returns the entire result object, to get just the token you will need to use $authResult.Result
        return $authResult
}


    #Getting the authorization token
    #If the user provides a redirectURL then assume native app
    if ($RedirectURI)
    {
        $token = (Get-AuthTokenWithCreds -TenantName $TenantName -clientId $ClientID -redirecturi $RedirectURI -resourceAppIdURI "https://graph.microsoft.com").result
    }
    elseif ($ClientSecret) #if the user provides a clientsecret then assume a web app
    {
        $token = (Get-AuthTokenWithClientSecret -TenantName $TenantName -clientId $ClientID -clientsecret $ClientSecret -resourceAppIdURI "https://graph.microsoft.com").result
    }
 
    #Build REST API header with authorization token
    $authHeader = @{
       'Content-Type'='application\json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    #Build Parameter String

    #If period is specified then add that to the parameters unless it is not supported
    if($period -and $Report -notlike "*Office365Activation*")
        {
            $str = "period='{0}'," -f $Period
            $parameterset += $str
        }
    
    #If the date is specified then add that to the parameters unless it is not supported
    if($date -and !($report -eq "MailboxUsage" -or $report -notlike "*Office365Activation*" -or $report -notlike "*getSkypeForBusinessOrganizerActivity*"))
        {
            $str = "date='{0}'" -f $Date
            $parameterset += $str
        }
    #Trim a trailing comma off the ParameterSet if needed
    if($parameterset)
        {
            $parameterset = $parameterset.TrimEnd(",")
        }
    Write-Verbose "Parameter set is: $parameterset"

    #Build the request URL and invoke
    #$uri = "https://graph.microsoft.com/v1.0/reports/{0}({1})/content" -f $report, $parameterset
    $uri = "https://graph.microsoft.com/v1.0/reports/{0}({1})/" -f $report, $parameterset
    Write-Host $uri
    Write-Host "Retrieving Report $report, please wait" -ForegroundColor Green
    $result = Invoke-RestMethod -Uri $uri –Headers $authHeader –Method Get
    
    #Convert the stream result to an array
    $resultarray = ConvertFrom-Csv -InputObject $result

}

End{
    Return $resultarray
   }

