import os
import subprocess
import time
import colorama
from colorama import Fore, Back, Style
import argparse

colorama.init(autoreset = True)

parser = argparse.ArgumentParser(description="GCP Bucket Write and Deletion rights tester.")
parser.add_argument("-iF", "--bucketfolderslist", help="Bucket Folders List. Default is FoldersList.txt", default="FoldersList.txt")
parser.add_argument("-tF", "--testfile", help="Test file used for upload. Default is testfile", default="testfile")
args = parser.parse_args()
bucketFoldersFile = args.bucketfolderslist
testFile = args.testfile

if not os.path.isfile(testFile):
    print("File to be uploaded does not exist.")
    print("Exiting.. ")
    exit()

folders = open(bucketFoldersFile).read().splitlines()

for folder in folders:
    if folder.endswith("/") is False:
        print("Error at path: " + folder)
        print("File in folders list.")
        print("Please remove the file or add / at the end in case it is a folder.")
        print("Exiting.. ")
        exit()
    elif folder.startswith("gs://") is False:
        print("Error at path: " + folder)
        print("Folder is not a google cloud bucket folder.")
        print("Please format the file accordingly with elements starting with gs://")
        print("Exiting.. ")
        exit()

#In case folders are duplicate inside input file.
unique_folders = list(set(folders))

outputFolder = "output"
runTime = time.strftime("%Y-%m-%d--%H-%M")
writeVulnerableBucketsAndFoldersOutputPath = outputFolder + "/OutputWriteVulnerableBucketsAndFolders-" + runTime + ".txt"
deleteVulnerableBucketsAndFoldersOutputPath = outputFolder + "/OutputDeleteVulnerableBucketsAndFolders-" + runTime + ".txt"

write_vulnerable_folders = []
delete_vulnerable_folders = []

print(Fore.CYAN + Style.BRIGHT + "Started testing bucket folders for write and delete rights" + '\n', end='')

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
            
# Do work 
for folder in unique_folders:
    print("========================================")
    print(Fore.CYAN + Style.BRIGHT + "Assessing bucket folder: " + folder + '\n', end='')
    # Start with clear lists.
    write_vulnerable_folders.clear()
    delete_vulnerable_folders.clear()
    
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
