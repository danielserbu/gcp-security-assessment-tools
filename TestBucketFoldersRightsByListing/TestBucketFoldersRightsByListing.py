import os
import subprocess
import time
import colorama
from colorama import Fore, Back, Style
import argparse

colorama.init(autoreset = True)

parser = argparse.ArgumentParser(description="GCP Bucket Write and Deletion rights tester.")
parser.add_argument("-iF", "--bucketfolderslist", help="Bucket Folders List. Default is listOfOpenBuckets.txt", default="listOfOpenBuckets.txt")
parser.add_argument("-tF", "--testfile", help="Test file used for upload. Default is testfile", default="testfile")
args = parser.parse_args()
bucketFoldersFile = args.bucketfolderslist
testFile = args.testfile

if not os.path.isfile(testFile):
    print("File to be uploaded does not exist.")
    print("Exiting.. ")
    exit()

buckets = open(bucketFoldersFile).read().splitlines()
# Check if buckets in list are badly formated: e.g if they have more than 2 //
for bucket in buckets:
    if bucket.count('/') > 3:
        print("One or more elements in input list are badly formatted.")
        print("Exiting.. ")
        exit()
outputFolder = "output"
runTime = time.strftime("%Y-%m-%d--%H-%M")
writeVulnerableBucketsAndFoldersOutputPath = outputFolder + "/OutputWriteVulnerableBucketsAndFolders-" + runTime + ".txt"
deleteVulnerableBucketsAndFoldersOutputPath = outputFolder + "/OutputDeleteVulnerableBucketsAndFolders-" + runTime + ".txt"
# These lists are populated and cleared for each bucket.
folders_already_listed = []
write_vulnerable_folders = []
delete_vulnerable_folders = []

print(Fore.CYAN + Style.BRIGHT + "Started testing buckets for write and delete rights" + '\n', end='')

# Functions
def list_folders_in_bucket_folder(bucketFolder):
    print("Listing bucket folder " + bucketFolder)
    process = subprocess.Popen("gsutil ls " + bucketFolder, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=True)
    stderroutput = ''
    stdoutput = ''
    while True:
        stderroutput += process.stderr.read()
        stdoutput += process.stdout.read()
        if process.stderr.read() == '' and process.poll() != None:
            break
    if "AccessDeniedException: 403" and "does not have storage.objects.list access" in stderroutput:
        print(Fore.YELLOW + Style.BRIGHT + "[?] " + bucketFolder + " is not listable!")
        return "Not listable"
    filesAndFolders = stdoutput.splitlines()
    folders = []
    try:
        # select only folders (remove files from list)
        for item in filesAndFolders:
            if item[-1] == '/':
                folders.append(item)
    except Exception as e:
        print("Exception")
    return folders

def list_subfolders_from_list_of_folders(list_of_folders):
    items = []
    for folder in list_of_folders:
        if folder not in folders_already_listed:
            new_items = list_folders_in_bucket_folder(folder)
            folders_already_listed.append(folder)
            items.extend(new_items)
    return items

def list_all_subfolders_in_bucket(list_of_folders):
    items = []
    new_items = list_subfolders_from_list_of_folders(list_of_folders)
    if len(new_items) != 0:
        items.extend(new_items)
        # Explore all subfolders
        while True:
            new_items = list_subfolders_from_list_of_folders(new_items)
            if len(new_items) == 0:
                break
            elif len(new_items) != 0:
                items.extend(new_items)
    return items

def test_delete_rights_in_bucket_folder(folder):
    print(Style.BRIGHT + "Testing delete rights for folder " + folder)
    testFilePath = folder + testFile
    process = subprocess.Popen("gsutil rm " + testFilePath, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=True)
    output = ''
    while True:
        output += process.stderr.read()
        if process.stderr.read() == '' and process.poll() != None:
            break
    vulnerableStatus = False
    if "AccessDeniedException: 403" and "does not have storage.objects.delete access" not in output:
        print(Fore.RED + Style.BRIGHT + "[!!!] " + folder + " is vulnerable to deletion!")
        vulnerableStatus = True
    else:
        print(Fore.GREEN + Style.BRIGHT + "[OK] " + folder + " is NOT vulnerable to deletion!")
        vulnerableStatus = False
    return vulnerableStatus
        
def test_write_rights_in_bucket_folder(folder):
    print("---------------------------------------")
    print(Style.BRIGHT + "Testing write rights for folder " + folder)
    process = subprocess.Popen("gsutil cp " + testFile + " " + folder, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=True)
    output = ''
    while True:
        output += process.stderr.read()
        if process.stderr.read() == '' and process.poll() != None:
            break
    writeVulnerableStatus = False
    deleteVulnerableStatus = False
    if "Operation completed over 1 objects" in output:
        print(Fore.RED + Style.BRIGHT + "[!!!] " + folder + " is vulnerable to writing!")
        writeVulnerableStatus = True
        # Since we could write the test file, now test for delete rights (storage.objects.delete access)
        deleteVulnerableStatus = test_delete_rights_in_bucket_folder(folder)
    elif "Copying file" and "AccessDeniedException: 403" and "does not have storage.objects.delete access" in output:
        print(Fore.YELLOW + Style.BRIGHT + "[?] The file you are trying to write is already inside the bucket and you don't have delete rights!")
    else:
        print(Fore.GREEN + Style.BRIGHT + "[OK] " + folder + " is NOT vulnerable to writing!")
        print("Skipping deletion test.")
        writeVulnerableStatus = False
    return writeVulnerableStatus, deleteVulnerableStatus   

def write_folder_list_to_output_file(folderList, outputFile):
    with open(outputFile, "a") as file:
        for folder in folderList:
            file.writelines(folder + '\n')
# Functions

# Do work 
for bucket in buckets:
    print("========================================")
    print(Fore.CYAN + Style.BRIGHT + "Assessing bucket: " + bucket + '\n', end='')
    print("Listing bucket folders..")
    all_discovered_folders_in_bucket = []
    # In case buckets inside input file don't have /'s at the end.
    if bucket[-1] != '/':
        bucket = bucket + '/'
    # Start with clear lists.
    folders_already_listed.clear()
    write_vulnerable_folders.clear()
    delete_vulnerable_folders.clear()
    # List folders in bucket
    items = list_folders_in_bucket_folder(bucket)
    # If bucket is not listable, move on.
    if items == "Not listable":
        continue
    folders_already_listed.append(bucket)
    all_discovered_folders_in_bucket.extend(items)
    # Continue listing subfolders
    new_items = list_all_subfolders_in_bucket(items)
    all_discovered_folders_in_bucket.extend(new_items)
    unique_folders = list(set(all_discovered_folders_in_bucket))
    unique_folders.append(bucket)
    # Test write and delete rights on subfolders
    for folder in unique_folders:
        writeVulnerableStatus, deleteVulnerableStatus = test_write_rights_in_bucket_folder(folder)
        if writeVulnerableStatus:
            write_vulnerable_folders.append(folder)
        if deleteVulnerableStatus:
            delete_vulnerable_folders.append(folder)

    # Write vulnerable paths to output files 
    write_folder_list_to_output_file(write_vulnerable_folders, writeVulnerableBucketsAndFoldersOutputPath)
    write_folder_list_to_output_file(delete_vulnerable_folders, deleteVulnerableBucketsAndFoldersOutputPath)
    
print("Done")
print("Make sure to check output folder in case anything has been found.")