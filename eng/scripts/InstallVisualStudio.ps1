<#
.SYNOPSIS
    Installs or updates Visual Studio on a local developer machine.
.DESCRIPTION
    This installs Visual Studio along with all the workloads required to contribute to this repository.
.PARAMETER Edition
    Selects which 'offering' of Visual Studio to install. Must be one of these values:
        BuildTools
        Community
        Professional
        Enterprise (the default)
.PARAMETER InstallPath
    The location on disk where Visual Studio should be installed or updated.
.PARAMETER Passive
    Run the installer without requiring interaction.
.PARAMETER Quiet
    Run the installer without UI and wait for installation to complete.
.LINK
    https://visualstudio.com
    https://github.com/aspnet/AspNetCore/blob/master/docs/BuildFromSource.md
.EXAMPLE
    To install VS 2019 Enterprise, run this command in PowerShell:

        .\InstallVisualStudio.ps1
#>
[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [ValidateSet('BuildTools','Community', 'Professional', 'Enterprise')]
    [string]$Edition = 'Enterprise',
    [string]$InstallPath,
    [switch]$Passive,
    [switch]$Quiet
)

if ($Passive -and $Quiet) {
    Write-Host "The -Passive and -Quiet options cannot be used together." -f Red
    Write-Host "Run ``Get-Help $PSCommandPath`` for more details." -f Red
    exit 1
}

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 1

$intermedateDir = "$PSScriptRoot\obj"
mkdir $intermedateDir -ErrorAction Ignore | Out-Null

$bootstrapper = "$intermedateDir\vsinstaller.exe"
$ProgressPreference = 'SilentlyContinue' # Workaround PowerShell/PowerShell#2138
Invoke-WebRequest -Uri "https://aka.ms/vs/16/release/vs_$($Edition.ToLowerInvariant()).exe" -OutFile $bootstrapper

if (-not $InstallPath) {
    $basePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\"
    if ((Test-Path "$basePath\Preview") -and ("$Edition" -eq "Enterprise")) {
        $InstallPath = "$basePath\Preview"
    } else {
        $InstallPath = "$basePath\$Edition"
    }
}

# no backslashes - this breaks the installer
$InstallPath = $InstallPath.TrimEnd('\')

[string[]] $arguments = @()

if (Test-path $InstallPath) {
    $arguments += 'modify'
}

$responseFile = "$PSScriptRoot\vs.json"
if ("$Edition" -eq "BuildTools") {
    $responseFile = "$PSScriptRoot\vs.buildtools.json"
}

$arguments += `
    '--productId', "Microsoft.VisualStudio.Product.$Edition", `
    '--installPath', "`"$InstallPath`"", `
    '--in', "`"$responseFile`"", `
    '--norestart'

if ($Passive) {
    $arguments += '--passive'
}
if ($Quiet) {
    $arguments += '--quiet', '--wait'
}

Write-Host ""
Write-Host "Installing Visual Studio 2019 $Edition" -f Magenta
Write-Host ""
Write-Host "Running '$bootstrapper $arguments'"

$process = Start-Process -FilePath "$bootstrapper" -ArgumentList $arguments `
    -PassThru -RedirectStandardError "$intermedateDir\errors.txt" -Verbose -Wait
if ($process.ExitCode -ne 0) {
    Get-Content "$intermedateDir\errors.txt" | Write-Error
}

Remove-Item "$intermedateDir\errors.txt" -errorAction SilentlyContinue

exit $process.ExitCode
