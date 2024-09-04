Configuration NetworkConfig {
    param (
        [string]$ComputerName,
        [string]$IPConfigurationType,
        [string]$IPAddress,
        [string]$SubnetPrefix,
        [string]$DefaultGateway,
        [string]$PreferredDNS,
        [string]$AlternativeDNS,
        [string]$Domain,
        [string]$Workgroup
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $ComputerName {
        # Find the network interface alias
        $interfaceAlias = (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }).Name

        if ($IPConfigurationType -eq "static") {
            # Configure static IP
            Script SetStaticIP {
                GetScript = {
                    # Script to check current IP configuration
                    $interface = Get-NetAdapter | Where-Object { $_.Name -eq $using:interfaceAlias }
                    $currentIP = Get-NetIPAddress -InterfaceAlias $interfaceAlias
                    if ($currentIP.IPAddress -ne $using:IPAddress) {
                        return $true
                    }
                    return $false
                }
                SetScript = {
                    # Script to apply static IP configuration
                    New-NetIPAddress -InterfaceAlias $using:interfaceAlias -IPAddress $using:IPAddress -PrefixLength $using:SubnetPrefix -DefaultGateway $using:DefaultGateway
                    Set-DnsClientServerAddress -InterfaceAlias $using:interfaceAlias -ServerAddresses $using:PreferredDNS, $using:AlternativeDNS
                }
                TestScript = {
                    # Test if IP is set correctly
                    $currentIP = Get-NetIPAddress -InterfaceAlias $using:interfaceAlias
                    $dns = Get-DnsClientServerAddress -InterfaceAlias $using:interfaceAlias
                    $currentIP.IPAddress -eq $using:IPAddress -and $dns.ServerAddresses -contains $using:PreferredDNS -and $dns.ServerAddresses -contains $using:AlternativeDNS
                }
            }
        } elseif ($IPConfigurationType -eq "dynamic") {
            # Configure DHCP
            Script SetDHCP {
                GetScript = {
                    $interface = Get-NetAdapter | Where-Object { $_.Name -eq $using:interfaceAlias }
                    $currentIP = Get-NetIPAddress -InterfaceAlias $interfaceAlias
                    if ($currentIP.IPAddress) {
                        return $true
                    }
                    return $false
                }
                SetScript = {
                    # Script to apply DHCP configuration
                    Remove-NetIPAddress -InterfaceAlias $using:interfaceAlias -Confirm:$false
                    Set-DnsClientServerAddress -InterfaceAlias $using:interfaceAlias -ServerAddresses $using:PreferredDNS, $using:AlternativeDNS
                }
                TestScript = {
                    # Test if DHCP is set correctly
                    $currentIP = Get-NetIPAddress -InterfaceAlias $using:interfaceAlias
                    $dns = Get-DnsClientServerAddress -InterfaceAlias $using:interfaceAlias
                    -not $currentIP.IPAddress -and $dns.ServerAddresses -contains $using:PreferredDNS -and $dns.ServerAddresses -contains $using:AlternativeDNS
                }
            }
        }

        if ($Domain) {
            # Join Domain
            Computer JoinDomain {
                Name = $ComputerName
                DomainName = $Domain
                Credential = $Credential
                Restart = $true
            }
        } elseif ($Workgroup) {
            # Join Workgroup
            Computer JoinWorkgroup {
                Name = $ComputerName
                WorkGroupName = $Workgroup
                Credential = $Credential
                Restart = $true
            }
        }
    }
}
