#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Identifies guest accounts (external users) in a GCP organization and lists their roles.

.DESCRIPTION
    This script scans a GCP organization's IAM policy to identify members from
    outside the organization domain (guest accounts) and reports their assigned roles.

.PARAMETER OrgId
    The GCP Organization ID to scan (required)

.PARAMETER OutputFile
    Optional file path to save results

.EXAMPLE
    .\TestGuestAccountsPermissions.ps1 -OrgId "123456789012"

.EXAMPLE
    .\TestGuestAccountsPermissions.ps1 -OrgId "123456789012" -OutputFile "guest_accounts.txt"
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the GCP Organization ID")]
    [string]$OrgId,

    [Parameter(Mandatory=$false)]
    [string]$OutputFile
)

# Check if gcloud is installed
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Error "gcloud CLI is not installed or not in PATH"
    Write-Host "Please install the Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    exit 1
}

Write-Host "==================================================================="
Write-Host "GCP Guest Accounts Scanner"
Write-Host "==================================================================="
Write-Host "Organization ID: $OrgId"
Write-Host ""

try {
    # Get the organization domain
    Write-Host "Retrieving organization domain..."
    $orgDomain = gcloud organizations describe $OrgId --format="value(domain)" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to describe organization $OrgId. Please check the Organization ID and your permissions."
        exit 1
    }

    Write-Host "Organization domain: $orgDomain"
    Write-Host ""

    # Get a list of all IAM members in the organization
    Write-Host "Retrieving IAM policy for organization..."
    $members = gcloud organizations get-iam-policy $OrgId --flatten="bindings[].members" --format="value(bindings.members)" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get IAM policy for organization $OrgId"
        exit 1
    }

    $guestAccounts = @()
    $guestCount = 0

    Write-Host "Analyzing IAM members..."
    Write-Host ""

    # Loop through each member and check if it's a guest account
    foreach ($member in $members) {
        # Skip service accounts and special members
        if ($member -like "serviceAccount:*" -or $member -like "domain:*" -or [string]::IsNullOrWhiteSpace($member)) {
            continue
        }

        # Check if the member email address doesn't contain the organization domain
        if ($member -notlike "*@$orgDomain") {
            $guestCount++

            # Get the member's roles
            $roles = gcloud organizations get-iam-policy $OrgId --flatten="bindings[].role" --filter="bindings.members:$member" --format="value(bindings.role)" 2>&1

            $guestInfo = [PSCustomObject]@{
                Account = $member
                Roles = ($roles -join ", ")
            }

            $guestAccounts += $guestInfo

            Write-Host "Guest account found: $member" -ForegroundColor Yellow
            Write-Host "  Roles: $($guestInfo.Roles)" -ForegroundColor Cyan
            Write-Host ""
        }
    }

    # Summary
    Write-Host "==================================================================="
    Write-Host "SUMMARY"
    Write-Host "==================================================================="
    Write-Host "Total guest accounts found: $guestCount"
    Write-Host ""

    # Save to file if requested
    if ($OutputFile) {
        $outputContent = @"
=================================================================
GCP Guest Accounts Report
=================================================================
Organization ID: $OrgId
Organization Domain: $orgDomain
Scan Date: $(Get-Date)
Total Guest Accounts: $guestCount

=================================================================
GUEST ACCOUNTS
=================================================================

"@

        foreach ($guest in $guestAccounts) {
            $outputContent += "Account: $($guest.Account)`n"
            $outputContent += "Roles: $($guest.Roles)`n"
            $outputContent += "`n"
        }

        $outputContent | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "Results saved to: $OutputFile" -ForegroundColor Green
    }

    if ($guestCount -eq 0) {
        Write-Host "No guest accounts found in organization $OrgId" -ForegroundColor Green
    }

} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
