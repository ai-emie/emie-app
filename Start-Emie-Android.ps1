param(
    [ValidatePattern('^emulator-[0-9]+$')][string]$DeviceId = 'emulator-5554',
    [ValidateSet('Offline', 'KI')][string]$Development = 'Offline'
)
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "Emie Windows - Flutter $Development - $DeviceId (r = Hot Reload)"
$flutter = 'C:\Users\Patze\flutter\bin\flutter.bat'
$sdk = 'C:\Users\Patze\AppData\Local\Android\sdk'
$jdk = 'C:\Users\Patze\Emie-LocalDev\b3-20261002T132620Z-4c04767e\tools\jdk-21.0.12.1+1'
foreach ($required in @($flutter,"$sdk\platform-tools\adb.exe","$jdk\bin\java.exe")) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw 'Vorhandenes Werkzeug fehlt; keine automatische Installation.' }
}
$state = & "$sdk\platform-tools\adb.exe" -s $DeviceId get-state
if ($LASTEXITCODE -ne 0 -or $state -ne 'device') { throw 'Expliziter Emulator ist nicht bereit.' }
$config = Join-Path $PSScriptRoot '.dart_tool\p2-flutter-config'
New-Item -ItemType Directory -Path $config -Force | Out-Null
# Per-process Flutter JDK selection, using an existing JDK; no global settings.
@{'jdk-dir'=$jdk} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $config '.flutter_settings') -Encoding UTF8
$names = @('APPDATA','JAVA_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','FLUTTER_SUPPRESS_ANALYTICS','DART_SUPPRESS_ANALYTICS','GRADLE_OPTS')
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
try {
    $env:APPDATA = $config
    $env:JAVA_HOME = $jdk
    $env:ANDROID_HOME = $sdk
    $env:ANDROID_SDK_ROOT = $sdk
    $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
    $env:DART_SUPPRESS_ANALYTICS = 'true'
    $env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx3G -Dorg.gradle.workers.max=2 -Dorg.gradle.daemon=false'
    Push-Location -LiteralPath $PSScriptRoot
    try {
        $localMode = if ($Development -eq 'KI') { '--dart-define=EMIE_P3=true' } else { '--dart-define=EMIE_OFFLINE=true' }
        & $flutter run --debug --no-pub -d $DeviceId --dart-define=EMIE_LOCAL=true --dart-define=EMIE_LOCAL_PORT=8011 $localMode --vmservice-out-file=.dart_tool/p2-vm-service.json
        $result = $LASTEXITCODE
    } finally { Pop-Location }
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$saved[$name],'Process') }
}
exit $result
