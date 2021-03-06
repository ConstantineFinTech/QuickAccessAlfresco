$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

.".\QuickAccessAlfresco.ps1"

$whoAmI = $env:UserName
$linkBaseDir = "$env:userprofile\Links"
$appData = "$env:APPDATA\QuickAccessLinks"
$url = "http://localhost:8080/alfresco/service/api/people/$whoAmI/sites/"
$convertedJSON = @{0 = @{"title" = "Benchmark"; "description" = "This site is for bench marking Alfresco"; "shortName" = "benchmark";};1 = @{"title" = "Recruitment"; "description" = "Recruitment site"; "shortName" = "Recruitment";};}
$convertedCachedJSON = @{0 = @{"title" = "Benchmark"; "description" = "This site is for bench marking Alfresco"; "shortName" = "benchmark";};1 = @{"title" = "Recruitment"; "description" = "Recruitment site"; "shortName" = "Recruitment";};2 = @{"title" = "Recruitment"; "description" = "Recruitment site"; "shortName" = "Recruitment";};3 = @{"title" = "Recruitment"; "description" = "Recruitment site"; "shortName" = "Recruitment";};4 = @{"title" = "Recruitment"; "description" = "Recruitment site"; "shortName" = "Recruitment";};}
$homeAndShared = @{0 = @{"title" = "Home"; "description" = "My Files"; "shortName" = $env:UserName;};1 = @{"title" = "Shared"; "description" = "Shared Files"; "shortName" = "Shared";};}


function setUp {
    New-Item -ItemType Directory -Force -Path $appData
}

function Clean-Up($links, $fileExt = ".lnk") {
    # Clean up after test
    $testLink = "$env:userprofile\Links\"
    foreach($link in $links) {
        if ($fileExt -eq ".lnk") {
            if (Test-Path "$($testLink)$($link)$($fileExt)") {
                Remove-Item "$($testLink)$($link)$($fileExt)"
            } else {
                Write-Host "Can not find $link"
            }
        } else {
            if (Test-Path "$($appData)\$($link)$($fileExt)") {
                Remove-Item "$($appData)\$($link)$($fileExt)"
            } else {
                Write-Host "Can not find $link"
            }            
        }
    }
}

Describe "Create-AppData" {
    It "Should create the AppData folder for QuickAccessAlfresco" {
        $createAppData = Create-AppData
        $doesAppDataExist = Test-Path $appData
        $createAppData | Should be $doesAppDataExist
    }
    #Remove-Item "$($appData)"
}

Describe "CopyIcon" {
    It "Should copy the icon to the user appData folder." {
        $doesIconExist = Test-Path "$appData\alfresco_careers_icon.ico"
        $copyIcon = CopyIcon ".\alfresco_careers_icon.ico"
        $copyIcon | Should be "True"
    }

    It "Should not copy the icon to the user appData folder." {
        $doesIconExist = Test-Path "$appData\alfresco_careers_icon.ico"
        $copyIcon = CopyIcon ".\alfresco_careers_icon.ico"
        $copyIcon | Should be "False"
    }    
    Clean-Up @('*') ".ico"
}

Describe 'Build-Url' {
  It "Should build the URL for connecting to Alfresco." {
    Build-Url | Should -Be $url
  }

  It "Should build the URL for connecting to Alfresco with paramaters prepended." {
    $urlWithParams = Build-Url "hello=world"
    $urlWithParams | Should -Be "http://localhost:8080/alfresco/service/api/people/$whoAmI/sites/?hello=world"
  }
}

Describe 'Get-ListOfSites' {
    It "Should retrieve a list of sites for the currently logged in user." {
        $convertedObject = (Get-Content stub\sites.json)
        $sites = Get-ListOfSites -url "$url/index.json"
        $sites[0].title | Should Match $convertedJSON[0].title
    }
}

Describe 'Create-HomeAndSharedLinks' {
    It "Should not create links for the user home and shared because of the cache." {
        New-Item "$appData\5.cache" -type file
        $createHomeAndShared = Create-HomeAndSharedLinks 
        $createHomeAndShared.Count | Should be 0
    }
    
    Clean-Up @('*') ".cache"

    It "Should create links for the user home and shared." {
        $createHomeAndShared = Create-HomeAndSharedLinks 
        $createHomeAndShared[0].Description | Should Match $homeAndShared[0].description
        $createHomeAndShared[0].TargetPath | Should Be "\\localhost\Alfresco\User Homes\$whoAmI"
        $createHomeAndShared[1].Description | Should Match $homeAndShared[1].description
        $createHomeAndShared[1].TargetPath | Should Be "\\localhost\Alfresco\Shared"
    }

    Clean-Up @('*') ".cache"
}

Describe 'Create-Link' {
    It "Should create Quick Access link to Alfresco." {
        $createLink = Create-Link $convertedJSON[0]
        $result = Test-Path "$env:userprofile\Links\Benchmark.lnk"       
        $createLink | Should be $result
        $createLink.Description | Should Match $convertedJSON[0].description
    }

    It "Should not create Quick Access link to Alfresco because it exists." {
        $createLink = Create-Link $convertedJSON[0]
        $createLink | Should be "False"
    }

    It "Should not create an empty Quick Access link to Alfresco." {
        $createLink = Create-Link @{}
        $createLink | Should be "False"
    }

    Clean-Up @("Home", "Shared", "Benchmark")

    It "Should pepend text to the Quick Access link to Alfresco." {
        $prependedJSON = $convertedJSON[0..3]
        $prependedJSON[0]["prepend"] = "Alfresco - "
        $createLink = Create-Link $prependedJSON[0]
        $result = Test-Path "$env:userprofile\Links\Alfresco - Benchmark.lnk"
        $createLink | Should Not Be "False"
        $createLink.Description | Should Match $prependedJSON[0].description
    }    

    Clean-Up @('Alfresco - Benchmark')

    It "Should set an icon for the Quick Access link to Alfresco." {
        $iconJSON = $convertedJSON[0..3]
        $iconJSON[0]["icon"] = "$appData\alfresco_careers_icon.ico"
        $createLink = Create-Link $iconJSON[0] "Sites" "True"
        $result = Test-Path "$env:userprofile\Links\Alfresco - Benchmark.lnk"
        $createLink | Should Be $result
        $createLink.Description | Should Match $iconJSON[0].description
        $iconFile = $createLink.IconLocation.split(",")[0]
        $iconFile | Should Be "$appData\alfresco_careers_icon.ico"
    }    

    Clean-Up @('Alfresco - Benchmark')

    # FIXME: There is a side effect here, the title is prepended to when it shouldn't be
    It "Should create a ftps Quick Access link to an Alfresco site." {
        $createLink = Create-Link $convertedJSON[0] "Sites" "ftps"
        $result = Test-Path "$env:userprofile\Links\Alfresco - Benchmark.lnk"       
        $createLink | Should be $result
        $createLink.Description | Should Match $convertedJSON[0].description
    }

    Clean-Up @('Alfresco - Benchmark')

    It "Should create a ftps Quick Access link to user home." {
        $createLink = Create-Link $homeAndShared[0] "User Homes" "ftps"
        $result = Test-Path "$env:userprofile\Links\Home.lnk"
        $createLink | Should be $result
        $createLink.Description | Should Match "My Files"
    }

    Clean-Up @('Home') 

    It "Should create a ftps Quick Access link to Shared." {
        $createLink = Create-Link $homeAndShared[1] "shared" "ftps"
        $result = Test-Path "$env:userprofile\Links\Shared.lnk"       
        $createLink | Should be $result
        $createLink.Description | Should Match "Shared Files"
    }

    Clean-Up @('Shared')           

    It "Should create a WebDav Quick Access link to an Alfresco site." {
        $createLink = Create-Link $convertedJSON[0] "Sites" "https"
        $result = Test-Path "$env:userprofile\Links\Alfresco - Benchmark.lnk"       
        $createLink | Should be $result
        $createLink.Description | Should Match $convertedJSON[0].description
    }

    Clean-Up @('Alfresco - Benchmark') 

    It "Should create a WebDav Quick Access link to user home." {
        $createLink = Create-Link $homeAndShared[0] "User Homes" "https"
        $result = Test-Path "$env:userprofile\Links\Home.lnk"       
        $createLink | Should be $result
        $createLink.Description | Should Match "My Files"
    }

    Clean-Up @('Home')

    It "Should create a WebDav Quick Access link to Shared." {
        $createLink = Create-Link $homeAndShared[1] "shared" "https"
        $result = Test-Path "$env:userprofile\Links\Shared.lnk"       
        $createLink | Should be $result
        $createLink.Description | Should Match "Shared Files"
    }

    Clean-Up @('Shared')  

    It "Should not create any link to Alfresco because the path is wrong." {
        $createLink = Create-Link $homeAndShared[1] "wrongPath"
        $createLink | Should be "False"
    }
}
  
Describe 'Create-QuickAccessLinks' {
    It "Should not create any Quick Access links to sites within Alfresco because of the cache." {
        New-Item "$appData\5.cache" -type file
        $createLinks = Create-QuickAccessLinks $convertedCachedJSON
        $createLinks.Count | Should Be 0
    }

    Clean-Up @('*') ".cache"

    It "Should create all Quick Access links to sites within Alfresco because of the change in cache size." {
        New-Item "$appData\5.cache" -type file
        $createLinks = Create-QuickAccessLinks $convertedCachedJSON
        $createLinks.Count | Should Be 0
        Clean-Up @('*') ".cache"
        Mock CacheTimeChange {return 5}
        New-Item "$appData\2.cache" -type file
        $createLinks = Create-QuickAccessLinks $convertedJSON
        $createLinks.Count | Should Be 2
    }

    Clean-Up @('*') ".cache"    
    Clean-Up @('Alfresco - Benchmark', "Benchmark", "Recruitment")

    It "Should create all Quick Access links to sites within Alfresco" {
        Mock CacheTimeChange {return 5}
        $createLinks = Create-QuickAccessLinks $convertedJSON
        $createLinks[0].Description | Should Match $convertedJSON[0].description
        $createLinks[1].Description | Should Match $convertedJSON[1].description
    }    
    Clean-Up @('Alfresco - Benchmark', "Benchmark", "Recruitment")
    
    It "Should pepend text to all Quick Access links to sites within Alfresco" {
        Mock CacheTimeChange {return 5}
        $createLinks = Create-QuickAccessLinks $convertedJSON "Alfresco - "
        
        $benchmark = Test-Path "$env:userprofile\Links\Alfresco - Benchmark.lnk"
        $benchmark | Should Not Be "False"
        $createLinks[0].Description | Should Match $convertedJSON[0].description
        
        $recruitment = Test-Path "$env:userprofile\Links\Alfresco - Recruitment.lnk"
        $recruitment | Should Not Be "False"
        $createLinks[1].Description | Should Match $convertedJSON[1].description
    }
    Clean-Up @('Alfresco - Benchmark', "Alfresco - Recruitment")

    It "Should add an icon to all Quick Access links to sites within Alfresco" {
        $createLinks = Create-QuickAccessLinks $convertedJSON "" "$appData\alfresco_careers_icon.ico"
        
        $benchmark = Test-Path "$env:userprofile\Links\Alfresco - Benchmark.lnk"
        $benchmark | Should Not Be "False"
        $icon = $createLinks[0].IconLocation.split(",")[0]
        $icon | Should be "$appData\alfresco_careers_icon.ico"
        
        $recruitment = Test-Path "$env:userprofile\Links\Alfresco - Recruitment.lnk"
        $recruitment | Should Not Be "False"
        $icon = $createLinks[1].IconLocation.split(",")[0]
        $icon | Should be "$appData\alfresco_careers_icon.ico"
    }
    Clean-Up @('Alfresco - Benchmark', "Alfresco - Recruitment")    
}

Describe 'CreateCache' {
    It "Should create cache if it doesn't exists." {
        $createCache = CreateCache
        $createCache.Count | Should be 2
    }
    Clean-Up @('*') ".cache"
}

Describe 'CacheExists' {
    It "Should test that the cache doesn't exists." {
        $cacheExists = CacheExists
        $cacheExists.Count | Should be 0
    }

    It "Should test that the cache does exists." {
        New-Item "$appData\5.cache" -type file
        $cacheExists = CacheExists
        $cacheExists.Name | Should be "5.cache"
    }
}

Describe 'CacheInit' {
    It "Should not remove the cache if cache size doesn't change." {
        Mock CacheTimeChange {return 5}
        $CacheInit = CacheInit
        $CacheInit | Should be "False"
    }
    
    Clean-Up @('*') ".cache"

    It "Should remove the cache if cache size does change." {
        # Mock CacheTimeChange {return 4}
        New-Item "$appData\4.cache" -type file
        $CacheInit = CacheInit
        $CacheInit.Name | Should Match "5.cache"
    }    
    Clean-Up @('*') ".cache"
}

Describe 'CacheSizeChanged' {
    It "Should detect if there is a change in the size of the cache." {
        Mock CacheTimeChange {return 5}
        New-Item "$appData\4.cache" -type file
        $cacheSizeChanged = CacheSizeChanged
        $cacheSizeChanged | Should Match "True"       
    }
    Clean-Up @('*') ".cache"

    It "Should detect if the cache is the same size." {
        New-Item "$appData\5.cache" -type file
        $cacheSizeChanged = CacheSizeChanged
        $cacheSizeChanged | Should Match "False"       
    }
    Clean-Up @('*') ".cache"
}

Describe "CacheTimeChange" {
    It "Should detect if the cache has been modified in the last 10 minutes. If so do a web request." {
        $lastWriteTime = @{"LastWriteTime" = [datetime]"1/2/14 00:00:00";}
        $cacheTimeChange = CacheTimeChange $lastWriteTime 5
        $cacheTimeChange | Should Be 5
    }

    It "Should detect if the cache has not been modified in the last 10 minutes. If so do not do a web request." {
        $lastWriteTime = @{"LastWriteTime" = get-date;}
        $cacheTimeChange = CacheTimeChange $lastWriteTime
        $cacheTimeChange | Should Be 0
    }    

    It "Should detect if no date is passed to the function. If so do not do a web request." {
        $cacheTimeChange = CacheTimeChange ""
        $cacheTimeChange | Should Be 0
    }    
}