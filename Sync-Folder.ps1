function Log-Object {
    <#
.SYNOPSIS
    Create object with provided arguments
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][string]$Operation,
        [Parameter(Mandatory = $true)][string]$FromFolder,
        [Parameter(Mandatory = $true)][string]$ToFolder
    )

    $log = [pscustomobject]@{Time = $(Get-Date); File = $File; Operation = $Operation; FromFolder = $SourceFolder; ToFolder = $BackupFolder}
    return $log

}
function Verify-Content {
    <#
.SYNOPSIS
    Verify the content of both folders once the sync is done
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SourceFolder,
        [Parameter(Mandatory = $true)][string]$BackupFolder,
        [Parameter(Mandatory = $true)][string]$LogFolder
    )
                    
    $source_list = Get-ChildItem -Path $SourceFolder
    $LogPath = $LogFolder + "\" + "activities.log"


    $result = foreach ($item in $source_list) {

        $TestPath = $BackupFolder + "\" + $item.Name
        if ((Test-Path -Path $item.FullName) -and (Test-Path -Path $TestPath)){
            if ((Get-ChildItem -Path $item.FullName).LastWriteTime -eq (Get-ChildItem -Path $TestPath).LastWriteTime){
                continue
                Write-Output $TestPath
            }else{
                $output = "$item present, but last write time doesn't match"
                Write-Output $output 
                $output | Out-File -Append -FilePath $LogPath | Wait-Process
            }
                continue
            }else{
            $output = "$item not found in the backup folder"
            Write-Output $output
            $output | Out-File -Append -FilePath $LogPath | Wait-Process
        }
    }

    if ($result){                        
        $result | Out-File -Append -FilePath $LogPath | Wait-Process

    }else{
        $output = "`nBackup content successfully verified at " + "$(Get-Date)`n"
        Write-Host $output -ForegroundColor Green
        $output | Out-File -Append -FilePath $LogPath | Wait-Process
    }

    foreach ($item in (Get-ChildItem -Path $BackupFolder).Name){
        if (!($source_list.Name.Contains($item))){
            Write-Warning "$item not found in source folder!"
        }
    }                    
}

function Sync-Folder {
    <#
.SYNOPSIS
        Syncronizes the content of a given folder to another folder

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
    Example 2: Sync-Folder -SourceFolder "C:\source" -BackupFolder "C:\backup" -LogFolder "C:\Logs" -Interval 23 -EndTime "15:44"
    Example 3: Sync-Folder -SourceFolder "C:\source" -BackupFolder "C:\backup" -LogFolder "C:\Logs" -Interval 23 -EndTime "15:44" -Verify -OutJSON
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$SourceFolder,
        [Parameter(Mandatory=$true)][string]$BackupFolder,
        [Parameter(Mandatory=$true)][string]$LogFolder,
        [Parameter(Mandatory=$false)][int]$Interval = 10,
        [Parameter(Mandatory=$false)][string]$EndTime,
        [switch]$Verify,
        [switch]$OutJSON
    )

    $LogPath = "$LogFolder" + "\" + "activities.log"
    $LogObjects = @()

    # Check if the paths exist and indeed each points to a folder. If path are correct, continue.
    $paths = $SourceFolder, $BackupFolder, $LogFolder
    foreach ($item in $paths) {
        if ( !(Test-Path -Path $item) -or !(Test-Path -Path $item -PathType Container) ){
            Write-Output "Folder $item doesn't exsist or provied path is not a folder"
            break
        
        }else {
            # This loop conatins the main logic. It works with a list, created from the content of the given source folder. Once all files and
            # their last write time have been compared, the loop repeats when the given time is up.
            $index = 0
            do {
                
                $output = "###  Synchronization started at " + "$(Get-Date)  ###"
                Write-Output $output
                $output | Out-File -Append -FilePath $LogPath | Wait-Process 
                
                $source_list = Get-ChildItem -Path $SourceFolder
                # Loop through the list
                foreach($item in $source_list) {
  
                    $backup = $BackupFolder + "\" + $item.Name
                    $source = $SourceFolder + "\" + $item.Name
                                    
                    # Check if the file exists in the backup folder. If it doesn't, copy it from the source folder. Create custom object,
                    # containing time stamp, the file name, the operation performed on it, the source folder path and the backup folder path.
                    # The object then is added to the $LogObjects array, which can be exported to JSON file with the -OutJSON switch and
                    # later used further down the pipeline if needed. This should provide much more convenient use of the data generated,
                    # unlike the regular log.
                    if (!(Test-Path -Path $backup)){
                        
                        $date = Get-Date
                        Copy-Item -Path $source -Destination $backup                         
                        $OutObject = Log-Object -File $item.Name -Operation "Copy" -FromFolder $source -ToFolder $BackupFolder
                        $LogObjects += $OutObject
                        $output = "$date " + $item.Name + " missing in $BackupFolder, copying from $SourceFolder"
                        Write-Output $output
                        $output | Out-File -Append -FilePath $LogPath | Wait-Process
                    
                        # If the file exist in the backup folder already, check the last write time and if there is any difference,
                        # copy and replace it 
                    }elseif (Test-Path -Path $backup) {
                        if ($item.LastWriteTime -gt (Get-ChildItem -Path $backup).LastWriteTime){
                            
                            $date = Get-Date
                            Copy-Item -Path $source -Destination $backup                             
                            $OutObject = Log-Object -File $item.Name -Operation "Replace" -FromFolder $source -ToFolder $BackupFolder
                            $LogObjects += $OutObject
                            $output = "$date " + $item.Name + " found in $BackupFolder, replacing with the latest version from $SourceFolder"
                            Write-Output $output
                            $output | Out-File -Append -FilePath $LogPath | Wait-Process
                        }
                    }
                }
                $index++
                Start-Sleep $Interval
                
                if ($Verify){
                    if($index -gt 0){
                        Verify-Content -SourceFolder $SourceFolder -BackupFolder $BackupFolder -LogFolder $LogFolder
                    }
                }

                # Create JSON file if the log will be used down the line
                if($OutJSON){
                    if ($LogObjects){
                        $Path = $LogFolder + "\objects.json"
                        $LogObjects | ConvertTo-Json | Out-File -FilePath $Path
                        Write-Host "Objects array exported to JSON" -ForegroundColor Green
                    }else {
                        Write-Warning "No objects were created"
                    }
                }

                $output = "`n###  Synchronization ended at " + "$(Get-Date) ###`n" 
                Write-Output $output 
                $output | Out-File -Append -FilePath $LogPath
                
            }until ($(Get-Date -Format "HH:mm") -ge $EndTime)
        }
    }
}
    