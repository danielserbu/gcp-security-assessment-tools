# Check Cloud SQL encryption for data at rest

# Retrieve a list of all projects
$projectList = gcloud projects list --format="value(projectId)"

# Iterate through each project
foreach ($project in $projectList) {
    Write-Host "Checking project $project..."

    # Set the current project
    gcloud config set project $project

    # Retrieve a list of Cloud SQL instances in the project
    $instanceList = gcloud sql instances list --format="value(name)"

    # Check encryption status for each instance
    foreach ($instance in $instanceList) {
        $encryptionStatus = gcloud sql instances describe $instance --format="value(settings.dataDiskEncryptionStatus)"

        if ($encryptionStatus -eq "True") {
            Write-Host "Data at rest encryption is enabled for Cloud SQL instance $instance in project $project."
        } else {
            Write-Host "Data at rest encryption is disabled for Cloud SQL instance $instance in project $project."
        }

        # Log encryption status information
        Write-Output "[$project][$instance]: Encryption status = $encryptionStatus"
    }
}