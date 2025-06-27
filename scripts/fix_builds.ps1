# Fix Build Issues Script
# Run this after installing Visual Studio Build Tools

param(
    [switch]$SkipRust = $false,
    [switch]$SkipGo = $false,
    [switch]$SkipZig = $false
)

function Write-FixLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [FIX-$Level] $Message" -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }; "SUCCESS" { "Green" }; "WARN" { "Yellow" }; default { "Cyan" }
    })
}

function Test-VisualStudioBuildTools {
    Write-FixLog "🔍 Checking for Visual Studio Build Tools..."
    
    # Check for link.exe (MSVC linker)
    $linkExe = Get-Command "link.exe" -ErrorAction SilentlyContinue
    if ($linkExe) {
        Write-FixLog "✅ Visual Studio Build Tools found: $($linkExe.Source)" "SUCCESS"
        return $true
    }
    
    # Check common installation paths
    $commonPaths = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\*\bin\Hostx64\x64\link.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\*\bin\Hostx64\x64\link.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\*\bin\Hostx64\x64\link.exe"
    )
    
    foreach ($path in $commonPaths) {
        $found = Get-ChildItem $path -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            Write-FixLog "✅ Found Visual Studio Build Tools at: $($found.DirectoryName)" "SUCCESS"
            
            # Add to PATH for current session
            $env:PATH += ";$($found.DirectoryName)"
            
            return $true
        }
    }
    
    Write-FixLog "❌ Visual Studio Build Tools not found. Please install from:" "ERROR"
    Write-FixLog "   https://visualstudio.microsoft.com/visual-cpp-build-tools/" "ERROR"
    return $false
}

function Fix-RustBuild {
    if ($SkipRust) {
        Write-FixLog "⏭️ Skipping Rust build fix"
        return
    }
    
    Write-FixLog "🦀 Fixing Rust build..."
    
    if (-not (Test-VisualStudioBuildTools)) {
        Write-FixLog "❌ Cannot fix Rust build without Visual Studio Build Tools" "ERROR"
        return
    }
    
    if (-not (Test-Path "rust-core\Cargo.toml")) {
        Write-FixLog "⚠️ Rust project not found" "WARN"
        return
    }
    
    try {
        Set-Location "rust-core"
        
        Write-FixLog "Cleaning previous build artifacts..."
        cargo clean
        
        Write-FixLog "Rebuilding Rust core with optimizations..."
        $env:RUSTFLAGS = "-C target-cpu=native"
        cargo build --release
        
        if (Test-Path "target\release\rust-core.exe") {
            Write-FixLog "✅ Rust core built successfully!" "SUCCESS"
            $exeSize = (Get-Item "target\release\rust-core.exe").Length / 1MB
            Write-FixLog "Binary size: $([math]::Round($exeSize, 2)) MB"
        } else {
            Write-FixLog "❌ Rust build failed - executable not found" "ERROR"
        }
    }
    catch {
        Write-FixLog "❌ Rust build error: $_" "ERROR"
    }
    finally {
        Set-Location ".."
    }
}

function Fix-GoBuild {
    if ($SkipGo) {
        Write-FixLog "⏭️ Skipping Go build fix"
        return
    }
    
    Write-FixLog "🔷 Fixing Go build..."
    
    if (-not (Get-Command "go" -ErrorAction SilentlyContinue)) {
        Write-FixLog "❌ Go not installed. Download from: https://golang.org/dl/" "ERROR"
        return
    }
    
    if (-not (Test-Path "go-services\go.mod")) {
        Write-FixLog "⚠️ Go project not found" "WARN"
        return
    }
    
    try {
        Set-Location "go-services"
        
        Write-FixLog "Downloading Go dependencies..."
        go mod download
        go mod tidy
        
        # Create bin directory
        if (-not (Test-Path "bin")) {
            New-Item -ItemType Directory -Force -Path "bin" | Out-Null
        }
        
        Write-FixLog "Building Go services..."
        go build -ldflags="-s -w" -o bin\ .\...
        
        $binFiles = Get-ChildItem "bin" -Filter "*.exe"
        if ($binFiles.Count -gt 0) {
            Write-FixLog "✅ Go services built successfully! ($($binFiles.Count) executables)" "SUCCESS"
            foreach ($file in $binFiles) {
                $size = $file.Length / 1MB
                Write-FixLog "  - $($file.Name): $([math]::Round($size, 2)) MB"
            }
        } else {
            Write-FixLog "❌ Go build failed - no executables found" "ERROR"
        }
    }
    catch {
        Write-FixLog "❌ Go build error: $_" "ERROR"
    }
    finally {
        Set-Location ".."
    }
}

function Fix-ZigBuild {
    if ($SkipZig) {
        Write-FixLog "⏭️ Skipping Zig build fix"
        return
    }
    
    Write-FixLog "⚡ Fixing Zig build..."
    
    if (-not (Get-Command "zig" -ErrorAction SilentlyContinue)) {
        Write-FixLog "❌ Zig not installed" "ERROR"
        return
    }
    
    if (-not (Test-Path "zig-query\build.zig")) {
        Write-FixLog "⚠️ Zig project not found" "WARN"
        return
    }
    
    try {
        Set-Location "zig-query"
        
        Write-FixLog "Cleaning Zig cache..."
        if (Test-Path "zig-cache") {
            Remove-Item "zig-cache" -Recurse -Force
        }
        if (Test-Path "zig-out") {
            Remove-Item "zig-out" -Recurse -Force
        }
        
        Write-FixLog "Building Zig query engine (without AVX-512 for compatibility)..."
        # Build without AVX-512 to ensure compatibility
        zig build -Doptimize=ReleaseFast
        
        if (Test-Path "zig-out\bin") {
            $binFiles = Get-ChildItem "zig-out\bin" -File
            if ($binFiles.Count -gt 0) {
                Write-FixLog "✅ Zig query engine built successfully!" "SUCCESS"
                foreach ($file in $binFiles) {
                    $size = $file.Length / 1KB
                    Write-FixLog "  - $($file.Name): $([math]::Round($size, 2)) KB"
                }
            } else {
                Write-FixLog "❌ Zig build failed - no executables found" "ERROR"
            }
        } else {
            Write-FixLog "❌ Zig build failed - output directory not found" "ERROR"
        }
    }
    catch {
        Write-FixLog "❌ Zig build error: $_" "ERROR"
    }
    finally {
        Set-Location ".."
    }
}

function Test-AllBuilds {
    Write-FixLog "🧪 Testing all builds..."
    
    $results = @{
        Rust = Test-Path "rust-core\target\release\rust-core.exe"
        Go = (Get-ChildItem "go-services\bin" -Filter "*.exe" -ErrorAction SilentlyContinue).Count -gt 0
        Zig = (Get-ChildItem "zig-query\zig-out\bin" -File -ErrorAction SilentlyContinue).Count -gt 0
    }
    
    $totalTests = $results.Count
    $passedTests = ($results.Values | Where-Object { $_ -eq $true }).Count
    
    Write-FixLog "📊 Build Results: $passedTests/$totalTests successful"
    
    foreach ($test in $results.GetEnumerator()) {
        $status = if ($test.Value) { "✅ PASS" } else { "❌ FAIL" }
        Write-FixLog "$($test.Key): $status"
    }
    
    if ($passedTests -eq $totalTests) {
        Write-FixLog "🎉 All builds successful! Ready for deployment!" "SUCCESS"
    } else {
        Write-FixLog "⚠️ Some builds failed. Check error messages above." "WARN"
    }
    
    return $passedTests -eq $totalTests
}

# Main execution
Write-FixLog "🔧 Starting build fixes..."

# Check prerequisites
Write-FixLog "Checking prerequisites..."
$rustOk = Get-Command "rustc" -ErrorAction SilentlyContinue
$zigOk = Get-Command "zig" -ErrorAction SilentlyContinue
$goOk = Get-Command "go" -ErrorAction SilentlyContinue

Write-FixLog "Prerequisites: Rust=$(if($rustOk){'✅'}else{'❌'}) Go=$(if($goOk){'✅'}else{'❌'}) Zig=$(if($zigOk){'✅'}else{'❌'})"

# Fix builds
Fix-RustBuild
Fix-GoBuild  
Fix-ZigBuild

# Test everything
$allSuccess = Test-AllBuilds

if ($allSuccess) {
    Write-FixLog "🚀 All builds fixed! You can now run:" "SUCCESS"
    Write-FixLog "   .\scripts\enterprise_deployment.ps1" "SUCCESS"
} else {
    Write-FixLog "📋 Next steps:" "INFO"
    Write-FixLog "1. Install Visual Studio Build Tools if Rust failed"
    Write-FixLog "2. Install Go from https://golang.org/dl/ if Go failed"
    Write-FixLog "3. Check error messages for specific issues"
}

Write-FixLog "✅ Build fix process completed!" 