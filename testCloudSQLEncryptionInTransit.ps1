#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks Cloud SQL instances for SSL/TLS encryption in transit requirements.

.DESCRIPTION
    This script scans all accessible GCP projects and checks whether Cloud SQL
    instances require SSL/TLS for client connections (encryption in transit).

.PARAMETER OutputFile
    Optional file path to save results

.PARAMETER ProjectId
    Optional specific project ID to check (instead of all projects)

.EXAMPLE
    .\testCloudSQLEncryptionInTransit.ps1

.EXAMPLE
    .\testCloudSQLEncryptionInTransit.ps1 -OutputFile "ssl_report.txt"

.EXAMPLE
    .\testCloudSQLEncryptionInTransit.ps1 -ProjectId "my-project-123"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputFile,

    [Parameter(Mandatory=$false)]
    [string]$ProjectId
)

# Check if gcloud is installed
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Error "gcloud CLI is not installed or not in PATH"
    Write-Host "Please install the Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    exit 1
}

Write-Host "==================================================================="
Write-Host "GCP Cloud SQL Encryption in Transit (SSL) Checker"
Write-Host "==================================================================="
Write-Host ""

# Store current project to restore later
$originalProject = gcloud config get-value project 2>$null

$results = @()
$totalInstances = 0
$sslRequired = 0
$sslNotRequired = 0

try {
    # Get list of projects
    if ($ProjectId) {
        $projectList = @($ProjectId)
        Write-Host "Checking specific project: $ProjectId"
    } else {
        Write-Host "Retrieving list of projects..."
        $projectList = gcloud projects list --format="value(projectId)" 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to list projects. Please check your permissions."
            exit 1
        }
    }

    Write-Host ""

    # Iterate through each project
    foreach ($project in $projectList) {
        if ([string]::IsNullOrWhiteSpace($project)) {
            continue
        }

        Write-Host "Checking project: $project" -ForegroundColor Cyan

        # Set the current project
        $null = gcloud config set project $project 2>&1

        # Retrieve a list of Cloud SQL instances in the project
        $instanceList = gcloud sql instances list --format="value(name)" 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Unable to list Cloud SQL instances (API may not be enabled)" -ForegroundColor Yellow
            continue
        }

        if ([string]::IsNullOrWhiteSpace($instanceList)) {
            Write-Host "  No Cloud SQL instances found" -ForegroundColor Gray
            continue
        }

        # Check SSL requirement for each instance
        foreach ($instance in $instanceList) {
            if ([string]::IsNullOrWhiteSpace($instance)) {
                continue
            }

            $totalInstances++

            $requireSsl = gcloud sql instances describe $instance --format="value(settings.ipConfiguration.requireSsl)" 2>&1

            if ($requireSsl -eq "True") {
                Write-Host "  ✓ Instance '$instance': SSL is REQUIRED" -ForegroundColor Green
                $sslRequired++
                $sslStatus = "Required"
            } else {
                Write-Host "  ✗ Instance '$instance': SSL is NOT required" -ForegroundColor Red
                $sslNotRequired++
                $sslStatus = "Not Required"
            }

            $results += [PSCustomObject]@{
                Project = $project
                Instance = $instance
                SslRequired = $sslStatus
            }
        }
    }

    # Summary
    Write-Host ""
    Write-Host "==================================================================="
    Write-Host "SUMMARY"
    Write-Host "==================================================================="
    Write-Host "Total Cloud SQL instances found: $totalInstances"
    Write-Host "Instances requiring SSL: $sslRequired" -ForegroundColor Green
    Write-Host "Instances NOT requiring SSL: $sslNotRequired" -ForegroundColor $(if ($sslNotRequired -gt 0) { "Red" } else { "Green" })
    Write-Host ""

    if ($sslNotRequired -gt 0) {
        Write-Host "WARNING: $sslNotRequired instance(s) do not require SSL for connections!" -ForegroundColor Red
        Write-Host "This allows unencrypted connections and may expose data in transit." -ForegroundColor Yellow
    }

    # Save to file if requested
    if ($OutputFile -and $results.Count -gt 0) {
        $outputContent = @"
=================================================================
GCP Cloud SQL Encryption in Transit Report
=================================================================
Scan Date: $(Get-Date)
Total Instances: $totalInstances
SSL Required: $sslRequired
SSL Not Required: $sslNotRequired

=================================================================
DETAILED RESULTS
=================================================================

"@

        foreach ($result in $results) {
            $outputContent += "Project: $($result.Project)`n"
            $outputContent += "  Instance: $($result.Instance)`n"
            $outputContent += "  SSL Required: $($result.SslRequired)`n"
            $outputContent += "`n"
        }

        $outputContent | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "Results saved to: $OutputFile" -ForegroundColor Green
    }

} catch {
    Write-Error "An error occurred: $_"
    exit 1
} finally {
    # Restore original project
    if ($originalProject) {
        $null = gcloud config set project $originalProject 2>&1
    }
}
