<#
.SYNOPSIS
 Performs pre-installation check of a SQL server for a SharePoint 2013/2016 farm
 
.DESCRIPTION
 Validates that the following:
 1) TCP connectivity to SQL using Test-NetConnection
 2) SQL connection using System.Data.SqlClient.SqlConnection
 3) The setup account has the proper roles (dbcreator & securityadmin) or (sysadmin)
 4) MAXDOP is configured to 1
 5) Number of tempDB data files (if less than 8 cores, then a 1:1 mapping, if more than 8 cores then between 8-10 data files)

.EXAMPLE
 .\Test-SQLPrerequisites.ps1 -SQLServer SQL -SetupAccount "Contoso\SPSetup" -SQLServerTCPPort 1999
 
.PARAMETER SQLServer
The SQL Server name, listener or alias that SharePoint will use

.PARAMETER SetupAccount
The setup/installer account for SharePoint

.PARAMETER SQLServerTCPPort
Custom port for SQL (if used). If not specified defaults to 1433
 
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
################# REVISION HISTORY #######################
11/14/2017
    Script created
1/16/2017
    Fixed Sysadmin check
    Updated TempDB check to allow for multiple CPU sockets
    Updated MAXDOP check to only prompt the user to update SQL show advanced options when requird
#>

#Script parameters
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SQLServer,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $SetupAccount,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $SQLServerTCPPort = 1433,

    [switch] $ConnectivityTestsOnly

)

#####################################
#         Helper functions          #
#####################################
#region HelperFunction

#Function to test SQL Server role membership
Function Test-SQLServerRoles
{
<#
.SYNOPSIS
 Checks to see if the given account has the proper permissions in SQL to install a SharePoint farm
 
.DESCRIPTION
 Verifies that the given account has either sysadmin rights or dbcreator AND securityadmin

.EXAMPLE
 Test-SQLServerRoles -SQLServer SQL -SetupAccount "Contoso\SPSetup"
 
.PARAMETER SQLServer
The SQL Server name or alias to be used by SharePoint

.PARAMETER SetupAccount
SharePoint Setup/Install account
#>
    
    Param
    (
        $SQLServer,
        $SetupAccount
    )
    
    #$SQLServer = "SQL" #use Server\Instance for named instances
    $SQLDBName = "Master"
    $SqlQuery = "Exec sp_HelpSrvRoleMember"
    #$SetupAccount = "Contoso\SPSetup"

    #Create SQL Connection and Open 
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $SQLServer; Database = $SQLDBName; Integrated Security = True"
    $SqlConnection.Open()

    #Build SQL Command 
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $SqlQuery
    $SqlCmd.Connection = $SqlConnection

    #Create table for SQL query results
    $table = new-object “System.Data.DataTable”
    $table.Load($SqlCmd.ExecuteReader())
    $serverRoles = $table | ?{$_.MemberName -eq $SetupAccount} | Select ServerRole

    #Close SQL Connection
    $SqlConnection.Close()

    #Evaluate the server roles
    $hasRequiredRoles = $false
    if ($serverRoles)
        {
            $hasRequiredRoles = $false
            $hasDBCreator = $serverroles.serverrole.Contains("dbcreator")
            $hasSecurityAdmin = $serverroles.serverrole.Contains("securityadmin")
            $hasSysAdmin = $serverroles.serverrole.Contains("sysadmin")
        }


    if (($hasDBCreator -and $hasSecurityAdmin) -or $hasSysAdmin)
        {
            $hasRequiredRoles = $true
        }
        else
        {
            $hasRequiredRoles = $false
            if (!$hasDBCreator){Write-Error "DBCreatorRole Not Assigned"}
            if (!$hasSecurityAdmin){Write-Error "SecurityAdmin Role Not Assigned"}
        }

        Return $hasRequiredRoles
}

#Test SQL Connection
Function Test-SQLConnection
{
<#
.SYNOPSIS
 Verifies that the current user can connect to SQL Server
 
.DESCRIPTION
 Verifies that the current user can connect to SQL Server

.EXAMPLE
 Test-SQLConnection -SQLServer SQL
 
.PARAMETER SQLServer
The SQL Server name or alias to be used by SharePoint
#>
    Param
    (
        $SQLServer
    )
    
    $SQLDBName = "Master"

    #Create SQL Connection and Open 
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $SQLServer; Database = $SQLDBName; Integrated Security = True"
    $SqlConnection.Open()

    #Set SQL Connection Status
    $SQLConnectionSuccessful = $false
    if($SQLConnection.State -eq "Open"){$SQLConnectionSuccessful = $true}
    
    #Close SQL Connection
    $SqlConnection.Close()

    Return $SQLConnectionSuccessful
}

#Test Advanced Options
Function Test-SQLAdvancedOptionsEnabled
{
<#
.SYNOPSIS
 Verifies that that the SQL Server Show Advnaced Options is enabled
 
.DESCRIPTION
 Verifies that that the SQL Server Show Advnaced Options is enabled. Returns TRUE if 'show advanced options' is set to 1.
 Returns FALSE for any other value

.EXAMPLE
 Test-SQLAdvancedOptionsEnabled -SQLServer SQL
 
.PARAMETER SQLServer
The SQL Server name or alias to be used by SharePoint
#>
Param
(
    $SQLServer
)
    ## Check to see if 'show advaced options' is enabled ##
    $SQLDBName = "Master"
    $SqlQuery = "EXEC sp_configure @configname='show advanced option'"

    #Create SQL Connection and Open 
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $SQLServer; Database = $SQLDBName; Integrated Security = True"
    $SqlConnection.Open()

    #Build SQL Command 
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $SqlQuery
    $SqlCmd.Connection = $SqlConnection

    #Create table for SQL query results
    $advancedOptions = new-object “System.Data.DataTable”
    $advancedOptions.Load($SqlCmd.ExecuteReader())

    #Close SQL Connection
    $SqlConnection.Close()

    $advancedOptionsEnabled = $false
    if ($advancedOptions.config_value -eq 1) {$advancedOptionsEnabled  = $true}

    return $advancedOptionsEnabled

}

#Test Advanced Options
Function Enable-SQLAdvancedOptions
{
<#
.SYNOPSIS
 Enable SQL 'show advanecd options'
 
.DESCRIPTION
 Enables the SQL Server Show Advnaced Option. Returns TRUE if 'show advanced options' is set to 1.
 Returns FALSE for any other value

.EXAMPLE
 Enable-SQLAdvancedOptions -SQLServer SQL
 
.PARAMETER SQLServer
The SQL Server name or alias to be used by SharePoint
#>
Param
(
    $SQLServer
)
    ## Check to see if 'show advaced options' is enabled ##
    $SQLDBName = "Master"
    $SqlQuery = "EXEC sp_configure 'show advanced option', '1'; RECONFIGURE;"

    #Create SQL Connection and Open 
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $SQLServer; Database = $SQLDBName; Integrated Security = True"
    $SqlConnection.Open()

    #Build SQL Command 
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $SqlQuery
    $SqlCmd.Connection = $SqlConnection

    #Create table for SQL query results
    $advancedOptions = new-object “System.Data.DataTable”
    $advancedOptions.Load($SqlCmd.ExecuteReader())

    #Close SQL Connection
    $SqlConnection.Close()

    Return Test-MaxDOP -SQLServer SQL
}

#Test MaxDOP
Function Test-MaxDOP
{
<#
.SYNOPSIS
 Verifies that that the SQL Server Setting 'max degree of parallelism' is set properly for SharePoint 
 
.DESCRIPTION
 Verifies that that the SQL Server Setting 'max degree of parallelism' is set properly for SharePoint. Returns TRUE if MAXDOP is set to one.
 Returns FALSE for any other falue

.EXAMPLE
 Test-MaxDOP -SQLServer SQL
 
.PARAMETER SQLServer
The SQL Server name or alias to be used by SharePoint
#>
Param
(
    $SQLServer
)

    $SQLDBName = "Master"
    $SqlQuery = "EXEC sp_configure 'show advanced option', '1'; RECONFIGURE; EXEC sp_configure @configname='max degree of parallelism'"

    #Create SQL Connection and Open 
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $SQLServer; Database = $SQLDBName; Integrated Security = True"
    $SqlConnection.Open()

    #Build SQL Command 
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $SqlQuery
    $SqlCmd.Connection = $SqlConnection

    #Create table for SQL query results
    $maxDOP = new-object “System.Data.DataTable”
    $MaxDOP.Load($SqlCmd.ExecuteReader())
    
    #Close SQL Connection
    $SqlConnection.Close()

    $maxDOPcorrect = $false
    if ($MaxDOP.config_value -eq 1) {$maxDOPcorrect = $true}

    Return $maxDOPcorrect
}

#Test the number of TempDB data files against the number of procesor cores
Function Test-TempDBFileCount
{
<#
.SYNOPSIS
 Compares the number of TempDB data files against the number of processor cores 
 
.DESCRIPTION
 When there is less than 8 processor cores returns TRUE if the number of data files and core are equal
 When there is 8 or more data files returns TRUE if there are less than 10 data files
 Returns FALSE in all other scenarios, including when WMI cannot be access to retrieve processor core count

.EXAMPLE
 Test-MaxDOP -SQLServer SQL
 
.PARAMETER SQLServer
The SQL Server name or alias to be used by SharePoint
#>
Param
(
    $SQLServer
)
    $SQLDBName = "Master"
    $SqlQuery = "SELECT count(distinct physical_name) AS TempDBFileCount FROM sys.master_files WHERE database_id = DB_ID(N'tempdb') and type_desc = 'rows'"

    #Create SQL Connection and Open 
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $SQLServer; Database = $SQLDBName; Integrated Security = True"
    $SqlConnection.Open()

    #Build SQL Command 
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $SqlQuery
    $SqlCmd.Connection = $SqlConnection

    #Create table for SQL query results
    $TempDBFileCount = new-object “System.Data.DataTable”
    $TempDBFileCount.Load($SqlCmd.ExecuteReader())
    $TempDBFileCount = $TempDBFileCount.Rows[0].TempDBFileCount

     
    #Close SQL Connection
    $SqlConnection.Close()

    #Get the number of processor cores
    # If unable to connect via WMI, report the number of TempDB data files, return false and exit the function
    try
    {
        #This line only works only for a single socket: $numberOfCores = (Get-WmiObject Win32_Processor -ComputerName $SQLServer -Property NumberOfCores -ErrorAction Stop).NumberOfCores
        
        # Hyper VM usually returns just a single socket with N number of cores. Other hypervisors may return
        # multiple sockets each with N number of cores. To work with this we loop through an array of WMI Win32_Processor objects
        $numberOfCores = 0
        $procs = Get-WmiObject Win32_Processor -ComputerName $SQLServer -Property NumberOfCores -ErrorAction Stop
        ForEach ($proc in $procs)
            {
                $numberOfCores += $proc.numberofcores
            }
    }
    catch [System.Exception]
    {
        Write-Error "Unable to connect to $SQLServer via WMI to check number of processor cores"
        Write-Host "$TempDBFileCount TempDB data files found" -ForegroundColor Yellow
        return $false
    }

    # Compare the number of data files for TempDB and number of processor cores
    # If less than 8 processor cores, then there should be a 1:1 mapping
    # If there is more than 8 processor cores there shoujld be at least 8 tempDB data files

    if ($numberOfCores -lt 8 -and ($numberOfCores -eq $TempDBFileCount))
        {
            Return $true
        }
    if ($numberOfCores -ge 8 -and $TempDBFileCount -le 10)
        {
            Return $true
        }
    else
        {
            Return $false
        }
}

#endregion

#####################################
#               Main                #
#####################################
#Validate TCP connectivity
Write-Output "Testing TCP Connectivity"
If ((Test-NetConnection -ComputerName $SQLServer -Port $SQLServerTCPPort).TcpTestSucceeded)
    {
        Write-Host "Connection to $SQLServer on port $SQLServerTCPPort Successful" -ForegroundColor Green
    }
else
    {
        Write-Warning "Connection to $SQLServer on port $SQLServerTCPPort failed"
    }

#Validate SQL Connection
Write-Output "Testing SQL Connectivity"
if (Test-SQLConnection -SQLServer $SQLServer)
    {
        Write-Host "Connection to $SQLServer successful" -ForegroundColor Green
    }
else
    {
        Write-Warning "Connection to $SQLServer failed"
    }

#Only perform the remaining tests when ConnectivityTestOnly is false
If (!$ConnectivityTestsOnly)
{
    If ($SetupAccount)
        {
            #Validate SQL Server Roles
            Write-Output "Checking for DBCreator and SecurityAdmin roles"
            if (Test-SQLServerRoles -SQLServer $SQLServer -SetupAccount $SetupAccount)
                {
                    Write-Host "Account $SetupAccount has the proper permmissions" -ForegroundColor Green
                }
            else
                {
                    Write-Warning "The correct SQL Server roles have not been assigned"
                }
        }
    else
        {
            Write-Warning "SPSetupAccount not specified, skipping role check"
        }

    #Validate Max degree of parallelism
    Write-Output "Checking MAXDOP Setting"
    
    #'Show advanced options' is required to check MAXOP. Check to see if this is enabled
    # if it is not enable, prompt the user to enable it
    Write-Verbose "Checking to see if 'show advanced options' is enabled"
    $sqlAdvancedOptionsEnabled = Test-SQLAdvancedOptionsEnabled -SQLServer SQL
    if(!$sqlAdvancedOptionsEnabled)
    {
        Write-Warning "Checking MAXDOP setting requires that 'show advanced option' be enabled. Would you like to enable this now? (Y/N)"
        if((read-Host) -eq "y")
        {
            $sqlAdvancedOptionsEnabled = Enable-SQLAdvancedOptions -SQLServer $SQLServer
            if (!$sqlAdvancedOptionsEnabled)
            {
                Write-Warning "Unable to enable SQL advanced options, skipping MAXDOP check"
            }
        }
    }

    #if sqlAdvancedOptionsEnable is true then we can test for MaxDOP
    if ($sqlAdvancedOptionsEnabled)
    {

        if (Test-MaxDOP -SQLServer $SQLServer)
            {
                Write-Host "MaxDOP is configured correctly" -ForegroundColor Green
            }
        else
            {
                Write-Warning "MAXDOP is not configured correctly"
            }
    }
    else
        {
            Write-Output "Skipping MAXDOP check"
        }
           

    #Validate TempDB File Count
    Write-Output "Checking TempDB File count"
    If (Test-TempDBFileCount -SQLServer $SQLServer)
        {
            Write-Host "TempDB has the correct number of data files" -ForegroundColor Green
        }
    else
        {
            Write-Warning "TempDB does not have the right number of data files configured"
        }
}

