$domainName = "localhost:8080" # This parameter stores the link to local host.
$mapDomain = "localhost"
$linkBaseDir = "$env:userprofile\Links"
$appData = "$env:APPDATA\QuickAccessLinks"
$prependToLinkTitle = "" # Variable is assigned but doesn't do anything.

function Create-AppData { 
# Creates AppData forlder on users machine
# and checks if it was created successfully.

    New-Item -ItemType Directory -Force -Path $appData

}

function CopyIcon($icon="") {
<#
Copies entities logo to the corner of AppData folder.
Checks if operation was successful.
#>

    $testPath = (-Not (Test-Path "$appData\$icon"))
    if ($icon -And $testPath) {
        Copy-Item $icon "$appData\"
        return "True"
    }
    return "False"
}

function Build-Url([String] $urlParams="") {
    <#
    Creates connection between local machine and (internet server) --?
    Checks if connection was established and returns URL.(Uniform Resource Locator).
    #>
    $whoAmI = $env:UserName
    $url = "http://$domainName/alfresco/service/api/people/$whoAmI/sites/"
    
    if ($urlParams) {
        $url = "$($url)?$($urlParams)"
    }
    return $url
}

function Get-ListOfSites {

# Retreives list of sites for currently logged in user from --fail

    Param([String] $url)
    $webclient = new-object System.Net.WebClient
    $webclient.UseDefaultCredentials=$true
    $response = $webclient.DownloadString($url) | ConvertFrom-Json
    return $response
}

function Create-HomeAndSharedLinks {

# 

   $links = @{}
   $cacheExists = CacheExists
   if (-not $cacheExists.Name.Count) {
        $links[0] = Create-Link @{"title" = "Home"; "description" = "My Files"; "shortName" = $env:UserName;} "User Homes"
        $links[1] = Create-Link @{"title" = "Shared"; "description" = "Shared Files"; "shortName" = "Shared";} "Shared"
        $createCache = CacheInit
   }
   return $links
}

function Create-QuickAccessLinks($links, $prepend="", $icon="") {
    $createdLinks = @()

    $cacheSizeChanged = CacheSizeChanged
    if ($cacheSizeChanged) {    
        for($i = 0; $i -lt $links.Count; $i++) {
            if ($prepend) {
                $links[$i]["prepend"] = $prepend
            }
            if ($icon) {
                $links[$i]["icon"] = $icon
            }            
            $addLink = Create-Link $links[$i]
            if ($addLink -ne "False") {
                $createdLinks += $addLink
            }
        }
        $createCache = CacheInit
    }    
    return $createdLinks
}

function Create-Link($link, [String] $whatPath = "Sites", $protocol="") {

    if ($link.Count -eq 0) {
        return "False"
    }

    $path = "$linkBaseDir\$($link.title).lnk"

    if($link.contains("prepend")){
        $path = "$linkBaseDir\$($link.prepend)$($link.title).lnk"
    }
 
    if (Test-Path $path) {
        return "False"
    }

    $findPath = @{
        "Sites" = "\\$mapDomain\Alfresco\$whatPath\" + $link.shortName + "\documentLibrary"; 
        "User Homes" = "\\$mapDomain\Alfresco\$whatPath\" + $link.shortName;
        "Shared" = "\\$mapDomain\Alfresco\$whatPath";
    }

    if ($protocol -eq "ftps") {
        $findPath = @{
            "Sites" = "ftps://$mapDomain/alfresco/$whatPath/" + $link.shortName + "/documentLibrary"; 
            "User Homes" = "ftps://$mapDomain/alfresco/$whatPath/" + $link.shortName;
            "Shared" = "ftps://$mapDomain/alfresco/$whatPath";
        }
    } 
    if ($protocol -eq "https") {
        $findPath = @{
            "Sites" = "https://$mapDomain/alfresco/webdav/$($whatPath.ToLower())/" + $link.shortName + "/documentLibrary"; 
            "User Homes" = "https://$mapDomain/alfresco/webdav/$($whatPath.ToLower())/" + $link.shortName;
            "Shared" = "https://$mapDomain/alfresco/webdav/$($whatPath.ToLower())";
        }
    }     

    $fullPath = $findPath.Get_Item($whatPath)

    if ($fullPath.length -eq 0) {
        return "False"
    }

    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut("$path")

    $shortcut.TargetPath = $fullPath
    $shortcut.Description = $link.description
    if($link.contains("icon")){
        $shortcut.IconLocation = "$appData\alfresco_careers_icon.ico"
    }    
    $shortcut.Save()
    return $shortcut
}

function CacheInit {
    $createCache = "False"
    $cacheExists = CacheExists

    if ($cacheExists.Name.Count -ne 0) { # Check cache is current
        $cacheSizeChanged = CacheSizeChanged

        if ($cacheSizeChanged) {
            Remove-Item "$appData\*.cache"
            $createCache = CreateCache
        }        
    }
    return $createCache
}

function CacheSizeChanged {
    $cacheExists = CacheExists
    $howManySitesCached = 0
    if ($cacheExists.Name.Count -ne 0) {
        [int]$howManySitesCached = $cacheExists.Name.Split(".")[0]
    }
    $countliveSites = CacheTimeChange $cacheExists $howManySitesCached
    $cacheSizeChanged = ($countliveSites -ne $howManySitesCached)
    
    return $cacheSizeChanged
}

function CacheTimeChange($lastWriteTime, $countliveSites = 0, $index="") {

    if ($lastWriteTime -ne "") {
        $lastWriteTime = $lastWriteTime.LastWriteTime
    } else {
        $lastWriteTime = get-date
    }

    $timespan = new-timespan -minutes 10
    if (((get-date) - $lastWriteTime) -gt $timespan) {
        $url = Build-Url
        $sites = Get-ListOfSites -url "$url/index.json"
        [int]$countliveSites = $sites.Count
    }
    return $countliveSites
}

function CreateCache {
    $cacheExists = CacheExists
    if ($cacheExists.Name.Count -eq 0) {
        $url = Build-Url
        $sites = Get-ListOfSites -url $url
        New-Item "$appData\$($sites.Count).cache" -type file
    }
    $cacheExists = CacheExists
    return $cacheExists
}

function CacheExists {
    $cacheFile = get-childitem "$appData\*.cache" | Select-Object Name, LastWriteTime
    return $cacheFile
}