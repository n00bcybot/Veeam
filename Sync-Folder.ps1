
$source_folder = "C:\Users\fresh\Desktop\Veeam\source"
$backup_folder = "C:\Users\fresh\Desktop\Veeam\backup"
$log_folder = "C:\Users\fresh\Desktop\Veeam\logs\activity.log"
$source_list = Get-ChildItem -Path $source_folder

$date = Get-Date
$output = "###   $date" +  " ###  New log started at $log_folder  ###" +
"`n###--------------------------------------------------------------------------------------------------------###`n" 

Write-Host $output
$output | Out-File -Append -FilePath $log_folder | Wait-Process


# Check if each file in the source folder exists in the backup folder already. Using "parallel" switch for faster processing.
# ForEach-Object -Parallel runs in a separate runspace, so it doesn't see the variables in the body
$source_list | ForEach-Object -Parallel {
    
    $date = Get-Date
    $folder = $using:backup_folder
    $path = $using:source_folder + "\" + $_.Name
    $log_path = $using:log_folder

    # Check if the file exists in the backup folder. If it doesn't, copy it from the source folder
    if (!(Test-Path -Path $($folder + "\" + $_.Name))){
        
        $output = "$date " + $_.Name + " not found in $folder, copying..."
        # Log to console
        Write-Host $output
        # Log to file
        $output | Out-File -Append -FilePath $log_path | Wait-Process
        Copy-Item -Path $path -Destination $folder
    
    # If it does exist, check if the source file has been modified by comparing the last time both files have been modified. If the source
    # file is newer, overwrite the backup file with it, otherwise do nothing. That way, only those files which have been modified will be 
    # replaced, instead of all files. This should save a lot of time, if the folder contains large files and/or large number of them. 
    }elseif (Test-Path -Path $($folder + "\" + $_.Name)) {
        if ($_.LastWriteTime -gt (Get-ChildItem -Path $($folder + "\" + $_.Name)).LastWriteTime){
            
            $output = "$date " + $_.Name + " found in $folder, overwriting..." 
            # Log to console
            Write-Host $output 
            # Log to file
            $output | Out-File -Append -FilePath $log_path | Wait-Process
            Copy-Item -Path $path -Destination $folder
        }
    } 
}

$date = Get-Date
$output = "`n###--------------------------------------------------------------------------------------------------------###" +
"`n###   $date" +  " ###  Log ended  ###" 

Write-Host $output 
$output | Out-File -Append -FilePath $log_folder
