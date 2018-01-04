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
