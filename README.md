# GCP Security Assessment Tools

A comprehensive collection of security assessment tools for Google Cloud Platform (GCP). These tools help identify security vulnerabilities, misconfigurations, and compliance issues across GCP resources.

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Tools Overview](#tools-overview)
- [Usage Examples](#usage-examples)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

## Features

- **IAM Permission Testing**: Test and enumerate IAM permissions for service accounts
- **GCS Bucket Security**: Identify write/delete vulnerabilities in Cloud Storage buckets
- **Cloud SQL Auditing**: Check encryption at rest and in transit for Cloud SQL instances
- **Guest Account Detection**: Identify external users in your GCP organization
- **Cloud Functions Analysis**: Discover Cloud Functions and their IAM policies
- **Log Retention Auditing**: Verify log retention compliance across projects

## Prerequisites

### Required Tools
- **Python 3.7+** (for Python scripts)
- **Google Cloud SDK** (gcloud CLI) - [Install Guide](https://cloud.google.com/sdk/docs/install)
- **PowerShell 7+** (for .ps1 scripts on Linux/macOS) - [Install Guide](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)

### GCP Authentication
Before using these tools, authenticate with GCP:
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/danielserbu/gcp-security-assessment-tools.git
   cd gcp-security-assessment-tools
   ```

2. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Make shell scripts executable:**
   ```bash
   chmod +x find_all_functions.sh
   ```

4. **Verify gcloud installation:**
   ```bash
   gcloud --version
   gsutil --version
   ```

## Tools Overview

### 1. IAM Permissions Tester (`testIamPermissions.py`)
Tests which IAM permissions a service account has on a GCP project.

**Features:**
- Tests 21+ common GCP permissions
- Custom permission list support
- Results export to file
- Detailed permission reporting

**Usage:**
```bash
# Basic usage
python testIamPermissions.py -p PROJECT_ID -k service-account-key.json

# Save results to file
python testIamPermissions.py -p PROJECT_ID -k key.json -o results.txt

# Test specific permissions
python testIamPermissions.py -p PROJECT_ID -k key.json --permissions "storage.buckets.list,compute.instances.list"

# Quiet mode (only show granted permissions)
python testIamPermissions.py -p PROJECT_ID -k key.json -q
```

### 2. Bucket Folder Rights Tester (By Listing)
Recursively discovers all subfolders in GCS buckets and tests write/delete permissions.

**Location:** `TestBucketFoldersRightsByListing/`

**Usage:**
```bash
cd TestBucketFoldersRightsByListing

# Install dependencies
pip install -r requirements.txt

# Run with default input file (listOfOpenBuckets.txt)
python TestBucketFoldersRightsByListing.py

# Use custom input and test files
python TestBucketFoldersRightsByListing.py -iF my-buckets.txt -tF my-test-file
```

**Input File Format (listOfOpenBuckets.txt):**
```
gs://bucket-name-1/
gs://bucket-name-2/
gs://bucket-name-3/folder/
```

**Output:**
- `output/OutputWriteVulnerableBucketsAndFolders-TIMESTAMP.txt`
- `output/OutputDeleteVulnerableBucketsAndFolders-TIMESTAMP.txt`

### 3. Bucket Folder Rights Tester (From List)
Tests write/delete permissions on a pre-defined list of GCS folders (no recursive listing).

**Location:** `TestBucketFoldersRightsFromList/`

**Usage:**
```bash
cd TestBucketFoldersRightsFromList

# Install dependencies
pip install -r requirements.txt

# Run with default input file (FoldersList.txt)
python TestBucketFoldersRightsFromList.py

# Use custom input
python TestBucketFoldersRightsFromList.py -iF my-folders.txt
```

**Input File Format (FoldersList.txt):**
```
gs://bucket/folder1/
gs://bucket/folder2/subfolder/
gs://another-bucket/data/
```

**Note:** All paths must end with `/` and start with `gs://`

### 4. Cloud Functions IAM Policy Scanner (`find_all_functions.sh`)
Scans all projects for Cloud Functions and retrieves their IAM policies.

**Usage:**
```bash
./find_all_functions.sh
```

**Output:**
- Console output with colored status
- `cloud_functions_iam_policies_TIMESTAMP.txt` with detailed results

### 5. Guest Accounts Permissions Checker (`TestGuestAccountsPermissions.ps1`)
Identifies external users (guest accounts) in your GCP organization.

**Usage:**
```bash
# Linux/macOS
pwsh TestGuestAccountsPermissions.ps1 -OrgId "123456789012"

# Windows
.\TestGuestAccountsPermissions.ps1 -OrgId "123456789012"

# Save to file
pwsh TestGuestAccountsPermissions.ps1 -OrgId "123456789012" -OutputFile "guests.txt"
```

### 6. Cloud SQL Encryption at Rest Checker (`testCloudSQLEncryptionAtRest.ps1`)
Checks if Cloud SQL instances have customer-managed encryption keys.

**Usage:**
```bash
# Check all projects
pwsh testCloudSQLEncryptionAtRest.ps1

# Check specific project
pwsh testCloudSQLEncryptionAtRest.ps1 -ProjectId "my-project"

# Save results
pwsh testCloudSQLEncryptionAtRest.ps1 -OutputFile "encryption-report.txt"
```

### 7. Cloud SQL Encryption in Transit Checker (`testCloudSQLEncryptionInTransit.ps1`)
Verifies that Cloud SQL instances require SSL/TLS for connections.

**Usage:**
```bash
# Check all projects
pwsh testCloudSQLEncryptionInTransit.ps1

# Check specific project
pwsh testCloudSQLEncryptionInTransit.ps1 -ProjectId "my-project"

# Save results
pwsh testCloudSQLEncryptionInTransit.ps1 -OutputFile "ssl-report.txt"
```

### 8. Log Retention Periods Checker (`testLogRetentionPeriods.ps1`)
Audits log retention periods across GCP projects.

**Usage:**
```bash
# Check all projects
pwsh testLogRetentionPeriods.ps1

# Check specific project
pwsh testLogRetentionPeriods.ps1 -ProjectId "my-project"

# Save results
pwsh testLogRetentionPeriods.ps1 -OutputFile "retention-report.txt"
```

## Usage Examples

### Example 1: Complete Security Audit Workflow

```bash
# 1. Test IAM permissions
python testIamPermissions.py -p my-project -k service-account.json -o iam-results.txt

# 2. Scan Cloud Functions
./find_all_functions.sh > functions-scan.log

# 3. Check Cloud SQL encryption
pwsh testCloudSQLEncryptionAtRest.ps1 -OutputFile sql-encryption.txt
pwsh testCloudSQLEncryptionInTransit.ps1 -OutputFile sql-ssl.txt

# 4. Check for guest accounts
pwsh TestGuestAccountsPermissions.ps1 -OrgId "123456789012" -OutputFile guests.txt

# 5. Test bucket permissions
cd TestBucketFoldersRightsByListing
python TestBucketFoldersRightsByListing.py
```

### Example 2: Testing Specific GCS Buckets

```bash
# Create a list of buckets to test
echo "gs://public-bucket-1/" > buckets-to-test.txt
echo "gs://public-bucket-2/" >> buckets-to-test.txt

# Test with recursive listing
cd TestBucketFoldersRightsByListing
python TestBucketFoldersRightsByListing.py -iF ../buckets-to-test.txt

# Check the results
cat output/OutputWriteVulnerableBucketsAndFolders-*.txt
```

### Example 3: Organization-Wide Assessment

```bash
# 1. Get organization ID
ORG_ID=$(gcloud organizations list --format="value(ID)")

# 2. Check guest accounts
pwsh TestGuestAccountsPermissions.ps1 -OrgId "$ORG_ID" -OutputFile org-guests.txt

# 3. Check all Cloud SQL instances
pwsh testCloudSQLEncryptionAtRest.ps1 -OutputFile org-sql-encryption.txt
pwsh testCloudSQLEncryptionInTransit.ps1 -OutputFile org-sql-ssl.txt

# 4. Check log retention
pwsh testLogRetentionPeriods.ps1 -OutputFile org-log-retention.txt
```

## Security Considerations

### Authorization
These tools are designed for **authorized security assessments only**. Ensure you have:
- Proper authorization to scan GCP resources
- Appropriate IAM permissions for the assessments
- Documented approval for penetration testing activities

### Required Permissions

**For IAM Testing:**
- `resourcemanager.projects.testIamPermissions`

**For Bucket Testing:**
- `storage.objects.list` (for recursive listing)
- `storage.objects.create` (to test write access)
- `storage.objects.delete` (to test delete access)

**For Cloud Functions:**
- `cloudfunctions.functions.list`
- `cloudfunctions.functions.getIamPolicy`

**For Cloud SQL:**
- `cloudsql.instances.list`
- `cloudsql.instances.get`

**For Organization Audits:**
- `resourcemanager.organizations.get`
- `resourcemanager.organizations.getIamPolicy`

### Best Practices

1. **Use Read-Only Service Accounts**: When possible, use service accounts with minimal permissions
2. **Log All Activities**: Keep audit logs of all security assessment activities
3. **Clean Up Test Files**: The bucket testing tools upload test files - ensure these are cleaned up
4. **Secure Credentials**: Never commit service account keys to version control
5. **Review Before Running**: Understand what each tool does before running it in production

## Troubleshooting

### Common Issues

**"gcloud: command not found"**
```bash
# Install Google Cloud SDK
# https://cloud.google.com/sdk/docs/install
```

**"Permission denied" errors**
```bash
# Ensure you're authenticated
gcloud auth login

# Check current account
gcloud auth list

# Check project permissions
gcloud projects get-iam-policy PROJECT_ID
```

**"Module not found" errors**
```bash
# Install Python dependencies
pip install -r requirements.txt

# Or install specific packages
pip install google-api-python-client google-auth colorama
```

**PowerShell scripts not running**
```bash
# Install PowerShell on Linux/macOS
# https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell
```

**Bucket testing hangs**
- The tools may slow down with very large buckets
- Use `TestBucketFoldersRightsFromList` for specific folders instead
- Consider testing buckets in smaller batches

## Output Files

All tools generate timestamped output files to avoid overwriting previous results:

- IAM Results: `results.txt` (or custom name)
- Bucket Vulnerabilities: `output/OutputWriteVulnerableBucketsAndFolders-YYYY-MM-DD--HH-MM.txt`
- Delete Vulnerabilities: `output/OutputDeleteVulnerableBucketsAndFolders-YYYY-MM-DD--HH-MM.txt`
- Functions Scan: `cloud_functions_iam_policies_YYYY-MM-DD_HH-MM-SS.txt`
- SQL/Guest/Log Reports: Custom names specified with `-OutputFile`

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Daniel Serbu**

## Disclaimer

These tools are provided for authorized security testing purposes only. The authors are not responsible for misuse or damage caused by these tools. Always obtain proper authorization before conducting security assessments.

## Changelog

### Version 2.0 (2025)
- Fixed critical boolean logic bugs in bucket testing scripts
- Improved error handling across all scripts
- Added command-line argument support to all tools
- Enhanced PowerShell scripts with proper parameter handling
- Added comprehensive documentation and usage examples
- Improved output formatting and file handling
- Added dependency checks and validation
- Fixed subprocess handling issues

### Version 1.0 (2023)
- Initial release
- Basic security assessment tools for GCP
