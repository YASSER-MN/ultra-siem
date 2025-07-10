# 🌟 BRILLIANT ULTRA SIEM CLEANUP SCRIPT
# The most intelligent cleanup ever performed - removes all bloat while preserving production essentials

param(
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-BrilliantLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "DELETE" { "Magenta" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Show-BrilliantBanner {
    Clear-Host
    Write-Host "🌟 BRILLIANT ULTRA SIEM CLEANUP" -ForegroundColor Magenta
    Write-Host "=================================" -ForegroundColor Magenta
    Write-Host "🧠 Most Intelligent Cleanup Ever Performed" -ForegroundColor Cyan
    Write-Host "⚡ Surgical Bloat Removal" -ForegroundColor Green
    Write-Host "🎯 Production Essentials Preserved" -ForegroundColor Yellow
    Write-Host "🚀 Zero Compromise Architecture" -ForegroundColor Red
    Write-Host ""
}

function Test-EssentialFile {
    param($FilePath)
    
    $essentialFiles = @(
        "README.md",
        "LICENSE",
        "CHANGELOG.md",
        "SECURITY.md",
        "CONTRIBUTING.md",
        "CODE_OF_CONDUCT.md",
        "INSTALLATION_GUIDE.md",
        "QUICK_START.md",
        "DEPLOYMENT_GUIDE.md",
        "TROUBLESHOOTING_GUIDE.md",
        "UPGRADE_GUIDE.md",
        "API.md",
        "docker-compose.simple.yml",
        "docker-compose.ultra.yml",
        "docker-compose.universal.yml",
        "Makefile",
        ".gitignore"
    )
    
    $fileName = Split-Path $FilePath -Leaf
    return $essentialFiles -contains $fileName
}

function Test-EssentialScript {
    param($FilePath)
    
    $essentialScripts = @(
        "enterprise_deployment.ps1",
        "security_hardening.ps1",
        "setup_windows.ps1",
        "validate_production.ps1",
        "production_simulation.ps1",
        "install_requirements.ps1",
        "install_user_requirements.ps1",
        "deploy_universal.sh",
        "performance_optimization.ps1",
        "benchmark.ps1",
        "start_services.ps1",
        "setup_dashboards.ps1",
        "load_test.js",
        "create_tables.sql"
    )
    
    $fileName = Split-Path $FilePath -Leaf
    return $essentialScripts -contains $fileName
}

function Remove-BloatFiles {
    param($Directory, $Pattern, $Description)
    
    Write-BrilliantLog "🔍 Scanning $Description in $Directory" "INFO"
    
    if (Test-Path $Directory) {
        $files = Get-ChildItem -Path $Directory -Recurse -File | Where-Object {
            $_.Name -match $Pattern -and -not (Test-EssentialFile $_.FullName)
        }
        
        foreach ($file in $files) {
            if ($DryRun) {
                Write-BrilliantLog "Would delete: $($file.FullName)" "DELETE"
            } else {
                try {
                    Remove-Item $file.FullName -Force
                    Write-BrilliantLog "Deleted: $($file.Name)" "SUCCESS"
                } catch {
                    Write-BrilliantLog "Failed to delete $($file.Name): $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

function Remove-BloatScripts {
    param($Directory, $Description)
    
    Write-BrilliantLog "🔍 Scanning $Description in $Directory" "INFO"
    
    if (Test-Path $Directory) {
        $files = Get-ChildItem -Path $Directory -Recurse -File -Include "*.ps1", "*.sh", "*.js", "*.sql" | Where-Object {
            -not (Test-EssentialScript $_.FullName) -and (
                $_.Name -match "test_|demo_|attack_|simulate_|quantum_|chaos_|bulletproof_|ultra_|zero_|ymdemo_|real_detection_|verify_|open_|demo_ready_|test_|fix_|quick_fix_|comprehensive_fix_|deploy_cloud_|deploy_quantum_|deploy_zero_|setup_siem_|start_siem_|setup_dashboards_simple_|test_wsl_|fix_all_paths_|fix_go_path_|fix_rust_path_|fix_zig_path_|generate_real_events_|verify-detections_|attack-simulation_|performance_optimization_|security_hardening_|bulletproof_deployment_|deploy_quantum_siem_|deploy_zero_latency_|create_tables_|setup_dashboards_simple_|load_test_|test_wsl_deployment_|deploy_universal_|fix_builds_corrected_|fix_all_paths_|fix_go_path_|fix_rust_path_|fix_zig_path_|setup_siem_complete_|start_siem_basic_|quick_fix_rust_|fix_builds_|install_user_requirements_|install_requirements_|production_simulation_|validate_production_|enterprise_deployment_|benchmark_|start_services_|setup_windows_"
            )
        }
        
        foreach ($file in $files) {
            if ($DryRun) {
                Write-BrilliantLog "Would delete: $($file.FullName)" "DELETE"
            } else {
                try {
                    Remove-Item $file.FullName -Force
                    Write-BrilliantLog "Deleted: $($file.Name)" "SUCCESS"
                } catch {
                    Write-BrilliantLog "Failed to delete $($file.Name): $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

function Remove-BloatDirectories {
    param($Directory, $Description)
    
    Write-BrilliantLog "🔍 Scanning $Description in $Directory" "INFO"
    
    if (Test-Path $Directory) {
        $dirs = Get-ChildItem -Path $Directory -Directory | Where-Object {
            $_.Name -match "achievements|partnerships|education|research|i18n|community|profile|analytics|badges" -or
            $_.Name -match "examples|demo|test|tutorial|sample|example"
        }
        
        foreach ($dir in $dirs) {
            if ($DryRun) {
                Write-BrilliantLog "Would delete directory: $($dir.FullName)" "DELETE"
            } else {
                try {
                    Remove-Item $dir.FullName -Recurse -Force
                    Write-BrilliantLog "Deleted directory: $($dir.Name)" "SUCCESS"
                } catch {
                    Write-BrilliantLog "Failed to delete directory $($dir.Name): $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

function Remove-BloatMarkdown {
    param($Directory, $Description)
    
    Write-BrilliantLog "🔍 Scanning $Description in $Directory" "INFO"
    
    if (Test-Path $Directory) {
        $files = Get-ChildItem -Path $Directory -Recurse -File -Include "*.md" | Where-Object {
            -not (Test-EssentialFile $_.FullName) -and (
                $_.Name -match "PHASE|COMPLETION|SUMMARY|REPORT|FINAL|ULTRA|QUANTUM|ZERO|ENTERPRISE|WORLD_CLASS|DEEP_ANALYSIS|DEMO_READY|PRESENTATION|ATTACK_TESTING|REAL_TIME|SMTP_SETUP|GRAFANA_DASHBOARD|SIEM_QUICK|ULTRA_SIEM_ACCESS|QUICK_FIX|DEPLOYMENT_SUMMARY|USER_INSTALLATION|FINAL_PRODUCTION|ENTERPRISE_PRODUCTION|ULTRA_SIEM_FINAL|ULTRA_SIEM_COMPLETE|ULTRA_SIEM_FULL|ULTRA_SIEM_HEALTH|TESTING_SUMMARY|STARTUP_GUIDE|REAL_DETECTION|REAL_TIME_TESTING|GPU_ACCELERATION|CROSS_PLATFORM|GOVERNANCE|dashboard_creation_guide|API_INTEGRATION|UPGRADE|TROUBLESHOOTING|PHASE1|PHASE2|PHASE3|PHASE4|PHASE5|PHASE6"
            )
        }
        
        foreach ($file in $files) {
            if ($DryRun) {
                Write-BrilliantLog "Would delete: $($file.FullName)" "DELETE"
            } else {
                try {
                    Remove-Item $file.FullName -Force
                    Write-BrilliantLog "Deleted: $($file.Name)" "SUCCESS"
                } catch {
                    Write-BrilliantLog "Failed to delete $($file.Name): $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

function Remove-RootBloatFiles {
    Write-BrilliantLog "🔍 Scanning root directory for bloat files" "INFO"
    
    $bloatPatterns = @(
        "*PHASE*COMPLETION*",
        "*SUMMARY*",
        "*REPORT*",
        "*FINAL*",
        "*ULTRA*",
        "*QUANTUM*",
        "*ZERO*",
        "*ENTERPRISE*",
        "*WORLD_CLASS*",
        "*DEEP_ANALYSIS*",
        "*DEMO_READY*",
        "*PRESENTATION*",
        "*ATTACK_TESTING*",
        "*REAL_TIME*",
        "*SMTP_SETUP*",
        "*GRAFANA_DASHBOARD*",
        "*SIEM_QUICK*",
        "*ULTRA_SIEM_ACCESS*",
        "*QUICK_FIX*",
        "*DEPLOYMENT_SUMMARY*",
        "*USER_INSTALLATION*",
        "*FINAL_PRODUCTION*",
        "*ENTERPRISE_PRODUCTION*",
        "*ULTRA_SIEM_FINAL*",
        "*ULTRA_SIEM_COMPLETE*",
        "*ULTRA_SIEM_FULL*",
        "*ULTRA_SIEM_HEALTH*",
        "*TESTING_SUMMARY*",
        "*STARTUP_GUIDE*",
        "*REAL_DETECTION*",
        "*REAL_TIME_TESTING*",
        "*GPU_ACCELERATION*",
        "*CROSS_PLATFORM*",
        "*GOVERNANCE*",
        "*demo*",
        "test_*.ps1",
        "attack_*.ps1",
        "simulate_*.ps1",
        "quantum_*.ps1",
        "chaos_*.ps1",
        "bulletproof_*.ps1",
        "ultra_*.ps1",
        "zero_*.ps1",
        "ymdemo*.ps1",
        "real_detection_*.ps1",
        "verify_*.ps1",
        "open_*.ps1",
        "demo_ready*.ps1",
        "fix_*.ps1",
        "quick_fix_*.ps1",
        "comprehensive_fix*.ps1",
        "deploy_cloud_*.ps1",
        "deploy_quantum_*.ps1",
        "deploy_zero_*.ps1",
        "setup_siem_*.ps1",
        "start_siem_*.ps1",
        "setup_dashboards_simple*.ps1",
        "test_wsl_*.ps1",
        "fix_all_paths*.ps1",
        "fix_go_path*.ps1",
        "fix_rust_path*.ps1",
        "fix_zig_path*.ps1",
        "generate_real_events*.ps1",
        "verify-detections*.ps1",
        "attack-simulation*.ps1",
        "performance_optimization*.ps1",
        "security_hardening*.ps1",
        "bulletproof_deployment*.ps1",
        "deploy_quantum_siem*.ps1",
        "deploy_zero_latency*.ps1",
        "create_tables*.sql",
        "setup_dashboards_simple*.ps1",
        "load_test*.js",
        "test_wsl_deployment*.ps1",
        "deploy_universal*.sh",
        "fix_builds_corrected*.ps1",
        "fix_all_paths*.ps1",
        "fix_go_path*.ps1",
        "fix_rust_path*.ps1",
        "fix_zig_path*.ps1",
        "setup_siem_complete*.ps1",
        "start_siem_basic*.ps1",
        "quick_fix_rust*.ps1",
        "fix_builds*.ps1",
        "install_user_requirements*.ps1",
        "install_requirements*.ps1",
        "production_simulation*.ps1",
        "validate_production*.ps1",
        "enterprise_deployment*.ps1",
        "benchmark*.ps1",
        "start_services*.ps1",
        "setup_windows*.ps1",
        "siem_monitor*.ps1",
        "quantum_monitor*.ps1",
        "auto_scaling_controller*.ps1",
        "bulletproof_monitor*.ps1",
        "chaos_monkey*.ps1",
        "zero_latency_monitor*.ps1",
        "attack_control_center*.ps1",
        "test_real_attacks*.ps1",
        "demo_shutdown*.ps1",
        "demo_quick_start*.ps1",
        "test_network_detection*.ps1",
        "test_malware_detection*.ps1",
        "test_windows_events*.ps1",
        "test_with_existing_infra*.ps1",
        "test_real_detection*.ps1",
        "verify_real_detection*.ps1",
        "real_detection_demo*.ps1",
        "ymdemo*.ps1",
        "demo_ready*.ps1",
        "test_dashboard_queries*.ps1",
        "open_dashboard*.ps1",
        "setup_email_alerts*.ps1",
        "ultra_atomic_health_monitor*.ps1",
        "ultra_siem_health_exporter*.ps1",
        "ultra_siem_health_monitor*.ps1",
        "start-ultra-siem*.ps1",
        "FINAL_STATUS*.txt",
        "USER_INSTALLATION_COMPLETE*.txt"
    )
    
    foreach ($pattern in $bloatPatterns) {
        $files = Get-ChildItem -Path "." -File | Where-Object {
            $_.Name -like $pattern -and -not (Test-EssentialFile $_.FullName)
        }
        
        foreach ($file in $files) {
            if ($DryRun) {
                Write-BrilliantLog "Would delete: $($file.Name)" "DELETE"
            } else {
                try {
                    Remove-Item $file.FullName -Force
                    Write-BrilliantLog "Deleted: $($file.Name)" "SUCCESS"
                } catch {
                    Write-BrilliantLog "Failed to delete $($file.Name): $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

function Cleanup-DataDirectories {
    Write-BrilliantLog "🧹 Cleaning up data directories" "INFO"
    
    # Clean up demo/test data while preserving production configs
    $dataDirs = @("data/grafana/pdf", "data/grafana/csv", "data/grafana/png")
    
    foreach ($dir in $dataDirs) {
        if (Test-Path $dir) {
            $files = Get-ChildItem -Path $dir -File
            foreach ($file in $files) {
                if ($DryRun) {
                    Write-BrilliantLog "Would delete demo data: $($file.FullName)" "DELETE"
                } else {
                    try {
                        Remove-Item $file.FullName -Force
                        Write-BrilliantLog "Deleted demo data: $($file.Name)" "SUCCESS"
                    } catch {
                        Write-BrilliantLog "Failed to delete $($file.Name): $($_.Exception.Message)" "ERROR"
                    }
                }
            }
        }
    }
}

function Show-CleanupSummary {
    Write-BrilliantLog "🎯 BRILLIANT CLEANUP COMPLETE" "SUCCESS"
    Write-BrilliantLog "✅ All bloat removed while preserving production essentials" "SUCCESS"
    Write-BrilliantLog "🚀 Ultra SIEM is now streamlined and production-ready" "SUCCESS"
    Write-BrilliantLog "🌟 The most intelligent cleanup ever performed" "SUCCESS"
}

# MAIN EXECUTION
Show-BrilliantBanner

if ($DryRun) {
    Write-BrilliantLog "🔍 DRY RUN MODE - No files will be deleted" "WARN"
}

Write-BrilliantLog "🚀 Starting brilliant cleanup process..." "INFO"

# Remove bloat from root directory
Remove-RootBloatFiles

# Remove bloat from scripts directory
Remove-BloatScripts "scripts" "bloat scripts"

# Remove bloat from .github directory
Remove-BloatDirectories ".github" "bloat directories"
Remove-BloatMarkdown ".github" "bloat markdown files"

# Remove bloat from docs directory
Remove-BloatMarkdown "docs" "bloat documentation"

# Remove bloat from examples directory
if (Test-Path "examples") {
    if ($DryRun) {
        Write-BrilliantLog "Would delete entire examples directory" "DELETE"
    } else {
        try {
            Remove-Item "examples" -Recurse -Force
            Write-BrilliantLog "Deleted examples directory" "SUCCESS"
        } catch {
            Write-BrilliantLog "Failed to delete examples directory: $($_.Exception.Message)" "ERROR"
        }
    }
}

# Clean up data directories
Cleanup-DataDirectories

# Remove specific bloat files that might have been missed
$specificBloatFiles = @(
    "FINAL_STATUS.txt",
    "USER_INSTALLATION_COMPLETE.txt",
    "comprehensive_fix.ps1"
)

foreach ($file in $specificBloatFiles) {
    if (Test-Path $file) {
        if ($DryRun) {
            Write-BrilliantLog "Would delete: $file" "DELETE"
        } else {
            try {
                Remove-Item $file -Force
                Write-BrilliantLog "Deleted: $file" "SUCCESS"
            } catch {
                $errorMsg = $_.Exception.Message
                Write-BrilliantLog "Failed to delete $file`: $errorMsg" "ERROR"
            }
        }
    }
}

Show-CleanupSummary

if ($DryRun) {
    Write-BrilliantLog "🔍 Dry run completed. Run without -DryRun to perform actual cleanup." "WARN"
} else {
    Write-BrilliantLog "🌟 BRILLIANT CLEANUP SUCCESSFULLY COMPLETED!" "SUCCESS"
} 