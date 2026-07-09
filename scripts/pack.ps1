<#
.SYNOPSIS
    MCP Offline Pack Script (Windows PowerShell)
.DESCRIPTION
    Bundles all MCP tools and dependencies into an offline installer.
    Uses a unified deps/ structure for caching and installation.
.PARAMETER SkipNodejs / SkipPython / SkipPdf / SkipOffice
    Skip specific components (all included by default)
.PARAMETER NoCache
    Ignore cache, force re-download everything
#>
param(
    [switch]$SkipNodejs, [switch]$SkipPython, [switch]$SkipPdf, [switch]$SkipOffice,
    [switch]$NoCache, [string]$OutputDir = ""
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
if (-not $OutputDir) { $OutputDir = Join-Path $ProjectDir "build" }
$BundleDir = Join-Path $OutputDir "mcp-offline-bundle"
$BundleDeps = Join-Path $BundleDir "deps"
$BundleTools = Join-Path $BundleDir "tools"
$CacheDir = Join-Path $ProjectDir ".cache"
$CacheNpm = Join-Path $CacheDir "npm"; $CachePip = Join-Path $CacheDir "pip"
$CacheRuntimes = Join-Path $CacheDir "runtimes"; $CacheGit = Join-Path $CacheDir "git"
$NodeVersion = "22.14.0"; $PythonVersion = "3.11.9"
$PdfReaderV = "3.0.10"; $PdfToolkitRef = "main"  # git branch (version is in package.json, not a git tag)
$PipFastmcp = "3.2.0"; $PipDocx = "1.1.2"; $PipPptx = "1.0.2"; $PipXl = "3.1.5"; $PipPil = "11.0.0"
$Platform = "win"; $DateStamp = Get-Date -Format "yyyyMMdd"

function wI { Write-Host "[INFO]  " -F Blue -NoNewline; Write-Host $args[0] }
function wOK { Write-Host "[OK]    " -F Green -NoNewline; Write-Host $args[0] }
function wW { Write-Host "[WARN]  " -F Yellow -NoNewline; Write-Host $args[0] }
function wE { Write-Host "[ERROR] " -F Red -NoNewline; Write-Host $args[0] }
function wS { Write-Host ""; Write-Host ">>> $($args[0])" -F Cyan }
function wC { Write-Host "[CACHE] " -F Blue -NoNewline; Write-Host $args[0] }

# ---- Cache helpers ----
function _initCache { foreach ($d in @($CacheNpm,$CachePip,$CacheRuntimes,$CacheGit)) { mkdir $d -Force | Out-Null } }
function _cacheFile($n,$u) { $d=Join-Path $CacheRuntimes $n; if(!$NoCache-and(Test-Path $d)){wC "Hit: $n";return $d};wI "Download: $n";try{Invoke-WebRequest -Uri $u -OutFile $d -UseBasicParsing}catch{wE "Download failed: $_";exit 1};wC "Cached: $n";return $d }
function _cacheGit($n,$u,$b) { $d=Join-Path $CacheGit $n; if(!$NoCache-and(Test-Path "$d\.git")){wC "Hit: $n (git)";return $d};wI "Clone: $u";rm $d -Recurse -Force -EA SilentlyContinue;$save=$ErrorActionPreference;$ErrorActionPreference="Continue";$r=&git clone --depth 1 --branch $b $u $d 2>&1;$ok=($LASTEXITCODE -eq 0);$ErrorActionPreference=$save;if(!$ok){wW "Branch '$b' not found, trying default...";$ErrorActionPreference="Continue";$r=&git clone --depth 1 $u $d 2>&1;$ErrorActionPreference=$save};if($r){$r|%{Write-Host "         $_" -F DarkGray}};wC "Cached: $n";return $d }
function _cacheNpm($w) { if($NoCache){return $false};if(Test-Path "$CacheNpm\node_modules\@sylphx\pdf-reader-mcp"){wC "npm node_modules";cp "$CacheNpm\node_modules" "$w\" -Recurse -Force;return $true};return $false }
function _saveNpm($s) { if(!$NoCache){rm "$CacheNpm\node_modules" -Recurse -Force -EA SilentlyContinue;cp "$s\node_modules" "$CacheNpm\" -Recurse -Force;wC "Saved: npm"} }
function _restorePip($d) { if(!$NoCache-and(Test-Path "$CachePip\*.whl")){wC "pip wheels";cp "$CachePip\*.whl" $d -Force -EA SilentlyContinue;return $true};return $false }
function _savePip($s) { if(!$NoCache){cp "$s\*.whl" $CachePip -Force -EA SilentlyContinue} }

# ---- Banner ----
Write-Host ""
Write-Host "==============================================" -F Magenta
Write-Host "|     MCP Offline Pack Tool (Windows)          |" -F Magenta
Write-Host "|----------------------------------------------|" -F Magenta
$l="|  PDF: "+$(if($SkipPdf){'SKIP'}else{'PACK'}).PadLeft(28)+" Office: "+$(if($SkipOffice){'SKIP'}else{'PACK'}).PadLeft(6)+" |"
Write-Host $l -F Magenta
$l="|  Node.js: "+$(if($SkipNodejs){'SKIP'}else{'PACK'}).PadLeft(24)+" Python: "+$(if($SkipPython){'SKIP'}else{'PACK'}).PadLeft(6)+" |"
Write-Host $l -F Magenta
$l=("|  Node v$NodeVersion  Python $PythonVersion").PadRight(47)+"|"
Write-Host $l -F Magenta
Write-Host "==============================================" -F Magenta
Write-Host ""

# Pre-calculate total steps for consistent numbering
$totalSteps = 2  # env, dirs (always)
if (!$SkipPdf)    { $totalSteps += 2 }  # npm + toolkit
if (!$SkipOffice) { $totalSteps += 1 }  # mcp-office
$totalSteps += 2  # launchers + config (always)
if (!$SkipNodejs) { $totalSteps++ }
if (!$SkipPython -and !$SkipOffice) { $totalSteps++ }
$step = 0

# ---- 1. Env checks ----
$step++; wS "$step/$totalSteps Checking environment..."
$nv=&node --version 2>&1; wOK "Node.js: $nv"
if(([int]($nv -replace 'v' -replace '\..*')) -lt 22){wW "Node.js below 22.13.0; runtime will be bundled"}
wOK "npm: v$(&npm --version 2>&1)"
$gv=&git --version 2>&1; wOK "git: $($gv -replace 'git version ','')"

$PythonExe=$null
if(!$SkipOffice){
  $PythonExe=(Get-Command python -EA SilentlyContinue).Source
  if(!$PythonExe){$PythonExe=(Get-Command python3 -EA SilentlyContinue).Source}
  if(!$PythonExe){wE "Python >=3.11 not found. Use -SkipOffice to skip.";exit 1}
  wOK "Python: $(&$PythonExe --version 2>&1)"
  wOK "pip: v$(&$PythonExe -m pip --version 2>&1)"
}

# ---- 2. Prepare dirs ----
$step++; wS "$step/$totalSteps Preparing build directories..."
_initCache
if(Test-Path $OutputDir){rm $OutputDir -Recurse -Force -EA SilentlyContinue}
foreach($d in @("$BundleDir\bin","$BundleDir\config","$BundleDir\docs",
    "$BundleDeps\npm","$BundleDeps\pip","$BundleDeps\runtimes","$BundleTools")){mkdir $d -Force|Out-Null}
$WorkDir=Join-Path $OutputDir "_workspace"; mkdir $WorkDir -Force|Out-Null

# ---- 3. npm: pdf-reader-mcp ----
if(!$SkipPdf){
$step++; wS "$step/$totalSteps Installing PDF MCP tools (npm)..."
Push-Location $WorkDir
$cached=_cacheNpm $WorkDir
if(!$cached){
  @{name="mcp-offline-bundle";private=$true;type="module"}|ConvertTo-Json|Set-Content package.json
  wI "npm install @sylphx/pdf-reader-mcp@$PdfReaderV ..."
  $null=&npm install "@sylphx/pdf-reader-mcp@$PdfReaderV" --legacy-peer-deps 2>&1
  _saveNpm $WorkDir
}
cp "$WorkDir\node_modules" "$BundleDeps\npm\" -Recurse -Force
$v=(Get-Content "$WorkDir\node_modules\@sylphx\pdf-reader-mcp\package.json" -Raw|ConvertFrom-Json).version
$c=(ls "$BundleDeps\npm\node_modules" -Directory).Count
wOK "@sylphx/pdf-reader-mcp v$v ($c deps)"
Pop-Location

# ---- 4. Git: pdf-toolkit-mcp ----
$step++; wS "$step/$totalSteps Building pdf-toolkit-mcp..."
$repo=_cacheGit "pdf-toolkit-mcp" "https://github.com/beepboop2025/pdf-toolkit-mcp.git" $PdfToolkitRef
$tdir=Join-Path $WorkDir "pdf-toolkit-mcp"; rm $tdir -Recurse -Force -EA SilentlyContinue
cp $repo $tdir -Recurse -Force
Push-Location $tdir
wI "npm install..."; $null=&npm install --legacy-peer-deps 2>&1
wI "npm build..."; $null=&npm run build 2>&1
$dest=Join-Path $BundleTools "pdf-toolkit-mcp"; mkdir $dest -Force|Out-Null
cp dist $dest -Recurse -Force; cp package.json $dest -Force
# Copy node_modules so the tool can find its deps at runtime
cp node_modules $dest -Recurse -Force
# Verify critical scoped package was copied
if (!(Test-Path "$dest\node_modules\@modelcontextprotocol\sdk")) {
  wW "@modelcontextprotocol/sdk not in tools cache — forcing copy from shared"
  cp "$BundleDeps\npm\node_modules\@modelcontextprotocol" "$dest\node_modules\@" -Recurse -Force -EA SilentlyContinue
}
$sm="$BundleDeps\npm\node_modules"
ls "$tdir\node_modules" -Directory|%{$d=Join-Path $sm $_.Name; if(!(Test-Path $d)){cp $_.FullName $d -Recurse -Force}}
ls "$tdir\node_modules" -Directory -Filter "@*" -EA SilentlyContinue|%{
  $sn=$_.Name; $_|ls -Directory|%{$sd=Join-Path $sm $sn; $d=Join-Path $sd $_.Name
  if(!(Test-Path $d)){mkdir $sd -Force|Out-Null;cp $_.FullName $d -Recurse -Force}}
}
$toolkitVer=(Get-Content package.json -Raw|ConvertFrom-Json).version; wOK "pdf-toolkit-mcp v$toolkitVer built"
Pop-Location; Pop-Location
}

# ---- 5. Git: mcp-office ----
if(!$SkipOffice){
$step++; wS "$step/$totalSteps Packaging mcp-office (Python)..."
$repo=_cacheGit "mcp-office" "https://github.com/dosev-ai/mcp-office.git" "main"
$odir=Join-Path $WorkDir "mcp-office"; rm $odir -Recurse -Force -EA SilentlyContinue
cp $repo $odir -Recurse -Force
$osrc=Join-Path $BundleTools "mcp-office"; mkdir $osrc -Force|Out-Null
@("wordmcp","pptmcp","excelmcp","shared")|%{if(Test-Path "$odir\$_"){cp "$odir\$_" "$osrc\$_" -Recurse -Force}}
$wheels=Join-Path $BundleDeps "pip"; mkdir $wheels -Force|Out-Null
_restorePip $wheels
Push-Location $odir
$pyForPip = $PythonExe

# If pack machine Python != 3.11, use bundled Python 3.11 for wheel download
# This ensures binary compatibility (cp311 wheels for target machine)
$py311 = "$BundleDeps\runtimes\python-3.11.9-amd64.exe"
if ((Test-Path $py311) -and ($pyForPip -notmatch "3\.11")) {
    wI "  Using Python 3.11 for binary-compatible wheel download..."
    $tmpPy = Join-Path $OutputDir "_py311"
    $null = Start-Process -FilePath $py311 -ArgumentList @("/quiet","InstallAllUsers=0","PrependPath=0","Include_test=0","TargetDir=$tmpPy") -Wait -NoNewWindow
    if (Test-Path "$tmpPy\python.exe") { $pyForPip = "$tmpPy\python.exe"; wOK "Python 3.11 ready" }
    else { wW "Could not set up Python 3.11, using system Python (wheels may be incompatible)" }
    # Clear cp314-only wheels that won't work with 3.11
    if (!$NoCache) { rm "$CachePip\*cp3*" -Force -EA SilentlyContinue; rm "$wheels\*cp3*" -Force -EA SilentlyContinue; _restorePip $wheels }
}

# Try local-only resolution first (fast, no network if cache was complete)
wI "  Checking local wheels..."
$allLocal = $true
foreach ($p in @("wordmcp","pptmcp","excelmcp")) {
    $result = & $pyForPip -m pip download --no-index --find-links "$wheels" -d "$wheels" "$odir\$p" 2>&1
    if ($LASTEXITCODE -ne 0) { $allLocal = $false; break }
}

if ($allLocal) {
    wOK "All wheels resolved from cache (no network needed)"
} else {
    # Download missing deps individually (much faster than full venv)
    wI "  Some wheels missing, downloading from network..."
    $topPkgs = @("fastmcp","python-docx","python-pptx","openpyxl","Pillow","setuptools","wheel")
    foreach ($n in $topPkgs) {
        if (ls "$wheels\${n}*.whl" -EA SilentlyContinue) { continue }
        wI "    Downloading: $n"
        & $pyForPip -m pip download -d "$wheels" "$n" 2>&1 | ForEach-Object {
            if ($_ -match "Downloading|Saved|Collecting") { Write-Host "         $_" -ForegroundColor DarkGray }
        }
    }
    # Download transitive deps from each sub-package
    foreach ($p in @("wordmcp","pptmcp","excelmcp")) {
        wI "    Resolving: $p deps"
        # Try local first, then network
        & $pyForPip -m pip download --no-index --find-links "$wheels" -d "$wheels" "$odir\$p" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            & $pyForPip -m pip download -d "$wheels" "$odir\$p" 2>&1 | ForEach-Object {
                if ($_ -match "Downloading|Saved|Collecting") { Write-Host "         $_" -ForegroundColor DarkGray }
            }
        }
    }
}
_savePip $wheels
Pop-Location
if ($pyForPip -ne $PythonExe -and $tmpPy) { rm $tmpPy -Recurse -Force -EA SilentlyContinue }
$wc=(ls "$wheels\*.whl" -EA SilentlyContinue).Count
$ws=[math]::Round(((ls "$wheels\*.whl" -EA SilentlyContinue|Measure-Object Length -Sum).Sum)/1MB,1)
wOK "Python deps: $wc wheels ($ws MB)"
}

# ---- 6. Launchers ----
$step++; wS "$step/$totalSteps Creating launchers..."
$bin=Join-Path $BundleDir "bin"
if(!$SkipPdf){
@'
@echo off
setlocal
set "BD=%~dp0.."
set "NJS=%BD%\deps\runtimes\nodejs\node.exe"
set "TOOL=%BD%\deps\npm\node_modules\@sylphx\pdf-reader-mcp\dist\index.js"
if exist "%NJS%" ("%NJS%" "%TOOL%" %*) else (node "%TOOL%" %*)
endlocal
'@ | Set-Content "$bin\pdf-reader.cmd" -Encoding ASCII

@'
@echo off
setlocal
set "BD=%~dp0.."
set "NJS=%BD%\deps\runtimes\nodejs\node.exe"
set "TOOL=%BD%\tools\pdf-toolkit-mcp\dist\index.js"
if exist "%NJS%" ("%NJS%" "%TOOL%" %*) else (node "%TOOL%" %*)
endlocal
'@ | Set-Content "$bin\pdf-toolkit.cmd" -Encoding ASCII
}

if(!$SkipOffice){
  foreach($t in @("wordmcp","pptmcp","excelmcp")){
@"
@echo off
setlocal
set "BD=%~dp0.."
set "PY=%BD%\python\python.exe"
set "PYTHONPATH=%BD%\tools\mcp-office\shared\src;%BD%\tools\mcp-office\wordmcp\src;%BD%\tools\mcp-office\pptmcp\src;%BD%\tools\mcp-office\excelmcp\src;%PYTHONPATH%"
if exist "%PY%" ( "%PY%" -m ${t}.server %* ) else ( python -m ${t}.server %* )
endlocal
"@ | Set-Content "$bin\${t}.cmd" -Encoding ASCII
  }
}
wOK "Launchers created"

# ---- 7. Config files ----
$step++; wS "$step/$totalSteps Generating MCP config files..."
$cfg=Join-Path $BundleDir "config"; $IB='%LOCALAPPDATA%\MCP-Tools'

if(!$SkipPdf){
  $c=@{mcpServers=@{
    "pdf-reader"=@{command="$IB\bin\pdf-reader.cmd";description="PDF read, search, extract, render"}
    "pdf-toolkit"=@{command="$IB\bin\pdf-toolkit.cmd";description="PDF create, edit, merge, split, forms, encrypt"}
  }}
  $c|ConvertTo-Json -Depth 4|Set-Content "$cfg\claude-code.json"
  $s=@{mcpServers=@{"pdf-reader"=@{command="$IB\bin\pdf-reader.cmd"};"pdf-toolkit"=@{command="$IB\bin\pdf-toolkit.cmd"}}}
  $s|ConvertTo-Json -Depth 3|Set-Content "$cfg\claude-desktop.json"
  @{"cline.mcpServers"=$s.mcpServers}|ConvertTo-Json -Depth 3|Set-Content "$cfg\cline.json"
  @{mcp_servers=$s.mcpServers}|ConvertTo-Json -Depth 3|Set-Content "$cfg\codex.json"
}

if(!$SkipOffice){
  $o=@{
    "word"=@{command="$IB\bin\wordmcp.cmd";env=@{WORD_ALLOWLIST_ROOTS="C:\Users\%USERNAME%\Documents";WORD_ENABLE_WRITE="true"};description="Word docs - 51 tools"}
    "ppt"=@{command="$IB\bin\pptmcp.cmd";env=@{PPT_ALLOWLIST_ROOTS="C:\Users\%USERNAME%\Documents";PPT_ENABLE_WRITE="true"};description="PowerPoint - 48 tools"}
    "excel"=@{command="$IB\bin\excelmcp.cmd";env=@{EXCEL_ALLOWLIST_ROOTS="C:\Users\%USERNAME%\Documents";EXCEL_ENABLE_WRITE="true"};description="Excel - 65 tools"}
  }
  @{mcpServers=$o}|ConvertTo-Json -Depth 5|Set-Content "$cfg\claude-code-office.json"
  if(!$SkipPdf){
    $fc=@{mcpServers=@{}}
    foreach($k in $c.mcpServers.Keys){$fc.mcpServers[$k]=$c.mcpServers[$k]}
    foreach($k in $o.Keys){$fc.mcpServers[$k]=$o[$k]}
    $fc|ConvertTo-Json -Depth 5|Set-Content "$cfg\claude-code-full.json"
  }
}
wOK "Config files generated"

# ---- 8. Runtimes ----
if(!$SkipNodejs){
  $step++; wS "$step/$totalSteps Downloading Node.js portable..."
  $nz=_cacheFile "node-v${NodeVersion}-win-x64.zip" "https://nodejs.org/dist/v${NodeVersion}/node-v${NodeVersion}-win-x64.zip"
  wI "Extracting..."; $ne=Join-Path $OutputDir "_ne"; rm $ne -Recurse -Force -EA SilentlyContinue
  Expand-Archive $nz -Dest $ne -Force
  $ns=(ls $ne -Directory|Select -First 1).FullName; $nd=Join-Path $BundleDeps "runtimes\nodejs"
  # Use robocopy for reliable directory copy (no warnings)
  & robocopy "$ns" "$nd" /E /NFL /NDL /NJH /NJS 2>&1 | Out-Null
  if ($LASTEXITCODE -ge 8) { cp "$ns\*" $nd -Recurse -Force -EA SilentlyContinue }
  rm $ne -Recurse -Force
  $sz=[math]::Round(((ls $nd -Recurse|Measure-Object Length -Sum).Sum)/1MB,1)
  wOK "Node.js v$NodeVersion bundled ($sz MB)"
}

if(!$SkipPython -and !$SkipOffice){
  $step++; wS "$step/$totalSteps Downloading Python installer..."
  # Download full Python installer (not embedded) for reliable offline install
  $pyInstaller = "python-${PythonVersion}-amd64.exe"
  $pyInstallerPath = _cacheFile $pyInstaller "https://www.python.org/ftp/python/${PythonVersion}/${pyInstaller}"
  cp $pyInstallerPath "$BundleDeps\runtimes\" -Force
  $sz=[math]::Round((Get-Item $pyInstallerPath).Length/1MB,1)
  wOK "Python v$PythonVersion installer bundled ($sz MB)"
}

# ---- 9. Copy install scripts & docs ----
wI "Copying install scripts & docs..."
cp "$ScriptDir\install.ps1" "$BundleDir\" -Force -EA SilentlyContinue
cp "$ScriptDir\install.cmd" "$BundleDir\" -Force -EA SilentlyContinue
cp "$ScriptDir\install.sh" "$BundleDir\" -Force -EA SilentlyContinue
if(Test-Path "$ProjectDir\README.md"){cp "$ProjectDir\README.md" "$BundleDir\docs\" -Force}

# ---- 10. Bundle README ----
$rm=@"
# MCP Offline Installer Package

## Unified Dependency Structure
All dependencies are stored under a single `deps/` directory:

| Directory | Content |
|-----------|---------|
| `deps/npm/node_modules/` | All Node.js dependencies |
| `deps/pip/*.whl` | All Python wheel packages |
| `deps/runtimes/nodejs/` | Node.js portable runtime |
| `deps/runtimes/python/` | Python embedded runtime |
| `tools/` | Tool source code (pdf-toolkit-mcp, mcp-office) |

## Included Tools
| Tool | Runtime | Description |
|------|---------|-------------|
| pdf-reader-mcp | Node.js | PDF read, search, table extraction |
| pdf-toolkit-mcp | Node.js | PDF create, edit, merge, split (37 tools) |
"@
if(!$SkipOffice){ $rm+=@"
| wordmcp | Python | Word docs - 51 tools |
| pptmcp | Python | PowerPoint - 48 tools |
| excelmcp | Python | Excel - 65 tools |
"@}
$rm+=@"

## Installation
Run PowerShell as Administrator:
```powershell
.\install.ps1
```
The installer auto-detects system runtimes and uses bundled ones if needed.
All deps are installed from the unified `deps/` directory (no network required).

Double-click `install.cmd` or run `install.ps1` as Administrator.
"@
Set-Content "$BundleDir\README.md" $rm -Encoding ASCII

# ---- 11. Zip ----
wI "Creating zip archive..."
$an="mcp-offline-${Platform}-${DateStamp}"
if($SkipNodejs){$an+="-no-nodejs"}; if($SkipPython){$an+="-no-python"}
if($SkipPdf){$an+="-no-pdf"}; if($SkipOffice){$an+="-no-office"}
$ap=Join-Path $OutputDir "${an}.zip"
Compress-Archive $BundleDir -Dest $ap -CompressionLevel Fastest -Force
$sz=[math]::Round((Get-Item $ap).Length/1MB,1)

# Cleanup temporary workspace (already copied to bundle)
wI "Cleaning up build temp files..."
rm $WorkDir -Recurse -Force -EA SilentlyContinue
rm "$OutputDir\get-pip.py" -Force -EA SilentlyContinue
rm "$OutputDir\_ne" -Recurse -Force -EA SilentlyContinue

# ---- 12. Done ----
Write-Host ""
Write-Host "==============================================" -F Green
Write-Host "|          PACK COMPLETE!                      |" -F Green
Write-Host "|----------------------------------------------|" -F Green
Write-Host ("|  Output:  $ap").PadRight(47)+"|" -F Green
Write-Host ("|  Size:    ${sz} MB").PadRight(47)+"|" -F Green
Write-Host "|----------------------------------------------|" -F Green
Write-Host "|  Bundle structure (unified deps):            |" -F Green
Write-Host "|    deps/npm/      - Node.js dependencies     |" -F Green
Write-Host "|    deps/pip/      - Python wheels            |" -F Green
Write-Host "|    deps/runtimes/ - Node.js + Python         |" -F Green
Write-Host "|    tools/         - Tool source code         |" -F Green
Write-Host "==============================================" -F Green
Write-Host ""
Write-Host "Press any key to close..." -ForegroundColor White
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

return $ap
