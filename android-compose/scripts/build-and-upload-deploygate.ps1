param(
    [string]$ApkName = "motchill-debug.apk"
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Text) {
    Write-Host "[INFO] $Text" -ForegroundColor Cyan
}

function Write-ErrorAndExit([string]$Text) {
    Write-Host "[ERROR] $Text" -ForegroundColor Red
    exit 1
}

function Write-Success([string]$Text) {
    Write-Host "[SUCCESS] $Text" -ForegroundColor Green
}

function Ensure-JavaHome {
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
        return
    }

    $androidStudioJbr = "C:\Program Files\Android\Android Studio\jbr"
    if (Test-Path (Join-Path $androidStudioJbr "bin\java.exe")) {
        $env:JAVA_HOME = $androidStudioJbr
        $env:Path = "$($env:JAVA_HOME)\bin;$env:Path"
        Write-Info "JAVA_HOME set to Android Studio JBR."
        return
    }

    Write-ErrorAndExit "JAVA_HOME is not set and Android Studio JBR was not found."
}

function Get-DebugApkPath {
    $apkPath = Join-Path $PSScriptRoot "..\app\build\outputs\apk\debug\app-debug.apk"
    $resolved = Resolve-Path $apkPath -ErrorAction SilentlyContinue
    if (-not $resolved) {
        Write-ErrorAndExit "Debug APK was not found at $apkPath"
    }

    return $resolved.Path
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $repoRoot.Path
try {
    Ensure-JavaHome

    Write-Info "Building debug APK..."
    & .\gradlew.bat :app:assembleDebug
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorAndExit "Gradle build failed."
    }

    $apkPath = Get-DebugApkPath
    $docsDir = Join-Path $repoRoot.Path "docs"

    if (-not (Test-Path $docsDir)) {
        New-Item -Path $docsDir -ItemType Directory | Out-Null
    }

    $targetApkPath = Join-Path $docsDir $ApkName

    Write-Info "Copying APK to docs..."
    Copy-Item -LiteralPath $apkPath -Destination $targetApkPath -Force

    Write-Success "Done. APK copied to $targetApkPath"
}
finally {
    Pop-Location
}
