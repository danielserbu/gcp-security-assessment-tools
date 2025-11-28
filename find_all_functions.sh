#!/bin/bash
#
# GCP Cloud Functions IAM Policy Scanner
# Scans all projects for Cloud Functions and retrieves their IAM policies
#

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Output file
OUTPUT_FILE="cloud_functions_iam_policies_$(date +%Y-%m-%d_%H-%M-%S).txt"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed or not in PATH${NC}"
    echo "Please install the Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with gcloud${NC}"
    echo "Please run: gcloud auth login"
    exit 1
fi

echo "==================================================================="
echo "GCP Cloud Functions IAM Policy Scanner"
echo "==================================================================="
echo "Output file: $OUTPUT_FILE"
echo ""

# Initialize counters
total_projects=0
projects_with_functions=0
total_functions=0

# Get list of projects
echo "Retrieving list of projects..."
projects=$(gcloud projects list --format="value(projectId)" 2>/dev/null)

if [ -z "$projects" ]; then
    echo -e "${YELLOW}No projects found or no access to list projects${NC}"
    exit 0
fi

# Write header to output file
{
    echo "==================================================================="
    echo "GCP Cloud Functions IAM Policy Scan Results"
    echo "Scan Date: $(date)"
    echo "==================================================================="
    echo ""
} > "$OUTPUT_FILE"

# Iterate through projects
for proj in $projects; do
    ((total_projects++))
    echo -e "${GREEN}[*] Scanning project: $proj${NC}"

    # Check if Cloud Functions API is enabled
    enabled=$(gcloud services list --project "$proj" 2>/dev/null | grep "Cloud Functions API" || true)

    if [ -z "$enabled" ]; then
        echo "    Cloud Functions API not enabled, skipping..."
        continue
    fi

    # List functions in the project
    func_list=$(gcloud functions list --quiet --project "$proj" --format="value[separator=','](NAME,REGION)" 2>/dev/null || true)

    if [ -z "$func_list" ]; then
        echo "    No functions found in this project"
        continue
    fi

    ((projects_with_functions++))

    # Process each function
    while IFS= read -r func_region; do
        if [ -z "$func_region" ]; then
            continue
        fi

        func="${func_region%%,*}"
        region="${func_region##*,}"

        echo "    Found function: $func (region: $region)"
        ((total_functions++))

        # Get IAM policy
        ACL=$(gcloud functions get-iam-policy "$func" --project "$proj" --region "$region" 2>/dev/null || echo "ERROR: Failed to get IAM policy")

        # Write to output file
        {
            echo "-------------------------------------------------------------------"
            echo "Project: $proj"
            echo "Function: $func"
            echo "Region: $region"
            echo "IAM Policy:"
            echo "$ACL"
            echo ""
        } >> "$OUTPUT_FILE"

    done <<< "$func_list"

done

# Summary
echo ""
echo "==================================================================="
echo "SCAN COMPLETE"
echo "==================================================================="
echo "Total projects scanned: $total_projects"
echo "Projects with Cloud Functions: $projects_with_functions"
echo "Total functions found: $total_functions"
echo "Results saved to: $OUTPUT_FILE"
echo "==================================================================="

# Append summary to output file
{
    echo "==================================================================="
    echo "SUMMARY"
    echo "==================================================================="
    echo "Total projects scanned: $total_projects"
    echo "Projects with Cloud Functions: $projects_with_functions"
    echo "Total functions found: $total_functions"
} >> "$OUTPUT_FILE"
