#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks log retention periods for GCP projects.

.DESCRIPTION
    This script scans GCP projects and checks the retention periods configured
    for logging sinks and log buckets to ensure compliance with retention policies.

.PARAMETER OutputFile
    Optional file path to save results

.PARAMETER ProjectId
    Optional specific project ID to check (instead of all projects)

.PARAMETER SinkName
    Name of the sink to check (default: "_Default")

.EXAMPLE
    .\testLogRetentionPeriods.ps1

.EXAMPLE
    .\testLogRetentionPeriods.ps1 -OutputFile "retention_report.txt"

.EXAMPLE
    .\testLogRetentionPeriods.ps1 -ProjectId "my-project-123" -SinkName "_Default"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputFile,

    [Parameter(Mandatory=$false)]
    [string]$ProjectId,

    [Parameter(Mandatory=$false)]
    [string]$SinkName = "_Default"
)

# Check if gcloud is installed
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Error "gcloud CLI is not installed or not in PATH"
    Write-Host "Please install the Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    exit 1
}

Write-Host "==================================================================="
Write-Host "GCP Log Retention Periods Checker"
Write-Host "==================================================================="
Write-Host "Sink Name: $SinkName"
Write-Host ""

# Store current project to restore later
$originalProject = gcloud config get-value project 2>$null

$results = @()
$totalProjects = 0
$projectsWithSinks = 0

try {
    # Get list of projects
    if ($ProjectId) {
        $projects = @($ProjectId)
        Write-Host "Checking specific project: $ProjectId"
    } else {
        Write-Host "Retrieving list of projects..."
        $projects = gcloud projects list --format="value(projectId)" 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to list projects. Please check your permissions."
            exit 1
        }
    }

    Write-Host ""

    foreach ($project in $projects) {
        if ([string]::IsNullOrWhiteSpace($project)) {
            continue
        }

        $totalProjects++
        Write-Host "Checking project: $project" -ForegroundColor Cyan

        # Set the current project
        $null = gcloud config set project $project 2>&1

        # Try to get the default log bucket retention
        $bucketRetention = gcloud logging buckets describe _Default --location=global --format="value(retentionDays)" 2>&1

        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($bucketRetention)) {
            Write-Host "  Default log bucket retention: $bucketRetention days" -ForegroundColor Green
            $projectsWithSinks++

            $results += [PSCustomObject]@{
                Project = $project
                BucketName = "_Default"
                RetentionDays = $bucketRetention
                Status = "Configured"
            }
        } else {
            Write-Host "  No default log bucket found or unable to retrieve retention" -ForegroundColor Yellow

            $results += [PSCustomObject]@{
                Project = $project
                BucketName = "_Default"
                RetentionDays = "N/A"
                Status = "Not Found"
            }
        }

        # Check for custom log buckets
        $customBuckets = gcloud logging buckets list --location=global --format="value(name)" 2>&1

        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($customBuckets)) {
            foreach ($bucket in $customBuckets) {
                if ($bucket -eq "_Default" -or [string]::IsNullOrWhiteSpace($bucket)) {
                    continue
                }

                $retention = gcloud logging buckets describe $bucket --location=global --format="value(retentionDays)" 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  Custom bucket '$bucket' retention: $retention days" -ForegroundColor Cyan

                    $results += [PSCustomObject]@{
                        Project = $project
                        BucketName = $bucket
                        RetentionDays = $retention
                        Status = "Configured"
                    }
                }
            }
        }
    }

    # Summary
    Write-Host ""
    Write-Host "==================================================================="
    Write-Host "SUMMARY"
    Write-Host "==================================================================="
    Write-Host "Total projects checked: $totalProjects"
    Write-Host "Projects with log buckets: $projectsWithSinks"
    Write-Host ""

    # Save to file if requested
    if ($OutputFile -and $results.Count -gt 0) {
        $outputContent = @"
=================================================================
GCP Log Retention Periods Report
=================================================================
Scan Date: $(Get-Date)
Total Projects: $totalProjects
Projects with Log Buckets: $projectsWithSinks

=================================================================
DETAILED RESULTS
=================================================================

"@

        foreach ($result in $results) {
            $outputContent += "Project: $($result.Project)`n"
            $outputContent += "  Bucket: $($result.BucketName)`n"
            $outputContent += "  Retention: $($result.RetentionDays) days`n"
            $outputContent += "  Status: $($result.Status)`n"
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
