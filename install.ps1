# orchestrate installer (PLAN_D-O D-O.48). It lives in the release repository; the README's one line runs it:
#
#   irm https://raw.githubusercontent.com/choohui/forme/main/install.ps1 | iex
#
# It reads latest.json of the newest release, downloads that zip, checks its SHA-256 against latest.json, unpacks it
# into %LOCALAPPDATA%\orchestrate and runs its setup.ps1. A folder that already holds an install is updated with its
# own update.ps1 (data stays). Nothing needs administrator rights and nothing outside the install folder and %TEMP%
# is written here.
#
# With arguments (the piped form takes none):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/choohui/forme/main/install.ps1))) -Dir D:\orchestrate
#   -Dir <folder>     where to install (default %LOCALAPPDATA%\orchestrate)
#   -Source <where>   an https address or a local folder that holds latest.json and the zip (default: the newest release)
#   -NoSetup          unpack only; run setup.ps1 yourself
#   -SetupArgs ...    switches handed to setup.ps1 / update.ps1 (e.g. -SetupArgs '-Yes')
#
# ASCII only on purpose: Windows PowerShell 5.1 reads a script file without a byte order mark as ANSI, and a mark at
# the start of a piped script is not safe either. scripts/release.ps1 -Repo fills in the repository's name (the
# placeholder in the three addresses of this file) when it stages it for the release repository.
function Install-Orchestrate {
  param(
    [string]$Dir = (Join-Path $env:LOCALAPPDATA 'orchestrate'),
    [string]$Source = 'https://github.com/choohui/forme/releases/latest/download',
    [switch]$NoSetup,
    [string[]]$SetupArgs = @()
  )
  $ErrorActionPreference = 'Stop'
  $work = $null
  try {
    if ($PSVersionTable.PSVersion -lt [version]'5.1') { throw 'Windows PowerShell 5.1 or later is needed.' }
    if (-not [Environment]::Is64BitOperatingSystem) { throw '64-bit Windows 10 or 11 is needed.' }
    $os = [Environment]::OSVersion.Version
    if ($os.Major -lt 10 -or $os.Build -lt 17763) { throw "Windows 10 (1809 or later) or 11 is needed (this is $os)." }

    $remote = $Source -match '^[a-z][a-z0-9+.-]*://'
    if ($remote -and $Source -notmatch '^https://' -and $Source -notmatch '^http://(127\.0\.0\.1|localhost)(:\d+)?(/|$)') {
      throw "-Source must be an https address or a local folder: $Source"
    }
    if ($remote) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
    $Source = $Source.TrimEnd('/', '\')
    $Dir = [IO.Path]::GetFullPath($Dir)

    $work = Join-Path $env:TEMP ('orchestrate-install-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force $work | Out-Null
    function Get-ReleaseFile([string]$Name) {
      $target = Join-Path $work $Name
      if ($remote) {
        $previous = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'   # the progress bar makes Invoke-WebRequest many times slower in 5.1
        try { Invoke-WebRequest -UseBasicParsing -Uri "$Source/$Name" -OutFile $target } finally { $ProgressPreference = $previous }
      } else {
        Copy-Item -Force (Join-Path $Source $Name) $target
      }
      return $target
    }

    # --- 1 which release -------------------------------------------------------------------------------------------
    Write-Host "orchestrate installer - from $Source"
    $latest = Get-Content -Raw -Encoding UTF8 (Get-ReleaseFile 'latest.json') | ConvertFrom-Json
    $file = [string]$latest.file
    $sha = ([string]$latest.sha256).ToLower()
    $version = [string]$latest.version
    if ($file -notmatch '^orchestrate-[A-Za-z0-9._+-]+\.zip$') { throw "latest.json names an unexpected file: $file" }
    if ($sha -notmatch '^[0-9a-f]{64}$') { throw 'latest.json has no SHA-256.' }

    $installed = $null
    $mark = Join-Path $Dir 'release.json'
    if (Test-Path $mark) { $installed = [string](Get-Content -Raw -Encoding UTF8 $mark | ConvertFrom-Json).version }
    if ($installed -and $installed -eq $version) {
      Write-Host "orchestrate $version is already installed in $Dir."
      Write-Host "Start it with: powershell -NoProfile -ExecutionPolicy Bypass -File `"$Dir\scripts\start.ps1`""
      return
    }
    if (-not $installed -and (Test-Path $Dir) -and @(Get-ChildItem -Force $Dir).Count) {
      throw "$Dir is not empty and is not an orchestrate install. Choose another folder with -Dir."
    }

    # --- 2 download and check --------------------------------------------------------------------------------------
    Write-Host "downloading $file"
    $zip = Get-ReleaseFile $file
    $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
    if ($actual -ne $sha) { throw "the SHA-256 of $file differs from latest.json: nothing was installed." }
    Write-Host 'sha256 ok'
    [IO.File]::WriteAllText("$zip.sha256", "$sha  $file`n")   # update.ps1 checks the zip against the file beside it

    function Invoke-Script([string]$Script, [string[]]$Arguments) {
      $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Script`"") + $Arguments
      # not through a pipe: the servers setup.ps1 starts must not keep this installer waiting
      $run = Start-Process -FilePath 'powershell' -ArgumentList $all -WorkingDirectory $Dir -NoNewWindow -PassThru
      $null = $run.Handle
      $run.WaitForExit()
      return $run.ExitCode
    }

    # --- 3 an existing install: its own update.ps1 (the data stays) ------------------------------------------------
    if ($installed) {
      Write-Host "updating $installed -> $version in $Dir"
      if ($NoSetup) { Write-Host "the new zip is at $zip (-NoSetup: update.ps1 was not run)"; $work = $null; return }
      $code = Invoke-Script (Join-Path $Dir 'update.ps1') (@('-Zip', "`"$zip`"") + $SetupArgs)
      if ($code -ne 0) { throw "update.ps1 stopped (exit $code). The zip stays at $zip." }
      return
    }

    # --- 4 a new install -------------------------------------------------------------------------------------------
    Write-Host "installing orchestrate $version into $Dir"
    # unpacked beside the target (the same drive: a folder cannot be moved across drives), then moved in
    $unpack = "$Dir.unpack"
    if (Test-Path $unpack) { Remove-Item -Recurse -Force $unpack }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $unpack)
    $top = @(Get-ChildItem -Directory $unpack)
    if ($top.Count -ne 1 -or -not (Test-Path (Join-Path $top[0].FullName 'app/dist-server/server/hub/main.js'))) {
      Remove-Item -Recurse -Force $unpack
      throw 'the zip is not an orchestrate release.'
    }
    New-Item -ItemType Directory -Force $Dir | Out-Null
    Get-ChildItem -Force $top[0].FullName | Move-Item -Destination $Dir
    Remove-Item -Recurse -Force $unpack
    if ($NoSetup) {
      Write-Host "unpacked. Next: powershell -NoProfile -ExecutionPolicy Bypass -File `"$Dir\setup.ps1`""
      return
    }
    $code = Invoke-Script (Join-Path $Dir 'setup.ps1') $SetupArgs
    if ($code -ne 0) { throw "setup.ps1 stopped (exit $code). Run it again: powershell -NoProfile -ExecutionPolicy Bypass -File `"$Dir\setup.ps1`"" }
  } catch {
    Write-Host ''
    Write-Host "orchestrate installer stopped: $($_.Exception.Message)" -ForegroundColor Red
  } finally {
    if ($work -and (Test-Path $work)) { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
  }
}
Install-Orchestrate @args
