$env:JAVA_HOME = "C:\Java\jdk-17.0.13+11"
$env:ANDROID_HOME = "C:\Android\Sdk"
$env:PATH = "$env:JAVA_HOME\bin;C:\flutter\bin;C:\Android\Sdk\platform-tools;$env:PATH"

Write-Host "Flutter SDK: C:\flutter"
Write-Host "Java: $env:JAVA_HOME"
Write-Host "Android SDK: $env:ANDROID_HOME"

Set-Location C:\pid_tuner_app

Write-Host "`n[1/3] Getting dependencies..."
flutter pub get

Write-Host "`n[2/3] Building APK..."
flutter build apk --release

Write-Host "`n[3/3] Done!"
Write-Host "APK location: C:\pid_tuner_app\build\app\outputs\flutter-apk\app-release.apk"
