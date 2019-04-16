
function Get-CurrentMIM
{
    [CmdletBinding()]
    $MIM = Get-Package | where {$_.Name -eq "Microsoft Identity Manager Service and Portal"}
    return $MIM
}

function Install-MimSvc
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $setupFiles,

        [Parameter(Mandatory = $true)]
        [string]
        $productId,
        
        [Parameter(Mandatory = $true)]
        [string]
        $sqlServerInstance, 

        [Parameter(Mandatory = $true)]
        [string]
        $sqlServerDb,

         
        [Parameter(Mandatory = $true)]
        [pscredential]
        $mimSvcAccount,

         
        [Parameter(Mandatory = $true)]
        [pscredential]
        $emailSvcAccount,

        [Parameter(Mandatory = $false)]
        [string]
        $serviceServer = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false)]
        [string]
        $syncServer = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [string]
        $syncServiceAccount,

        [Parameter(Mandatory = $false)]
        [string]
        $mailServer = "outlook.office365.com",

        [Parameter(Mandatory = $true)] 
        [ValidateSet(0,1)]
        [int]
        $useExistingDatabase,

        [Parameter(Mandatory = $true)]
        [string]
        $serviceAddress

    )

    Write-Verbose -Message "Starting MIM Service pre-reqs check."

    if(!(Test-Path $setupFiles))
    {
        Write-Error "$setupFiles location is not found or not accessible please check and try again."
        break
    }

    Write-Verbose "Checking windows pre-reqs required for MIM Service."

    #Checking windows features

    Test-WinFPrereqs

    ##################################################################

    $mimSvcAccountD = $mimSvcAccount.UserName.Split("\")
    $mimSvcAccountName = $mimSvcAccountD[1]
    $mimSvcAccountDomain = $mimSvcAccountD[0]
    $mimSvcAccountPass = $mimSvcAccount.GetNetworkCredential().Password
    $logs = "$env:TMP\FimService.log"

    $emailAccount = $emailSvcAccount.UserName
    $emailAccountPass = $emailSvcAccount.GetNetworkCredential().Password

    $setupFiles = '"{0}"' -f $setupFiles

    $exitcodes = @(0, 3010, 1641)

    Write-Verbose "Merging data inputs"

    $Arguments = @(
                            "/i"
                            $setupFiles
                            "ADDLOCAL=CommonServices"
                            "ACCEPT_EULA=1"
                            "SQLSERVER_SERVER=$sqlServerInstance"
                            "SQLSERVER_DATABASE=$sqlServerDb"
                            "EXISTINGDATABASE=$useExistingDatabase"
                            "SERVICE_ACCOUNT_NAME=$mimSvcAccountName"
                            "SERVICE_ACCOUNT_PASSWORD=$mimSvcAccountPass"
                            "SERVICE_ACCOUNT_DOMAIN=$mimSvcAccountDomain"
                            "SERVICE_ACCOUNT_EMAIL=$emailAccount"
                            "SERVICE_ACCOUNT_EMAIL_PASSWORD=$emailAccountPass"
                            "SERVICE_MANAGER_SERVER=$serviceServer"
                            "SYNCHRONIZATION_SERVER=$syncServer"
                            "SYNCHRONIZATION_SERVER_ACCOUNT=$syncServiceAccount"
                            "MAIL_SERVER=$mailServer"
                            "SERVICEADDRESS=$serviceAddress"
                            "MAIL_SERVER_USE_SSL=1"
                            "MAIL_SERVER_IS_EXCHANGE=1"
                            "POLL_EXCHANGE_ENABLED=0"
                            "MAIL_SERVER_IS_EXCHANGE_ONLINE=1"
                            "SQMOPTINSETTING=0"
                            "REBOOT=ReallySuppress"
                            "/l*v $logs"
                            "/qn"
                            ) -join ' '

    #######################################################################

    try
    {
        #Checking user rights assignment

        Test-ServiceAccountRights -svcAccountName $mimSvcAccount.UserName -ErrorAction Stop
        Test-ServiceAccountRights -svcAccountName $syncServiceAccount -ErrorAction Stop

        $sqlCon = Test-SqlDb -SqlServerInstance $sqlServerInstance -SqlDbName $sqlServerDb
        if($sqlCon.Exists -and $useExistingDatabase -eq 1)
        {
            Write-Verbose "Database $sqlServerDb exists and will be used for this configuration"
        }
        elseif($sqlCon.Exists -and $useExistingDatabase -eq 0)
        {
            Write-Error "Database with name $sqlServerDb already exists. Either delete this DB or Change UseExistingDatabase to 1"
            break
        }

        elseif(!$sqlCon.Exists -and $useExistingDatabase -eq 0)
        {
            Write-Verbose "Creating database with name $sqlServerDb"
        }

        Write-Verbose "Starting MIM Service Installation"
        $run = Start-Process msiexec -ArgumentList $Arguments -Wait -PassThru -Verbose -Verb RunAs
        $ex = $run.ExitCode
        Start-Sleep -Seconds 10
        if($exitcodes -ccontains $ex)
        {
            Write-Verbose "FimService installation completed."
            Write-Verbose "For detailed logs check file at $logs"
        }
        elseif($ex -eq 1618)
        {
            Write-Error "ERROR_INSTALL_ALREADY_RUNNING - Another MSI installation is running. Either wait for it to complete
                            Or Stop msiexec process and Try again..."
            break
        }
        elseif($ex -eq 1619 -or $ex -eq 1620)
        {
            Write-Error "ERROR_INSTALL_PACKAGE_OPEN_FAILED - This installation package $setupFiles could not be opened.
                         Verify that the package exists and is accessible."
            break
        }
        else
        {
            Write-Error "Fim Service installation has failed. Installation returned error $ex, refer to `
            https://docs.microsoft.com/en-us/windows/desktop/msi/error-codes for more details on error codes"
            Write-Verbose "For detailed logs check file at $logs, if file doesnt exists please check events"
            break
        }
    }
    catch
    {
        $errorMessage =  $_.Exception.Message
        $failedItems = $_.Exception.itemName
        Write-Error $errorMessage
        Write-Error $failedItems
        Write-Warning "For detailed logs check file at $logs"
        break
    }
}

function Update-MimSvc
{
    [CmdletBinding()]
    param(

        [Parameter(Mandatory = $true)]
        [string]
        $SourceFile
    )

    $SourceFile = '"{0}"' -f $SourceFile
    $exitcodes = @(0, 3010, 1641)

    $logs = "$env:TMP\MimServicePatch.log"
    $arguments = @(
                    "/p"
                    $SourceFile
                    "/l*v"
                    $logs
                    "/qn"
    ) -join " "

    try
    {
        Get-VisualC -Verbose -ErrorAction Stop
        Write-Verbose "Stopping FimService..."
        Stop-Service -Name FIMService -Force -Verbose
        Write-Verbose "Starting installation of $SourceFile patch"
        $run = Start-Process msiexec -ArgumentList $arguments -Verb RunAs -Wait -PassThru -Verbose
        $ex = $run.ExitCode
        if($exitcodes -ccontains $ex)
        {
            Write-Verbose "FimService is successfully updated."
            Write-Verbose "For detailed logs check file at $logs"
        }
        elseif($ex -eq 1635 -or $ex -eq 1636)
        {
            Write-Error "ERROR_INSTALL_PACKAGE_OPEN_FAILED - This installation package $SourceFile could not be opened.
                         Verify that the package exists and is accessible."
            break
        }
        else
        {
            Write-Error "Fim Service update installation has failed. Installation returned error $ex, refer to `
            https://docs.microsoft.com/en-us/windows/desktop/msi/error-codes for more details on error codes"
            Write-Verbose "For detailed logs check file at $logs, if file doesnt exists please check events"
            break
        }
    }

    catch
    {
        $errorMessage =  $_.Exception.Message
        $failedItems = $_.Exception.itemName
        Write-Error $errorMessage
        Write-Error $failedItems
        Write-Warning "For detailed logs check file at $logs"
        break
    }
}

function Test-WinFPrereqs
{
    import-module ServerManager -Cmdlet Get-WindowsFeature
    $install = @()
    $requiredFeatures = @("Web-WebServer", 
                        "Net-Framework-Features",
                        "rsat-ad-powershell",
                        "Web-Mgmt-Tools",
                        "Windows-Identity-Foundation",
                        "Server-Media-Foundation",
                        "Xps-Viewer"
                        )
    foreach($feature in $requiredFeatures)
    {
        $f = Get-WindowsFeature -Name $feature -Verbose
        if($f.Installed -ne $true)
        {
            $install += $f.Installed
            Write-Error "$feature is not installed. Please install first and try again."
        }
        else
        {
            $install += $f.Installed
            Write-Verbose "$feature is installed."
        }
    }

    if($install -contains $false)
    {
        Write-Error "One of pre-req is missing, please check and try again."
        break
    }
    
    Write-Verbose "Required windows features are installed."
}

function Test-ServiceAccountRights
{
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $true)]
        [string]
        $svcAccountName
    )
    Write-Verbose "Checking Log on as Service rights for $svcAccountName on server..."
    $tempPath = [System.IO.Path]::GetTempPath()
    $export = Join-Path -Path $tempPath -ChildPath "SeExport.inf"
    $sid = ((New-Object System.Security.Principal.NTAccount($svcAccountName)).Translate([System.Security.Principal.SecurityIdentifier])).Value
    $sid = "*"+$sid
    $ex = secedit /export /cfg $export
    $sids = (Select-String $export -Pattern "SeServiceLogonRight").Line
    $sids = $sids.Split(",")
    $sids = $sids.Split("=").Trim()
    if($sids -ccontains $sid)
    {
        Write-Verbose "$svcAccountName has Log on as Service rights."
        return $true
    }
    else
    {
        Write-Error "$svcAccountName is not granted Log on as Service rights on server."
        #break
    }
}

function Update-FimServiceReg
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $svcGmsaAccountName
    )

    Write-Verbose "Updating FimService registry..."

    $FimService = Get-FimReg
    $regAccount = $FimService.GetValue("ObjectName")

    try
    {
        if($FimService)
        {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\FimService" `
            -Name "ObjectName" -Value $svcGmsaAccountName
        }
    }
    catch
    {
        throw $_.Exception.Message
    }   
}

function Install-MIMPamWithGmsa
{
    [CmdletBinding()]
    param(

        [parameter(Mandatory = $true)]
        [System.String]
        $SetupFiles,

        [parameter(Mandatory = $false)]
        [System.String]
        $SyncServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServiceServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $true)]
        [System.String]
        $PAMCompGmsaAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $PAMMonGmsaAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $PAMWebPoolGmsaAccount,

        [parameter(Mandatory = $false)]
        [System.UInt16]
        $PAMRestApiPort = 8089,

        [Parameter(Mandatory = $true)]
        [pscredential]
        $emailSvcAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceAddress
    )

    ###########################################################################

    #Building variables

    $FimServiceReg = Get-FimReg

    $sqlServerInstance = $FimServiceReg.GetValue("DatabaseServer")
    $sqlServerDb = $FimServiceReg.GetValue("DatabaseName")

    $emailAccount = $emailSvcAccount.UserName
    $emailAccountPass = $emailSvcAccount.GetNetworkCredential().Password

    $syncServiceAccount = $FimServiceReg.GetValue("SynchronizationAccount")

    $mailServer = "outlook.office365.com"

    $exitcodes = @(0, 3010, 1641)

    $MIMSvcGmsaAccount = $FimServiceReg.GetValue("ObjectName")
    $mimSvcAccountD = $MIMSvcGmsaAccount.Split("\")
    $mimSvcAccountName = $mimSvcAccountD[1]
    $mimSvcAccountDomain = $mimSvcAccountD[0]

    $pamCompAccount = $PAMCompGmsaAccount.Split("\")
    $pamCompAccountName = $pamCompAccount[1]
    $pamCompAccountDomain = $pamCompAccount[0]

    $pamMonAccount = $PAMMonGmsaAccount.Split("\")
    $pamMonAccountName = $pamMonAccount[1]
    $pamMonAccountDomain = $pamMonAccount[0]

    $pamWebPoolAcc = $PAMWebPoolGmsaAccount.Split("\")
    $pamWebPoolAccName = $pamWebPoolAcc[1]
    $PAMWebPoolAccDomain = $pamWebPoolAcc[0]

    $logs = "$env:TMP\MIMPAM_Install.log"

    ###########################################################################

    Write-Verbose -Message "Starting MIM PAM Services pre-reqs check."

    if(!(Test-Path $SetupFiles))
    {
        Write-Error "$SetupFiles location is not found or not accessible please check and try again."
        break
    }

    $SetupFiles = '"{0}"' -f $SetupFiles

    Write-Verbose "Checking windows pre-reqs required for MIM PAM Services."

    #Checking windows features
    ##########################

    Test-WinFPrereqs
    
    $Arguments = @(
                            "/i"                            
                            $SetupFiles                            
                            "ADDLOCAL=CommonServices,PAMServices"
                            "ACCEPT_EULA=1"
                            "USE_MANAGED_ACCOUNT_FOR_SERVICE=1"
                            "SQLSERVER_SERVER=$sqlServerInstance"
                            "SQLSERVER_DATABASE=$sqlServerDb"
                            "EXISTINGDATABASE=1"
                            "SERVICE_ACCOUNT_NAME=$mimSvcAccountName"
                            "SERVICE_ACCOUNT_DOMAIN=$mimSvcAccountDomain"
                            "SERVICE_ACCOUNT_EMAIL=$emailAccount"
                            "SERVICE_ACCOUNT_EMAIL_PASSWORD=$emailAccountPass"
                            "SERVICE_MANAGER_SERVER=$ServiceServer"
                            "SYNCHRONIZATION_SERVER=$SyncServer"
                            "SYNCHRONIZATION_SERVER_ACCOUNT=$syncServiceAccount"
                            "MAIL_SERVER=$mailServer"
                            "SERVICEADDRESS=$ServiceAddress"
                            "POLL_EXCHANGE_ENABLED=0"
                            "MAIL_SERVER_IS_EXCHANGE_ONLINE=1"
                            "PAM_MONITORING_SERVICE_ACCOUNT_DOMAIN=$pamMonAccountDomain"
                            "PAM_MONITORING_SERVICE_ACCOUNT_NAME=$pamMonAccountName"                            
                            "PAM_COMPONENT_SERVICE_ACCOUNT_DOMAIN=$pamCompAccountDomain"
                            "PAM_COMPONENT_SERVICE_ACCOUNT_NAME=$pamCompAccountName"                            
                            "PAM_REST_API_APPPOOL_ACCOUNT_DOMAIN=$PAMWebPoolAccDomain" 
                            "PAM_REST_API_APPPOOL_ACCOUNT_NAME=$PAMWebPoolAccName"
                            "MIMPAM_REST_API_PORT=$PAMRestApiPort"
                            "SQMOPTINSETTING=0"
                            "FIREWALL_CONF=1"
                            "REBOOT=ReallySuppress"
                            "/l*v $logs"
                            "/qn"
                            ) -join ' ' 

    try
    {
        #Checking user rights assignment

        Write-Verbose "Checking SVCs accounts Log on as Service Rights on server.."
        Test-ServiceAccountRights -svcAccountName $PAMCompGmsaAccount -Verbose -ErrorAction Stop
        Test-ServiceAccountRights -svcAccountName $PAMMonGmsaAccount -Verbose -ErrorAction Stop
        Test-ServiceAccountRights -svcAccountName $PAMWebPoolGmsaAccount -Verbose -ErrorAction Stop

        Write-Verbose "Starting PAM Services Installation...."
        $run = Start-Process msiexec -ArgumentList $Arguments -Wait -PassThru -Verbose -Verb RunAs
        $ex = $run.ExitCode
        Start-Sleep -Seconds 10
        if($exitcodes -ccontains $ex)
        {
            Write-Warning "PAM Services installations is successful."
            Write-Verbose "For detailed logs check file at $logs"
            #$global:DSCMachineStatus = 1
        }
        elseif($ex -eq 1618)
        {
            Write-Error "ERROR_INSTALL_ALREADY_RUNNING - Another MSI installation is running. Either wait for it to complete
                            Or Stop msiexec process and Try again..."
            break
        }
        elseif($ex -eq 1619 -or $ex -eq 1620)
        {
            Write-Error "ERROR_INSTALL_PACKAGE_OPEN_FAILED - This installation package $SetupFiles could not be opened.
                         Verify that the package exists and is accessible."
            break
        }
        else
        {
            Write-Error "PAM Installation has failed. Installation returned error $ex, refer to `
            https://docs.microsoft.com/en-us/windows/desktop/msi/error-codes for more details on error codes"
            Write-Verbose "For detailed logs check file at $logs, if file doesnt exists please check events"
            break
        }
    }
    catch
    {
        $errorMessage =  $_.Exception.Message
        $failedItems = $_.Exception.itemName
        Write-Error $errorMessage
        Write-Error $failedItems
        Write-Warning "For detailed logs check file at $logs"
        break
    }
    return $ex
}

function Get-FimReg
{
    $fimReg = Get-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\FimService"
    return $fimReg
}

function Switch-MimToGmsa
{
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $true)]
        [string]
        $SetupFiles,

        [Parameter(Mandatory = $true)]
        [pscredential]
        $CurrentServiceAccount,

        [Parameter(Mandatory = $true)]
        [string]
        $MIMSvcGmsaAccount,

        [parameter(Mandatory = $false)]
        [System.String]
        $SyncServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServiceServer = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [pscredential]
        $emailSvcAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceAddress

    )

    #=========================================================================
    #Creating variables
    $FimServiceReg = Get-FimReg

    $currentRegAccount = $FimServiceReg.GetValue("ObjectName")
    if($CurrentServiceAccount.UserName -ne $currentRegAccount)
    {
        Write-Error "Current Service Account provided doesnt match with the account linked to Fim service."
        break
    }

    $sqlServerInstance = $FimServiceReg.GetValue("DatabaseServer")
    $sqlServerDb = $FimServiceReg.GetValue("DatabaseName")

    $emailAccount = $emailSvcAccount.UserName
    $emailAccountPass = $emailSvcAccount.GetNetworkCredential().Password

    $syncServiceAccount = $FimServiceReg.GetValue("SynchronizationAccount")

    $mailServer = "outlook.office365.com"
    
    $useExistingDatabase = "1"

    $SetupFiles = '"{0}"' -f $SetupFiles
    $exitcodes = @(0, 3010, 1641)
    
    $mimSvcAccountD = $MIMSvcGmsaAccount.Split("\")
    $mimSvcAccountName = $mimSvcAccountD[1]
    $mimSvcAccountDomain = $mimSvcAccountD[0]

    $logs = "$env:TMP\MIMSvc_GmsaSwitch.log"
    #==========================================================================

    $Arguments = @(
                            "/i"
                            $SetupFiles
                            "ADDLOCAL=CommonServices"
                            "ACCEPT_EULA=1"
                            "SQLSERVER_SERVER=$sqlServerInstance"
                            "SQLSERVER_DATABASE=$sqlServerDb"
                            "EXISTINGDATABASE=$useExistingDatabase"
                            "SERVICE_ACCOUNT_NAME=$mimSvcAccountName"
                            "SERVICE_ACCOUNT_DOMAIN=$mimSvcAccountDomain"
                            "SERVICE_ACCOUNT_EMAIL=$emailAccount"
                            "SERVICE_ACCOUNT_EMAIL_PASSWORD=$emailAccountPass"
                            "SERVICE_MANAGER_SERVER=$ServiceServer"
                            "SYNCHRONIZATION_SERVER=$SyncServer"
                            "SYNCHRONIZATION_SERVER_ACCOUNT=$syncServiceAccount"
                            "MAIL_SERVER=$mailServer"
                            "SERVICEADDRESS=$ServiceAddress"
                            "MAIL_SERVER_USE_SSL=1"
                            "MAIL_SERVER_IS_EXCHANGE=1"
                            "POLL_EXCHANGE_ENABLED=0"
                            "MAIL_SERVER_IS_EXCHANGE_ONLINE=1"
                            "USE_MANAGED_ACCOUNT_FOR_SERVICE=1"
                            "SQMOPTINSETTING=0"
                            "REBOOT=ReallySuppress"
                            "/l*v $logs"
                            "/qn"
                    )

    try
    {
        Write-Verbose "Starting MIM Service swtitch to GMSA.."
        Update-FimServiceReg -svcGmsaAccountName $MIMSvcGmsaAccount -Verbose -ErrorAction Stop
        Get-GmsaAccount -accountName $MIMSvcGmsaAccount -Verbose
        Test-ServiceAccountRights -svcAccountName $MIMSvcGmsaAccount -Verbose -ErrorAction Stop
        Write-Verbose "Changes are in progress..."
        $run = Start-Process msiexec -ArgumentList $Arguments -Wait -PassThru -Verbose -Verb RunAs
        $ex = $run.ExitCode
        Start-Sleep -Seconds 10
        if($exitcodes -ccontains $ex)
        {
            Write-Warning "FimService able to switch to GMSA successfully, Reboot needed to complete installation."
            Write-Verbose "For detailed logs check file at $logs"
            #$global:DSCMachineStatus = 1
        }
        elseif($ex -eq 1618)
        {
            Write-Error "ERROR_INSTALL_ALREADY_RUNNING - Another MSI installation is running. Either wait for it to complete
                            Or Stop msiexec process and Try again..."
            break
        }
        elseif($ex -eq 1619 -or $ex -eq 1620)
        {
            Write-Error "ERROR_INSTALL_PACKAGE_OPEN_FAILED - This installation package $SetupFiles could not be opened.
                         Verify that the package exists and is accessible."
            break
        }
        else
        {
            Write-Warning "Fim Service unable to switch to GMSA. Installation returned error $ex, refer to `
            https://docs.microsoft.com/en-us/windows/desktop/msi/error-codes for more details on error codes"
            Write-Warning "For detailed logs check file at $logs, if file doesnt exists please check events"
            Write-Verbose "Rolling back to previous service account"

            Switch-MimToNormalSvcAccount -SetupFiles $SetupFiles -NormalServiceAccount $CurrentServiceAccount `
            -SyncServer $SyncServer -ServiceServer $ServiceServer -emailSvcAccount $emailSvcAccount -ServiceAddress $ServiceAddress `
            -Verbose

            Write-Verbose "FIM Service unable to switch to GMSA. Rolled back to previous account.."
        }
    }
    catch
    {
        $errorMessage =  $_.Exception.Message
        $failedItems = $_.Exception.itemName
        Write-Error $errorMessage
        Write-Error $failedItems
        Write-Warning "For detailed logs check file at $logs"
        break
    }

    return $ex
}

function Switch-MimToNormalSvcAccount
{
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $true)]
        [string]
        $SetupFiles,

        [Parameter(Mandatory = $true)]
        [pscredential]
        $NormalServiceAccount,

        [parameter(Mandatory = $false)]
        [System.String]
        $SyncServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServiceServer = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [pscredential]
        $emailSvcAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceAddress

    )

    #==================================================================
    #Building Variables

    $FimServiceReg = Get-FimReg

    $sqlServerInstance = $FimServiceReg.GetValue("DatabaseServer")
    $sqlServerDb = $FimServiceReg.GetValue("DatabaseName")

    $emailAccount = $emailSvcAccount.UserName
    $emailAccountPass = $emailSvcAccount.GetNetworkCredential().Password

    $syncServiceAccount = $FimServiceReg.GetValue("SynchronizationAccount")

    $mailServer = "outlook.office365.com"

    $useExistingDatabase = "1"

    $SetupFiles = '"{0}"' -f $SetupFiles
    $exitcodes = @(0, 3010, 1641)

    $mimSvcAccountD = $NormalServiceAccount.Username.Split("\")
    $mimSvcAccountName = $mimSvcAccountD[1]
    $mimSvcAccountDomain = $mimSvcAccountD[0]

    $mimSvcAccountPass = $NormalServiceAccount.GetNetworkCredential().Password

    $logs = "$env:TMP\MIMSvc_NormalAccountSwitch.log"

    $Arguments = @(
                            "/i"
                            $SetupFiles
                            "ADDLOCAL=CommonServices"
                            "ACCEPT_EULA=1"
                            "SQLSERVER_SERVER=$sqlServerInstance"
                            "SQLSERVER_DATABASE=$sqlServerDb"
                            "EXISTINGDATABASE=$useExistingDatabase"
                            "SERVICE_ACCOUNT_NAME=$mimSvcAccountName"
                            "SERVICE_ACCOUNT_DOMAIN=$mimSvcAccountDomain"
                            "SERVICE_ACCOUNT_PASSWORD=$mimSvcAccountPass"
                            "SERVICE_ACCOUNT_EMAIL=$emailAccount"
                            "SERVICE_ACCOUNT_EMAIL_PASSWORD=$emailAccountPass"
                            "SERVICE_MANAGER_SERVER=$ServiceServer"
                            "SYNCHRONIZATION_SERVER=$SyncServer"
                            "SYNCHRONIZATION_SERVER_ACCOUNT=$syncServiceAccount"
                            "MAIL_SERVER=$mailServer"
                            "SERVICEADDRESS=$ServiceAddress"
                            "MAIL_SERVER_USE_SSL=1"
                            "MAIL_SERVER_IS_EXCHANGE=1"
                            "POLL_EXCHANGE_ENABLED=0"
                            "MAIL_SERVER_IS_EXCHANGE_ONLINE=1"
                            "USE_MANAGED_ACCOUNT_FOR_SERVICE=0"
                            "SQMOPTINSETTING=0"
                            "REBOOT=ReallySuppress"
                            "/l*v $logs"
                            "/qn"
                            )

    #===================================================================

    try
    {
        Write-Verbose "Switching to MIM Service to Normal Account.."
        Update-FimServiceReg -svcGmsaAccountName $NormalServiceAccount.UserName -Verbose -ErrorAction Stop
        Test-ServiceAccountRights -svcAccountName $NormalServiceAccount.UserName -Verbose -ErrorAction Stop
        Write-Verbose "Roll back in progress.."
        $run = Start-Process msiexec -ArgumentList $Arguments -Wait -PassThru -Verbose -Verb RunAs
        $ex = $run.ExitCode
        Start-Sleep -Seconds 10
        if($exitcodes -ccontains $ex)
        {
            Write-Warning "FimService able to switch to Normal Account, Reboot needed to complete installation."
            Write-Verbose "For detailed logs check file at $logs"
            $global:DSCMachineStatus = 1
        }
        elseif($ex -eq 1618)
        {
            Write-Error "ERROR_INSTALL_ALREADY_RUNNING - Another MSI installation is running. Either wait for it to complete
                            Or Stop msiexec process and Try again..."
            break
        }
        elseif($ex -eq 1619 -or $ex -eq 1620)
        {
            Write-Error "ERROR_INSTALL_PACKAGE_OPEN_FAILED - This installation package $SetupFiles could not be opened.
                         Verify that the package exists and is accessible."
            break
        }
        else
        {
            Write-Error "Fim Service unable to switch to Normal Account. Installation returned error $ex, refer to `
            https://docs.microsoft.com/en-us/windows/desktop/msi/error-codes for more details on error codes"
            Write-Warning "For detailed logs check file at $logs, if file doesnt exists please check events"
        }
    }
    catch
    {
        $errorMessage =  $_.Exception.Message
        $failedItems = $_.Exception.itemName
        Write-Error $errorMessage
        Write-Error $failedItems
        Write-Warning "For detailed logs check file at $logs"
        break
    }
}

function Get-GmsaAccount
{
    param(
        [parameter(mandatory = $true)]
        [string]
        $accountName
    )

    $accountN = $accountName.Split("\")
    if($accountN.Count -ne 2)
    {
        Write-Error "Provided account is not in Domain\UserName format.."
        break
    }

    $gmsaType = "ms-DS-Group-Managed-Service-Account"
    $accountN = $accountN[1]
    $accountDetails = ([adsisearcher]"(sAMAccountName=$accountN)").FindOne()
    $accountType = [string]($accountDetails.Properties.objectcategory)
    if($accountType -match $gmsaType)
    {
        Write-Verbose "$accountName is GMSA account.."
        return $true
    }
    else
    {
        Write-Verbose "$accountName is not of GMSA Type.."
        return $false
    }
}

function Get-CurrentAccount
{
    $fimreg = Get-FimReg
    $AccountName = $fimreg.GetValue("ObjectName")
    $accountN = $AccountName.Split("\")
    
    if(Get-GmsaAccount -accountName $AccountName)
    {
        return $true
    }
    
    else
    {
        return $false
    }
}

function Get-VisualC
{
    $vs = "Microsoft Visual C++ 2013 Redistributable (x64)"
    $p = Get-Package | where {$_.Name -like "$vs*"}
    if($p -ne $null)
    {
        Write-Verbose "$vs is installed on server.."
    }
    else
    {
        Write-Error "Please install $vs on server before installing Hotfix."
    }
}

function Test-SqlDb
{
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $true)]
        [string]
        $SqlServerInstance,

        [Parameter(Mandatory = $true)]
        [string]
        $SqlDbName
    )

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $SqlServerInstance; Database = $SqlDbName; Integrated Security = True"

    do{
        $open = $SqlConnection.OpenAsync()
        $SqlConnection.Close()
        $canceled = $open.IsCanceled
        $fault = $open.IsFaulted
    }
    while($canceled)
    if($fault)
    {
        return @{
            Exists = $false
        }
    }
    else
    {
        return @{
            Exists = $true
        }
    }
}
