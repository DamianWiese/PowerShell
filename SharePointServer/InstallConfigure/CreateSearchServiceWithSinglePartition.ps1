<#Damian Wiese
#4/12/2015
This script will provision a SharePoint 2013 Search Service Application with a single index partition which can index up to 10M items.
#>
<#
This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree:
(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded
(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and 
(iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
#>


#### Define Variables ###
$DBServer = 'SQLSP13Config'
$SearchServiceAccount = 'Contoso\SPSearch'
$SearchAdminDatabaseName = 'SP2013SearchService'
$IndexServers = 'SP2013FE1','SP2013FE2'
$QueryServers = 'SP2013FE1','SP2013FE2' 
$ContentProcessingServers = 'SP2013FE1','SP2013FE2'
$CrawlServers = 'SP2013FE1','SP2013FE2'
$AnalyticsServers = 'SP2013FE1','SP2013FE2'
$AdminServers = 'SP2013FE1','SP2013FE2'
$SearchApplicationPool = 'SPSearch'
$SearchServiceName ="Search"
$IndexLocation = "C:\SearchIndex"


##################################
##################################
##### Create Search Service #####
##################################
##################################
#Add the SharePoint PowerSHell Module
Write-Host 'Adding the SharePoint Snapin'
Add-PSSnapin Microsoft.SharePoint.PowerShell

#Check for existing Search Service
$ExistingSSA = Get-SPEnterpriseSearchServiceApplication
If ($ExistingSSA -ne $Null)
    {
        Write-Host "A Search Service Application is already deployed to this farm, stopping script execution"
        exit
    }

#Validate Index File Location
#Test for Index path borrowed from Joe Rodgers
ForEach ($IndexServer in $IndexServers)
    {
        $driveLetter = $IndexLocation.SubString(0,1)
        $folderPath  = $IndexLocation.SubString(3)
        $uncIndexPath = "\\$IndexServer\$driveLetter`$\$folderPath"
        $TestPath = Test-Path -Path $uncIndexPath
        IF ($TestPath -ne $True)
            {
                Write-Host "The index location does not exist on at least one index server, stopping script"
                exit
            }
        $EmptyTest = Get-ChildItem -Path $uncIndexPath
        IF ($EmptyTest -ne $NULL)
            {
                Write-Host "The index location is not empty on at least one server, stopping script"
                exit
            }
        Write-Host "Index location is ready on" $IndexServer
    }
                

#Prompt user to enter Search Service Account Password
$SearchCredential = Get-Credential -UserName $SearchServiceAccount -Message 'Search Service Account'

#Check for Search Service Managed Account and if it doesn't exist, create it
$ManagedAccount = Get-SPManagedAccount | ?{$_.username -eq $SearchCredential.UserName}
If ($ManagedAccount -eq $NULL)
    {
        Write-Host 'Adding' $SearchCredential.UserName 'as a managed account'
        $ManagedAccount = New-SPManagedAccount -Credential $SearchCredential
    }
ELSE
    {
        Write-Host 'Managed Account' $SearchCredential.UserName 'already exists'
    }

#Validate managed account
IF ($ManagedAccount -eq $NULL)
    {
        Write-Host "There is an error with the managed account, stopping script"
        break
    }


#Change the service account for host controller service and noderunner
#BK:2604515
$CurrentEnterpriseSearchAccount = (Get-SPEnterpriseSearchService).ProcessIdentity
IF($CurrentEnterpriseSearchAccount -ne $SearchCredential.UserName)
    {
        Write-Host 'Changing Process identity for Search Services to' $SearchCredential.UserName
        Get-SPEnterpriseSearchService | Set-SPEnterpriseSearchService -ServiceAccount $SearchCredential.UserName -ServicePassword $SearchCredential.Password
    }
ELSE
    {
        Write-Host 'Search Service process identity is already set to' $CurrentEnterpriseSearchAccount
    }


#Start Services on Index Servers and retreive the Search Instance for the index servers
$IndexSearchInstances = @() #Declare empty array for index instances
Write-Host 'Starting Index Servers'
ForEach ($IndexServer in $IndexServers)
    {
        $IndexInstance = Get-SPEnterpriseSearchServiceInstance | ?{$_.Server -like "*$IndexServer*"} #Get reference to search service instance
        IF ($IndexInstance.Status -eq "disabled")
            {
                Start-SPEnterpriseSearchServiceInstance -Identity $IndexInstance #Start the Search Service Instance
                Start-Sleep -Second 10
            }
        $SSQSIInstance = Get-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance | ?{$_.Server -like "*$IndexServer*"}
        IF ($SSQSIInstance.status -eq "disabled")
            {
                Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Identity $SSQSIInstance #Retrieve and start the SQSSI for this server
                Start-SLeep -Seconds 10
            }
        $IndexSearchInstances += $IndexInstance
    }

#Start Services on query Servers and retreive the Search Instance for the query servers
$QuerySearchInstances = @() #Delcare empty array for query instances
Write-Host 'Starting Query Servers'
ForEach ($QueryServer in $QueryServers)
    {
        $QueryInstance = Get-SPEnterpriseSearchServiceInstance | ?{$_.Server -like "*$QueryServer*"} #Get reference to search service instance
        IF ($QueryInstance.Status -eq "disabled")
            {
                Start-SPEnterpriseSearchServiceInstance -Identity $QueryInstance #Start the Search Service Instance
                Start-Sleep -Second 10
            }
        $SSQSIInstance = Get-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance | ?{$_.Server -like "*$QueryServer*"}#Retrieve and start the SQSSI for this server
        IF ($SSQSIInstance.Status -eq "disabled")
            {
                 Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Identity $SSQSIInstance
                 Start-Sleep -Seconds 10
            }
        $QuerySearchInstances += $QueryInstance
    }

#Start services on Content procesing serviers servers and retrieve the search instanes for content procesing servers
$CPCInstances = @() #declare empty array
Write-Host 'Starting CPC Servers'
ForEach ($ContentProcessingServer in $ContentProcessingServers)
    {
        $CPCInstance = Get-SPEnterpriseSearchServiceInstance | ?{$_.Server -like "*$ContentProcessingServer*"}
        IF ($CPCInstance.status -eq "disabled")
            {
                Start-SPEnterpriseSearchServiceInstance -Identity $CPCInstance #Start the Search Service Instance
                Start-Sleep -Seconds 10
            }
        $CPCInstances += $CPCInstance
    }

#Start services on Crawl servers and retrieve the search instanes for servers
$CrawlInstances = @() #declare empty array
Write-Host 'Starting Crawl Servers'
ForEach ($CrawlServer in $CrawlServers)
    {
        $CrawlInstance = Get-SPEnterpriseSearchServiceInstance | ?{$_.Server -like "*$CrawlServer*"}
        IF ($CrawlInstance.Status -eq 'disabled')
            {
                Start-SPEnterpriseSearchServiceInstance -Identity $CrawlInstance #Start the Search Service Instance
                Start-Sleep -Seconds 10
            }
        $CrawlInstances += $CrawlInstance
    }

#Start services in Analytics Processing Servers and retrieve the search instance for these servers
$APCInstances = @() #Delcare an empty array
Write-Host 'Starting APC Servers'
ForEach ($AnalyticsServer in $AnalyticsServers)
    {
        $APCInstance = Get-SPEnterpriseSearchServiceInstance | ?{$_.Server -like "*$AnalyticsServer*"}
        IF ($APCIntance.Status -eq 'disabled')
            {
                Start-SPEnterpriseSearchServiceInstance -Identity $APCInstance #Start the Search Service Instance
                Start-Sleep -Seconds 10
            }
        $APCInstances += $APCInstance
    }

#Start services in Admin Servers and retrieve the search instance for these servers
$AdminInstances = @() #Delcare an empty array
Write-Host 'Starting Admin Servers'
ForEach ($AdminServer in $AdminServers)
    {
        $AdminInstance = Get-SPEnterpriseSearchServiceInstance | ?{$_.Server -like "*$AdminServer*"}
        IF ($AdminInstance.Status -eq 'disabled')
            {
                Start-SPEnterpriseSearchServiceInstance -Identity $AdminInstance #Start the Search Service Instance
                Start-SLeep -Seconds 10
            }
        $AdminInstances += $AdminInstance
    }

#Confirm with user that running search instances are correct
$Response = 'c'
While ($Response -eq 'c')
    {
        $RunningSearchInstances = Get-SPEnterpriseSearchServiceInstance | ?{$_.Status -eq "Online"}
        Write-Host "The following Servers are running the service 'SharePoint Server Search'"
        ForEach ($SearchInstance in $RunningSearchInstances) {Write-Host $SearchInstance.Server}
        $Response = Read-Host "Press C to check again, N to stop script execution or any other key to continue"
    }
If ($Reponse -eq 'n')
    {
        Exit
    }
        


#Confirm with user that running Search Query and Site Settings Service Instances are correct
$Response = 'c'
While ($Response -eq 'c')
    {
        $RunningSQSSI = Get-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance | ?{$_.Status -eq "Online"}
        Write-Host "The following Servers are running the service 'SharePoint Search Query and Site Setting Service'"
        ForEach ($SQSSI in $RunningSQSSI) {Write-Host $SQSSI.Server}
        $Response = Read-Host "Press C to check again, N to stop script execution or any other key to continue"
    }
If ($Reponse -eq 'n')
    {
        Exit
    }


#Create the Search Service Application Pool
$AppPool = Get-SPServiceApplicationPool | ?{$_.name -eq "$SearchApplicationPool"}
IF ($AppPool -eq $NULL)
    {
        
        Write-Host 'Creating Application Pool' $SearchApplicationPool
        $AppPool = New-SPServiceApplicationPool -Name $SearchApplicationPool -Account $ManagedAccount   
    }
ELSE
    {
        Write-Host 'Application Pool' $SearchApplicationPool 'already exists'
    }

#Create Search Service Application
Write-Host 'Creating Search Service Application, this may take a few minutes'
$SearchServiceApp = New-SPEnterpriseSearchServiceApplication -Name $SearchServiceName -ApplicationPool $AppPool -DatabaseServer $DBServer -DatabaseName $SearchAdminDatabasename
New-SPEnterpriseSearchServiceApplicationProxy -Name $SearchServiceName -SearchApplication $SearchServiceApp
Get-SPEnterpriseSearchServiceApplication


##Create a new search topology
#Create a variable to hold the new search topology
#Defining a search topology
Write-Host "Creating empty search topology"
$SearchServiceApp = Get-SPEnterpriseSearchServiceApplication
$NewSearchTopology = New-SPEnterpriseSearchTopology -SearchApplication $SearchServiceApp


#Define new search topology
Write-Host 'Populating new search topology'

#Define Search Index Components
ForEach ($IndexSearchInstance in $IndexSearchInstances)
    {
        New-SPEnterpriseSearchIndexComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $IndexSearchInstance -IndexPartition 0 -RootDirectory $IndexLocation
    }

#Define Search Query Components
ForEach ($QuerySearchInstance in $QuerySearchInstances)
    {
        New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $QuerySearchInstance
    }


#Define Content Processing Components
ForEach ($CPCInstance in $CPCInstances)
    {
        New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $CPCInstance
    }

#Define Search Crawl Components
ForEach ($CrawlInstance in $CrawlInstances)
    {
        New-SPEnterpriseSearchCrawlComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $CrawlInstance
    }

#Define Analytics Components
ForEach ($APCInstance in $APCInstances)
    {
        New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $APCInstance
    }

#Define Admin Components
ForEach ($AdminInstance in $AdminInstances)
    {
        New-SPEnterpriseSearchAdminComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $AdminInstance
    }

$Topo = Get-SPEnterpriseSearchTopology -Identity $NewSearchTopology -SearchApplication $SearchServiceApp
$topo.GetComponents() | Sort-Object Name | FT ServerName, Name
Write-Host "Number of Components:" $Topo.ComponentCount

#Activate the Search Topology
$Response = Read-Host -Prompt 'Would you like to activate the above search topology? Press Y or N. Pressing N will stop script execution'
IF ($Response -ne "y")
    {
        Write-Host 'Stopping script'
        exit
    }
ELSE
    {
         Write-Host "Activating Search Topology"
         Set-SPEnterpriseSearchTopology -Identity $NewSearchTopology
    }

#If desired remove inactive topologies
$Resposne = Read-Host -Prompt 'Would you like to remove inactive search topologies?'
IF ($Response -ne "y")
    {
        Write-Host 'Stopping script'
        exit
    }
ELSE
    {

        Get-SPEnterprisesearchTopology -SearchApplication $SearchServiceApp | ?{$_.state -eq "Inactive"} | Remove-SPEnterpriseSearchTopology
    }











































