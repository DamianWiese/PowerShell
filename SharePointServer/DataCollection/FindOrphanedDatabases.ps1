<# 
This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree:
(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded
(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and 
(iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
#>

Add-PSSnapin Microsoft.SharePoint.PowerShell

#################################################
#################################################
################### FUNCTIONS ###################
#################################################
#################################################

##############################
# Check if user has sysadmin #
##############################
Function Test-CurrentUserHasSysAdmin
{
#$SQLServer = "SQL" #use Server\Instance for named instances
    $SQLDBName = "Master"
    $SqlQuery = "Exec sp_HelpSrvRoleMember"
    $CurrentUser = whoami
   
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
    $serverRoles = $table | ?{$_.MemberName -eq $CurrentUser} | Select ServerRole

    #Close SQL Connection
    $SqlConnection.Close()

    Return $serverroles.serverrole.Contains("sysadmin")

}

##########################################
# Get list of databases from each SQL    #
# Server and compile into a single array #
# that includes server name              #
##########################################
Function Get-DatabasesFromInstance
{
    Param(
        $SQLServer
        )

    $SQLDBName = "Master"
    $SqlQuery = "Select name from sys.databases"
    
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
    $databases = $table | Select name, @{L='SQLServer';E={$SQLServer}}

    #Close SQL Connection
    $SqlConnection.Close()

    Return $databases
}


#################################################
#################################################
#################### Script #####################
#################################################
#################################################

#Get list of all DB Servers that SharePoint knows about
$SQLServers = Get-SPServer | ?{$_.ServiceInstances.TypeName -eq "Microsoft SharePoint Foundation Database"} | Select Address

#Compile list of all databases from the SQL Servers into single array
$allDatabases = ForEach ($SQLServer in $SQLServers)
{
    Get-DatabasesFromInstance -SQLServer $SQLServer.Address
}

#Compile list of all database referenecs that SharePoint has
$sharePointDBs = Get-SPDatabase

#initialize output
$orphans = @()

$result = $false
#Compare SharePoint's list to the SQL instances
ForEach ($spdb in $sharePointDBs)
{
    $db = $allDatabases | ?{$_.name -eq $spdb.Name}
    if($db)
    {
        #test if DB exists with the same name
        $result = ($spdb.Name) -eq ($db.name | Select -First 1)
        
        #test if DB exists with the same server name
        $result = $db.sqlserver.Contains($spdb.NormalizedDataSource)
        #$result = $db.sqlserver.Contains($spdb.Server.name.split("=")[-1]) #some databases store name as 'Name=SP2016SQL' so we split the string to make it easier to match
        
        #Write results to screen and array for output to CSV at end
        If($result)
        {
            Write-Host "Database $($spdb.name) found on $($spdb.Server)" -ForegroundColor Green
        }
        elseif(!$result)
        {
            Write-Host "Database $($spdb.name) not found on $($spdb.Server)" -ForegroundColor Red
            $orphans += $spdb.Name
            
        }

    }
    elseif(!$db)
    {
        Write-Host "Database $($spdb.name) not found on $($spdb.Server)" -ForegroundColor Red
        $orphans += $spdb.Name
        
    }
}

$orphans
