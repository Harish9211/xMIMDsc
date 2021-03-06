function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SetupFiles,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $CurrentServiceAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $MIMSvcGmsaAccount,

        [parameter(Mandatory = $false)]
        [System.String]
        $SyncServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServiceServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceAddress,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $EmailSvcAccount
    )

    Write-Verbose "Checking current MIM SVC account type.."
    if(!(Get-CurrentAccount))
    {
        Write-Verbose "Current SVC account is not GMSA.."
        $Ensure = "Absent"
    }
    else
    {
        Write-Verbose "Current SVC account is of GMSA type.."
        $Ensure = "Present"
    }

    
    $returnValue = @{
    Ensure = $Ensure
    MIMSvcGmsaAccount = $MIMSvcGmsaAccount
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

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $CurrentServiceAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $MIMSvcGmsaAccount,

        [parameter(Mandatory = $false)]
        [System.String]
        $SyncServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServiceServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceAddress,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $EmailSvcAccount
    )

    $install = Switch-MimToGmsa -SetupFiles $SetupFiles -CurrentServiceAccount $CurrentServiceAccount -MIMSvcGmsaAccount $MIMSvcGmsaAccount `
    -SyncServer $SyncServer -ServiceServer $ServiceServer -emailSvcAccount $EmailSvcAccount -ServiceAddress $ServiceAddress `
    -Verbose

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

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $CurrentServiceAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $MIMSvcGmsaAccount,

        [parameter(Mandatory = $false)]
        [System.String]
        $SyncServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServiceServer = $env:COMPUTERNAME,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceAddress,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $EmailSvcAccount
    )

    if($Ensure -eq "Absent")
    {
        throw [Exception] ("MIM DSC does not support uninstalling MIM Service. Please remove it manually.")
        return
    }

    else
    {
        $current = Get-TargetResource @PSBoundParameters
        if($current.Ensure -eq "Absent")
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

