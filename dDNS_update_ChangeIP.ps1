# PowerShell script for updating dDNS with ChangeIP.com
# Written 5/31/24 by Todd Maxey
# Updated 6/2/24 by Todd Maxey
# Released to the Public Domain

# Script Variables
$IPPATH = "C:\temp\IP"
$TMPIP = "C:\temp\tmpIP"
$LOGPATH = "C:\temp\changeip.log"
$TEMP = "C:\temp\temp"
$CIPUSER = "Jardani_Jovonovich" # USERNAME
$CIPPASS = "D@1$yL1v3$F0r3v3r1nMy<3" # PASSWORD
$CIPSET = 1 # DDNS SET 1 or 2
$LOGLEVEL = 2
$LOGMAX = 500

# Ensure directories and files exist
$paths = @($IPPATH, $TMPIP, $LOGPATH, $TEMP)
foreach ($path in $paths) {
    $directory = Split-Path $path -Parent
    if (-Not (Test-Path $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    if (-Not (Test-Path $path)) {
        New-Item -ItemType File -Force -Path $path | Out-Null
    }
}

# Get current IP from ip.changeip.com and store in $TEMP
try {
    Invoke-WebRequest -Uri "http://ip.changeip.com" -UserAgent "maxey.ps1 Invoke-WebRequest" -OutFile $TEMP
} catch {
    Write-Error "Failed to fetch IP from ip.changeip.com: $_"
    exit 1
}

# Read IP content from $TEMP
try {
    $ipContent = Get-Content $TEMP
    Write-Output "IP Content: $ipContent" # Log the IP content for debugging

    # Extract IP address using regex
    $ipPattern = '([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})'
    $currentIP = [regex]::Match($ipContent, $ipPattern).Value

    if (-not $currentIP) {
        throw "Unable to parse IP address from response: $ipContent"
    }
    
    Write-Output "Parsed IP: $currentIP"
    $currentIP | Out-File -FilePath $TMPIP -Encoding ASCII
} catch {
    Write-Error $_
    exit 1
}

# Compare $IPPATH with $TMPIP, and if different, execute update
$currentIPContent = if (Test-Path $IPPATH) { Get-Content $IPPATH } else { "" }
$newIPContent = Get-Content $TMPIP

Write-Output "Current IP Content: $currentIPContent"
Write-Output "New IP Content: $newIPContent"

if ($currentIPContent -ne $newIPContent) {
    # Different IP, execute update
    try {
        Invoke-WebRequest -Uri "https://nic.changeip.com/nic/update?u=$CIPUSER&p=$CIPPASS&set=$CIPSET" -UserAgent "maxey.ps1 Invoke-WebRequest" -OutFile $TEMP
        if ($LOGLEVEL -ne 0) {
            # If logging, log update
            Add-Content -Path $LOGPATH -Value "--------------------------------"
            Add-Content -Path $LOGPATH -Value (Get-Date)
            Add-Content -Path $LOGPATH -Value "Updating"
            Add-Content -Path $LOGPATH -Value "NewIP: $newIPContent"
            if ($LOGLEVEL -eq 2) {
                # Verbose logging
                Add-Content -Path $LOGPATH -Value "OldIP: $currentIPContent"
                Add-Content -Path $LOGPATH -Value (Get-Content $TEMP)
            }
        }
        # Store new IP
        Copy-Item -Path $TMPIP -Destination $IPPATH -Force
    } catch {
        Write-Error "Failed to update IP: $_"
        exit 1
    }
} else {
    # Same IP, no update
    if ($LOGLEVEL -eq 2) {
        # If verbose, log no change
        Add-Content -Path $LOGPATH -Value "--------------------------------"
        Add-Content -Path $LOGPATH -Value (Get-Date)
        Add-Content -Path $LOGPATH -Value "No Change"
        Add-Content -Path $LOGPATH -Value "IP: $currentIPContent"
    }
}

# If $LOGMAX not equal to 0, reduce log size to last $LOGMAX number of lines
if ($LOGMAX -ne 0) {
    try {
        $logContent = Get-Content -Path $LOGPATH
        if ($logContent.Count -gt $LOGMAX) {
            $logContent[-$LOGMAX..-1] | Out-File -FilePath $LOGPATH
        }
    } catch {
        Write-Error "Failed to trim log file: $_"
        exit 1
    }
}
