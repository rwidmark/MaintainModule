$ModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'MaintainModule'
Publish-Module -Path $ModulePath -NuGetApiKey $Env:PSGALLERY
