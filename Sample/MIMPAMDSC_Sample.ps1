Configuration MIMDSC
{
    Import-DscResource -ModuleName xMimDsc
    $computername = "MIMPamComputerName"
    Node $computername
    {
        xMIMSvc MIMSvc
        {
            Ensure = "Present"
            SetupFiles =  "\\sharedLocation\Service and Portal\Service and Portal.msi"
            ProductId = "----PRODUCT ID----"
            ServiceServer = $computername
            SQLServerInstance = $computername
            SQLServerDB = "FimService"
            SyncServer = $computername
            SyncServiceAccount = $AllNodes.SyncAccount
            UseExistingDatabase = 1
            MimSvcAccount = $AllNodes.ServiceAccount
            EmailSvcAccount = $AllNodes.EmailAccount
            MailServer = "outlook.office.365.com"
            ServiceAddress = $computername
            PsDscRunAsCredential = $AllNodes.RunAs
        }

        
        xMIMSvcHotfix "MimSvcHotfix"
        {
            Ensure = "Present"
            MspFileSource = "\\sharedLocation\Service and Portal\Hotfix\MIMService_x64_KB4469694.msp"
            VersionToUpdate = "4.5.286.0"
            PsDscRunAsCredential = $AllNodes.RunAs
            DependsOn = "[xMIMSvc]MIMSvc"
        }

        xMIMSvcSwitchToGmsa "MIMSvcSwitchToGmsa"
        {
            CurrentServiceAccount = $AllNodes.ServiceAccount
            EmailSvcAccount = $AllNodes.EmailAccount
            Ensure = "Present"
            MIMSvcGmsaAccount = "Domain\svcGmsaAccount$"
            ServiceAddress = $computername
            SetupFiles = "\\sharedLocation\Service and Portal\Service and Portal.msi"
            DependsOn = "[xMIMSvcHotfix]MimSvcHotfix"
            PsDscRunAsCredential = $AllNodes.RunAs
        }

        xMIMPamInstall "MIMPAM"
        {
            EmailSvcAccount = $AllNodes.EmailAccount
            Ensure = "Present"
            PAMCompGmsaAccount = "Domain\ComponentServiceGmsa$"
            PAMMonGmsaAccount = "Domain\MonitoringServiceGmsa$"
            PAMWebPoolGmsaAccount = "Domain\IISAppPoolGmsa$"
            ServiceAddress = $computername
            SetupFiles = "\\SharedLocation\Service and Portal\Service and Portal.msi"
            PsDscRunAsCredential = $AllNodes.RunAs
            DependsOn = "[xMIMSvcSwitchToGmsa]MIMSvcSwitchToGmsa"
        }
    }
}

$cd = @{
    AllNodes = @(
        @{
            NodeName = "MIMPamComputerName"
            PSDscAllowPlainTextPassword = $true
            PsDscAllowDomainUser = $true
            RunAs = New-Object System.Management.Automation.PSCredential ("Domain\AdminAccount", (ConvertTo-SecureString "Password" -AsPlainText -Force))
            ServiceAccount = New-Object System.Management.Automation.PSCredential ("Domain\MimServiceAccount", (ConvertTo-SecureString "Password" -AsPlainText -Force))
            EmailAccount = New-Object System.Management.Automation.PSCredential ("Office365 Email account UPN", (ConvertTo-SecureString "Password" -AsPlainText -Force))
            SyncAccount = "Domain\ManagementAgentSvcAccount"
        }
    )
}

MIMDSC -ConfigurationData $cd