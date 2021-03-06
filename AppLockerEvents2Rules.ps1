$statistics = @{
    eventsProcessed = 0
    rulesCreated = 0
    rulesSkipped = 0
    exeSigned = 0
    exeUnsigned = 0
}

# Files:
# eventSources.txt: text file containing list of machines to extract events from
# eventQuery.xml: XML file containing event query
# DefaultAppLockerPolicy.xml: base Applocker policy
# UpdatedAppLockerPolicy.xml: resulting AppLocker policy

$eventSources = Get-Content -Path 'eventSources.txt'
[xml]$eventQuery = Get-Content -Path 'eventQuery.xml'

$eventCollection = @{}

foreach ($pc in $eventSources) {
    Write-Host "Adding $pc"
    $events = Get-WinEvent -FilterXml $eventQuery -Computer $pc -ErrorAction SilentlyContinue
    $eventCollection.Add($pc, $events)
}

# load default policy
[xml]$policy = Get-Content 'DefaultAppLockerPolicy.xml'

# This script only updates the exe rule collection
$ruleCollection = $policy.SelectSingleNode('/AppLockerPolicy/RuleCollection[@Type="Exe"]')

$newRules = @{}

# Iterate through the events that have been harvested from event sources

$eventCollection.GetEnumerator() | ForEach-Object {
    
    Write-Host "Processing events from $($_.key)"
    
    foreach ($event in $_.value) {

        $statistics.eventsProcessed += 1

        [xml]$x = $event.ToXml()
        
        $sys = $x.Event.System
        $rfd = $x.Event.UserData.RuleAndFileData
        
        if ($rfd.Fqbn -match '-') {
        
            # Unsigned executable
            
            $key = $rfd.FileHash
            
            if (-not $newRules.ContainsKey($key)) {
                
                # Create and add the rule
                
                $filename = Split-Path $rfd.FilePath -Leaf
                
                $rule = $policy.CreateNode('element', 'FileHashRule', $null)
                $rule.SetAttribute('Id', [guid]::newguid())
                $rule.SetAttribute('Name', "Auto rule for $filename")
                $rule.SetAttribute('Description', "0x$($rfd.FileHash)")
                
                $conditions = $policy.CreateNode('element','Conditions', $null)
                $fileHashCondition = $policy.CreateNode('element','FileHashCondition', $null)
                $fileHash = $policy.CreateNode('element','FileHash', $null)
                
                $fileHash.SetAttribute('Type', 'SHA256')
                $fileHash.SetAttribute('Data', "0x$($rfd.FileHash)")
                $fileHash.SetAttribute('SourceFileName', $filename)
                $fileHash.SetAttribute('SourceFileLength', '0')
                
                $fileHashCondition.AppendChild($fileHash) | Out-Null
                $conditions.AppendChild($fileHashCondition) | Out-Null
                $rule.AppendChild($conditions) | Out-Null

                $statistics.rulesCreated += 1
                $statistics.exeUnsigned += 1
                
                $newRules.Add($key, $rule)
            }
            
        } else {

            # Signed executable
            
            # Rule granularity:
            # Publisher + Product + Filename
            # Allow any version to run
            
            if ($rfd.Fqbn -notmatch '(?<Publisher>[^\\]+)\\(?<Product>[^\\]+)\\(?<Filename>[^\\]+)\\(?<Version>.*)') {
                # AppID doesn't match our regexp - move along
                $statistics.rulesSkipped += 1
                continue
            }

            $key = "$($Matches.Publisher)\$($Matches.Product)\$($Matches.FileName)"
            
            if (-not $newRules.ContainsKey($key)) {
             
                # Create and add the rule
                
                $rule = $policy.CreateNode('element', 'FilePublisherRule', $null)
                $rule.SetAttribute('Id', [guid]::newguid())
                $rule.SetAttribute('Name', "Auto rule for $($Matches.Product)\$($Matches.FileName)")
                $rule.SetAttribute('Description', $Matches.Publisher)
                
                $conditions = $policy.CreateNode('element','Conditions', $null)
                $filePublisherCondition = $policy.CreateNode('element','FilePublisherCondition', $null)
                $binaryVersionRange = $policy.CreateNode('element','BinaryVersionRange', $null)
                
                $filePublisherCondition.SetAttribute('PublisherName', $Matches.Publisher)
                $filePublisherCondition.SetAttribute('ProductName', $Matches.Product)
                $filePublisherCondition.SetAttribute('BinaryName', $Matches.FileName)

                $binaryVersionRange.SetAttribute('LowSection', '*')
                $binaryVersionRange.SetAttribute('HighSection', '*')
                
                $filePublisherCondition.AppendChild($binaryVersionRange) | Out-Null
                $conditions.AppendChild($filePublisherCondition) | Out-Null
                $rule.AppendChild($conditions) | Out-Null

                $statistics.rulesCreated += 1
                $statistics.exeSigned += 1
                
                $newRules.Add($key, $rule)
            }
            
        }
        
    }

}

# New rules allow Everyone to run the defined executable
# Update and add each rule to the in-memory XML policy document

$newRules.GetEnumerator() | ForEach-Object {
    $rule = $_.value
    $rule.SetAttribute('UserOrGroupSid', 'S-1-1-0')
    $rule.SetAttribute('Action', 'Allow')
    $ruleCollection.AppendChild($rule) | Out-Null
}

# Create the finalised AppLocker policy XML file
# Show off some statistics

$policy.Save('UpdatedAppLockerPolicy.xml')

Write-Host 'Statistics:'
$statistics
