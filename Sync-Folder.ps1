<#
.SYNOPSIS
        Syncronises the content of a given folder to another folder

.DESCRIPTION
        This function syncronyzes the content of a given folder to another folder. It has five paramters, three of which are mandatory, for the
    folders paths, one optional parameter to define at what interval the function should run in seconds (the default is 10 seconds), and one 
    optional parameter with which a time argument can be provided (hour and minute in the format "HH:mm") if the function should stop running
    at specific time in the same day. 
        The function starts by getting a list of all files in the source folder and checks if the same file exists in the backup folder. 
    If it doesn't, it copies it and if it does exist, checks if the file has been modified at earler date than the corresponding file in the 
    source folder and if so, overwrites it. All operations are output to console and a log file with a time stamp, as well as the file names 
    and folder paths.
     
.NOTES
        For itteration over the files in the source folder, the function uses parallel processing with "ForEach-Object -Parallel", since this is a
    simple way to speed up this process. For a folder containing large number of files, multiprocessing solution with PowerShell jobs might be 
    more suitable. "ForEach-Object -Parallel" executes in a different runspace than the current one, therefore "using" is used to import the 
    variables. 
        The functions assumes that the back folder has already been created and does not check if it contains files that are not found
    in the source folder.
        Wait-Process ensures that only one process at a time has been recorded in the log and  
        Certainly different conditional logic can be used in the "until" section of the do-until loop, depending on specific use, or different
    loop could be used altogether.
        If more convinient, the script can be stripped from the function, while keeping the parameters, so that the ps1 file itself can be run
    from the command line, instead of the code, and still accept arguments.
        More fail save blocks can be added, as well as console inputs for more granular control, depending on the usecase.

.EXAMPLE

    Example 1: Sync-Folder -SourceFolder "C:\source" -BackupFolder "C:\backup" -LogFolder "C:\Logs"

    Example 2: Sync-Folder -SourceFolder "C:\source" -BackupFolder "C:\backup" -LogFolder "C:\Logs" -Interval 230 -EndTime "15:44"
#>


function Sync-Folder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$SourceFolder,
        [Parameter(Mandatory=$true)][string]$BackupFolder,
        [Parameter(Mandatory=$true)][string]$LogFolder,
        [Parameter(Mandatory=$false)][int]$Interval = 10,
        [Parameter(Mandatory=$false)][string]$EndTime,
        [switch]$Verify
    )

    # Check if the paths exist and indeed point to a folder
    $paths = $SourceFolder, $BackupFolder, $LogFolder
    foreach ($item in $paths) {
        if ( !(Test-Path -Path $item) -or !(Test-Path -Path $item -PathType Container) ){
            Write-Output "Folder $item doesn't exsist or provied path is not a folder"
            break
        }else {
            
            $LogPath = "$LogFolder" + "\" + "activities.log"
                        
            do {
                $source_list = Get-ChildItem -Path $SourceFolder
                $date = Get-Date

                $output = "###   $date" +  " ###  New log started at $LogPath  ###" +
                "`n###--------------------------------------------------------------------------------------------------------###`n" 

                Write-Output $output
                $output | Out-File -Append -FilePath $LogPath | Wait-Process 

                # Check if each file in the source folder exists in the backup folder already. Using "parallel" switch for faster processing.
                # ForEach-Object -Parallel runs in a separate runspace, so it doesn't see the variables in the body
                $source_list | ForEach-Object -Parallel {
                    
                    $date = Get-Date
                    $backup = $using:BackupFolder
                    $source = $using:SourceFolder + "\" + $_.Name
                    $log = $using:LogPath

                    # Check if the file exists in the backup folder. If it doesn't, copy it from the source folder
                    if (!(Test-Path -Path $($backup + "\" + $_.Name))){
                        
                        $output = "$date " + $_.Name + " missing in $backup, copying from $using:SourceFolder"
                        # Log to console
                        Write-Output $output
                        # Log to file
                        $output | Out-File -Append -FilePath $log | Wait-Process
                        Copy-Item -Path $source -Destination $backup 
                    
                    # If it does exist, check if the source file has been modified by comparing the last time both files have been modified. If the source
                    # file is newer, overwrite the backup file with it, otherwise do nothing. That way, only those files which have been modified will be 
                    # replaced, instead of all files. This should save a lot of time, if the folder contains large files and/or large number of them. 
                    }elseif (Test-Path -Path $($backup + "\" + $_.Name)) {
                        if ($_.LastWriteTime -gt (Get-ChildItem -Path $($backup + "\" + $_.Name)).LastWriteTime){
                            
                            $output = "$date " + $_.Name + " already present in $backup, overwriting..." 
                            # Log to console
                            Write-Output $output 
                            # Log to file
                            $output | Out-File -Append -FilePath $log | Wait-Process
                            Copy-Item -Path $source -Destination $backup 
                        }
                    } 
                }

                Start-Sleep $Interval
                
                if($Verify){
                    
                    $source_list = Get-ChildItem -Path $SourceFolder
                    $result = $source_list | ForEach-Object -Parallel {
                        
                        $LogPath = $using:LogFolder + "\" + "activities.log"
                        $TestPath = $($using:BackupFolder + "\" + $_.Name)

                        if ((Test-Path -Path $_.FullName) -and (Test-Path -Path $TestPath)){
                            if (((Get-ChildItem -Path $_).LastWriteTime) -eq ((Get-ChildItem -Path $TestPath).LastWriteTime)){
                                continue
                                Write-Output $TestPath
                            }else{
                                $output = "$_ present, but last write time doesn't match"
                                Write-Output $output 
                                $output | Out-File -Append -FilePath $LogPath | Wait-Process
                            }
                                continue
                            }else{
                            $output = "$_ not found in the backup folder"
                            Write-Output $output
                            $output | Out-File -Append -FilePath $LogPath | Wait-Process
                        }
                    }

                    
                    if ($result){                        
                        $result | Out-File -Append -FilePath $LogPath | Wait-Process

                    }else{
                        $date = Get-Date
                        $output = "`nBackup content successfully verified at " + "$date`n"
                        Write-Host $output -ForegroundColor Green
                        $output | Out-File -Append -FilePath $LogPath | Wait-Process
                        
                    }

                    foreach ($item in (Get-ChildItem -Path $BackupFolder).Name){
                        if (!($source_list.Name.Contains($item))){
                            Write-Warning "$item not found in source folder!"
                        }
                    }                    
                }

                $output = "`n###--------------------------------------------------------------------------------------------------------###" +
                "`n###   $date" +  " ###  Log ended  ###`n" 

                Write-Output $output 
                $output | Out-File -Append -FilePath $LogPath
 
            }until ($(Get-Date -Format "HH:mm") -ge $EndTime)
        }
    }
}
    