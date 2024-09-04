param (
    [string]$ipConfigurationType,
    [string]$ipAddress,
    [int]$prefixLength,
    [string]$defaultGateway,
    [string]$dns1,
    [string]$dns2,
    [string]$domain,
    [string]$workgroup
)

function Get-SubnetMask {
    param (
        [int]$PrefixLength
    )

    $binary = '1' * $PrefixLength + '0' * (32 - $PrefixLength)
    $octets = @()
    for ($i = 0; $i -lt 4; $i++) {
        $octet = $binary.Substring($i * 8, 8)
        $octets += [Convert]::ToByte($octet, 2)
    }
    return "$($octets[0]).$($octets[1]).$($octets[2]).$($octets[3])"
}

function Get-PrimaryNetworkAdapter {
    $interfaces = netsh interface show interface
    foreach ($line in $interfaces) {
        if ($line -match "Connected") {
            $interfaceName = $line -split '\s{2,}' | Select-Object -Last 1
            return $interfaceName.Trim()
        }
    }
    return $null
}

function Get-CurrentIPConfiguration {
    param (
        [string]$AdapterName
    )
    $config = netsh interface ip show config name="$AdapterName"
    $ipInfo = @{
        IPAddress = $null
        SubnetMask = $null
        DefaultGateway = $null
    }
    foreach ($line in $config) {
        if ($line -match "IP Address") {
            $ipInfo.IPAddress = ($line -split ':')[1].Trim()
        } elseif ($line -match "Subnet Mask") {
            $ipInfo.SubnetMask = ($line -split ':')[1].Trim()
        } elseif ($line -match "Default Gateway") {
            $ipInfo.DefaultGateway = ($line -split ':')[1].Trim()
        }
    }
    return $ipInfo
}

$adapterName = Get-PrimaryNetworkAdapter

if ($adapterName) {
    Write-Output "Using Network Adapter: $adapterName"
    Write-Output "IP Configuration Type: $ipConfigurationType"
    Write-Output "IP Address: $ipAddress"
    Write-Output "Subnet Prefix: $prefixLength"
    Write-Output "Default Gateway: $defaultGateway"
    Write-Output "DNS1: $dns1"
    Write-Output "DNS2: $dns2"
    Write-Output "Domain: $domain"
    Write-Output "Workgroup: $workgroup"

    $currentConfig = Get-CurrentIPConfiguration -AdapterName $adapterName
    $subnetMask = Get-SubnetMask -PrefixLength $prefixLength

    if ($ipConfigurationType -eq 'static') {
        if ($currentConfig.IPAddress -ne $ipAddress -or
            $currentConfig.SubnetMask -ne $subnetMask -or
            $currentConfig.DefaultGateway -ne $defaultGateway) {
            netsh interface ip set address name="$adapterName" static $ipAddress $subnetMask $defaultGateway
            Write-Output "Static IP address set successfully on '$adapterName'."
            netsh interface ip set dns name="$adapterName" static $dns1 primary
            if ($dns2) {
                netsh interface ip add dns name="$adapterName" $dns2 index=2
            }
            Write-Output "DNS servers set successfully on '$adapterName'."
        } else {
            Write-Output "IP configuration for '$adapterName' is already up-to-date."
        }
    } elseif ($ipConfigurationTy
