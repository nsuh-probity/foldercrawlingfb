# Folder Crawling Fastback Prototype

This repository contains early prototype work for a Fastback folder crawling tool.

## Current Bash Prototype

The current prototype script is located at:      prototypes/bash-packager/package_folder.sh

The script takes a source folder, packages it into a .tar.gz archive, generates a SHA-256 hash file, and stores both outputs in an output/ directory for staging.



BASIC FLOW
------------------
source folder
    ↓
.tar.gz package
    ↓
SHA-256 hash
    ↓
ready to move through a Fastback dataflow as files
------------------


-------------------
Running the Prototype
-------------------
 
Make the script executable:

chmod +x prototypes/bash-packager/package_folder.sh

Run the script with a source folder:

./prototypes/bash-packager/package_folder.sh /path/to/source/folder

Example:

./prototypes/bash-packager/package_folder.sh testProject




Expected outputs:

output/folder_package.tar.gz
output/folder_package_hash.sha256

Verify the Package Hash

After the package is created, verify the SHA-256 hash:

cd output
sha256sum -c folder_package_hash.sha256




Expected result:

folder_package.tar.gz: OK

This confirms that the package still matches its generated hash.




Windows / VS Code Notes

If testing this on Windows using Visual Studio Code, use a Bash-compatible terminal such as Git Bash.

Suggested setup:

Install Git for Windows.
Restart Visual Studio Code.
Open the project folder in VS Code.
Open a new terminal.
Select Git Bash as the terminal profile.
Run the script from Git Bash, not PowerShell.

PowerShell will not run .sh scripts the same way as Bash.