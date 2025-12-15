param(
    [ValidateSet('Debug','Release','Beta')]
    [string]$Configuration = 'Release',

    [string]$OutputDirectory = 'dist',

    [switch]$CreateNuGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$csproj = Join-Path $root 'PowerBiEmbedder.csproj'

Write-Host "Building configuration '$Configuration'..." -ForegroundColor Cyan
dotnet build $csproj -c $Configuration | Out-Null

$copyDir = if ($Configuration -eq 'Beta') { 'PluginsBeta' } else { 'Plugins' }
$pluginSource = Join-Path $root $copyDir

if (-not (Test-Path $pluginSource)) {
    throw "Expected plugin directory '$pluginSource' was not produced. Verify the build completed successfully."
}

$output = Join-Path $root $OutputDirectory
if (-not (Test-Path $output)) {
    New-Item -ItemType Directory -Path $output | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$zipName = "PowerBiEmbedder-$Configuration-$timestamp.zip"
$zipPath = Join-Path $output $zipName

Write-Host "Creating archive '$zipPath'" -ForegroundColor Cyan
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $pluginSource '*') -DestinationPath $zipPath -Force

if ($Configuration -eq 'Beta') {
    $xrmToolBoxPluginRoot = 'C:\Users\misewell\AppData\Roaming\MscrmTools\XrmToolBox\Plugins'

    Write-Host "Deploying beta build to '$xrmToolBoxPluginRoot'" -ForegroundColor Cyan
    try {
        Copy-Item -Path (Join-Path $pluginSource '*') -Destination $xrmToolBoxPluginRoot -Recurse -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to copy files to '$xrmToolBoxPluginRoot'. Ensure XrmToolBox is closed and try again. Details: $($_.Exception.Message)"
    }
}

if ($CreateNuGet -and $Configuration -eq 'Release') {
    $nugetExe = Get-Command nuget -ErrorAction SilentlyContinue
    if (-not $nugetExe) {
        Write-Warning 'nuget.exe was not found on PATH; skipping .nupkg creation.'
    }
    else {
        $nugetOutput = Join-Path $output 'nuget'
        if (-not (Test-Path $nugetOutput)) {
            New-Item -ItemType Directory -Path $nugetOutput | Out-Null
        }

        $nuspec = Join-Path $root 'Fic.XTB.PowerBiEmbedder.nuspec'
        Write-Host "Packing NuGet package to '$nugetOutput'" -ForegroundColor Cyan
        & $nugetExe.Path pack $nuspec -OutputDirectory $nugetOutput -Properties "Configuration=$Configuration" | Out-Null
    }
}

Write-Host "Packaging complete." -ForegroundColor Green