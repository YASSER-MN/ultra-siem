# 🛡️ Ultra SIEM - Windows Event Log Collector
# Professional Windows Event Log ingestion for Ultra SIEM
# Collects Security, System, and Application logs in real-time

param(
    [string]$NatsUrl = "nats://admin:ultra_siem_admin_2024@localhost:4222",
    [int]$CollectionInterval = 5,
    [string]$LogLevel = "Security,System,Application",
    [switch]$Verbose
)

# Import required modules
Add-Type -AssemblyName System.Web.Extensions

# Global variables
$global:lastEventIds = @{
    "Security" = 0
    "System" = 0
    "Application" = 0
}

# Event schema for Ultra SIEM
class UltraSIEMEvent {
    [string]$id
    [long]$timestamp
    [string]$source_ip
    [string]$destination_ip
    [string]$event_type
    [int]$severity
    [string]$message
    [string]$raw_message
    [string]$log_source
    [string]$user
    [string]$hostname
    [string]$process
    [string]$event_id
    [string]$event_category
    [hashtable]$metadata
}

# Initialize NATS connection
function Initialize-NatsConnection {
    try {
        # Use .NET NATS client for PowerShell
        $natsAssembly = [System.Reflection.Assembly]::LoadWithPartialName("NATS.Client")
        if (-not $natsAssembly) {
            Write-Error "NATS client not available. Using HTTP fallback."
            return $null
        }
        
        $connectionFactory = New-Object NATS.Client.ConnectionFactory
        $connection = $connectionFactory.CreateConnection($NatsUrl)
        Write-Host "✅ Connected to NATS at $NatsUrl" -ForegroundColor Green
        return $connection
    }
    catch {
        Write-Warning "NATS connection failed. Using HTTP fallback to Go bridge."
        return $null
    }
}

# Send event via HTTP to Go bridge (fallback)
function Send-EventViaHttp {
    param([UltraSIEMEvent]$Event)
    
    try {
        $json = $Event | ConvertTo-Json -Depth 10
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "http://localhost:8080/events" -Method POST -Body $json -Headers $headers -TimeoutSec 5
        if ($Verbose) {
            Write-Host "📤 Event sent via HTTP: $($Event.event_id)" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Warning "HTTP fallback failed: $($_.Exception.Message)"
    }
}

# Normalize Windows Event Log to Ultra SIEM schema
function Convert-WindowsEventToUltraSIEM {
    param([System.Diagnostics.Eventing.Reader.EventLogRecord]$Event)
    
    $ultraEvent = [UltraSIEMEvent]::new()
    $ultraEvent.id = [guid]::NewGuid().ToString()
    $ultraEvent.timestamp = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    $ultraEvent.log_source = "windows_event_log"
    $ultraEvent.event_id = $Event.Id.ToString()
    $ultraEvent.event_category = $Event.ProviderName
    $ultraEvent.hostname = $env:COMPUTERNAME
    $ultraEvent.raw_message = $Event.FormatDescription()
    
    # Extract user information
    try {
        $userProperty = $Event.Properties | Where-Object { $_.Name -eq "TargetUserName" -or $_.Name -eq "SubjectUserName" }
        if ($userProperty) {
            $ultraEvent.user = $userProperty.Value
        }
    }
    catch {
        $ultraEvent.user = "SYSTEM"
    }
    
    # Extract IP addresses from event data
    try {
        $ipProperties = $Event.Properties | Where-Object { $_.Value -match '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' }
        if ($ipProperties) {
            $ips = $ipProperties.Value -split '\s+' | Where-Object { $_ -match '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' }
            if ($ips.Count -ge 1) {
                $ultraEvent.source_ip = $ips[0]
            }
            if ($ips.Count -ge 2) {
                $ultraEvent.destination_ip = $ips[1]
            }
        }
    }
    catch {
        $ultraEvent.source_ip = "127.0.0.1"
    }
    
    # Determine event type and severity based on Event ID
    switch ($Event.Id) {
        # Security Events
        4624 { # Successful logon
            $ultraEvent.event_type = "successful_login"
            $ultraEvent.severity = 2
            $ultraEvent.message = "Successful login: $($ultraEvent.user) from $($ultraEvent.source_ip)"
        }
        4625 { # Failed logon
            $ultraEvent.event_type = "failed_login"
            $ultraEvent.severity = 4
            $ultraEvent.message = "Failed login attempt: $($ultraEvent.user) from $($ultraEvent.source_ip)"
        }
        4634 { # Logoff
            $ultraEvent.event_type = "user_logoff"
            $ultraEvent.severity = 1
            $ultraEvent.message = "User logoff: $($ultraEvent.user)"
        }
        4647 { # User initiated logoff
            $ultraEvent.event_type = "user_logoff"
            $ultraEvent.severity = 1
            $ultraEvent.message = "User initiated logoff: $($ultraEvent.user)"
        }
        4672 { # Special privileges assigned
            $ultraEvent.event_type = "privilege_escalation"
            $ultraEvent.severity = 5
            $ultraEvent.message = "Special privileges assigned: $($ultraEvent.user)"
        }
        4688 { # Process creation
            $ultraEvent.event_type = "process_creation"
            $ultraEvent.severity = 3
            $ultraEvent.message = "Process created: $($Event.Properties[5].Value)"
        }
        4700 { # Scheduled task creation
            $ultraEvent.event_type = "scheduled_task_creation"
            $ultraEvent.severity = 3
            $ultraEvent.message = "Scheduled task created: $($Event.Properties[0].Value)"
        }
        4719 { # System audit policy changed
            $ultraEvent.event_type = "audit_policy_change"
            $ultraEvent.severity = 4
            $ultraEvent.message = "System audit policy changed"
        }
        4720 { # Account created
            $ultraEvent.event_type = "account_creation"
            $ultraEvent.severity = 4
            $ultraEvent.message = "Account created: $($ultraEvent.user)"
        }
        4722 { # Account enabled
            $ultraEvent.event_type = "account_enabled"
            $ultraEvent.severity = 3
            $ultraEvent.message = "Account enabled: $($ultraEvent.user)"
        }
        4724 { # Password reset
            $ultraEvent.event_type = "password_reset"
            $ultraEvent.severity = 4
            $ultraEvent.message = "Password reset: $($ultraEvent.user)"
        }
        4728 { # Member added to security group
            $ultraEvent.event_type = "group_membership_change"
            $ultraEvent.severity = 4
            $ultraEvent.message = "Member added to security group: $($ultraEvent.user)"
        }
        4732 { # Member added to admin group
            $ultraEvent.event_type = "admin_group_change"
            $ultraEvent.severity = 5
            $ultraEvent.message = "Member added to admin group: $($ultraEvent.user)"
        }
        4740 { # Account locked out
            $ultraEvent.event_type = "account_locked"
            $ultraEvent.severity = 4
            $ultraEvent.message = "Account locked out: $($ultraEvent.user)"
        }
        4767 { # Account unlocked
            $ultraEvent.event_type = "account_unlocked"
            $ultraEvent.severity = 3
            $ultraEvent.message = "Account unlocked: $($ultraEvent.user)"
        }
        4771 { # Kerberos pre-authentication failed
            $ultraEvent.event_type = "kerberos_failure"
            $ultraEvent.severity = 4
            $ultraEvent.message = "Kerberos pre-authentication failed: $($ultraEvent.user)"
        }
        4776 { # Credential validation
            $ultraEvent.event_type = "credential_validation"
            $ultraEvent.severity = 3
            $ultraEvent.message = "Credential validation: $($ultraEvent.user)"
        }
        1102 { # Audit log cleared
            $ultraEvent.event_type = "audit_log_cleared"
            $ultraEvent.severity = 5
            $ultraEvent.message = "Audit log cleared - potential security incident"
        }
        default {
            $ultraEvent.event_type = "windows_event"
            $ultraEvent.severity = 2
            $ultraEvent.message = "Windows Event ID $($Event.Id): $($Event.ProviderName)"
        }
    }
    
    # Add metadata
    $ultraEvent.metadata = @{
        "EventRecordID" = $Event.RecordId
        "TimeCreated" = $Event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        "ProviderName" = $Event.ProviderName
        "Level" = $Event.Level
        "Keywords" = $Event.Keywords
        "MachineName" = $Event.MachineName
    }
    
    return $ultraEvent
}

# Collect Windows Event Logs
function Get-WindowsEvents {
    param([string]$LogName, [int]$LastEventId)
    
    try {
        $query = "*[System[EventRecordID>$LastEventId]]"
        $events = Get-WinEvent -LogName $LogName -FilterXPath $query -ErrorAction SilentlyContinue
        
        if ($events) {
            $maxEventId = ($events | Measure-Object -Property RecordId -Maximum).Maximum
            $global:lastEventIds[$LogName] = $maxEventId
            
            foreach ($event in $events) {
                $ultraEvent = Convert-WindowsEventToUltraSIEM -Event $event
                
                # Send to NATS or HTTP fallback
                if ($natsConnection) {
                    try {
                        $json = $ultraEvent | ConvertTo-Json -Depth 10
                        $natsConnection.Publish("ultra_siem.events", [System.Text.Encoding]::UTF8.GetBytes($json))
                        if ($Verbose) {
                            Write-Host "📤 Event sent to NATS: $($ultraEvent.event_type) - $($ultraEvent.event_id)" -ForegroundColor Green
                        }
                    }
                    catch {
                        Write-Warning "NATS publish failed, using HTTP fallback"
                        Send-EventViaHttp -Event $ultraEvent
                    }
                }
                else {
                    Send-EventViaHttp -Event $ultraEvent
                }
            }
            
            Write-Host "📊 Collected $($events.Count) events from $LogName (Max ID: $maxEventId)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "Error collecting events from $LogName`: $($_.Exception.Message)"
    }
}

# Main collection loop
function Start-EventCollection {
    Write-Host "🚀 Ultra SIEM Windows Event Log Collector Starting..." -ForegroundColor Green
    Write-Host "📡 NATS URL: $NatsUrl" -ForegroundColor Cyan
    Write-Host "⏱️ Collection Interval: $CollectionInterval seconds" -ForegroundColor Cyan
    Write-Host "📋 Log Sources: $LogLevel" -ForegroundColor Cyan
    
    # Initialize NATS connection
    $script:natsConnection = Initialize-NatsConnection
    
    # Parse log sources
    $logSources = $LogLevel -split ','
    
    # Initialize last event IDs
    foreach ($log in $logSources) {
        try {
            $lastEvent = Get-WinEvent -LogName $log -MaxEvents 1 -ErrorAction SilentlyContinue
            if ($lastEvent) {
                $global:lastEventIds[$log] = $lastEvent.RecordId
                Write-Host "📊 Initialized $log with last Event ID: $($lastEvent.RecordId)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Warning "Could not initialize $log`: $($_.Exception.Message)"
        }
    }
    
    Write-Host "✅ Starting real-time event collection..." -ForegroundColor Green
    
    # Main collection loop
    while ($true) {
        try {
            foreach ($logSource in $logSources) {
                Get-WindowsEvents -LogName $logSource -LastEventId $global:lastEventIds[$logSource]
            }
            
            Start-Sleep -Seconds $CollectionInterval
        }
        catch {
            Write-Error "Collection error: $($_.Exception.Message)"
            Start-Sleep -Seconds 10
        }
    }
}

# Handle script termination
Register-EngineEvent PowerShell.Exiting -Action {
    Write-Host "🛑 Ultra SIEM Windows Event Log Collector stopping..." -ForegroundColor Red
    if ($script:natsConnection) {
        $script:natsConnection.Close()
    }
}

# Start collection
Start-EventCollection 