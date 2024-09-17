# Global proxy settings
$global:ProxyHost = "127.0.0.1"
$global:ProxyPort = "1080"
$global:HttpProxy = "http://$($global:ProxyHost):$($global:ProxyPort)"
$global:HttpsProxy = "http://$($global:ProxyHost):$($global:ProxyPort)"
$global:NoProxy = "localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

# Print the values to verify
Write-Host "HttpProxy: $global:HttpProxy"
Write-Host "HttpsProxy: $global:HttpsProxy"

function Format-BypassList {
    $noProxyList = $global:NoProxy -split ','
    $formattedList = @()
    
    foreach ($item in $noProxyList) {
        if ($item -eq "localhost" -or $item -eq "127.0.0.1") {
            if (-not ($formattedList -contains "<local>")) {
                $formattedList += "<local>"
            }
        } else {
            $formattedList += $item
        }
    }
    
    return ($formattedList -join ';')
}

$global:BypassList = Format-BypassList

function Update-MavenProxy {
    param (
        [string]$MavenSettingsPath = "$env:USERPROFILE\.m2\settings.xml",
        [string]$HttpProxy,
        [string]$HttpsProxy,
        [string]$NoProxy,
        [string]$ProxyUsername = "",
        [string]$ProxyPassword = ""
    )

    # Check if settings.xml exists, if not, create it with the default structure
    if (-Not (Test-Path $MavenSettingsPath)) {
        if (-Not (Test-Path "$env:USERPROFILE\.m2")) {
            New-Item -Path "$env:USERPROFILE\.m2" -ItemType Directory
        }
        
        @"
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              http://maven.apache.org/xsd/settings-1.0.0.xsd">
</settings>
"@ | Out-File -FilePath $MavenSettingsPath -Encoding utf8
    }

    [xml]$xml = Get-Content $MavenSettingsPath

    # Remove existing proxy elements
    $existingProxies = $xml.settings.proxies.proxy
    foreach ($proxy in $existingProxies) {
        $xml.settings.proxies.RemoveChild($proxy) | Out-Null
    }

    if (-Not $xml.settings.proxies) {
        $proxiesNode = $xml.CreateElement("proxies")
        $xml.settings.AppendChild($proxiesNode) | Out-Null
    }

    $proxy = $xml.CreateElement("proxy")
    $proxy.AppendChild($xml.CreateElement("active")).InnerText = "true"
    $proxy.AppendChild($xml.CreateElement("protocol")).InnerText = "http"
    $proxy.AppendChild($xml.CreateElement("host")).InnerText = ($HttpProxy -split ':')[1].Trim('/')
    $proxy.AppendChild($xml.CreateElement("port")).InnerText = ($HttpProxy -split ':')[-1]

    if ($ProxyUsername -and $ProxyPassword) {
        $proxy.AppendChild($xml.CreateElement("username")).InnerText = $ProxyUsername
        $proxy.AppendChild($xml.CreateElement("password")).InnerText = $ProxyPassword
    }

    $proxy.AppendChild($xml.CreateElement("nonProxyHosts")).InnerText = $NoProxy.Replace(",", "|")

    $xml.settings.proxies.AppendChild($proxy) | Out-Null
    $xml.Save($MavenSettingsPath)

    Write-Host "Maven proxy settings updated in $MavenSettingsPath"

}

function Update-WindowsProxy {
    param (
        [string]$HttpProxy,
        [string]$HttpsProxy,
        [string]$NoProxy
    )

    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -Value $HttpProxy
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 1
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyOverride -Value $NoProxy

    $signature = @'
[DllImport("wininet.dll", SetLastError = true, CharSet=CharSet.Auto)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@

    $type = Add-Type -MemberDefinition $signature -Name WinINet -Namespace pinvoke -PassThru
    $type::InternetSetOption(0, 39, 0, 0) | Out-Null
    $type::InternetSetOption(0, 37, 0, 0) | Out-Null

    Write-Host "Windows proxy settings updated and enabled"
    Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Select-Object ProxyServer, ProxyEnable, ProxyOverride
}

function Update-GitProxy {
    param (
        [string]$HttpProxy,
        [string]$HttpsProxy,
        [string]$NoProxy
    )

    $sshConfigPath = "$env:USERPROFILE\.ssh\config"
    @"
Host github.com
    Hostname ssh.github.com
    Port 443
    User git
"@ | Out-File -Append -FilePath $sshConfigPath -Encoding utf8

    git config --global http.proxy $HttpProxy
    git config --global https.proxy $HttpsProxy

    Write-Host "Git proxy settings updated"
    $gitProxy = git config --get http.proxy
    Write-Host "Current Git HTTP Proxy: $gitProxy"

    $gitHttpsProxy = git config --get https.proxy
    Write-Host "Current Git HTTPS Proxy: $gitHttpsProxy"
}

function Update-NpmProxy {
    param (
        [string]$HttpProxy,
        [string]$HttpsProxy,
        [string]$NoProxy
    )

    npm config set proxy $HttpProxy
    npm config set https-proxy $HttpsProxy

    Write-Host "NPM proxy settings updated"

    $npmProxy = npm config get proxy
    Write-Host "Current NPM Proxy: $npmProxy"

    $npmHttpsProxy = npm config get https-proxy
    Write-Host "Current NPM HTTPS Proxy: $npmHttpsProxy"
}

function Update-DockerProxy {
    param (
        [string]$HttpProxy,
        [string]$HttpsProxy,
        [string]$NoProxy
    )

    $dockerConfigPath = "$env:USERPROFILE\.docker\config.json"

    if (Test-Path $dockerConfigPath) {
        $json = Get-Content $dockerConfigPath | ConvertFrom-Json
    } else {
        $json = @{}
    }

    $json.proxies.default = @{
        httpProxy  = $HttpProxy
        httpsProxy = $HttpsProxy
        noProxy    = $NoProxy
    }

    $json | ConvertTo-Json -Depth 10 | Set-Content $dockerConfigPath

    Write-Host "Docker proxy settings updated"
}

function Update-AllProxySettings {
    param (
        [string]$HttpProxy,
        [string]$HttpsProxy,
        [string]$NoProxy
    )

    Update-MavenProxy -HttpProxy $HttpProxy -HttpsProxy $HttpsProxy -NoProxy $NoProxy
    Update-WindowsProxy -HttpProxy $HttpProxy -HttpsProxy $HttpsProxy -NoProxy $NoProxy
    Update-GitProxy -HttpProxy $HttpProxy -HttpsProxy $HttpsProxy -NoProxy $NoProxy
    Update-NpmProxy -HttpProxy $HttpProxy -HttpsProxy $HttpsProxy -NoProxy $NoProxy
    Update-DockerProxy -HttpProxy $HttpProxy -HttpsProxy $HttpsProxy -NoProxy $NoProxy

    Write-Host "All proxy settings have been updated successfully."
}


Write-Host "Environment Variables Defined:"
Write-Host "ProxyHost: $global:ProxyHost"
Write-Host "ProxyPort: $global:ProxyPort"
Write-Host "HttpProxy: $global:HttpProxy"
Write-Host "HttpsProxy: $global:HttpsProxy"
Write-Host "NoProxy: $global:NoProxy"
# Run the main function to update all proxy settings
Update-AllProxySettings -HttpProxy $global:HttpProxy -HttpsProxy $global:HttpsProxy -NoProxy $global:NoProxy