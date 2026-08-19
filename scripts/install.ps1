<#
.SYNOPSIS
    MCP Offline Installer (Windows PowerShell)
.DESCRIPTION
    Installs MCP tools from the unified deps/ structure on an offline Windows machine.
    No admin privileges required — installs to user-writable paths by default.
.PARAMETER TargetPath
    Install path (default: %LOCALAPPDATA%\MCP-Tools, no admin required)
.PARAMETER AddToPath
    Add tools to system PATH (default: $true)
.PARAMETER ConfigureClaudeCode
    Auto-configure Claude Code MCP settings (default: $true)
.PARAMETER ConfigureCline
    Auto-configure Cline (VSCode) MCP settings (default: $true)
.PARAMETER ConfigureCodex
    Auto-configure Codex CLI MCP settings in ~/.codex/config.toml (default: $true)
.EXAMPLE
    .\install.ps1
    .\install.ps1 -TargetPath "D:\Tools\MCP"
    .\install.ps1 -ConfigureCodex $false
#>

param(
    [string]$TargetPath = "$env:LOCALAPPDATA\MCP-Tools",
    [bool]$AddToPath = $true,
    [bool]$ConfigureClaudeCode = $true,
    [bool]$ConfigureCline = $true,
    [bool]$ConfigureCodex = $true
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MCP Offline Installer"

function Write-Info  { Write-Host "[INFO]  " -ForegroundColor Blue   -NoNewline; Write-Host $args[0] }
function Write-OK    { Write-Host "[OK]    " -ForegroundColor Green  -NoNewline; Write-Host $args[0] }
function Write-Warn  { Write-Host "[WARN]  " -ForegroundColor Yellow -NoNewline; Write-Host $args[0] }
function Write-Error_ { Write-Host "[ERROR] " -ForegroundColor Red    -NoNewline; Write-Host $args[0] }
function Write-Step  { Write-Host ""; Write-Host ">>> $($args[0])" -ForegroundColor Cyan }

Write-Host ""
Write-Host "==============================================" -ForegroundColor Magenta
Write-Host "|     MCP Tools - Offline Installer (Windows)  |" -ForegroundColor Magenta
Write-Host "==============================================" -ForegroundColor Magenta
Write-Host ""

# ---- 1. Locate bundle ----
Write-Step "1/6 Checking bundle..."

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BundleDir = $ScriptDir

# Unified dependency directories
$DepsDir   = "$BundleDir\deps"
$ToolsDir  = "$BundleDir\tools"
$DepsNpm   = "$DepsDir\npm\node_modules"
$DepsPip   = "$DepsDir\pip"
$DepsRuntimes = "$DepsDir\runtimes"

$HasPdfTools    = (Test-Path "$DepsNpm\@sylphx\pdf-reader-mcp") -and (Test-Path "$ToolsDir\pdf-toolkit-mcp\dist")
$HasOfficeTools = (Test-Path "$ToolsDir\mcp-office") -and (Test-Path "$DepsPip\*.whl")

if (-not ($HasPdfTools -or $HasOfficeTools)) {
    Write-Error_ "Bundle incomplete: no tools found under deps/ or tools/"
    Write-Info "Make sure you run this script from the extracted mcp-offline-bundle directory."
    exit 1
}
Write-OK "Bundle OK (PDF: $HasPdfTools, Office: $HasOfficeTools)"

# ---- 2. Check Node.js (smart detection) ----
Write-Step "2/6 Checking Node.js environment..."

$NodeExe = $null
$NodeSource = ""
$BundledNodeDir = "$DepsRuntimes\nodejs"
$BundledNodeExe = "$BundledNodeDir\node.exe"
$NodeReq = "22.13.0"
$NodeMajorReq = 22

$SysNode = (Get-Command node -ErrorAction SilentlyContinue).Source
$SysNodeOK = $false
if ($SysNode) {
    $v = & $SysNode --version 2>&1
    $m = [int]($v -replace 'v' -replace '\..*')
    if ($m -ge $NodeMajorReq) { $SysNodeOK = $true }
}

if ($SysNodeOK) {
    $NodeExe = $SysNode; $NodeSource = "system"
    Write-OK "System Node.js $v meets requirement (>= $NodeReq)"
}
elseif (Test-Path $BundledNodeExe) {
    Copy-Item -Recurse $BundledNodeDir "$TargetPath\deps\runtimes\nodejs" -Force
    $NodeExe = "$TargetPath\deps\runtimes\nodejs\node.exe"
    $NodeSource = "bundled"
    $info = if ($SysNode) { "system too old" } else { "no system Node.js" }
    Write-OK "Using bundled Node.js ($info)"
}
elseif ($SysNode) {
    $NodeExe = $SysNode; $NodeSource = "system(outdated)"
    Write-Warn "System Node.js below $NodeReq; pdf-reader-mcp may not work"
}
else {
    Write-Error_ "Node.js >= $NodeReq not found and no bundled runtime"
    exit 1
}

# ---- 3. Check Python (only for Office tools) ----
$PythonExe = $null
$PythonSource = ""
$PythonReq = "3.11"
$BundledPyInstaller = "$DepsRuntimes\python-3.11.9-amd64.exe"
$PyInstallDir = "$TargetPath\python"

if ($HasOfficeTools) {
    $SysPy = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $SysPy) { $SysPy = (Get-Command python3 -ErrorAction SilentlyContinue).Source }
    $SysPyOK = $false
    if ($SysPy) {
        $raw = & $SysPy --version 2>&1
        if ($raw -match '(\d+)\.(\d+)') {
            if ([int]$Matches[1] -gt 3 -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -ge 11)) { $SysPyOK = $true }
        }
    }

    if ($SysPyOK) {
        $PythonExe = $SysPy; $PythonSource = "system"
        Write-OK "System Python meets requirement (>= $PythonReq)"
    }
    elseif (Test-Path $BundledPyInstaller) {
        Write-Host ""
        Write-Host "  ========================================" -ForegroundColor Yellow
        Write-Host "  Python >= $PythonReq not found." -ForegroundColor Yellow
        Write-Host "  The Python installer will now open." -ForegroundColor Yellow
        Write-Host "  Please complete the installation wizard." -ForegroundColor Yellow
        Write-Host "  (Default options are fine — just click Install)" -ForegroundColor Yellow
        Write-Host "  ========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to start the Python installer..." -ForegroundColor White
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        Start-Process -FilePath $BundledPyInstaller -Wait
        Write-Host ""

        # Re-check for Python after user install
        $SysPy = (Get-Command python -ErrorAction SilentlyContinue).Source
        if (-not $SysPy) { $SysPy = (Get-Command python3 -ErrorAction SilentlyContinue).Source }
        $SysPyOK = $false
        if ($SysPy) {
            $raw = & $SysPy --version 2>&1
            if ($raw -match '(\d+)\.(\d+)') {
                if ([int]$Matches[1] -gt 3 -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -ge 11)) { $SysPyOK = $true }
            }
        }

        if ($SysPyOK) {
            $PythonExe = $SysPy; $PythonSource = "system"
            Write-OK "Python installation detected: $(&$PythonExe --version 2>&1)"
        } else {
            Write-Warn "Python >= $PythonReq still not detected. Office tools will be skipped."
            Write-Info "You can re-run install.ps1 after installing Python manually."
            $HasOfficeTools = $false
        }
    }
    elseif ($SysPy) {
        $PythonExe = $SysPy; $PythonSource = "system(outdated)"
        Write-Warn "System Python below $PythonReq; Office tools may not work"
    }
    else {
        Write-Warn "Python >= $PythonReq not found and no bundled installer"
        Write-Warn "Office tools (Word/PPT/Excel) will be skipped"
        $HasOfficeTools = $false
    }
}

# ---- 4. Install files ----
Write-Step "3/6 Installing to $TargetPath ..."

if (-not (Test-Path $TargetPath)) { New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null }

# Copy unified deps (deps/npm/node_modules, deps/pip, deps/runtimes)
if (Test-Path $DepsDir) {
    Copy-Item -Recurse -Force $DepsDir "$TargetPath\deps"
    Write-OK "Deps installed to $TargetPath\deps"
}

# Copy tools (pdf-toolkit-mcp, mcp-office)
if (Test-Path $ToolsDir) {
    Copy-Item -Recurse -Force $ToolsDir "$TargetPath\tools"
    Write-OK "Tools installed to $TargetPath\tools"
}

# Copy bin, config
foreach ($item in @("bin", "config", "docs")) {
    $src = "$BundleDir\$item"
    if (Test-Path $src) {
        if (Test-Path "$TargetPath\$item") { Remove-Item -Recurse -Force "$TargetPath\$item" }
        Copy-Item -Recurse -Force $src "$TargetPath\$item"
    }
}

# Ensure pdf-toolkit has its node_modules (ESM can't use NODE_PATH)
$toolkitNM = "$TargetPath\tools\pdf-toolkit-mcp\node_modules"
$sharedNM = "$TargetPath\deps\npm\node_modules"
if ((Test-Path $sharedNM) -and -not (Test-Path "$toolkitNM\@modelcontextprotocol")) {
    Write-Info "Linking pdf-toolkit node_modules..."
    New-Item -ItemType Directory -Path $toolkitNM -Force | Out-Null
    Copy-Item -Recurse "$sharedNM\*" $toolkitNM -Force
    Write-OK "pdf-toolkit node_modules linked from deps/npm"
}

Write-OK "All files installed"

# ---- 5. Install Python deps (from deps/pip/) ----
if ($HasOfficeTools -and $PythonExe) {
    Write-Step "4/6 Installing Office MCP tools from deps/pip/..."

    $WheelsDir = "$TargetPath\deps\pip"
    $OfficeSrc = "$TargetPath\tools\mcp-office"

    Write-Info "Installing Office runtime deps from local wheels..."
    # Only install runtime deps (fastmcp, etc.) — no pip install -e needed
    # because the launcher sets PYTHONPATH to the tools source directory
    $pipOut = & $PythonExe -m pip install --no-index --find-links "$WheelsDir" fastmcp python-docx python-pptx openpyxl Pillow 2>&1
    if ($pipOut) { $pipOut | ForEach-Object { Write-Host "         $_" -ForegroundColor DarkGray } }
    Write-OK "Office runtime deps installed (PYTHONPATH mode)"
}
else { Write-Step "4/6 Skipping Office tools (not available)" }

# ---- 6. Configure AI tools + PATH ----
Write-Step "5/6 Configuring AI tool MCP settings..."

if ($ConfigureClaudeCode) {
    $file = "$env:USERPROFILE\.claude.json"

    # Try to read and validate existing config
    $cfg = $null
    $canWrite = $false
    if (Test-Path $file) {
        try {
            $cfg = Get-Content $file -Raw | ConvertFrom-Json
            # Validate: must be an object (not array, not primitive)
            if ($cfg -is [System.Management.Automation.PSCustomObject] -or $cfg -is [hashtable]) {
                $canWrite = $true
            } else {
                Write-Warn "$file exists but is not a valid JSON object (array or primitive)"
            }
        } catch {
            Write-Warn "Cannot parse $file — not valid JSON"
        }
    } else {
        # No config yet — safe to create
        $canWrite = $true
        $cfg = @{ mcpServers = @{} }
    }

    if (-not $canWrite) {
        Write-Warn "Skipping automatic Claude Code config"
        Write-Host ""
        Write-Host "  ========================================" -ForegroundColor Yellow
        Write-Host "  To manually configure, add this to $file" -ForegroundColor Yellow
        Write-Host "  under the `"mcpServers`" section:" -ForegroundColor Yellow
        Write-Host "  ========================================" -ForegroundColor Yellow
        $cfgDir = Join-Path $TargetPath "config"
        if (Test-Path "$cfgDir\claude-code-full.json") {
            Write-Host "  See: $cfgDir\claude-code-full.json" -ForegroundColor White
        } else {
            foreach ($t in @("pdf-reader","pdf-toolkit","word","ppt","excel")) {
                $cmd = Join-Path $TargetPath "bin\$t.cmd"
                if (Test-Path $cmd) { Write-Host "  $t : $cmd" -ForegroundColor White }
            }
        }
        Write-Host "  ========================================" -ForegroundColor Yellow
        Write-Host ""
    } else {
        # Ensure mcpServers key exists
        if (-not ($cfg | Get-Member -Name 'mcpServers' -MemberType NoteProperty -EA SilentlyContinue)) {
            $cfg | Add-Member -Name 'mcpServers' -Value @{} -MemberType NoteProperty
        }

        # Only add new tools — never remove existing ones
        $newCount = 0
        if ($HasPdfTools) {
            if (-not $cfg.mcpServers."pdf-reader") {
                $cfg.mcpServers | Add-Member -Name "pdf-reader" -Value @{ command = "$TargetPath\bin\pdf-reader.cmd"; description = "PDF read, search, extract, render" } -MemberType NoteProperty
                $newCount++
            }
            if (-not $cfg.mcpServers."pdf-toolkit") {
                $cfg.mcpServers | Add-Member -Name "pdf-toolkit" -Value @{ command = "$TargetPath\bin\pdf-toolkit.cmd"; description = "PDF create, edit, merge, split, forms, encrypt" } -MemberType NoteProperty
                $newCount++
            }
        }
        if ($HasOfficeTools -and $PythonExe) {
            if (-not $cfg.mcpServers."word") {
                $cfg.mcpServers | Add-Member -Name "word" -Value @{ command = "$TargetPath\bin\wordmcp.cmd"; env = @{ WORD_ALLOWLIST_ROOTS = "C:\Users\$env:USERNAME\Documents"; WORD_ENABLE_WRITE = "true" }; description = "Word docs - 51 tools" } -MemberType NoteProperty
                $newCount++
            }
            if (-not $cfg.mcpServers."ppt") {
                $cfg.mcpServers | Add-Member -Name "ppt" -Value @{ command = "$TargetPath\bin\pptmcp.cmd"; env = @{ PPT_ALLOWLIST_ROOTS = "C:\Users\$env:USERNAME\Documents"; PPT_ENABLE_WRITE = "true" }; description = "PowerPoint - 48 tools" } -MemberType NoteProperty
                $newCount++
            }
            if (-not $cfg.mcpServers."excel") {
                $cfg.mcpServers | Add-Member -Name "excel" -Value @{ command = "$TargetPath\bin\excelmcp.cmd"; env = @{ EXCEL_ALLOWLIST_ROOTS = "C:\Users\$env:USERNAME\Documents"; EXCEL_ENABLE_WRITE = "true" }; description = "Excel - 65 tools" } -MemberType NoteProperty
                $newCount++
            }
        }

        $cfg | ConvertTo-Json -Depth 5 | Set-Content $file
        if ($newCount -gt 0) { Write-OK "Claude Code: +$newCount tool(s) -> $file" }
        else { Write-Info "Claude Code config already up to date" }
    }
}

if ($ConfigureCline -and (Test-Path "$env:APPDATA\Code\User")) {
    $sfile = "$env:APPDATA\Code\User\settings.json"
    $s = $null
    $canWrite = $false
    if (Test-Path $sfile) {
        try {
            $s = Get-Content $sfile -Raw | ConvertFrom-Json
            if ($s -is [System.Management.Automation.PSCustomObject] -or $s -is [hashtable]) { $canWrite = $true }
            else { Write-Warn "$sfile is not a JSON object, skipping Cline config" }
        } catch {
            Write-Warn "Cannot parse $sfile (not valid JSON), skipping Cline config"
        }
    } else { $canWrite = $true; $s = @{} }

    if (-not $canWrite) {
        Write-Info "Cline config must be updated manually. See config/ templates in install dir."
    } else {
        # Preserve existing cline.mcpServers, only add new ones
    $existing = @{}
    if ($s | Get-Member -Name "cline.mcpServers" -MemberType NoteProperty -EA SilentlyContinue) { $existing = $s."cline.mcpServers" }
    $newC = 0
    if ($HasPdfTools) {
        if (-not $existing."pdf-reader") { $existing."pdf-reader" = @{ command = "$TargetPath\bin\pdf-reader.cmd" }; $newC++ }
        if (-not $existing."pdf-toolkit") { $existing."pdf-toolkit" = @{ command = "$TargetPath\bin\pdf-toolkit.cmd" }; $newC++ }
    }
    if ($HasOfficeTools -and $PythonExe) {
        if (-not $existing."word") { $existing."word" = @{ command = "$TargetPath\bin\wordmcp.cmd"; env = @{ WORD_ALLOWLIST_ROOTS = "C:\Users\$env:USERNAME\Documents"; WORD_ENABLE_WRITE = "true" } }; $newC++ }
        if (-not $existing."ppt") { $existing."ppt" = @{ command = "$TargetPath\bin\pptmcp.cmd"; env = @{ PPT_ALLOWLIST_ROOTS = "C:\Users\$env:USERNAME\Documents"; PPT_ENABLE_WRITE = "true" } }; $newC++ }
        if (-not $existing."excel") { $existing."excel" = @{ command = "$TargetPath\bin\excelmcp.cmd"; env = @{ EXCEL_ALLOWLIST_ROOTS = "C:\Users\$env:USERNAME\Documents"; EXCEL_ENABLE_WRITE = "true" } }; $newC++ }
    }
    $s | Add-Member -Name "cline.mcpServers" -Value $existing -MemberType NoteProperty -Force
    $s | ConvertTo-Json -Depth 5 | Set-Content $sfile
    if ($newC -gt 0) { Write-OK "Cline: +$newC tool(s) -> $sfile" }
        else { Write-Info "Cline config already up to date" }
    }
}

# ---- Codex CLI (TOML config) ----
if ($ConfigureCodex) {
    $codexDir = "$env:USERPROFILE\.codex"
    $codexFile = "$codexDir\config.toml"

    # Build the list of servers to add
    $codexServers = @()
    if ($HasPdfTools) {
        $codexServers += @{ name = "pdf-reader"; cmd = "$TargetPath\bin\pdf-reader.cmd"; env = @{} }
        $codexServers += @{ name = "pdf-toolkit"; cmd = "$TargetPath\bin\pdf-toolkit.cmd"; env = @{} }
    }
    if ($HasOfficeTools -and $PythonExe) {
        $docs = "C:\Users\$env:USERNAME\Documents"
        $codexServers += @{ name = "word";  cmd = "$TargetPath\bin\wordmcp.cmd";  env = @{ WORD_ALLOWLIST_ROOTS = $docs;  WORD_ENABLE_WRITE = "true" } }
        $codexServers += @{ name = "ppt";   cmd = "$TargetPath\bin\pptmcp.cmd";   env = @{ PPT_ALLOWLIST_ROOTS = $docs;   PPT_ENABLE_WRITE = "true" } }
        $codexServers += @{ name = "excel"; cmd = "$TargetPath\bin\excelmcp.cmd"; env = @{ EXCEL_ALLOWLIST_ROOTS = $docs; EXCEL_ENABLE_WRITE = "true" } }
    }

    if ($codexServers.Count -eq 0) {
        Write-Info "No tools available for Codex config"
    } else {
        if (-not (Test-Path $codexDir)) { New-Item -ItemType Directory -Path $codexDir -Force | Out-Null }

        $existingToml = ""
        if (Test-Path $codexFile) { $existingToml = Get-Content $codexFile -Raw }

        # Build TOML blocks only for servers not already present
        $newBlocks = @()
        $newCodexCount = 0
        foreach ($srv in $codexServers) {
            $header = "[mcp_servers.$($srv.name)]"
            if ($existingToml -match [regex]::Escape($header)) { continue }
            # TOML: escape backslashes in Windows paths
            $escCmd = $srv.cmd -replace '\\', '\\'
            $block = "$header`ncommand = `"$escCmd`""
            if ($srv.env.Count -gt 0) {
                $envPairs = @()
                foreach ($k in $srv.env.Keys) {
                    $escVal = $srv.env[$k] -replace '\\', '\\'
                    $envPairs += "$k = `"$escVal`""
                }
                $block += "`nenv = { $($envPairs -join ', ') }"
            }
            $newBlocks += $block
            $newCodexCount++
        }

        if ($newCodexCount -gt 0) {
            $appendText = ""
            if ($existingToml -and -not $existingToml.EndsWith("`n")) { $appendText += "`n" }
            $appendText += "`n# --- MCP Tools (added by install.ps1) ---`n"
            $appendText += ($newBlocks -join "`n`n")
            $appendText += "`n"
            Add-Content -Path $codexFile -Value $appendText -Encoding UTF8
            Write-OK "Codex: +$newCodexCount tool(s) -> $codexFile"
        } else {
            Write-Info "Codex config already up to date"
        }
    }
}

# ---- PATH ----
if ($AddToPath) {
    Write-Step "6/6 Configuring system PATH..."
    $cur = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($cur -notlike "*$TargetPath\bin*") {
        [Environment]::SetEnvironmentVariable("Path", "$cur;$TargetPath\bin", "User")
        Write-OK "Added to user PATH (new terminal required)"
    } else { Write-Info "Already in user PATH" }
}
else { Write-Step "6/6 Skipping PATH" }

# ---- Done ----
Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "|          INSTALL COMPLETE!                   |" -ForegroundColor Green
Write-Host "|----------------------------------------------|" -ForegroundColor Green
Write-Host ("|  Path: $TargetPath".PadRight(47) + "|") -ForegroundColor Green
Write-Host "|----------------------------------------------|" -ForegroundColor Green
Write-Host "|  Installed tools:                            |" -ForegroundColor Green
if ($HasPdfTools) {
    Write-Host "|    * pdf-reader  - PDF read/search/extract  |" -ForegroundColor Green
    Write-Host "|    * pdf-toolkit - PDF create/edit/merge     |" -ForegroundColor Green
}
if ($HasOfficeTools -and $PythonExe) {
    Write-Host "|    * wordmcp     - Word docs (51 tools)      |" -ForegroundColor Green
    Write-Host "|    * pptmcp      - PowerPoint (48 tools)     |" -ForegroundColor Green
    Write-Host "|    * excelmcp    - Excel (65 tools)          |" -ForegroundColor Green
}
Write-Host "|----------------------------------------------|" -ForegroundColor Green
Write-Host "|  Deps cache: deps/                           |" -ForegroundColor Green
Write-Host "|    deps/npm/    - Node.js dependencies       |" -ForegroundColor Green
Write-Host "|    deps/pip/    - Python wheels              |" -ForegroundColor Green
Write-Host "|    deps/runtimes/ - Node.js + Python         |" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to close..." -ForegroundColor White
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

return $TargetPath
