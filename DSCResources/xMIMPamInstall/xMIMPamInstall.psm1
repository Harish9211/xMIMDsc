function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SetupFiles,

        [parameter(Mandatory = $false)]
        [System.String]
        $SyncServer = $env:COMPUTERNAME,
        
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

        [parameter(Mandatory = $true)]
        [ValidateSet("Absent", "Present")]
        [System.String]
        $Ensure,

        [Parameter(Mandatory = $true)]
        [pscredential]
        $emailSvcAccount,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServiceServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceAddress 
    )

    $FimService = Get-WmiObject -Class Win32_Service -Filter "Name='FimService'"
    if($FimService -eq $null)
    {
        Write-Error "FIM Service is not installed. Install FIM Service first then install MIM PAM."
        break
    }
    elseif($FimService.State -ne "Running")
    {
        (Start-Service "FimService").WaitForStatus
        $FimService = Get-WmiObject -Class Win32_Service -Filter "Name='FimService'"
        if($FimService.State -ne "Running")
        {
            Write-Error "Fim Service cannot be started. try to start service manually or repair MIM Service."
            break
        }
        else
        {
            continue
        }
    }

    $currentMim = Get-CurrentAccount
    
    $PamMon = Get-WmiObject -Class Win32_service -Filter "Name='PamMonitoringService'"
    $PamComp = Get-WmiObject -Class Win32_service -Filter "Name='PrivilegeManagementComponentService'"

    if(!$currentMim)
    {
        Write-Error "MIM Service is not running as GMSA so cannot install PAM services with Gmsa.."
    }
            
    if($currentMim)
    {
        if($PamMon -eq $null -and $PamComp -eq $null)
        {
            $returnValue = @{
            PAMCompGmsaAccount = $PAMCompGmsaAccount
            PAMMonGmsaAccount = $PAMMonGmsaAccount
            PAMWebPoolGmsaAccount = $PAMWebPoolGmsaAccount
            PAMRestApiPort = $PAMRestApiPort
            Ensure = "Absent"
            }
        }
        else
        {
            $returnValue = @{
            PAMCompGmsaAccount = $PAMCompGmsaAccount
            PAMMonGmsaAccount = $PAMMonGmsaAccount
            PAMWebPoolGmsaAccount = $PAMWebPoolGmsaAccount
            PAMRestApiPort = $PAMRestApiPort
            Ensure = "Present"
            }
        }
    }

    $returnValue
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SetupFiles,

        [parameter(Mandatory = $false)]
        [System.String]
        $SyncServer = $env:COMPUTERNAME,

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

        [parameter(Mandatory = $true)]
        [ValidateSet("Absent", "Present")]
        [System.String]
        $Ensure,

        [Parameter(Mandatory = $true)]
        [pscredential]
        $emailSvcAccount,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServiceServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceAddress 
    )

    $install = Install-MIMPamWithGmsa -SetupFiles $SetupFiles -SyncServer $SyncServer -ServiceServer $ServiceServer `
    -PAMCompGmsaAccount $PAMCompGmsaAccount -PAMMonGmsaAccount $PAMMonGmsaAccount `
    -PAMWebPoolGmsaAccount $PAMWebPoolGmsaAccount -PAMRestApiPort $PAMRestApiPort -emailSvcAccount $emailSvcAccount `
    -ServiceAddress $ServiceAddress -Verbose
    if($install -eq 0)
    {
        $global:DSCMachineStatus = 1
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SetupFiles,

        [parameter(Mandatory = $false)]
        [System.String]
        $SyncServer = $env:COMPUTERNAME,

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

        [parameter(Mandatory = $true)]
        [ValidateSet("Absent", "Present")]
        [System.String]
        $Ensure,

        [Parameter(Mandatory = $true)]
        [pscredential]
        $emailSvcAccount,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServiceServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceAddress 
    )

    if($Ensure -eq "Absent")
    {
        throw [Exception] ("MIM DSC does not support uninstalling MIM and PAM service. Please remove it manually.")
        return
    }
    else
    {
        $result = Get-TargetResource @PSBoundParameters
        if($result.Ensure -eq "Absent")
        {
            return $false
        }

        else
        {    
            return $true
        }
    }
}


Export-ModuleMember -Function *-TargetResource

