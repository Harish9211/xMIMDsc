function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
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
        $serviceAddress,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )

    Write-Verbose "Getting install status of MIM Service."

    $installStatus = $null
    $MimStatus = Get-CurrentMIM
    if($MimStatus -eq $null)
    {
        Write-Verbose "MIM Service not installed on this computer."
        $Ensure = "Absent"
        
    }
    elseif($MimStatus -ne $null)
    {
        $ver = $MimStatus.Version
        Write-Verbose "MIM Service is already installed on this computer. MIM Version $ver"
        $Ensure = "Present"
    }
    
        
    
    $returnValue = @{
    Ensure = $Ensure
    ProductId = $productId
    SQLServerInstance = $sqlServerInstance
    SQLServerDB = $sqlServerDb
    ServiceServer = $serviceServer
    SyncServer = $syncServer
    SyncServiceAccount = $syncServiceAccount
    MailServer = $mailServer
    ServiceAddress = $serviceAddress
    }

    $returnValue
    
}


function Set-TargetResource
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
        $serviceAddress, 
        
        [Parameter()]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )

    if($Ensure -eq "Absent")
    {
        throw [Exception] ("MIM DSC does not support uninstalling MIM Service. Please remove it manually.")
        return
    }
    
    Install-MimSvc -setupFiles $setupFiles -productId $productId -sqlServerInstance $sqlServerInstance `
    -sqlServerDb $sqlServerDb -mimSvcAccount $mimSvcAccount -emailSvcAccount $emailSvcAccount -serviceServer $serviceServer `
    -syncServer $syncServer -syncServiceAccount $syncServiceAccount -mailServer $mailServer -useExistingDatabase $useExistingDatabase `
    -serviceAddress $serviceServer -Verbose
    
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
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
        $serviceAddress,

        [Parameter()]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )

    Write-Verbose "Testing MIM Service Install Status"
    $PSBoundParameters.Ensure = $Ensure
    if($Ensure -eq "Absent")
    {
        throw [Exception] ("MIM DSC does not support uninstalling MIM Service. Please remove it manually.")
        return
    }

    $currentStatus = Get-TargetResource @PSBoundParameters
    if($currentStatus.Ensure -eq "Present")
    {
        return $true
    }
    elseif($currentStatus.Ensure -eq "Absent")
    {
        return $false
    }
}


Export-ModuleMember -Function *

