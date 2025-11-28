#!/usr/bin/env python3
"""
GCP IAM Permissions Tester
Tests which IAM permissions a service account has on a specific GCP project.
"""

from googleapiclient import discovery
from google.oauth2 import service_account
import os
import json
import time
import argparse
import sys

# List of permissions to test
DEFAULT_PERMISSIONS = [
    "resourcemanager.projects.get",
    "resourcemanager.projects.getIamPolicy",
    "iam.serviceAccounts.get",
    "iam.serviceAccounts.list",
    "iam.roles.get",
    "iam.roles.list",
    "storage.buckets.list",
    "storage.buckets.get",
    "cloudresourcemanager.projects.getData",
    "custom.permissions.get",
    "compute.instances.list",
    "compute.instances.get",
    "container.clusters.list",
    "container.clusters.get",
    "cloudfunctions.functions.list",
    "cloudfunctions.functions.get",
    "cloudresourcemanager.projects.list",
    "monitoring.timeSeries.list",
    "logging.logs.list",
    "bigquery.datasets.get",
    "storage.objects.list"
]

def test_single_permission(crm_api, project_id, permission):
    """Test a single IAM permission on a project."""
    try:
        response = crm_api.projects().testIamPermissions(
            resource=project_id,
            body={'permissions': [permission]}
        ).execute()

        if 'permissions' in response and response['permissions']:
            return True
        return False
    except Exception as e:
        print(f"Error testing permission {permission}: {str(e)}", file=sys.stderr)
        return False

def main():
    parser = argparse.ArgumentParser(
        description="Test IAM permissions for a GCP service account on a project.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Using service account key file
  python testIamPermissions.py -p my-project-id -k service-account-key.json

  # Using custom permissions list
  python testIamPermissions.py -p my-project-id -k key.json --permissions "storage.buckets.list,compute.instances.list"

  # Save results to file
  python testIamPermissions.py -p my-project-id -k key.json -o results.txt
        """
    )
    parser.add_argument("-p", "--project-id", required=True,
                        help="GCP Project ID to test permissions on")
    parser.add_argument("-k", "--key-file", required=True,
                        help="Path to service account JSON key file")
    parser.add_argument("--permissions",
                        help="Comma-separated list of permissions to test (default: predefined list)")
    parser.add_argument("-o", "--output",
                        help="Output file to save results (optional)")
    parser.add_argument("-q", "--quiet", action="store_true",
                        help="Only show granted permissions")

    args = parser.parse_args()

    # Validate inputs
    if not os.path.isfile(args.key_file):
        print(f"Error: Key file '{args.key_file}' does not exist.", file=sys.stderr)
        sys.exit(1)

    # Load permissions to test
    if args.permissions:
        permissions = [p.strip() for p in args.permissions.split(',')]
    else:
        permissions = DEFAULT_PERMISSIONS

    try:
        # Create credentials using service account key file
        credentials = service_account.Credentials.from_service_account_file(args.key_file)

        # Build cloudresourcemanager REST API python object
        crm_api = discovery.build('cloudresourcemanager', 'v1', credentials=credentials)

        print(f"Project ID: {args.project_id}")
        print(f"Service Account: {credentials.service_account_email}")
        print(f"\nTesting {len(permissions)} permissions...")
        print("-" * 70)

        granted_permissions = []
        denied_permissions = []

        for permission in permissions:
            if not args.quiet:
                print(f"Testing: {permission}", end=" ... ")

            if test_single_permission(crm_api, args.project_id, permission):
                granted_permissions.append(permission)
                if args.quiet:
                    print(f"✓ {permission}")
                else:
                    print("✓ GRANTED")
            else:
                denied_permissions.append(permission)
                if not args.quiet:
                    print("✗ DENIED")

            time.sleep(0.5)  # Add small delay to avoid rate limiting

        # Summary
        print("\n" + "=" * 70)
        print(f"SUMMARY: {len(granted_permissions)} granted, {len(denied_permissions)} denied")
        print("=" * 70)

        if granted_permissions:
            print("\nGranted Permissions:")
            for perm in granted_permissions:
                print(f"  ✓ {perm}")
        else:
            print("\nNo permissions were granted.")

        # Save to file if requested
        if args.output:
            with open(args.output, 'w') as f:
                f.write(f"Project ID: {args.project_id}\n")
                f.write(f"Service Account: {credentials.service_account_email}\n")
                f.write(f"Tested: {len(permissions)} permissions\n")
                f.write(f"Granted: {len(granted_permissions)} permissions\n")
                f.write(f"Denied: {len(denied_permissions)} permissions\n\n")
                f.write("Granted Permissions:\n")
                for perm in granted_permissions:
                    f.write(f"  {perm}\n")
                f.write("\nDenied Permissions:\n")
                for perm in denied_permissions:
                    f.write(f"  {perm}\n")
            print(f"\nResults saved to: {args.output}")

    except FileNotFoundError:
        print(f"Error: Service account key file not found: {args.key_file}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in key file: {args.key_file}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
