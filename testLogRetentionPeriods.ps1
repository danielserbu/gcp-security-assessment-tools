# List projects and check their security log retention periods
$projects = gcloud projects list --format="value(projectId)"

foreach ($project in $projects) {
    # Retrieve the writer identity of the security sink
    $writerIdentity = gcloud logging sinks describe "security" --project=$project --format="value(writer_identity)"

    # Check if the writer identity is a log bucket
    if ($writerIdentity -like "*@logs-gcp.com") {
        # Extract the log bucket name from the writer identity
        $logBucketName = $writerIdentity.Split("@")[0]

        # Retrieve the retention period of the log bucket
        $retentionPeriod = gcloud logging buckets describe $logBucketName --project=$project --format="value(retentionPeriod)"
        Write-Host "Project $project has security log retention period of $retentionPeriod days."
    } else {
        Write-Host "Project $project does not have a log bucket configured for the security sink."
    }
}