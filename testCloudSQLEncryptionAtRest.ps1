#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks Cloud SQL instances across all GCP projects for data-at-rest encryption.

.DESCRIPTION
    This script scans all accessible GCP projects and checks whether Cloud SQL
    instances have data-at-rest encryption enabled.

.PARAMETER OutputFile
    Optional file path to save results

.PARAMETER ProjectId
    Optional specific project ID to check (instead of all projects)

.EXAMPLE
    .\testCloudSQLEncryptionAtRest.ps1

.EXAMPLE
    .\testCloudSQLEncryptionAtRest.ps1 -OutputFile "encryption_report.txt"

.EXAMPLE
    .\testCloudSQLEncryptionAtRest.ps1 -ProjectId "my-project-123"
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
Write-Host "GCP Cloud SQL Encryption at Rest Checker"
Write-Host "==================================================================="
Write-Host ""

# Store current project to restore later
$originalProject = gcloud config get-value project 2>$null

$results = @()
$totalInstances = 0
$encryptedInstances = 0
$unencryptedInstances = 0

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

        # Check encryption status for each instance
        foreach ($instance in $instanceList) {
            if ([string]::IsNullOrWhiteSpace($instance)) {
                continue
            }

            $totalInstances++

            $diskEncryptionConfig = gcloud sql instances describe $instance --format="value(diskEncryptionConfiguration.kmsKeyName)" 2>&1
            $diskEncryptionStatus = gcloud sql instances describe $instance --format="value(diskEncryptionStatus.kmsKeyVersionName)" 2>&1

            # Determine if encryption is enabled
            $isEncrypted = -not [string]::IsNullOrWhiteSpace($diskEncryptionConfig) -or -not [string]::IsNullOrWhiteSpace($diskEncryptionStatus)

            if ($isEncrypted) {
                Write-Host "  ✓ Instance '$instance': Encryption ENABLED" -ForegroundColor Green
                $encryptedInstances++
                $encStatus = "Enabled"
            } else {
                Write-Host "  ✗ Instance '$instance': Encryption DISABLED (using Google default encryption)" -ForegroundColor Yellow
                $unencryptedInstances++
                $encStatus = "Google Default"
            }

            $results += [PSCustomObject]@{
                Project = $project
                Instance = $instance
                EncryptionStatus = $encStatus
                KmsKey = if ($diskEncryptionConfig) { $diskEncryptionConfig } else { "N/A" }
            }
        }
    }

    # Summary
    Write-Host ""
    Write-Host "==================================================================="
    Write-Host "SUMMARY"
    Write-Host "==================================================================="
    Write-Host "Total Cloud SQL instances found: $totalInstances"
    Write-Host "Instances with customer-managed encryption: $encryptedInstances" -ForegroundColor Green
    Write-Host "Instances with Google default encryption: $unencryptedInstances" -ForegroundColor Yellow
    Write-Host ""

    # Save to file if requested
    if ($OutputFile -and $results.Count -gt 0) {
        $outputContent = @"
=================================================================
GCP Cloud SQL Encryption at Rest Report
=================================================================
Scan Date: $(Get-Date)
Total Instances: $totalInstances
Customer-Managed Encryption: $encryptedInstances
Google Default Encryption: $unencryptedInstances

=================================================================
DETAILED RESULTS
=================================================================

"@

        foreach ($result in $results) {
            $outputContent += "Project: $($result.Project)`n"
            $outputContent += "  Instance: $($result.Instance)`n"
            $outputContent += "  Encryption: $($result.EncryptionStatus)`n"
            $outputContent += "  KMS Key: $($result.KmsKey)`n"
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
