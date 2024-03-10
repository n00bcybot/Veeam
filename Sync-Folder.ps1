

function Log-Output {
    param(
    [Parameter(Mandatory=$true)][string]$SourceFolder,
    [Parameter(Mandatory=$true)][string]$BackupFolder,
    [Parameter(Mandatory=$true)][string]$LogFolder,
    [Parameter(Mandatory=$true)][string]$EndTime
)

    do{

    $source_list = Get-ChildItem -Path $SourceFolder
    $date = Get-Date

    $output = "###   $date" +  " ###  New log started at $LogFolder  ###" +
    "`n###--------------------------------------------------------------------------------------------------------###`n" 

    Write-Host $output
    $output | Out-File -Append -FilePath $LogFolder | Wait-Process

        # Check if each file in the source folder exists in the backup folder already. Using "parallel" switch for faster processing.
        # ForEach-Object -Parallel runs in a separate runspace, so it doesn't see the variables in the body
        $source_list | ForEach-Object -Parallel {
            
            $date = Get-Date
            $backup = $using:BackupFolder
            $source = $using:SourceFolder + "\" + $_.Name
            $log = $using:LogFolder

            # Check if the file exists in the backup folder. If it doesn't, copy it from the source folder
            if (!(Test-Path -Path $($backup + "\" + $_.Name))){
                
                $output = "$date " + $_.Name + " missing in $backup, copying from $using:SourceFolder..."
                # Log to console
                Write-Host $output
                # Log to file
                $output | Out-File -Append -FilePath $log | Wait-Process
                Copy-Item -Path $source -Destination $backup
            
            # If it does exist, check if the source file has been modified by comparing the last time both files have been modified. If the source
            # file is newer, overwrite the backup file with it, otherwise do nothing. That way, only those files which have been modified will be 
            # replaced, instead of all files. This should save a lot of time, if the folder contains large files and/or large number of them. 
            }elseif (Test-Path -Path $($backup + "\" + $_.Name)) {
                if ($_.LastWriteTime -gt (Get-ChildItem -Path $($backup + "\" + $_.Name)).LastWriteTime){
                    
                    $output = "$date " + $_.Name + " already exists in $backup, overwriting file in $using:source_folder..." 
                    # Log to console
                    Write-Host $output 
                    # Log to file
                    $output | Out-File -Append -FilePath $log | Wait-Process
                    Copy-Item -Path $source -Destination $backup
                }
            } 
        }

    $output = "`n###--------------------------------------------------------------------------------------------------------###" +
    "`n###   $date" +  " ###  Log ended  ###" 

    Write-Host $output 
    $output | Out-File -Append -FilePath $LogFolder

    Start-Sleep 15
    
    }until($(Get-Date -Format "HH:mm") -ge $EndTime)

}