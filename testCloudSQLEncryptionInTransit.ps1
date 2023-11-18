# Check Cloud SQL encryption for data in transit

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
        $requireSsl = gcloud sql instances describe $instance --format="value(settings.ipConfiguration.requireSsl)"
        Write-Host "$instance in project $project requires SSL encryption: $requireSsl"
    }
}