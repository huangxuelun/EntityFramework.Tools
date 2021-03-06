﻿$ErrorActionPreference = 'Stop'

#
# Add-Migration
#

Register-TabExpansion Add-Migration @{
    OutputDir = { <# Disabled. Otherwise, paths would be relative to the solution directory. #> }
    Context = { param($x) GetContextTypes $x.Project $x.StartupProject $x.Environment }
    Project = { GetProjects }
    StartupProject = { GetProjects }
}

<#
.SYNOPSIS
    Adds a new migration.

.DESCRIPTION
    Adds a new migration.

.PARAMETER Name
    The name of the migration.

.PARAMETER OutputDir
    The directory (and sub-namespace) to use. Paths are relative to the project directory. Defaults to "Migrations".

.PARAMETER Context
    The DbContext type to use.

.PARAMETER Environment
    The environment to use. Defaults to "Development".

.PARAMETER Project
    The project to use.

.PARAMETER StartupProject
    The startup project to use. Defaults to the solution's startup project.

.LINK
    Remove-Migration
    Update-Database
    about_EntityFrameworkCore
#>
function Add-Migration
{
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Name,
        [string] $OutputDir,
        [string] $Context,
        [string] $Environment,
        [string] $Project,
        [string] $StartupProject)

    WarnIfEF6 'Add-Migration'

    $dteProject = GetProject $Project
    $dteStartupProject = GetStartupProject $StartupProject $dteProject

    $params = 'migrations', 'add', $Name

    if ($OutputDir)
    {
        $params += '--output-dir', $OutputDir
    }

    $params += GetParams $Context $Environment

    $result = EF $dteProject $dteStartupProject $params -json
    Write-Output 'To undo this action, use Remove-Migration.'

    $dteProject.ProjectItems.AddFromFile($result.MigrationFile) | Out-Null
    $DTE.ItemOperations.OpenFile($result.MigrationFile) | Out-Null
    ShowConsole

    $dteProject.ProjectItems.AddFromFile($result.MetadataFile) | Out-Null

    $dteProject.ProjectItems.AddFromFile($result.SnapshotFile) | Out-Null
}

#
# Drop-Database
#

Register-TabExpansion Drop-Database @{
    Context = { param($x) GetContextTypes $x.Environment $x.Project $x.StartupProject }
    Project = { GetProjects }
    StartupProject = { GetProjects }
}

<#
.SYNOPSIS
    Drops the database.

.DESCRIPTION
    Drops the database.

.PARAMETER Context
    The DbContext to use.

.PARAMETER Environment
    The environment to use. Defaults to "Development".

.PARAMETER Project
    The project to use.

.PARAMETER StartupProject
    The startup project to use. Defaults to the solution's startup project.

.LINK
    Update-Database
    about_EntityFrameworkCore
#>
function Drop-Database
{
    [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([string] $Context, [string] $Environment, [string] $Project, [string] $StartupProject)

    $dteProject = GetProject $Project
    $dteStartupProject = GetStartupProject $StartupProject $dteProject

    if (IsUWP $dteProject)
    {
        throw 'Drop-Database shouldn''t be used with Universal Windows Platform apps. Instead, call ' +
            'DbContext.Database.EnsureDeleted() at runtime.'
    }

    $params = 'database', 'drop', '--dry-run'
    $params += GetParams $Context $Environment

    $info = EF $dteProject $dteStartupProject $params -json

    if ($PSCmdlet.ShouldProcess("database '$($info.databaseName)' on server '$($info.dataSource)'"))
    {
        $params = 'database', 'drop', '--force'
        $params += GetParams $Context $Environment

        EF $dteProject $dteStartupProject $params -skipBuild
    }
}

#
# Enable-Migrations (Obsolete)
#

function Enable-Migrations
{
    WarnIfEF6 'Update-Database'
    Write-Warning 'Enable-Migrations is obsolete. Use Add-Migration to start using Migrations.'
}

#
# Remove-Migration
#

Register-TabExpansion Remove-Migration @{
    Context = { param($x) GetContextTypes $x.Environment $x.Project $x.StartupProject }
    Project = { GetProjects }
    StartupProject = { GetProjects }
}

<#
.SYNOPSIS
    Removes the last migration.

.DESCRIPTION
    Removes the last migration.

.PARAMETER Force
    Don't check to see if the migration has been applied to the database. Always implied on UWP apps.

.PARAMETER Context
    The DbContext to use.

.PARAMETER Environment
    The environment to use. Defaults to "Development".

.PARAMETER Project
    The project to use.

.PARAMETER StartupProject
    The startup project to use. Defaults to the solution's startup project.

.LINK
    Add-Migration
    about_EntityFrameworkCore
#>
function Remove-Migration
{
    [CmdletBinding(PositionalBinding = $false)]
    param([switch] $Force, [string] $Context, [string] $Environment, [string] $Project, [string] $StartupProject)

    $dteProject = GetProject $Project
    $dteStartupProject = GetStartupProject $StartupProject $dteProject

    if (IsUWP $dteStartupProject)
    {
        $Force = [switch]::Present
    }

    $params = 'migrations', 'remove'

    if ($Force)
    {
        $params += '--force'
    }

    $params += GetParams $Context $Environment

    $result = EF $dteProject $dteStartupProject $params -json

    $result.files | %{
        $projectItem = GetProjectItem $dteProject $_
        if ($projectItem)
        {
            $projectItem.Remove()
        }
    }
}

#
# Scaffold-DbContext
#

Register-TabExpansion Scaffold-DbContext @{
    Provider = { param($x) GetProviders $x.Project }
    Project = { GetProjects }
    StartupProject = { GetProjects }
    OutputDir = { <# Disabled. Otherwise, paths would be relative to the solution directory. #> }
}

<#
.SYNOPSIS
    Scaffolds a DbContext and entity types for a database.

.DESCRIPTION
    Scaffolds a DbContext and entity types for a database.

.PARAMETER Connection
    The connection string to the database.

.PARAMETER Provider
    The provider to use. (E.g. Microsoft.EntityFrameworkCore.SqlServer)

.PARAMETER OutputDir
    The directory to put files in. Paths are relaive to the project directory.

.PARAMETER Context
    The name of the DbContext to generate.

.PARAMETER Schemas
    The schemas of tables to generate entity types for.

.PARAMETER Tables
    The tables to generate entity types for.

.PARAMETER DataAnnotations
    Use attributes to configure the model (where possible). If omitted, only the fluent API is used.

.PARAMETER Force
    Overwrite existing files.

.PARAMETER Environment
    The environment to use. Defaults to "Development".

.PARAMETER Project
    The project to use.

.PARAMETER StartupProject
    The startup project to use. Defaults to the solution's startup project.

.LINK
    about_EntityFrameworkCore
#>
function Scaffold-DbContext
{
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Connection,
        [Parameter(Position = 1, Mandatory =  $true)]
        [string] $Provider,
        [string] $OutputDir,
        [string] $Context,
        [string[]] $Schemas = @(),
        [string[]] $Tables = @(),
        [switch] $DataAnnotations,
        [switch] $Force,
        [string] $Environment,
        [string] $Project,
        [string] $StartupProject)

    $dteProject = GetProject $Project
    $dteStartupProject = GetStartupProject $StartupProject $dteProject

    $params = 'dbcontext', 'scaffold', $Connection, $Provider

    if ($OutputDir)
    {
        $params += '--output-dir', $OutputDir
    }

    if ($Context)
    {
        $params += '--context', $Context
    }

    $params += $Schemas | %{ '--schema', $_ }
    $params += $Tables | %{ '--table', $_ }

    if ($DataAnnotations)
    {
        $params += '--data-annotations'
    }

    if ($Force)
    {
        $params += '--force'
    }

    $params += GetParams -Environment $Environment

    $result = EF $dteProject $dteStartupProject $params -json

    $result.files | %{ $dteProject.ProjectItems.AddFromFile($_) | Out-Null }
    $DTE.ItemOperations.OpenFile($result.files[0]) | Out-Null
    ShowConsole
}

#
# Script-Migration
#

Register-TabExpansion Script-Migration @{
    From = { param($x) GetMigrations $x.Context $x.Environment $x.Project $x.StartupProject }
    To = { param($x) GetMigrations $x.Context $x.Environment $x.Project $x.StartupProject }
    Context = { param($x) GetContextTypes $x.Environment $x.Project $x.StartupProject }
    Project = { GetProjects }
    StartupProject = { GetProjects }
}

<#
.SYNOPSIS
    Generates a SQL script from migrations.

.DESCRIPTION
    Generates a SQL script from migrations.

.PARAMETER From
    The starting migration. Defaults to '0' (the initial database).

.PARAMETER To
    The ending migration. Defaults to the last migration.

.PARAMETER Idempotent
    Generate a script that can be used on a database at any migration.

.PARAMETER Context
    The DbContext to use.

.PARAMETER Environment
    The environment to use. Defaults to "Development".

.PARAMETER Project
    The project to use.

.PARAMETER StartupProject
    The startup project to use. Defaults to the solution's startup project.

.LINK
    Update-Database
    about_EntityFrameworkCore
#>
function Script-Migration
{
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ParameterSetName = 'WithoutTo', Position = 0)]
        [Parameter(ParameterSetName = 'WithTo', Position = 0, Mandatory = $true)]
        [string] $From,
        [Parameter(ParameterSetName = 'WithTo', Position = 1, Mandatory = $true)]
        [string] $To,
        [switch] $Idempotent,
        [string] $Context,
        [string] $Environment,
        [string] $Project,
        [string] $StartupProject)

    $dteProject = GetProject $Project
    $dteStartupProject = GetStartupProject $StartupProject $dteProject

    $projectDir = GetProperty $dteProject.Properties 'FullPath'
    $intermediatePath = GetIntermediatePath $dteProject
    $scriptFileName = [IO.Path]::ChangeExtension([IO.Path]::GetRandomFileName(), '.sql')
    $scriptPath = Join-Path (Join-Path $projectDir $intermediatePath) $scriptFileName

    $params = 'migrations', 'script', '--output', $scriptPath

    if ($From)
    {
        $params += $From
    }

    if ($To)
    {
        $params += $To
    }

    if ($Idempotent)
    {
        $params += '--idempotent'
    }

    $params += GetParams $Context $Environment

    EF $dteProject $dteStartupProject $params

    $DTE.ItemOperations.OpenFile($scriptPath) | Out-Null
    ShowConsole
}

#
# Update-Database
#

Register-TabExpansion Update-Database @{
    Migration = { param($x) GetMigrations $x.Context $x.Environment $x.Project $x.StartupProject }
    Context = { param($x) GetContextTypes $x.Environment $x.Project $x.StartupProject }
    Project = { GetProjects }
    StartupProject = { GetProjects }
}

<#
.SYNOPSIS
    Updates the database to a specified migration.

.DESCRIPTION
    Updates the database to a specified migration.

.PARAMETER Migration
    The target migration. If '0', all migrations will be reverted. Defaults to the last migration.

.PARAMETER Context
    The DbContext to use.

.PARAMETER Environment
    The environment to use. Defaults to "Development".

.PARAMETER Project
    The project to use.

.PARAMETER StartupProject
    The startup project to use. Defaults to the solution's startup project.

.LINK
    Script-Migration
    about_EntityFrameworkCore
#>
function Update-Database
{
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0)]
        [string] $Migration,
        [string] $Context,
        [string] $Environment,
        [string] $Project,
        [string] $StartupProject)

    WarnIfEF6 'Update-Database'

    $dteProject = GetProject $Project
    $dteStartupProject = GetStartupProject $StartupProject $dteProject

    if (IsUWP $dteStartupProject)
    {
        throw 'Update-Database shouldn''t be used with Universal Windows Platform apps. Instead, call ' +
            'DbContext.Database.Migrate() at runtime.'
    }

    $params = 'database', 'update'

    if ($Migration)
    {
        $params += $Migration
    }

    $params += GetParams $Context $Environment

    EF $dteProject $dteStartupProject $params
}

#
# (Private Helpers)
#

function GetProjects
{
    return Get-Project -All | %{ $_.ProjectName }
}

function GetProviders($projectName)
{
    if (!$projectName)
    {
        $projectName = (Get-Project).ProjectName
    }

    return Get-Package -ProjectName $projectName | %{ $_.Id }
}

function GetContextTypes($environment, $projectName, $startupProjectName)
{
    $project = GetProject $projectName
    $startupProject = GetStartupProject $startupProjectName $project

    $params = 'dbcontext', 'list'
    $params += GetParams -Environment $environment

    $result = EF $project $startupProject $params -json -skipBuild

    return $result | %{ $_.safeName }
}

function GetMigrations($context, $environment, $projectName, $startupProjectName)
{
    $project = GetProject $projectName
    $startupProject = GetStartupProject $startupProjectName $project

    $params = 'migrations', 'list'
    $params += GetParams $context $environment

    $result = EF $project $startupProject $params -json -skipBuild

    return $result | %{ $_.safeName }
}

function WarnIfEF6 ($cmdlet)
{
    if (Get-Module 'EntityFramework')
    {
        Write-Warning "Both Entity Framework Core and Entity Framework 6 are installed. The Entity Framework Core tools are running. Use 'EntityFramework\$cmdlet' for Entity Framework 6."
    }
}

function GetProject($projectName)
{
    if (!$projectName)
    {
        return Get-Project
    }

    return Get-Project $projectName
}

function GetStartupProject($name, $fallbackProject)
{
    if ($name)
    {
        return Get-Project $name
    }

    $startupProjectPaths = $DTE.Solution.SolutionBuild.StartupProjects
    if ($startupProjectPaths)
    {
        if ($startupProjectPaths.Length -eq 1)
        {
            $startupProjectPath = $startupProjectPaths[0]
            if (!(Split-Path -IsAbsolute $startupProjectPath))
            {
                $solutionPath = Split-Path (GetProperty $DTE.Solution.Properties 'Path')
                $startupProjectPath = Join-Path $solutionPath $startupProjectPath -Resolve
            }

            $startupProject = GetSolutionProjects | ?{
                try
                {
                    $fullName = $_.FullName
                }
                catch [NotImplementedException]
                {
                    return $false
                }

                if ($fullName -and $fullName.EndsWith('\'))
                {
                    $fullName = $fullName.Substring(0, $fullName.Length - 1)
                }

                return $fullName -eq $startupProjectPath
            }
            if ($startupProject)
            {
                return $startupProject
            }

            Write-Warning "Unable to resolve startup project '$startupProjectPath'."
        }
        else
        {
            Write-Verbose 'More than one startup project found.'
        }
    }
    else
    {
        Write-Verbose 'No startup project found.'
    }

    return $fallbackProject
}

function GetSolutionProjects()
{
    $projects = New-Object 'System.Collections.Stack'

    $DTE.Solution.Projects | %{
        $projects.Push($_)
    }

    while ($projects.Count -ne 0)
    {
        $project = $projects.Pop();

        <# yield return #> $project

        if ($project.ProjectItems)
        {
            $project.ProjectItems | ?{ $_.SubProject } | %{
                $projects.Push($_.SubProject)
            }
        }
    }
}

function GetParams($context, $environment)
{
    $params = @()

    if ($context)
    {
        $params += '--context', $context
    }

    if ($environment)
    {
        $params += '--environment', $environment
    }

    return $params
}

function ShowConsole
{
    $componentModel = Get-VSComponentModel
    $powerConsoleWindow = $componentModel.GetService([NuGetConsole.IPowerConsoleWindow])
    $powerConsoleWindow.Show()
}

function EF($project, $startupProject, $params, [switch] $json, [switch] $skipBuild)
{
    if (IsUWP $project)
    {
        $outputType = GetProperty $project.Properties 'OutputType'
        $outputTypeEx = GetProperty $project.Properties 'OutputTypeEx'
        if ($outputType -eq 2 -and $outputTypeEx -eq 3)
        {
            throw "Project '$($project.ProjectName)' is a Windows Runtime component. The Entity Framework Core " +
                'Package Manager Console Tools don''t support this type of project.'
        }
    }

    if (IsUWP $startupProject)
    {
        $useDotNetNative = GetProperty $startupProject.ConfigurationManager.ActiveConfiguration.Properties 'ProjectN.UseDotNetNativeToolchain'
        if ($useDotNetNative -eq 'True')
        {
            throw "Startup project '$($startupProject.ProjectName)' compiles with the .NET Native tool chan. Uncheck " +
                'this option in the project settings or use a different configuration and try again.'
        }

        $outputType = GetProperty $startupProject.Properties 'OutputType'
        if ($outputType -eq 2)
        {
            $outputTypeEx = GetProperty $startupProject.Properties 'OutputTypeEx'
            if ($outputTypeEx -eq 2)
            {
                throw "Startup project '$($startupProject.ProjectName)' is a class library. Select a Universal " +
                    'Windows Platform app as your startup project and try again.'
            }
            if ($outputTypeEx -eq 3)
            {
                throw "Startup project '$($startupProject.ProjectName)' is a Windows Runtime component. The Entity " +
                    'Framework Core Package Manager Console Tools don''t support this type of project.'
            }
        }
    }

    if (!$skipBuild)
    {
        Write-Verbose 'Build started...'

        # TODO: Only build startup project. Don't use BuildProject, you can't specify platform
        $solutionBuild = $DTE.Solution.SolutionBuild
        $solutionBuild.Build(<# WaitForBuildToFinish: #> $true)
        if ($solutionBuild.LastBuildInfo)
        {
            throw 'Build failed.'
        }

        Write-Verbose 'Build succeeded.'
    }

    $startupProjectDir = GetProperty $startupProject.Properties 'FullPath'
    $outputPath = GetOutputPath $startupProject
    $targetDir = Join-Path $startupProjectDir $outputPath
    $startupTargetFileName = GetOutputFileName $startupProject
    $startupTargetPath = Join-Path $targetDir $startupTargetFileName
    $targetFramework = GetTargetFramework $startupProject

    if ($targetFramework -in '.NETFramework', '.NETCore')
    {
        $platformTarget = GetPlatformTarget $startupProject
        if ($platformTarget -eq 'x86')
        {
            $exePath = Join-Path $PSScriptRoot 'net451\ef.x86.exe'
        }
        elseif ($platformTarget -in 'AnyCPU', 'x64')
        {
            $exePath = Join-Path $PSScriptRoot 'net451\ef.exe'
        }
        else
        {
            throw "Startup project '$($startupProject.ProjectName)' has an active platform of '$platformTarget'. Select " +
                'a different platform and try again.'
        }
    }
    elseif ($targetFramework -in '.NETCoreApp', '.NETStandard')
    {
        $exePath = (Get-Command 'dotnet').Path

        $startupTargetName = GetProperty $startupProject.Properties 'AssemblyName'
        $depsfile = Join-Path $targetDir ($startupTargetName + '.deps.json')
        $nugetPackageRoot = (GetNuGetPackageRoot $startupProject).TrimEnd('\')
        $runtimeconfig = Join-Path $targetDir ($startupTargetName + '.runtimeconfig.json')
        $efPath = Join-Path $PSScriptRoot 'netcoreapp1.0\ef.dll'

        $dotnetParams = 'exec', '--depsfile', $depsfile, '--additionalprobingpath', $nugetPackageRoot

        if (Test-Path $runtimeconfig)
        {
            $dotnetParams += '--runtimeconfig', $runtimeconfig
        }

        $dotnetParams += $efPath
    }
    else
    {
        throw "Startup project '$($startupProject.ProjectName)' targets framework '$targetFramework'. " +
            'The Entity Framework Core Package Manager Console Tools don''t support this framework.'
    }

    $projectDir = GetProperty $project.Properties 'FullPath'
    $targetFileName = GetOutputFileName $project
    $targetPath = Join-Path $targetDir $targetFileName
    $rootNamespace = GetProperty $project.Properties 'RootNamespace'

    if (IsWeb $startupProject)
    {
        $dataDir = Join-Path $startupProjectDir 'App_Data'
    }
    else
    {
        $dataDir = $targetDir
    }

    $efParams = '--verbose', '--no-color', '--prefix-output'

    if (IsUWP $startupProject)
    {
        $efParams += '--no-appdomain'
    }

    $efParams += '--assembly', $targetPath,
        '--startup-assembly', $startupTargetPath,
        '--project-dir', $projectDir,
        '--content-root-path', $startupProjectDir,
        '--data-dir', $dataDir

    if ($rootNamespace)
    {
        $efParams += '--root-namespace', $rootNamespace
    }

    $allParams = $dotnetParams + $efParams + $params
    if ($json)
    {
        $allParams += '--json'

        Invoke-Process -Executable $exePath -Arguments $allParams -RedirectByPrefix -ErrorAction SilentlyContinue -ErrorVariable invokeErrors -JsonOutput | ConvertFrom-Json
    }
    else
    {
        Invoke-Process -Executable $exePath -Arguments $allParams -RedirectByPrefix -ErrorAction SilentlyContinue -ErrorVariable invokeErrors
    }

    if ($invokeErrors)
    {
        $combined = ($invokeErrors |
            ?{ $_.Exception.Message -notLike '*non-zero exit code' } |
            %{ $_.Exception.Message }) -join "`n"
        if (!$combined)
        {
            $lastError = $invokeErrors | select -Last 1
            if (!$lastError.Exception.Message)
            {
                throw 'Operation failed with unspecified error'
            }

            throw $lastError.Exception.Message
        }

        throw $combined
    }
}

function IsXproj($project)
{
    return $project.Kind -eq '{8BB2217D-0F2D-49D1-97BC-3654ED321F3B}'
}

function IsCsproj2($project)
{
    return $project.Kind -eq '{9A19103F-16F7-4668-BE54-9A1E7A4F7556}'
}

function IsWeb($project)
{
    $types = GetProjectTypes $project

    return $types -contains '{349C5851-65DF-11DA-9384-00065B846F21}'
}

function IsUWP($project)
{
    $types = GetProjectTypes $project

    return $types -contains '{A5A43C5B-DE2A-4C0C-9213-0A381AF9435A}'
}

function GetIntermediatePath($project)
{
    # TODO: Remove when dotnet/roslyn-project-system#665 is fixed
    if (IsCsproj2 $project)
    {
        return GetCsproj2Property $project 'IntermediateOutputPath'
    }
    if (IsXproj $project)
    {
        $browseObjectContext = Get-Interface $project 'Microsoft.VisualStudio.ProjectSystem.Designers.IVsBrowseObjectContext'
        $unconfiguredProject = $browseObjectContext.UnconfiguredProject
        $configuredProject = $unconfiguredProject.GetSuggestedConfiguredProjectAsync().Result
        $properties = $configuredProject.Services.ProjectPropertiesProvider.GetCommonProperties()
        $baseIntermediatePath = $properties.GetEvaluatedPropertyValueAsync('IntermediateOutputPath').Result
        $configuration = $project.ConfigurationManager.ActiveConfiguration.ConfigurationName
        $targetFrameworkMoniker = GetXprojTargetFrameworkMoniker $project

        return Join-Path $baseIntermediatePath "$configuration\$targetFrameworkMoniker\"
    }

    return GetProperty $project.ConfigurationManager.ActiveConfiguration.Properties 'IntermediatePath'
}

function GetPlatformTarget($project)
{
    # TODO: Remove when dotnet/roslyn-project-system#669 is fixed
    if (IsCsproj2 $project)
    {
        return GetCsproj2Property $project 'PlatformTarget'
    }
    if (IsXproj $project)
    {
        return 'x64'
    }

    return GetProperty $project.ConfigurationManager.ActiveConfiguration.Properties 'PlatformTarget'
}

function GetOutputFileName($project)
{
    # TODO: Remove when dotnet/roslyn-project-system#667 is fixed
    if (IsCsproj2 $project)
    {
        return GetCsproj2Property $project 'TargetFileName'
    }
    if (IsXproj $project)
    {
        $outputFileName = GetProperty $project.Properties 'AssemblyName'

        $targetFramework = GetTargetFramework $project
        if ($targetFramework -eq '.NETFramework')
        {
            $outputFileName += '.exe'
        }
        else
        {
            $outputFileName += '.dll'
        }

        return $outputFileName
    }

    return GetProperty $project.Properties 'OutputFileName'
}

function GetTargetFramework($project)
{
    if (IsXproj $project)
    {
        $targetFrameworkMoniker = GetXprojTargetFrameworkMoniker $project
        if ($targetFrameworkMoniker -like 'net45*' -or $targetFrameworkMoniker -like 'net46*')
        {
            return '.NETFramework'
        }
        if ($targetFrameworkMoniker -like 'netcoreapp1.*')
        {
            return '.NETCoreApp'
        }
        if ($targetFrameworkMoniker -like 'netstandard1.*')
        {
            return '.NETStandard'
        }

        return $targetFrameworkMoniker
    }

    $targetFrameworkMoniker = GetProperty $project.Properties 'TargetFrameworkMoniker'
    $frameworkName = New-Object 'System.Runtime.Versioning.FrameworkName' $targetFrameworkMoniker

    return $frameworkName.Identifier
}

function GetXprojTargetFrameworkMoniker($project)
{
    $projectDir = GetProperty $project.Properties 'FullPath'
    $projectFile = Join-Path $projectDir 'project.json'
    $projectInfo = Get-Content $projectFile -Raw | ConvertFrom-Json

    $frameworks = $projectInfo.frameworks | Get-Member -MemberType NoteProperty | %{ $_.Name }
    if ($frameworks -is [string])
    {
        return $frameworks
    }

    return $frameworks[0]
}

function GetOutputPath($project)
{
    if (IsXproj $project)
    {
        $activeConfiguration = $project.ConfigurationManager.ActiveConfiguration
        $baseOutputPath = GetProperty $activeConfiguration.Properties 'OutputPath'
        $configuration = $activeConfiguration.ConfigurationName
        $targetFrameworkMoniker = GetXprojTargetFrameworkMoniker $project

        $outputPath = Join-Path $baseOutputPath "$configuration\$targetFrameworkMoniker\"

        $targetFramework = GetTargetFramework $project
        if ($targetFramework -eq '.NETFramework')
        {
            $outputPath += 'win7-x64\'
        }

        return $outputPath
    }

    return GetProperty $project.ConfigurationManager.ActiveConfiguration.Properties 'OutputPath'
}

function GetNuGetPackageRoot($project)
{
    if (IsXproj $project)
    {
        return Join-Path $env:USERPROFILE '.nuget\packages\'
    }

    return GetCsproj2Property $project 'NuGetPackageRoot'
}

function GetProjectTypes($project)
{
    $solution = Get-VSService 'Microsoft.VisualStudio.Shell.Interop.SVsSolution' 'Microsoft.VisualStudio.Shell.Interop.IVsSolution'
    $hierarchy = $null
    $hr = $solution.GetProjectOfUniqueName($project.UniqueName, [ref] $hierarchy)
    [Runtime.InteropServices.Marshal]::ThrowExceptionForHR($hr)

    $aggregatableProject = Get-Interface $hierarchy 'Microsoft.VisualStudio.Shell.Interop.IVsAggregatableProject'
    if (!$aggregatableProject)
    {
        return $project.Kind
    }

    $projectTypeGuidsString = $null
    $hr = $aggregatableProject.GetAggregateProjectTypeGuids([ref] $projectTypeGuidsString)
    [Runtime.InteropServices.Marshal]::ThrowExceptionForHR($hr)

    return $projectTypeGuidsString.Split(';')
}

function GetProperty($properties, $propertyName) {
    try
    {
        return $properties.Item($propertyName).Value
    }
    catch
    {
        return $null
    }
}

function GetCsproj2Property($project, $propertyName)
{
    $browseObjectContext = Get-Interface $project 'Microsoft.VisualStudio.ProjectSystem.Properties.IVsBrowseObjectContext'
    $unconfiguredProject = $browseObjectContext.UnconfiguredProject
    $configuredProject = $unconfiguredProject.GetSuggestedConfiguredProjectAsync().Result
    $properties = $configuredProject.Services.ProjectPropertiesProvider.GetCommonProperties()

    return $properties.GetEvaluatedPropertyValueAsync($propertyName).Result
}

function GetProjectItem($project, $path) {
    $fullPath = GetProperty $project.Properties 'FullPath'

    if (Split-Path $path -IsAbsolute)
    {
        $path = $path.Substring($fullPath.Length)
    }

    $itemDirectory = (Split-Path $path -Parent)

    $projectItems = $project.ProjectItems
    if ($itemDirectory)
    {
        $directories = $itemDirectory.Split('\')
        $directories | %{
            if ($projectItems)
            {
                $projectItems = $projectItems.Item($_).ProjectItems
            }
        }
    }

    if (!$projectItems)
    {
        return $null
    }

    $itemName = Split-Path $path -Leaf

    try
    {
        return $projectItems.Item($itemName)
    }
    catch [Exception]
    {
    }

    return $null
}
