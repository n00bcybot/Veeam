# Overview

## Task

Create a script that syncronizes two folders: source and replica. The script should maintain s full, identical copy of the source folder at the replica folder using PowerShell.

## Conditions

- syncronization must be one way: after the syncronization, the content of the replica folder should be modified to eaxactly match the content   of the source folder
- file creation/copy/removal should be logged to a file and to the console
- folder path and log file path should be provided using command line arguments
- no robocopy or similar tools allowed


# Approach and considerations

To achieve the goal, the main function starts with creating a list of all files located in the source folder, itterating over it and checking each file if it exsists in the backup folder. If it doesn't, it copies it to the backup folder and moves on to the next file in the list. If it does exist, it checks wheter the file in the backup folder is older thatn the one in the source folder and ovewrites it, if it is. All this is done inside another loop, which initiates after certain amount of time has passed, which can be set via argument when the script is initialized. Also within this loop, a couple of other script blocks are run and can be invoked with optional parameters - an extra verification of the content of both folders and log export to JSON.

The script assumes that the backup folder has already been created, before it is run. The folder paths are provided as arguments and are mandatory.
If any of the paths is incorrect or not a folder, the script will terminate. For itterating over the list entries, originally ForEach-Object was used, with -Parallel switch, which should have provided faster itteration than ForEach loop, which works sequentially. ForEach-Object works in a separate runspace, which intrduces complications with the data flow and it will only make sense in a case of solving problem of higher complexity and a large amount of files in the source folder, therefore ForEach loop has been used in the final version. Threading and Jobs would be another approach. For the main loop, a do-until loophas been used, but same result can be accomplished with other loops, like while loop, depending on the desired result and condition. In this case, the loop will break when the given time has been reached. The time interval is set in seconds, but can be changed to hours or days, depending on the need. Both -Endtime and -Interval parameters are not mandatory and if not set, the script will run pnly once. The -Interval parameter has default value of 10 seconds. The -OutJSON switch will create JSON file from $LogObjects variable. $LogObjects is fed by the Log-Object function which creates custom object with time stamp, file, operation and folders involved. This provides ease of use if the log is to be used further down the line, by some application or with another programming language and the JSON file can easily be imported back as object in PowerShell, unlike the simple log, which is not as easy to parse.

Certain blocks from the sript have been isolated into functions for better logical readability. The logic will work just as well as one continuous script. The code in the main function can be stripped from the function while preserving the parameters, so that the ps1 file itself can be called with parameters, which can be more convenient, depending on the case.