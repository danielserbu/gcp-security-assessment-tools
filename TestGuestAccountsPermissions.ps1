# Set the organization ID
$orgId = "COMPLETE"

# Get the organization domain
$orgDomain = (gcloud organizations describe $orgId --format="value(domain)")

# Get a list of all IAM members in the organization
$members = gcloud organizations get-iam-policy $orgId --flatten="bindings[].members" --format="value(bindings.members)"

# Loop through each member and check if it's a guest account
foreach ($member in $members) {
    # Check if the member email address doesn't contain the organization domain
    if ($member -notlike "*@$orgDomain") {
        # Get the member's roles and print them
        $roles = gcloud organizations get-iam-policy $orgId --flatten="bindings[?members.contains('$member')].role" --format="value(bindings.role)"
        Write-Host "Guest account: $member"
        Write-Host "Roles: $roles"
    }
}