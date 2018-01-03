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
