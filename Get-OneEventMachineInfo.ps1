#Author RChapman
#10/2018
#Get event log data and machine IP
<#
    TODO: Add help info

#>

[cmdletBinding()]
param(
    # List of computers to gather information form 
    [Parameter(ValueFromPipeline = $false, Mandatory = $false)]
    [string[]]
    $pComputerList,
    
    # Event Id to search for
    [Parameter(ValueFromPipeline = $false)]
    [int]
    $pEventId = 513,

    # Log to query
    [Parameter(ValueFromPipeline = $false)]
    [string]
    $pEventLog = "Microsoft-Windows-PrintService/Admin",

    # Credential Object
    [Parameter(ValueFromPipeline = $false)]
    [pscredential]
    $pCredential = (Get-Credential),

    #Last N days events
    [Parameter(ValueFromPipeline = $false)]
    [int]
    $pNDaysOld = 2
)


    $today = Get-Date
    $oldestDate = $today.AddDays(-$pNDaysOld)

    Write-Verbose "Today: $today"
    Write-Verbose "Oldest Date: $oldestDate"

    foreach($comp in $pComputerList){
        $c = $comp.Trim()
        
        if($(Test-Connection -Quiet $c) -eq $true){
            Write-Verbose "Computer: $c"
            $ip = (Get-WmiObject -Class Win32_NetWorkAdapterConfiguration -ComputerName $c -Credential $pCredential -Filter {ServiceName = 'e1dexpress'}).IPAddress[0]
            $events = $(Get-WinEvent -LogName $pEventLog -ComputerName $c | Where-Object {$_.Id -EQ $pEventId -and $_.TimeCreated -ge $oldestDate } | Select-Object TimeCreated, Id, Message, MachineName)

            #$events = (Get-WinEvent -LogName "Microsoft-Windows-PrintService/Admin" -ComputerName $c -Credential $pCredential | Where-Object {$_.Id -EQ 513} | Select-Object TimeCreated, Id, Message, MachineName)    

            #Write-Output "`n" | Out-File -FilePath E:Events.txt -Append
            #$events | Out-File -Append -FilePath E:\Events.txt    
            $events | ForEach-Object{
                #Write-Output $_.TimeCreated $ip
                $props = @{
                    "EventDate" = $_.TimeCreated;
                    "EventId" = $_.Id;
                    "Message" = $_.Message;
                    "MachineName" = $_.MachineName;
                    "IP" = $ip;
                }
                $outputObject = New-Object -TypeName psobject -Property $props
                $outputObject
            }
        } else {
            Write-Verbose "$c is not online"
        }
    }

