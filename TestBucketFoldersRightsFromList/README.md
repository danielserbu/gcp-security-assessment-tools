# TestBucketFoldersRightsFromList

## Description

This script tests write and delete permissions for a list of Google Cloud Storage (GCS) bucket folders. It attempts to write a test file to each folder and then checks if the file can be deleted. The script provides detailed output to the user and writes the results to output files.

## Usage

```bash
python3 TestBucketFoldersRightsFromList.py [OPTIONS]


## Options

* `-iF` or `--bucketfolderslist`: Path to the input file containing a list of bucket folders, one per line. Default: `FoldersList.txt`
* `-tF` or `--testfile`: Path to the test file to upload. Default: `testfile`

## Example Usage

bash
python3 TestBucketFoldersRightsFromList.py
python3 TestBucketFoldersRightsFromList.py -iF /path/to/input.txt -tF /path/to/testfile.txt


## Output

The script generates two output files in the `output` directory:

* `OutputWriteVulnerableBucketsAndFolders-<timestamp>.txt`: Lists bucket folders with write vulnerabilities
* `OutputDeleteVulnerableBucketsAndFolders-<timestamp>.txt`: Lists bucket folders with delete vulnerabilities

## Requirements

* `gsutil` tool installed and configured
* Authentication with Google Cloud Platform (GCP) using `gcloud`

## Notes

* If a write test is successful but the deletion test fails, you will need to manually clean up the test files from the GCS console or using `gsutil`.
* If a file already exists in a bucket folder and you don't have delete permissions, the write test may not report accurate results.
* If a write test fails, the deletion test will not be performed.

## Demo

[GIF demo of script usage](demo.gif)