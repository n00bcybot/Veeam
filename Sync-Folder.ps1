
# DRAFT

$source_folder = "C:\Users\fresh\Desktop\Veeam\source"
$backup_folder = "C:\Users\fresh\Desktop\Veeam\backup"
$log_folder = "C:\Users\fresh\Desktop\Veeam\logs\activity.log"

$source_list = Get-ChildItem -Path $source_folder

# Check if each file in the source folder exists in the backup folder already. Using parallel for faster processing
$source_list | ForEach-Object -Parallel {
    
    $date = Get-Date
    $folder = $using:backup_folder
    $path = $using:source_folder + "\" + $_.Name
    $log_path = $using:log_folder

    # Check if the file exists in the backup folder. If it doesn't, copy it from the source folder
    if (!(Test-Path -Path $($folder + "\" + $_.Name))){
        
        Write-Output $_.Name " not found in $folder, copying..."
        Copy-Item -Path $path -Destination $folder
    
    # If it does exist, check if the source file has been modified by comparing the last time both files have been modified. If the source
    # file is newer, rewrite the backup file with it, otherwise do nothing. That way, only those files which have been modified will be 
    # replaced, instead of all files. This should save a lot of time, if the folder contains large and numerous files. 
    }elseif (Test-Path -Path $($folder + "\" + $_.Name)) {
        if ($_.LastWriteTime -gt (Get-ChildItem -Path $($folder + "\" + $_.Name)).LastWriteTime){
            $output = "$date " + $_.Name + " found in $folder, rewriting..." 
            # Log to console
            Write-Host $output
            # Log to file
            $output | Out-File -Append -FilePath $log_path
            Copy-Item -Path $path -Destination $folder
        }
    } 
}
    
