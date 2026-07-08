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

# ---- 1. Env checks ----
wS "1/8 Checking environment..."
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
wS "2/8 Preparing build directories..."
_initCache
if(Test-Path $OutputDir){rm $OutputDir -Recurse -Force -EA SilentlyContinue}
foreach($d in @("$BundleDir\bin","$BundleDir\config","$BundleDir\docs",
    "$BundleDeps\npm","$BundleDeps\pip","$BundleDeps\runtimes","$BundleTools")){mkdir $d -Force|Out-Null}
$WorkDir=Join-Path $OutputDir "_workspace"; mkdir $WorkDir -Force|Out-Null

# ---- 3. npm: pdf-reader-mcp ----
if(!$SkipPdf){
wS "3/8 Installing PDF MCP tools (npm)..."
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
wS "4/8 Building pdf-toolkit-mcp..."
$repo=_cacheGit "pdf-toolkit-mcp" "https://github.com/beepboop2025/pdf-toolkit-mcp.git" $PdfToolkitRef
$tdir=Join-Path $WorkDir "pdf-toolkit-mcp"; rm $tdir -Recurse -Force -EA SilentlyContinue
cp $repo $tdir -Recurse -Force
Push-Location $tdir
wI "npm install..."; $null=&npm install --legacy-peer-deps 2>&1
wI "npm build..."; $null=&npm run build 2>&1
$dest=Join-Path $BundleTools "pdf-toolkit-mcp"; mkdir $dest -Force|Out-Null
cp dist $dest -Recurse -Force; cp package.json $dest -Force
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
wS "5/8 Packaging mcp-office (Python)..."
$repo=_cacheGit "mcp-office" "https://github.com/dosev-ai/mcp-office.git" "main"
$odir=Join-Path $WorkDir "mcp-office"; rm $odir -Recurse -Force -EA SilentlyContinue
cp $repo $odir -Recurse -Force
$osrc=Join-Path $BundleTools "mcp-office"; mkdir $osrc -Force|Out-Null
@("wordmcp","pptmcp","excelmcp","shared")|%{if(Test-Path "$odir\$_"){cp "$odir\$_" "$osrc\$_" -Recurse -Force}}
$wheels=Join-Path $BundleDeps "pip"; mkdir $wheels -Force|Out-Null
_restorePip $wheels
Push-Location $odir
&$PythonExe -m pip install -e "./shared" --quiet 2>&1|Out-Null
$pkgs=@("fastmcp==$PipFastmcp","python-docx==$PipDocx","python-pptx==$PipPptx","openpyxl==$PipXl","Pillow==$PipPil")
foreach($s in $pkgs){
  $n=($s -split '==')[0] -replace '-','_'
  if(!$NoCache -and (ls "$wheels\${n}*.whl" -EA SilentlyContinue)){wC "Hit: $s";continue}
  wI "  Download: $s"; &$PythonExe -m pip download -d $wheels $s 2>&1|%{Write-Host "         $_" -F DarkGray}
}
foreach($p in @("wordmcp","pptmcp","excelmcp")){
  wI "  Transitive deps: $p"
  &$PythonExe -m pip download -d $wheels "$odir\$p" 2>&1|%{Write-Host "         $_" -F DarkGray}
}
_savePip $wheels
Pop-Location
$wc=(ls "$wheels\*.whl" -EA SilentlyContinue).Count
$ws=[math]::Round(((ls "$wheels\*.whl" -EA SilentlyContinue|Measure-Object Length -Sum).Sum)/1MB,1)
wOK "Python deps: $wc wheels ($ws MB)"
}

# ---- 6. Launchers ----
wS "6/8 Creating launchers..."
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
set "PY=%BD%\deps\runtimes\python\python.exe"
if exist "%PY%" (set "PATH=%BD%\deps\runtimes\python;%BD%\deps\runtimes\python\Scripts;%PATH%" & "%PY%" -m ${t}.server %*) else (python -m ${t}.server %*)
endlocal
"@ | Set-Content "$bin\${t}.cmd" -Encoding ASCII
  }
}
wOK "Launchers created"

# ---- 7. Config files ----
wS "7/8 Generating MCP config files..."
$cfg=Join-Path $BundleDir "config"; $IB='C:\MCP-Tools'

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
$total = 7; if(!$SkipNodejs){$total++}; if(!$SkipPython -and !$SkipOffice){$total++}
$step = 8
if(!$SkipNodejs){
  wS "$step/$total Downloading Node.js portable..."
  $nz=_cacheFile "node-v${NodeVersion}-win-x64.zip" "https://nodejs.org/dist/v${NodeVersion}/node-v${NodeVersion}-win-x64.zip"
  wI "Extracting..."; $ne=Join-Path $OutputDir "_ne"; rm $ne -Recurse -Force -EA SilentlyContinue
  Expand-Archive $nz -Dest $ne -Force
  $ns=(ls $ne -Directory|Select -First 1).FullName; $nd=Join-Path $BundleDeps "runtimes\nodejs"
  # Use robocopy for reliable directory copy (no warnings)
  & robocopy "$ns" "$nd" /E /NFL /NDL /NJH /NJS 2>&1 | Out-Null
  if ($LASTEXITCODE -ge 8) { cp "$ns\*" $nd -Recurse -Force -EA SilentlyContinue }
  rm $ne -Recurse -Force
  $sz=[math]::Round(((ls $nd -Recurse|Measure-Object Length -Sum).Sum)/1MB,1)
  wOK "Node.js v$NodeVersion bundled ($sz MB)"; $step++
}

if(!$SkipPython -and !$SkipOffice){
  wS "$step/$total Downloading Python embedded..."
  $pz=_cacheFile "python-${PythonVersion}-embed-amd64.zip" "https://www.python.org/ftp/python/${PythonVersion}/python-${PythonVersion}-embed-amd64.zip"
  wI "Extracting..."; $pd=Join-Path $BundleDeps "runtimes\python"; mkdir $pd -Force|Out-Null
  Expand-Archive $pz -Dest $pd -Force
  $pf=Join-Path $pd "python._pth"
  if(Test-Path $pf){$c=Get-Content $pf -Raw;$c=$c -replace '#import site','import site';if($c -notmatch 'Lib/site-packages'){$c+="`r`nLib/site-packages`r`n"};Set-Content $pf $c -Encoding ASCII}
  wI "Installing pip into embedded Python..."
  $gp=Join-Path $OutputDir "get-pip.py"
  $pipOk=$false
  for ($retry=1; $retry -le 3; $retry++) {
    try {
      if ($retry -gt 1) { wI "Retry $retry/3..." }
      Invoke-WebRequest "https://bootstrap.pypa.io/get-pip.py" -OutFile $gp -UseBasicParsing -TimeoutSec 30
      & "$pd\python.exe" $gp --no-warn-script-location 2>&1 | Out-Null
      $pipOk=$true; break
    } catch { if ($retry -ge 3) { wW "pip download failed after 3 retries: $_" } }
  }
  if ($pipOk) { wOK "pip installed" } else { wI "Will install deps on target machine" }
  if(Test-Path "$BundleDeps\pip\*.whl"){
    wI "Pre-installing Office deps..."; $wh=Join-Path $BundleDeps "pip"; $os=Join-Path $BundleTools "mcp-office"
    &"$pd\python.exe" -m pip install --no-index --find-links $wh fastmcp python-docx python-pptx openpyxl Pillow 2>&1|%{Write-Host "         $_" -F DarkGray}
    foreach($p in @("shared","wordmcp","pptmcp","excelmcp")){ $pp=Join-Path $os $p; if(Test-Path $pp){&"$pd\python.exe" -m pip install --no-index --find-links $wh -e $pp 2>&1|Out-Null} }
    wOK "Office deps pre-installed"
  }
  $sz=[math]::Round(((ls $pd -Recurse|Measure-Object Length -Sum).Sum)/1MB,1)
  wOK "Python v$PythonVersion bundled ($sz MB)"; $step++
}

# ---- 9. Copy install scripts & docs ----
wI "Copying install scripts & docs..."
cp "$ScriptDir\install.ps1" "$BundleDir\" -Force -EA SilentlyContinue
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
"@
Set-Content "$BundleDir\README.md" $rm -Encoding ASCII

# ---- 11. Zip ----
wI "Creating zip archive..."
$an="mcp-offline-${Platform}-${DateStamp}"
if($SkipNodejs){$an+="-no-nodejs"}; if($SkipPython){$an+="-no-python"}
if($SkipPdf){$an+="-no-pdf"}; if($SkipOffice){$an+="-no-office"}
$ap=Join-Path $OutputDir "${an}.zip"
Compress-Archive $BundleDir -Dest $ap -Force
$sz=[math]::Round((Get-Item $ap).Length/1MB,1)

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

return $ap
