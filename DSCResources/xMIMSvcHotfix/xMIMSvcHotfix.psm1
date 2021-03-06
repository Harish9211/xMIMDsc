function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $MspFileSource,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $VersionToUpdate
    )

    Write-Verbose "Checking current MIM Version"
    $updateStatus = $null
    $current = Get-CurrentMIM
    $version = $current.Version
    if($version -eq "4.4.1302.0" -or $version -lt $VersionToUpdate)
    {
        Write-Verbose "Current MIM SVC version is $version and it will update to $VersionToUpdate."
        $Ensure = "Absent"
    }
    elseif($version -eq $VersionToUpdate)
    {
        Write-Verbose "MIM SVC version is already on requested version"
        $Ensure = "Present"
    }
    
    return @{
        VersionToUpdate = $VersionToUpdate
        Ensure = $Ensure
        }
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $MspFileSource,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $VersionToUpdate
    )

    if($Ensure -eq "Absent")
    {
        throw [Exception] ("MIM DSC does not support uninstalling MIM Hostifx. Please remove it manually.")
        return
    }

    Write-Verbose "Starting MIM Service update.."
    Update-MimSvc -SourceFile $MspFileSource -Verbose
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $MspFileSource,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $VersionToUpdate
    )

    $get = Get-TargetResource @PSBoundParameters
    if($get.Ensure -eq "Absent")
    {
        return $false
    }
    else
    {
        return $true
    }
}


Export-ModuleMember -Function *-TargetResource

