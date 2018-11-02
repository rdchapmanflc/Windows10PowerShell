
<# Script: Set-ADSILocalUserPassword
# Author: R Chapman
# Date: 5-21-2018
# Description: Using  ADSI and a DirectoryEntry object changes a local
# account password on a domain joined system.  Script must execute in
# context of an administrator on the remote system.
# Use at your own risk, know what this commandlet does before using.
#>

<#
    .SYNOPSIS
        Changes a local user password on domain joined system
    .DESCRIPTION
        Using  ADSI and a DirectoryEntry object changes a local
        account password on a domain joined system.  Script must execute in
        context of an administrator on the remote system.
    .PARAMETER pComputerName
        The domain joined computer that has the local account you'd like to change
    .PARAMETER pLocalUserName
        The user name whose password you'd like to change
    .PARAMETER pForceNewPasswordRequest
        Switch parameter to force prompting of a new password
    .PARAMETER pCleanupPWWhenDone
        Deletes the pw file after attempting to change password.  If password change fails pw file will
        still be deleted. 
    .EXAMPLE
        Set-ADSILocalUserPassword -pComputerName someHostOnTheNetwork -pLocalUserName ccadmin
    .EXAMPLE
        Set-ADSILocalUserPassword -pComputerName someHostOnTheNetwork -pLocalUserName ccadmin -pCleanupPWWhenDone
#>
[CmdletBinding()]

param(
    # Parameter Hostname: The name of the host whos local user password you'd like to change
    [Parameter(Mandatory = $true,
            ValueFromPipeline = $false)]
        [string] $pComputerName,

    # Parameter LocalUserName: The local user account to affect
    [Parameter(Mandatory = $true,
            ValueFromPipeline = $false)]
    [String] $pLocalUserName,

    # Parameter ForceNewPasswordRequest: Force prompting for new password and write to pw file
    [Parameter(Mandatory = $false,
        ValueFromPipeline = $false)]
    [switch] $pForceNewPasswordRequest,

    #Parameter CleanupPWWhenDone
    [Parameter(Mandatory = $false,
        ValueFromPipeline = $false)]
    [switch] $pCleanupPWWhenDone
)
begin
{
    Write-Verbose "Working on computer $pComputerName"
    Write-Verbose "Local user to affect will be $pLocalUserName"

    If($(Test-Connection -Quiet -ComputerName $pComputerName))
    {
        Write-Verbose "$pComputerName is reachable on the network."
    }
    Else
    {
        #Host is not reachable
        Write-Error "Host is not reacahable"
        Exit -100
    }

    #Test for PW file
    If(($(Test-Path -Path pw) -ne $true) `
        -or ($pForceNewPasswordRequest -eq $true))
    {
        #as secure string
        $pass = Read-Host -Prompt "Enter password:" -AsSecureString

        #encrypted string
        $pass | ConvertFrom-SecureString | Out-File -FilePath pw -ErrorAction Stop
    }
}

process
{
   
    if($(Test-Path -Path pw))
    {
        $errorCode = 0
        #secure string
        $pass = Get-Content -Path pw -ErrorAction Stop | ConvertTo-SecureString

        #unsecured
        $plain = (New-Object -TypeName PSCredential "user",$pass).GetNetworkCredential().Password

        [string]$computer = [string]::Format("WinNT://{0}/{1}",$pComputerName,$pLocalUserName)

        $DirectoryEntry = New-Object -TypeName System.DirectoryServices.DirectoryEntry -ArgumentList $computer

        Write-Verbose "Setting password for User: $pLocalUserName, on Computer: $pComputerName"

        try 
        {
            $DirectoryEntry.Invoke("SetPassword",$plain)
        }
        catch 
        {
            Write-Error "Exception: Could not set password for Computer: $pComputerName, User: $pLocalUserName"
            $errorCode = -101
        }
        if($errorCode -eq 0)
        {
            Write-Host "Password for User: $pLocalUserName changed on Computer: $pComputerName"
        }

    }

}

end
{
    #clean up variables
    Remove-Variable -Name plain 
    Remove-Variable -Name pass

    If($pCleanupPWWhenDone -eq $true)
    {
        Remove-Item -Path pw -Force
    }
}