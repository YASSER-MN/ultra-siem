#Requires -RunAsAdministrator

# Ultra SIEM Compliance Report Generator
# Automated GDPR/HIPAA/SOX compliance reporting

param(
    [ValidateSet("GDPR", "HIPAA", "SOX", "All")]
    [string]$ComplianceType = "All",
    [string]$OutputPath = "reports",
    [int]$ReportDays = 30,
    [switch]$GeneratePDF = $true
)

$ErrorActionPreference = "Stop"

function Write-ComplianceLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [COMPLIANCE-$Level] $Message" -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }; "WARN" { "Yellow" }; "SUCCESS" { "Green" }; default { "Blue" }
    })
    Add-Content -Path "logs/compliance.log" -Value "[$timestamp] [COMPLIANCE-$Level] $Message"
}

function Get-GDPRReport {
    Write-ComplianceLog "📋 Generating GDPR compliance report..."
    
    $endDate = Get-Date
    $startDate = $endDate.AddDays(-$ReportDays)
    
    # Query ClickHouse for GDPR metrics
    $gdprQuery = @"
SELECT
    toDate(event_time) AS day,
    countIf(gdpr_anonymized = 1) AS anonymized_count,
    countIf(gdpr_encrypted = 1) AS encrypted_count,
    countIf(data_subject_request = 1) AS subject_requests,
    countIf(consent_given = 1) AS consent_granted,
    countIf(consent_withdrawn = 1) AS consent_withdrawn,
    countIf(data_breach = 1) AS breach_incidents,
    count() AS total_events,
    round(100 * anonymized_count / total_events, 2) AS anonymization_rate,
    round(100 * encrypted_count / total_events, 2) AS encryption_rate
FROM threats
WHERE event_time >= '$($startDate.ToString("yyyy-MM-dd"))'
  AND event_time <= '$($endDate.ToString("yyyy-MM-dd"))'
  AND (user_location LIKE '%EU%' OR gdpr_applicable = 1)
GROUP BY day
ORDER BY day DESC
"@

    $gdprResults = clickhouse-client --query $gdprQuery --format JSONEachRow | ConvertFrom-Json
    
    # Calculate summary statistics
    $totalEvents = ($gdprResults | Measure-Object -Property total_events -Sum).Sum
    $avgAnonymization = ($gdprResults | Measure-Object -Property anonymization_rate -Average).Average
    $avgEncryption = ($gdprResults | Measure-Object -Property encryption_rate -Average).Average
    $totalBreaches = ($gdprResults | Measure-Object -Property breach_incidents -Sum).Sum
    $totalSubjectRequests = ($gdprResults | Measure-Object -Property subject_requests -Sum).Sum
    
    # Data retention compliance
    $retentionQuery = @"
SELECT
    data_category,
    count() AS records_count,
    min(event_time) AS oldest_record,
    max(event_time) AS newest_record,
    dateDiff('day', min(event_time), now()) AS retention_days
FROM threats
WHERE gdpr_applicable = 1
GROUP BY data_category
HAVING retention_days > 365
"@

    $retentionViolations = clickhouse-client --query $retentionQuery --format JSONEachRow | ConvertFrom-Json
    
    $report = @{
        ReportType = "GDPR"
        GeneratedAt = Get-Date
        ReportPeriod = @{
            StartDate = $startDate
            EndDate = $endDate
            Days = $ReportDays
        }
        Summary = @{
            TotalEvents = $totalEvents
            AverageAnonymizationRate = [math]::Round($avgAnonymization, 2)
            AverageEncryptionRate = [math]::Round($avgEncryption, 2)
            TotalBreachIncidents = $totalBreaches
            TotalSubjectRequests = $totalSubjectRequests
            ComplianceScore = [math]::Round((($avgAnonymization + $avgEncryption) / 2), 2)
        }
        DailyMetrics = $gdprResults
        RetentionViolations = $retentionViolations
        Recommendations = @()
    }
    
    # Generate recommendations
    if ($avgAnonymization -lt 95) {
        $report.Recommendations += "Improve data anonymization: Current rate $avgAnonymization% (target: 95%+)"
    }
    
    if ($avgEncryption -lt 99) {
        $report.Recommendations += "Enhance encryption coverage: Current rate $avgEncryption% (target: 99%+)"
    }
    
    if ($retentionViolations.Count -gt 0) {
        $report.Recommendations += "Address data retention violations: $($retentionViolations.Count) categories exceed 1 year"
    }
    
    if ($totalBreaches -gt 0) {
        $report.Recommendations += "Review breach response procedures: $totalBreaches incidents in reporting period"
    }
    
    Write-ComplianceLog "✅ GDPR report completed: $totalEvents events, $($avgAnonymization)% anonymization rate"
    return $report
}

function Get-HIPAAReport {
    Write-ComplianceLog "🏥 Generating HIPAA compliance report..."
    
    $endDate = Get-Date
    $startDate = $endDate.AddDays(-$ReportDays)
    
    # HIPAA-specific metrics
    $hipaaQuery = @"
SELECT
    toDate(event_time) AS day,
    countIf(phi_encrypted = 1) AS phi_encrypted_count,
    countIf(access_logged = 1) AS access_logged_count,
    countIf(unauthorized_access = 1) AS unauthorized_access,
    countIf(phi_disclosed = 1) AS phi_disclosures,
    countIf(audit_trail_complete = 1) AS complete_audit_trails,
    count() AS total_healthcare_events,
    round(100 * phi_encrypted_count / total_healthcare_events, 2) AS phi_encryption_rate,
    round(100 * access_logged_count / total_healthcare_events, 2) AS audit_coverage
FROM threats
WHERE event_time >= '$($startDate.ToString("yyyy-MM-dd"))'
  AND event_time <= '$($endDate.ToString("yyyy-MM-dd"))'
  AND (industry = 'healthcare' OR contains_phi = 1)
GROUP BY day
ORDER BY day DESC
"@

    $hipaaResults = clickhouse-client --query $hipaaQuery --format JSONEachRow | ConvertFrom-Json
    
    # Access control analysis
    $accessQuery = @"
SELECT
    user_role,
    count() AS access_attempts,
    countIf(access_granted = 1) AS successful_access,
    countIf(access_denied = 1) AS denied_access,
    countIf(minimum_necessary = 1) AS minimum_necessary_compliance
FROM auth_events
WHERE event_time >= '$($startDate.ToString("yyyy-MM-dd"))'
  AND resource_type = 'phi'
GROUP BY user_role
ORDER BY access_attempts DESC
"@

    $accessResults = clickhouse-client --query $accessQuery --format JSONEachRow | ConvertFrom-Json
    
    # Calculate metrics
    $totalHIPAAEvents = ($hipaaResults | Measure-Object -Property total_healthcare_events -Sum).Sum
    $avgPHIEncryption = ($hipaaResults | Measure-Object -Property phi_encryption_rate -Average).Average
    $avgAuditCoverage = ($hipaaResults | Measure-Object -Property audit_coverage -Average).Average
    $totalUnauthorized = ($hipaaResults | Measure-Object -Property unauthorized_access -Sum).Sum
    
    $report = @{
        ReportType = "HIPAA"
        GeneratedAt = Get-Date
        ReportPeriod = @{
            StartDate = $startDate
            EndDate = $endDate
            Days = $ReportDays
        }
        Summary = @{
            TotalHealthcareEvents = $totalHIPAAEvents
            PHIEncryptionRate = [math]::Round($avgPHIEncryption, 2)
            AuditCoverageRate = [math]::Round($avgAuditCoverage, 2)
            UnauthorizedAccessAttempts = $totalUnauthorized
            ComplianceScore = [math]::Round((($avgPHIEncryption + $avgAuditCoverage) / 2), 2)
        }
        DailyMetrics = $hipaaResults
        AccessControl = $accessResults
        Recommendations = @()
    }
    
    # HIPAA recommendations
    if ($avgPHIEncryption -lt 100) {
        $report.Recommendations += "Ensure 100% PHI encryption: Current rate $avgPHIEncryption%"
    }
    
    if ($avgAuditCoverage -lt 98) {
        $report.Recommendations += "Improve audit trail coverage: Current rate $avgAuditCoverage% (target: 98%+)"
    }
    
    if ($totalUnauthorized -gt 0) {
        $report.Recommendations += "Investigate unauthorized access: $totalUnauthorized incidents detected"
    }
    
    Write-ComplianceLog "✅ HIPAA report completed: $totalHIPAAEvents healthcare events analyzed"
    return $report
}

function Get-SOXReport {
    Write-ComplianceLog "💰 Generating SOX compliance report..."
    
    $endDate = Get-Date
    $startDate = $endDate.AddDays(-$ReportDays)
    
    # SOX financial controls
    $soxQuery = @"
SELECT
    toDate(event_time) AS day,
    countIf(financial_transaction = 1) AS financial_events,
    countIf(control_tested = 1) AS controls_tested,
    countIf(control_effective = 1) AS effective_controls,
    countIf(segregation_duties = 1) AS proper_segregation,
    countIf(change_approved = 1) AS approved_changes,
    count() AS total_system_events,
    round(100 * effective_controls / controls_tested, 2) AS control_effectiveness,
    round(100 * proper_segregation / financial_events, 2) AS segregation_rate
FROM threats
WHERE event_time >= '$($startDate.ToString("yyyy-MM-dd"))'
  AND event_time <= '$($endDate.ToString("yyyy-MM-dd"))'
  AND (sox_relevant = 1 OR system_type = 'financial')
GROUP BY day
ORDER BY day DESC
"@

    $soxResults = clickhouse-client --query $soxQuery --format JSONEachRow | ConvertFrom-Json
    
    # IT change management
    $changeQuery = @"
SELECT
    change_type,
    count() AS total_changes,
    countIf(change_approved = 1) AS approved_changes,
    countIf(change_tested = 1) AS tested_changes,
    countIf(rollback_available = 1) AS rollback_ready
FROM change_events
WHERE event_time >= '$($startDate.ToString("yyyy-MM-dd"))'
  AND sox_impact = 1
GROUP BY change_type
ORDER BY total_changes DESC
"@

    $changeResults = clickhouse-client --query $changeQuery --format JSONEachRow | ConvertFrom-Json
    
    $totalSOXEvents = ($soxResults | Measure-Object -Property total_system_events -Sum).Sum
    $avgControlEffectiveness = ($soxResults | Measure-Object -Property control_effectiveness -Average).Average
    $avgSegregationRate = ($soxResults | Measure-Object -Property segregation_rate -Average).Average
    $totalFinancialEvents = ($soxResults | Measure-Object -Property financial_events -Sum).Sum
    
    $report = @{
        ReportType = "SOX"
        GeneratedAt = Get-Date
        ReportPeriod = @{
            StartDate = $startDate
            EndDate = $endDate
            Days = $ReportDays
        }
        Summary = @{
            TotalSOXEvents = $totalSOXEvents
            FinancialTransactions = $totalFinancialEvents
            ControlEffectiveness = [math]::Round($avgControlEffectiveness, 2)
            SegregationOfDuties = [math]::Round($avgSegregationRate, 2)
            ComplianceScore = [math]::Round((($avgControlEffectiveness + $avgSegregationRate) / 2), 2)
        }
        DailyMetrics = $soxResults
        ChangeManagement = $changeResults
        Recommendations = @()
    }
    
    # SOX recommendations
    if ($avgControlEffectiveness -lt 95) {
        $report.Recommendations += "Strengthen internal controls: Current effectiveness $avgControlEffectiveness% (target: 95%+)"
    }
    
    if ($avgSegregationRate -lt 90) {
        $report.Recommendations += "Improve segregation of duties: Current rate $avgSegregationRate% (target: 90%+)"
    }
    
    Write-ComplianceLog "✅ SOX report completed: $totalSOXEvents system events, $totalFinancialEvents financial transactions"
    return $report
}

function ConvertTo-PDFReport {
    param($Report, $OutputFile)
    
    Write-ComplianceLog "📄 Converting report to PDF: $OutputFile"
    
    # Generate HTML content
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>$($Report.ReportType) Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 20px; }
        .summary { background-color: #f5f5f5; padding: 20px; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: white; border-radius: 5px; }
        .recommendations { background-color: #fff3cd; padding: 15px; margin: 20px 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .compliance-score { font-size: 24px; font-weight: bold; color: $(if($Report.Summary.ComplianceScore -ge 90){'green'}elseif($Report.Summary.ComplianceScore -ge 70){'orange'}else{'red'}); }
    </style>
</head>
<body>
    <div class="header">
        <h1>$($Report.ReportType) Compliance Report</h1>
        <p>Generated: $($Report.GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss'))</p>
        <p>Period: $($Report.ReportPeriod.StartDate.ToString('yyyy-MM-dd')) to $($Report.ReportPeriod.EndDate.ToString('yyyy-MM-dd'))</p>
    </div>
    
    <div class="summary">
        <h2>Executive Summary</h2>
        <div class="metric">
            <h3>Compliance Score</h3>
            <div class="compliance-score">$($Report.Summary.ComplianceScore)%</div>
        </div>
"@

    # Add specific metrics based on report type
    foreach ($key in $Report.Summary.Keys | Where-Object { $_ -ne "ComplianceScore" }) {
        $value = $Report.Summary[$key]
        $htmlContent += "<div class='metric'><h4>$key</h4><p>$value</p></div>"
    }
    
    $htmlContent += "</div>"
    
    # Add recommendations if any
    if ($Report.Recommendations.Count -gt 0) {
        $htmlContent += "<div class='recommendations'><h2>Recommendations</h2><ul>"
        foreach ($rec in $Report.Recommendations) {
            $htmlContent += "<li>$rec</li>"
        }
        $htmlContent += "</ul></div>"
    }
    
    $htmlContent += "</body></html>"
    
    # Save HTML file
    $htmlFile = $OutputFile -replace "\.pdf$", ".html"
    $htmlContent | Out-File $htmlFile -Encoding UTF8
    
    # Convert to PDF using wkhtmltopdf if available
    if (Get-Command "wkhtmltopdf" -ErrorAction SilentlyContinue) {
        wkhtmltopdf $htmlFile $OutputFile
        Remove-Item $htmlFile
        Write-ComplianceLog "✅ PDF report generated: $OutputFile"
    } else {
        Write-ComplianceLog "⚠️ wkhtmltopdf not found, HTML report saved: $htmlFile" "WARN"
    }
}

function New-ComplianceSubmission {
    param($Report, $SubmissionType)
    
    Write-ComplianceLog "📤 Creating $SubmissionType submission package..."
    
    $submissionId = "SUBMISSION_$($SubmissionType)_$(Get-Date -Format 'yyyyMMdd_HHmm')"
    $submissionDir = "$OutputPath\submissions\$submissionId"
    
    New-Item -ItemType Directory -Force -Path $submissionDir | Out-Null
    
    # Main report
    $Report | ConvertTo-Json -Depth 10 | Out-File "$submissionDir\compliance_report.json"
    
    # Supporting evidence
    $evidenceQuery = @"
SELECT *
FROM audit_trail
WHERE event_time >= '$($Report.ReportPeriod.StartDate.ToString("yyyy-MM-dd"))'
  AND event_time <= '$($Report.ReportPeriod.EndDate.ToString("yyyy-MM-dd"))'
  AND compliance_relevant = 1
ORDER BY event_time
"@

    $evidence = clickhouse-client --query $evidenceQuery --format JSONEachRow
    $evidence | Out-File "$submissionDir\audit_evidence.json"
    
    # Digital signature
    $reportHash = Get-FileHash "$submissionDir\compliance_report.json" -Algorithm SHA256
    $signature = @{
        SubmissionId = $submissionId
        ReportHash = $reportHash.Hash
        SignedBy = $env:USERNAME
        SignedAt = Get-Date
        DigitalSignature = "SIGNATURE_PLACEHOLDER"  # Would use actual PKI in production
    }
    
    $signature | ConvertTo-Json | Out-File "$submissionDir\digital_signature.json"
    
    # Create ZIP package
    $zipFile = "$OutputPath\$submissionId.zip"
    Compress-Archive -Path "$submissionDir\*" -DestinationPath $zipFile -Force
    
    Write-ComplianceLog "✅ Submission package created: $zipFile"
    return $zipFile
}

# Main execution
switch ($ComplianceType) {
    "GDPR" {
        $report = Get-GDPRReport
        $outputFile = "$OutputPath\GDPR_Report_$(Get-Date -Format 'yyyyMMdd').json"
        $report | ConvertTo-Json -Depth 10 | Out-File $outputFile
        
        if ($GeneratePDF) {
            ConvertTo-PDFReport -Report $report -OutputFile $outputFile.Replace(".json", ".pdf")
        }
    }
    
    "HIPAA" {
        $report = Get-HIPAAReport
        $outputFile = "$OutputPath\HIPAA_Report_$(Get-Date -Format 'yyyyMMdd').json"
        $report | ConvertTo-Json -Depth 10 | Out-File $outputFile
        
        if ($GeneratePDF) {
            ConvertTo-PDFReport -Report $report -OutputFile $outputFile.Replace(".json", ".pdf")
        }
    }
    
    "SOX" {
        $report = Get-SOXReport
        $outputFile = "$OutputPath\SOX_Report_$(Get-Date -Format 'yyyyMMdd').json"
        $report | ConvertTo-Json -Depth 10 | Out-File $outputFile
        
        if ($GeneratePDF) {
            ConvertTo-PDFReport -Report $report -OutputFile $outputFile.Replace(".json", ".pdf")
        }
    }
    
    "All" {
        $reports = @{
            GDPR = Get-GDPRReport
            HIPAA = Get-HIPAAReport
            SOX = Get-SOXReport
        }
        
        foreach ($type in $reports.Keys) {
            $outputFile = "$OutputPath\${type}_Report_$(Get-Date -Format 'yyyyMMdd').json"
            $reports[$type] | ConvertTo-Json -Depth 10 | Out-File $outputFile
            
            if ($GeneratePDF) {
                ConvertTo-PDFReport -Report $reports[$type] -OutputFile $outputFile.Replace(".json", ".pdf")
            }
        }
        
        # Combined executive summary
        $executiveSummary = @{
            GeneratedAt = Get-Date
            OverallComplianceScore = [math]::Round((($reports.GDPR.Summary.ComplianceScore + $reports.HIPAA.Summary.ComplianceScore + $reports.SOX.Summary.ComplianceScore) / 3), 2)
            GDPR = $reports.GDPR.Summary
            HIPAA = $reports.HIPAA.Summary
            SOX = $reports.SOX.Summary
        }
        
        $executiveSummary | ConvertTo-Json -Depth 10 | Out-File "$OutputPath\Executive_Summary_$(Get-Date -Format 'yyyyMMdd').json"
    }
}

Write-ComplianceLog "🎯 Compliance reporting completed successfully" "SUCCESS" 