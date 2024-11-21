from googleapiclient import discovery
from google.oauth2 import service_account
import os
import json
import time

# List of permissions to test
permissions = [
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

# Service account credentials
service_account_info = {
    "type": "service_account",
    "project_id": "XXXX",
    "private_key_id": "XXXX",
    "private_key": "XXXX",
    "client_email": "XXXX",
    "client_id": "XXXX",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "XXXXX",
    "universe_domain": "googleapis.com"
}

def test_single_permission(crm_api, project_id, permission):
    try:
        response = crm_api.projects().testIamPermissions(
            resource=project_id,
            body={'permissions': [permission]}
        ).execute()
        
        if 'permissions' in response and response['permissions']:
            return True
        return False
    except Exception as e:
        print(f"Error testing permission {permission}: {str(e)}")
        return False

def main():
    PROJECT_ID = "XXXXXXXXXX"
    print(f"Project ID: {PROJECT_ID}")

    # Save credentials to a temporary file
    with open('temp_sa_key.json', 'w') as f:
        json.dump(service_account_info, f)

    try:
        # Create credentials using service account key file
        credentials = service_account.Credentials.from_service_account_file('temp_sa_key.json')
        
        # Build cloudresourcemanager REST API python object
        crm_api = discovery.build('cloudresourcemanager', 'v1', credentials=credentials)
        
        print("\nTesting permissions one by one:")
        print("-" * 50)
        
        granted_permissions = []
        
        for permission in permissions:
            print(f"Testing permission: {permission}")
            if test_single_permission(crm_api, PROJECT_ID, permission):
                granted_permissions.append(permission)
                print(f"✓ GRANTED: {permission}")
            else:
                print(f"✗ DENIED: {permission}")
            time.sleep(0.5)  # Add small delay to avoid rate limiting
            
        print("\nSummary of Granted Permissions:")
        print("-" * 50)
        if granted_permissions:
            for perm in granted_permissions:
                print(f"- {perm}")
        else:
            print("No permissions were granted.")

    except Exception as e:
        print(f"Error: {e}")
    
    finally:
        # Clean up temporary file
        try:
            os.remove('temp_sa_key.json')
        except:
            pass

if __name__ == "__main__":
    main()
