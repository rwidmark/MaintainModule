<#
    MIT License

    Copyright (C) 2025 Robin Widmark.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
#>
function Get-rsModuleDetail {
    <#
        .SYNOPSIS
        Returns the newest installed version and older versions for one module.

        .DESCRIPTION
        Processes the installed versions for a single module name and returns
        the newest version together with any older installed versions.

        .PARAMETER InstalledModule
        One or more installed module objects for the same module name.

        .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'Enter installed module objects for a single module name.')]
        [ValidateNotNullOrEmpty()]
        [psobject[]]$InstalledModule
    )

    $latestModule = $null
    $latestVersion = $null
    $oldVersions = [System.Collections.Generic.List[version]]::new()

    foreach ($moduleInfo in $InstalledModule) {
        try {
            [version]$parsedVersion = $moduleInfo.Version
        }
        catch {
            throw "Failed to parse the installed version for module '$($moduleInfo.Name)'. $($PSItem.Exception.Message)"
        }

        if ($null -eq $latestVersion -or $parsedVersion -gt $latestVersion) {
            if ($null -ne $latestVersion) {
                [void]$oldVersions.Add($latestVersion)
            }

            $latestVersion = $parsedVersion
            $latestModule = $moduleInfo
            continue
        }

        if ($parsedVersion -lt $latestVersion) {
            [void]$oldVersions.Add($parsedVersion)
        }
    }

    return [PSCustomObject]@{
        Name          = $latestModule.Name
        Repository    = $latestModule.Repository
        OldVersion    = $oldVersions.ToArray()
        LatestVersion = $latestVersion
    }
}

function Get-rsCallerPreferenceMap {
    <#
        .SYNOPSIS
        Captures common caller preferences for nested commands.

        .DESCRIPTION
        Builds a hashtable of supported caller preferences so nested commands
        honor flags such as -Verbose and -WhatIf consistently.

        .OUTPUTS
        Hashtable
    #>
    [CmdletBinding()]
    param()

    $commonParameters = @{}

    # Forward caller preferences so nested commands honor -Verbose and -WhatIf consistently.
    if ($VerbosePreference -eq [System.Management.Automation.ActionPreference]::Continue) {
        $commonParameters.Verbose = $true
    }

    if ($WhatIfPreference) {
        $commonParameters.WhatIf = $true
    }

    return $commonParameters
}

function Get-rsRequestedModuleList {
    <#
        .SYNOPSIS
        Normalizes requested module names.

        .DESCRIPTION
        Trims input values, removes empty entries, and de-duplicates module
        names by using a case-insensitive comparison.

        .PARAMETER Module
        Module names to normalize.

        .OUTPUTS
        String[]
    #>
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = 'Enter module names to normalize and de-duplicate.')]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Module
    )

    $requestedModules = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($moduleName in $Module) {
        if ([string]::IsNullOrWhiteSpace($moduleName)) {
            continue
        }

        [void]$requestedModules.Add($moduleName.Trim())
    }

    return @($requestedModules)
}

function Get-rsLatestRepositoryModule {
    <#
        .SYNOPSIS
        Gets the newest available module version from a repository.

        .DESCRIPTION
        Queries PowerShellGet for a module and normalizes the result to a
        single newest repository version.

        .PARAMETER ModuleName
        The name of the module to find.

        .PARAMETER Repository
        The repository to query when one is known.

        .PARAMETER AllowPrerelease
        Includes prerelease versions in the repository lookup.

        .OUTPUTS
        PSObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'Enter the name of the module to look up in the repository.')]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,
        [Parameter(Mandatory = $false, HelpMessage = 'Enter the repository to query when one is known.')]
        [AllowEmptyString()]
        [string]$Repository,
        [Parameter(Mandatory = $false, HelpMessage = 'Include prerelease versions when querying the repository.')]
        [switch]$AllowPrerelease
    )

    $findModuleParameters = @{
        Name        = $ModuleName
        ErrorAction = 'Stop'
    }

    if (-not [string]::IsNullOrWhiteSpace($Repository)) {
        $findModuleParameters.Repository = $Repository
    }

    if ($AllowPrerelease) {
        $findModuleParameters.AllowPrerelease = $true
    }

    # When no repository is specified, Find-Module can return one result per registered repository.
    # Normalize that output to a single newest match so callers always receive one module object.
    return Find-Module @findModuleParameters |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
}

function Uninstall-rsModule {
    <#
        .SYNOPSIS
        Removes older installed versions of PowerShell modules.

        .DESCRIPTION
        Removes older installed versions for the requested modules. When no
        module names are provided, the command inspects all installed modules
        and removes every discovered older version.

        .PARAMETER Module
        One or more module names to clean up. If omitted, all installed modules
        are inspected.

        .PARAMETER OldVersion
        Specific versions to remove. If omitted, older installed versions are
        discovered automatically.

        .PARAMETER AllowPrerelease
        Allows prerelease versions when uninstalling a specific version.

        .EXAMPLE
        Uninstall-rsModule -Module 'VMware.PowerCLI'

        Removes older installed versions of VMware.PowerCLI.

        .EXAMPLE
        Uninstall-rsModule -Module 'VMware.PowerCLI', 'ImportExcel'

        Removes older installed versions of VMware.PowerCLI and ImportExcel.

        .EXAMPLE
        Uninstall-rsModule

        Removes older installed versions for every installed module.

        .LINK
        https://github.com/rwidmark/MaintainModule/blob/main/README.md

        .NOTES
        Author:         Robin Widmark
        Mail:           robin@widmark.dev
        Website/Blog:   https://widmark.dev
        X:              https://x.com/widmark_robin
        Mastodon:       https://mastodon.social/@rwidmark
        YouTube:        https://www.youtube.com/@rwidmark
        Linkedin:       https://www.linkedin.com/in/rwidmark/
        GitHub:         https://github.com/rwidmark
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Enter the module or modules you want to uninstall older version of, if not used all older versions will be uninstalled")]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Module,
        [Parameter(Mandatory = $false, HelpMessage = 'Enter the module versions that should be removed.')]
        [ValidateNotNullOrEmpty()]
        [version[]]$OldVersion,
        [Parameter(Mandatory = $false, HelpMessage = 'Allow prerelease versions when uninstalling a specific version.')]
        [switch]$AllowPrerelease
    )

    begin {
        $requestedModules = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $specifiedVersions = @($OldVersion | Where-Object { $null -ne $_ } | Select-Object -Unique)
    }

    process {
        foreach ($currentModule in (Get-rsRequestedModuleList -Module $Module)) {
            [void]$requestedModules.Add($currentModule)
        }
    }

    end {
        $moduleQuery = if ($requestedModules.Count -gt 0) {
            Get-rsInstalledModule -Module @($requestedModules)
        }
        else {
            Get-rsInstalledModule
        }

        foreach ($moduleInfo in @($moduleQuery.Module)) {
            $versionsToRemove = if ($specifiedVersions.Count -gt 0) {
                @($specifiedVersions)
            }
            else {
                @($moduleInfo.OldVersion)
            }

            if ($versionsToRemove.Count -eq 0) {
                Write-Verbose "$($moduleInfo.Name) does not have any older versions to uninstall."
                continue
            }

            Write-Output "START - Uninstall older versions of $($moduleInfo.Name)"
            Write-Output 'Please wait, this can take some time...'

            foreach ($currentVersion in $versionsToRemove) {
                if ($PSCmdlet.ShouldProcess("$($moduleInfo.Name) $currentVersion", 'Uninstall module version')) {
                    Write-Verbose "Uninstalling version $currentVersion of $($moduleInfo.Name)..."

                    try {
                        $uninstallModuleParameters = @{
                            Name            = $moduleInfo.Name
                            RequiredVersion = $currentVersion
                            Force           = $true
                            ErrorAction     = 'Stop'
                        }

                        if ($AllowPrerelease) {
                            $uninstallModuleParameters.AllowPrerelease = $true
                        }

                        Uninstall-Module @uninstallModuleParameters
                    }
                    catch {
                        Write-Error "Failed to uninstall version $currentVersion of $($moduleInfo.Name). $($PSItem.Exception.Message)"
                        continue
                    }
                }
            }

            Write-Output "FINISHED - All older versions of $($moduleInfo.Name) are now uninstalled!"
        }

        if (@($moduleQuery.Module).Count -eq 0 -and $specifiedVersions.Count -eq 0) {
            Write-Verbose 'No installed module versions were found for uninstall.'
        }
    }
}

function Get-rsInstalledModule {
    <#
        .SYNOPSIS
        Gets installed module details for one or more module names.

        .DESCRIPTION
        Collects installed module versions, identifies the newest installed
        version for each module, and returns any modules that were requested but
        not found.

        .PARAMETER Module
        One or more module names to inspect. If omitted, all installed modules
        are returned.

        .OUTPUTS
        OrderedDictionary
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Enter module or modules that you want to update, if you don't enter any, all of the modules will be updated")]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Module
    )

    begin {
        $returnCode = 0
        $returnData = [ordered]@{}
        $returnModule = [System.Collections.Generic.List[object]]::new()
        $missingModule = [System.Collections.Generic.List[string]]::new()
        $requestedModules = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    process {
        foreach ($moduleName in (Get-rsRequestedModuleList -Module $Module)) {
            [void]$requestedModules.Add($moduleName)
        }
    }

    end {
        if ($requestedModules.Count -eq 0) {
            try {
                Write-Verbose 'Caching all installed modules from the system...'
                $allInstalledModules = @(Get-InstalledModule -AllVersions -ErrorAction Stop)
            }
            catch {
                throw "Failed to collect installed modules. $($PSItem.Exception.Message)"
            }

            $groupedModules = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($installedModule in $allInstalledModules) {
                $moduleList = $null
                if (-not $groupedModules.TryGetValue($installedModule.Name, [ref]$moduleList)) {
                    $moduleList = [System.Collections.Generic.List[object]]::new()
                    $groupedModules[$installedModule.Name] = $moduleList
                }

                [void]$moduleList.Add($installedModule)
            }

            foreach ($moduleName in ($groupedModules.Keys | Sort-Object)) {
                $moduleInfo = Get-rsModuleDetail -InstalledModule $groupedModules[$moduleName].ToArray()
                [void]$returnModule.Add($moduleInfo)
            }
        }
        else {
            Write-Verbose 'Looking if the modules exist in the system...'
            foreach ($moduleName in $requestedModules) {
                try {
                    $installedModuleVersions = @(Get-InstalledModule -Name $moduleName -AllVersions -ErrorAction Stop)
                }
                catch {
                    Write-Warning "$($moduleName) is not installed, skipping this module..."
                    [void]$missingModule.Add($moduleName)
                    continue
                }

                $moduleInfo = Get-rsModuleDetail -InstalledModule $installedModuleVersions
                if ($null -ne $moduleInfo) {
                    Write-Verbose "$($moduleName) is installed, collecting information about it..."
                    [void]$returnModule.Add($moduleInfo)
                }
                else {
                    Write-Warning "$($moduleName) is not installed, skipping this module..."
                    [void]$missingModule.Add($moduleName)
                }
            }
        }

        if ($returnModule.Count -eq 0) {
            $returnCode = 1
            if ($requestedModules.Count -gt 0) {
                Write-Warning 'No matching installed modules were found for the requested module names...'
            }
            else {
                Write-Warning 'No installed modules were found...'
            }
        }

        $moduleResult = if ($returnModule.Count -gt 0) { $returnModule.ToArray() } else { $null }
        $missingResult = if ($missingModule.Count -gt 0) { $missingModule.ToArray() } else { @() }

        $returnData.Add('ReturnCode', $returnCode)
        $returnData.Add('Module', $moduleResult)
        $returnData.Add('MissingModule', $missingResult)

        return $returnData
    }
}

function Test-rsComponent {
    <#
        .SYNOPSIS
        Verifies required PowerShellGet prerequisites.

        .DESCRIPTION
        Ensures TLS 1.2 is enabled and makes sure the PowerShell Gallery is set
        to Trusted before module operations run.

        .OUTPUTS
        String
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(

    )

    begin {
        Write-Verbose 'Making sure that TLS 1.2 is used...'
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }

    process {
        Write-Verbose 'Checking if PowerShell Gallery is set to trusted...'

        try {
            $psGallery = Get-PSRepository -Name PSGallery -ErrorAction Stop
        }
        catch {
            throw "Failed to read PSGallery configuration. $($PSItem.Exception.Message)"
        }

        if ($psGallery.InstallationPolicy -eq 'Untrusted') {
            if ($PSCmdlet.ShouldProcess('PSGallery', 'Set installation policy to Trusted')) {
                try {
                    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
                    Write-Output "PowerShell Gallery was not set as trusted, it's now set as trusted!"
                }
                catch {
                    throw "Failed to set PSGallery as trusted. $($PSItem.Exception.Message)"
                }
            }
        }
        else {
            Write-Verbose "PowerShell Gallery was already set to trusted, continuing!"
        }
    }

    end {
    }
}

function Update-rsModule {
    <#
        .SYNOPSIS
        Updates installed PowerShell modules and optionally removes old versions.

        .DESCRIPTION
        Updates all installed modules or only the requested modules. The command
        can also install missing modules and remove older installed versions
        after a successful update.

        .PARAMETER Module
        One or more module names to update. If omitted, all installed modules
        are updated.

        .PARAMETER Scope
        Specifies the install scope for update and install operations. Valid
        values are CurrentUser and AllUsers. The default value is CurrentUser.

        .PARAMETER UninstallOldVersion
        Removes older installed versions after the update completes.

        .PARAMETER InstallMissing
        Installs requested modules that are not already installed.

        .PARAMETER AllowPrerelease
        Includes prerelease versions when searching, installing, and updating
        modules.

        .PARAMETER SkipPublisherCheck
        Skips the publisher certificate check during install and update
        operations.

        .EXAMPLE
        Update-rsModule -Module 'PowerCLI', 'ImportExcel' -Scope 'CurrentUser'

        Updates PowerCLI and ImportExcel for the current user.

        .EXAMPLE
        Update-rsModule -Module 'PowerCLI', 'ImportExcel' -UninstallOldVersion

        Updates PowerCLI and ImportExcel and removes older installed versions.

        .EXAMPLE
        Update-rsModule -Module 'PowerCLI', 'ImportExcel' -InstallMissing

        Installs missing requested modules and updates ones that are already
        installed.

        .EXAMPLE
        Update-rsModule -Module 'PowerCLI', 'ImportExcel' -UninstallOldVersion

        Updates the requested modules and removes their older installed
        versions.

        .LINK
        https://github.com/rwidmark/MaintainModule/blob/main/README.md

        .NOTES
        Author:         Robin Widmark
        Mail:           robin@widmark.dev
        Website/Blog:   https://widmark.dev
        X:              https://x.com/widmark_robin
        Mastodon:       https://mastodon.social/@rwidmark
        YouTube:        https://www.youtube.com/@rwidmark
        Linkedin:       https://www.linkedin.com/in/rwidmark/
        GitHub:         https://github.com/rwidmark
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Enter module or modules that you want to update, if you don't enter any, all of the modules will be updated")]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Module,
        [Parameter(Mandatory = $false, HelpMessage = "Enter CurrentUser or AllUsers depending on what scope you want to change your modules, default is CurrentUser")]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser',
        [Parameter(Mandatory = $false, HelpMessage = 'Uninstalls all old versions of the modules')]
        [switch]$UninstallOldVersion = $false,
        [Parameter(Mandatory = $false, HelpMessage = 'Install all of the modules that has been entered in module that are not installed on the system')]
        [switch]$InstallMissing = $false,
        [Parameter(Mandatory = $false, HelpMessage = "Don't check publishers certificate")]
        [switch]$SkipPublisherCheck = $false,
        [Parameter(Mandatory = $false, HelpMessage = 'Include prerelease versions when searching, installing, and updating modules.')]
        [switch]$AllowPrerelease
    )

    begin {
        $commonParameters = Get-rsCallerPreferenceMap
        $requestedModules = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        Write-Output "`n=== Module Maintenance - Widmark.dev 2025 ==="
        Write-Output "Please wait, this can take some time...`n"

        Test-rsComponent @commonParameters

        Write-Output "START - Updating modules`n"
    }

    process {
        foreach ($moduleName in (Get-rsRequestedModuleList -Module $Module)) {
            [void]$requestedModules.Add($moduleName)
        }
    }

    end {
        $modulesToProcess = @($requestedModules)
        $getModuleInfo = if ($modulesToProcess.Count -gt 0) {
            Get-rsInstalledModule -Module $modulesToProcess
        }
        else {
            Get-rsInstalledModule
        }

        if ($getModuleInfo.ReturnCode -eq 0) {
            foreach ($_module in @($getModuleInfo.Module)) {
                Write-Verbose "Collecting all installed version of $($_module.Name)..."

                try {
                    Write-Verbose "Looking up the latest version of $($_module.Name)..."
                    $latestRepositoryModule = Get-rsLatestRepositoryModule -ModuleName $_module.Name -Repository $_module.Repository -AllowPrerelease:$AllowPrerelease
                    if ($null -eq $latestRepositoryModule) {
                        Write-Warning "No repository versions were found for $($_module.Name), skipping this module..."
                        continue
                    }

                    [version]$collectLatestVersion = $latestRepositoryModule.Version
                }
                catch {
                    Write-Error "Failed to look up the latest version of $($_module.Name). $($PSItem.Exception.Message)"
                    continue
                }

                $versionsToRemove = @($_module.OldVersion)
                $requiresUpdate = $_module.LatestVersion -lt $collectLatestVersion

                if ($requiresUpdate) {
                    Write-Output "Found a newer version of $($_module.Name), version $collectLatestVersion"
                    Write-Output "Updating $($_module.Name) from $($_module.LatestVersion) to version $collectLatestVersion..."

                    if ($PSCmdlet.ShouldProcess($_module.Name, "Update module to version $collectLatestVersion")) {
                        try {
                            $updateModuleParameters = @{
                                Name              = $_module.Name
                                Scope             = $Scope
                                AcceptLicense     = $true
                                Force             = $true
                                ErrorAction       = 'Stop'
                            }

                            if ($AllowPrerelease) {
                                $updateModuleParameters.AllowPrerelease = $true
                            }

                            if ($SkipPublisherCheck) {
                                $updateModuleParameters.SkipPublisherCheck = $true
                            }

                            Update-Module @updateModuleParameters
                            Write-Output "$($_module.Name) has now been updated to version $collectLatestVersion!"
                            $versionsToRemove += $_module.LatestVersion
                        }
                        catch {
                            Write-Error "Failed to update $($_module.Name). $($PSItem.Exception.Message)"
                            continue
                        }
                    }
                }
                else {
                    Write-Verbose "$($_module.Name) is already up to date!"
                }

                if ($UninstallOldVersion) {
                    $versionsToRemove = @($versionsToRemove | Select-Object -Unique)
                    if ($versionsToRemove.Count -gt 0) {
                        Uninstall-rsModule -Module $_module.Name -OldVersion $versionsToRemove -AllowPrerelease:$AllowPrerelease @commonParameters
                    }
                    else {
                        Write-Verbose "$($_module.Name) don't have any older versions to uninstall!"
                    }
                }
            }
        }

        if ($InstallMissing -and @($getModuleInfo.MissingModule).Count -gt 0) {
            foreach ($missingModule in @($getModuleInfo.MissingModule)) {
                Write-Output "$missingModule is not installed, installing $missingModule..."

                if ($PSCmdlet.ShouldProcess($missingModule, 'Install missing module')) {
                    try {
                        $installModuleParameters = @{
                            Name            = $missingModule
                            Scope           = $Scope
                            AcceptLicense   = $true
                            Force           = $true
                            ErrorAction     = 'Stop'
                        }

                        if ($AllowPrerelease) {
                            $installModuleParameters.AllowPrerelease = $true
                        }

                        if ($SkipPublisherCheck) {
                            $installModuleParameters.SkipPublisherCheck = $true
                        }

                        Install-Module @installModuleParameters
                        Write-Output "$missingModule has now been installed!"
                    }
                    catch {
                        Write-Error "Failed to install $missingModule. $($PSItem.Exception.Message)"
                        continue
                    }
                }
            }
        }
        Write-Output "`n=== \\\ Script Finished! /// ===`n"
    }
}
