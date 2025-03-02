Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Define colors
$backgroundColor = [System.Drawing.Color]::FromArgb(245, 246, 247)
$accentColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$buttonHoverColor = [System.Drawing.Color]::FromArgb(0, 102, 204)
$groupBoxBackColor = [System.Drawing.Color]::White
$textBoxBackColor = [System.Drawing.Color]::White

# Get the script's directory
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# Create custom fonts
$defaultFont = New-Object System.Drawing.Font("Segoe UI", 9)
$titleFont = New-Object System.Drawing.Font("Segoe UI Semibold", 9)

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "File Backup System"
$form.Size = New-Object System.Drawing.Size(600,830)
$form.StartPosition = "CenterScreen"
$form.BackColor = $backgroundColor
$form.Font = $defaultFont

# Create a custom GroupBox style
function New-GroupBox {
    param($title, $location, $size)
    $groupBox = New-Object System.Windows.Forms.GroupBox
    $groupBox.Text = $title
    $groupBox.Location = $location
    $groupBox.Size = $size
    $groupBox.Font = $titleFont
    $groupBox.ForeColor = $accentColor
    $groupBox.BackColor = $groupBoxBackColor
    return $groupBox
}

# Create Users GroupBox
$usersGroupBox = New-GroupBox "Select Users to Backup" (New-Object System.Drawing.Point(10,20)) (New-Object System.Drawing.Size(560,150))
$form.Controls.Add($usersGroupBox)

# Create Users Panel (Scrollable)
$usersPanel = New-Object System.Windows.Forms.Panel
$usersPanel.Location = New-Object System.Drawing.Point(5,20)
$usersPanel.Size = New-Object System.Drawing.Size(530,110)
$usersPanel.AutoScroll = $true
$usersGroupBox.Controls.Add($usersPanel)

# Get list of users from Users directory
$users = Get-ChildItem "C:\Users" | Where-Object { 
    $_.PSIsContainer -and 
    $_.Name -notmatch '^(Public|Default|Default User|All Users|desktop.ini)$'
}

# Create checkboxes for each user
$userCheckboxes = @{}
$yPos = 0
foreach ($user in $users) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Location = New-Object System.Drawing.Point(5,$yPos)
    $checkbox.Size = New-Object System.Drawing.Size(500,20)
    $checkbox.Text = $user.Name
    $checkbox.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $userCheckboxes[$user.Name] = $checkbox
    $usersPanel.Controls.Add($checkbox)
    $yPos += 25
}

# Create Folders GroupBox
$foldersGroupBox = New-GroupBox "Select Folders to Backup" (New-Object System.Drawing.Point(10,180)) (New-Object System.Drawing.Size(560,150))
$form.Controls.Add($foldersGroupBox)

# Define folder options
$folderOptions = @{
    "Downloads" = "Downloads"
    "Documents" = "Documents"
    "Desktop" = "Desktop"
    "Chrome Data" = "AppData+Local+Google+Chrome+User Data"
    "Outlook Data" = "AppData+Local+Microsoft+Outlook"
}

# Create checkboxes for each folder
$folderCheckboxes = @{}
$yPos = 20
foreach ($folder in $folderOptions.GetEnumerator()) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Location = New-Object System.Drawing.Point(10,$yPos)
    $checkbox.Size = New-Object System.Drawing.Size(530,20)
    $checkbox.Text = $folder.Key
    $checkbox.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $folderCheckboxes[$folder.Value] = $checkbox
    $foldersGroupBox.Controls.Add($checkbox)
    $yPos += 25
}

# Create Program Files GroupBox
$programFilesGroupBox = New-GroupBox "Program Files (Requires Administrator Privileges)" (New-Object System.Drawing.Point(10,340)) (New-Object System.Drawing.Size(560,70))
$form.Controls.Add($programFilesGroupBox)

# Define program files options
$programFilesOptions = @{
    "Program Files" = "SYSTEM+Program Files"
    "Program Files (x86)" = "SYSTEM+Program Files (x86)"
}

# Create checkboxes for program files
$yPos = 20
foreach ($folder in $programFilesOptions.GetEnumerator()) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Location = New-Object System.Drawing.Point(10,$yPos)
    $checkbox.Size = New-Object System.Drawing.Size(530,20)
    $checkbox.Text = $folder.Key
    $checkbox.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $folderCheckboxes[$folder.Value] = $checkbox
    $programFilesGroupBox.Controls.Add($checkbox)
    $yPos += 25
}

# Create a function to check if the script is running with admin rights
function Test-AdminRights {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check if any Program Files folders are selected
function Test-ProgramFilesSelected {
    $selectedFolders = $folderCheckboxes.Keys | Where-Object { $folderCheckboxes[$_].Checked }
    return $selectedFolders | Where-Object { $_.StartsWith("SYSTEM+") }
}

# Create a global variable to track cancellation
$script:cancelBackup = $false

# Status TextBox
$statusTextBox = New-Object System.Windows.Forms.TextBox
$statusTextBox.Location = New-Object System.Drawing.Point(10,470)
$statusTextBox.Size = New-Object System.Drawing.Size(560,200)
$statusTextBox.Multiline = $true
$statusTextBox.ScrollBars = "Vertical"
$statusTextBox.BackColor = $textBoxBackColor
$statusTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($statusTextBox)

# Cancel Button (initially hidden)
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel Backup"
$cancelButton.Location = New-Object System.Drawing.Point(10,680)
$cancelButton.Size = New-Object System.Drawing.Size(560,30)
$cancelButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$cancelButton.BackColor = [System.Drawing.Color]::FromArgb(232, 17, 35)
$cancelButton.ForeColor = [System.Drawing.Color]::White
$cancelButton.Font = $defaultFont
$cancelButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$cancelButton.Visible = $false
$cancelButton.Add_MouseEnter({
    $this.BackColor = [System.Drawing.Color]::FromArgb(173, 26, 39)
})
$cancelButton.Add_MouseLeave({
    $this.BackColor = [System.Drawing.Color]::FromArgb(232, 17, 35)
})
$cancelButton.Add_Click({
    $script:cancelBackup = $true
    $statusTextBox.AppendText("`r`nCancelling backup... Please wait while current operations complete.`r`n")
    $cancelButton.Enabled = $false
})
$form.Controls.Add($cancelButton)

# Location Label
$locationLabel = New-Object System.Windows.Forms.Label
$locationLabel.Location = New-Object System.Drawing.Point(10,420)
$locationLabel.Size = New-Object System.Drawing.Size(560,40)
$locationLabel.Text = "Backups will be saved in:`r`n$scriptDirectory"
$locationLabel.ForeColor = $accentColor
$form.Controls.Add($locationLabel)

# Create a custom button style
function New-Button {
    param($text, $location, $size)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $text
    $button.Location = $location
    $button.Size = $size
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.BackColor = $accentColor
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Font = $defaultFont
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    # Add hover effect
    $button.Add_MouseEnter({
        $this.BackColor = $buttonHoverColor
    })
    $button.Add_MouseLeave({
        $this.BackColor = $accentColor
    })
    
    return $button
}

# Select All Users Button
$selectAllUsersButton = New-Button "Select All Users" (New-Object System.Drawing.Point(10,690)) (New-Object System.Drawing.Size(135,30))
$selectAllUsersButton.Add_Click({
    foreach ($checkbox in $userCheckboxes.Values) {
        $checkbox.Checked = $true
    }
})
$form.Controls.Add($selectAllUsersButton)

# Deselect All Users Button
$deselectAllUsersButton = New-Button "Deselect All Users" (New-Object System.Drawing.Point(150,690)) (New-Object System.Drawing.Size(135,30))
$deselectAllUsersButton.Add_Click({
    foreach ($checkbox in $userCheckboxes.Values) {
        $checkbox.Checked = $false
    }
})
$form.Controls.Add($deselectAllUsersButton)

# Select All Folders Button
$selectAllFoldersButton = New-Button "Select All Folders" (New-Object System.Drawing.Point(295,690)) (New-Object System.Drawing.Size(135,30))
$selectAllFoldersButton.Add_Click({
    foreach ($checkbox in $folderCheckboxes.Values) {
        $checkbox.Checked = $true
    }
})
$form.Controls.Add($selectAllFoldersButton)

# Deselect All Folders Button
$deselectAllFoldersButton = New-Button "Deselect All Folders" (New-Object System.Drawing.Point(435,690)) (New-Object System.Drawing.Size(135,30))
$deselectAllFoldersButton.Add_Click({
    foreach ($checkbox in $folderCheckboxes.Values) {
        $checkbox.Checked = $false
    }
})
$form.Controls.Add($deselectAllFoldersButton)

# Backup Button
$backupButton = New-Button "Start Backup" (New-Object System.Drawing.Point(10,730)) (New-Object System.Drawing.Size(560,30))
$backupButton.Add_Click({
    $selectedUsers = $userCheckboxes.Keys | Where-Object { $userCheckboxes[$_].Checked }
    $selectedFolders = $folderCheckboxes.Keys | Where-Object { $folderCheckboxes[$_].Checked }
    
    if ($selectedUsers.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one user to backup.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    if ($selectedFolders.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one folder to backup.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    # Check if Program Files are selected and if the script is running with admin rights
    $programFilesSelected = Test-ProgramFilesSelected
    if ($programFilesSelected -and -not (Test-AdminRights)) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "You have selected Program Files folders, but the application is not running with administrator rights.`r`n`r`nTo backup Program Files, you need to restart the application as administrator.`r`n`r`nDo you want to continue without backing up Program Files?",
            "Administrator Rights Required",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::No) {
            return
        }
        
        # Remove Program Files from selected folders
        $selectedFolders = $selectedFolders | Where-Object { -not $_.StartsWith("SYSTEM+") }
    }

    # Reset cancel flag
    $script:cancelBackup = $false
    
    # Show cancel button and disable backup button
    $cancelButton.Visible = $true
    $cancelButton.Enabled = $true
    $backupButton.Enabled = $false
    
    # Disable selection buttons during backup
    $selectAllUsersButton.Enabled = $false
    $deselectAllUsersButton.Enabled = $false
    $selectAllFoldersButton.Enabled = $false
    $deselectAllFoldersButton.Enabled = $false
    
    # Disable checkboxes during backup
    foreach ($checkbox in $userCheckboxes.Values) {
        $checkbox.Enabled = $false
    }
    foreach ($checkbox in $folderCheckboxes.Values) {
        $checkbox.Enabled = $false
    }

    $form.BackColor = $backgroundColor
    $statusTextBox.Clear()
    $errors = @()
    
    # Create date string for backup folder
    $date = Get-Date -Format "yyyy-MM-dd"
    
    foreach ($username in $selectedUsers) {
        # Check for cancellation
        if ($script:cancelBackup) {
            $statusTextBox.AppendText("`r`nBackup cancelled by user.`r`n")
            break
        }
        
        $statusTextBox.AppendText("`r`nProcessing user: $username`r`n")
        
        # Create backup folder for this user
        $backupRoot = Join-Path $scriptDirectory "${username}_${date}"
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        
        # Create a log file for this backup
        $logFile = Join-Path $backupRoot "logs.txt"
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "Backup started at $timestamp for user: $username" | Out-File -FilePath $logFile -Append
        "Selected folders: $($selectedFolders -join ', ')" | Out-File -FilePath $logFile -Append
        "`r`n" | Out-File -FilePath $logFile -Append
        
        foreach ($folderPath in $selectedFolders) {
            # Check for cancellation
            if ($script:cancelBackup) {
                $statusTextBox.AppendText("`r`nBackup cancelled by user.`r`n")
                break
            }
            
            $sourcePath = ""
            $folderName = ""
            
            # Check if this is a system folder (Program Files)
            if ($folderPath.StartsWith("SYSTEM+")) {
                $actualPath = $folderPath.Substring(7).Replace('+', '\')
                $sourcePath = "C:\$actualPath"
                
                # Standardize Program Files folder names
                if ($actualPath -eq "Program Files") {
                    $folderName = "Program+Files"
                } 
                elseif ($actualPath -eq "Program Files (x86)") {
                    $folderName = "Program+Files+(x86)"
                }
                else {
                    $folderName = $actualPath.Replace('\', '+')
                }
            } else {
                # Regular user folder
                $folderName = "Users+$username+$folderPath"
                $sourcePath = "C:\Users\$username\$($folderPath.Replace('+', '\'))"
            }
            
            $destPath = Join-Path $backupRoot $folderName
            
            $statusTextBox.AppendText("Processing $folderName...`r`n")
            "Processing $folderName..." | Out-File -FilePath $logFile -Append
            
            if (Test-Path $sourcePath) {
                try {
                    # Create the destination directory
                    if (-not (Test-Path $destPath)) {
                        New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                    }
                    
                    # Get all items to copy (excluding My Music folder)
                    $items = Get-ChildItem -Path $sourcePath -Recurse | Where-Object {
                        $relativePath = $_.FullName.Substring($sourcePath.Length + 1)
                        -not $relativePath.StartsWith("My Music") -and -not $relativePath.Contains("\My Music\")
                    }
                    
                    $totalItems = $items.Count
                    $processedItems = 0
                    
                    foreach ($item in $items) {
                        # Check for cancellation periodically
                        $processedItems++
                        if ($processedItems % 50 -eq 0) {
                            if ($script:cancelBackup) {
                                throw "Backup cancelled by user"
                            }
                            # Update progress
                            $progress = [math]::Round(($processedItems / $totalItems) * 100)
                            $statusTextBox.AppendText("Progress: $progress% ($processedItems of $totalItems items)`r")
                            "Progress: $progress% ($processedItems of $totalItems items)" | Out-File -FilePath $logFile -Append
                            # Refresh the UI
                            [System.Windows.Forms.Application]::DoEvents()
                        }
                        
                        $relativePath = $item.FullName.Substring($sourcePath.Length + 1)
                        $targetPath = Join-Path $destPath $relativePath
                        
                        if ($item.PSIsContainer) {
                            # Create directory
                            if (-not (Test-Path $targetPath)) {
                                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                            }
                        } else {
                            # Create parent directory if it doesn't exist
                            $targetDir = Split-Path -Parent $targetPath
                            if (-not (Test-Path $targetDir)) {
                                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                            }
                            # Copy file
                            Copy-Item -Path $item.FullName -Destination $targetPath -Force
                        }
                    }
                    
                    $statusTextBox.AppendText("`r`nSuccessfully backed up $folderName (excluding My Music folder)`r`n")
                    "Successfully backed up $folderName (excluding My Music folder)" | Out-File -FilePath $logFile -Append
                }
                catch {
                    if ($script:cancelBackup) {
                        $statusTextBox.AppendText("`r`nBackup of $folderName was cancelled.`r`n")
                        "Backup of $folderName was cancelled." | Out-File -FilePath $logFile -Append
                    } else {
                        $errors += "$folderName`: $_"
                        $statusTextBox.AppendText("Error backing up $folderName`: $_`r`n")
                        "Error backing up $folderName`: $_" | Out-File -FilePath $logFile -Append
                    }
                }
            }
            else {
                $errors += "$folderName`: Source path not found"
                $statusTextBox.AppendText("Warning: $folderName path not found`r`n")
                "Warning: $folderName path not found" | Out-File -FilePath $logFile -Append
            }
        }
        
        # Break out of user loop if cancelled
        if ($script:cancelBackup) {
            break
        }
    }
    
    # Re-enable UI controls
    $backupButton.Enabled = $true
    $selectAllUsersButton.Enabled = $true
    $deselectAllUsersButton.Enabled = $true
    $selectAllFoldersButton.Enabled = $true
    $deselectAllFoldersButton.Enabled = $true
    
    foreach ($checkbox in $userCheckboxes.Values) {
        $checkbox.Enabled = $true
    }
    foreach ($checkbox in $folderCheckboxes.Values) {
        $checkbox.Enabled = $true
    }
    
    # Hide cancel button
    $cancelButton.Visible = $false
    
    if ($script:cancelBackup) {
        $form.BackColor = [System.Drawing.Color]::FromArgb(255, 242, 204)
        $statusTextBox.AppendText("`r`nBackup operation was cancelled by user.`r`n")
        
        # Log the cancellation to all log files
        foreach ($username in $selectedUsers) {
            $backupRoot = Join-Path $scriptDirectory "${username}_${date}"
            $logFile = Join-Path $backupRoot "logs.txt"
            if (Test-Path $backupRoot) {
                $endTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "Backup operation was cancelled by user at $endTimestamp." | Out-File -FilePath $logFile -Append
            }
        }
    }
    elseif ($errors.Count -eq 0) {
        $form.BackColor = [System.Drawing.Color]::FromArgb(230, 255, 230)
        $statusTextBox.AppendText("`r`nBackup completed successfully!`r`n")
        
        # Log success to all log files
        foreach ($username in $selectedUsers) {
            $backupRoot = Join-Path $scriptDirectory "${username}_${date}"
            $logFile = Join-Path $backupRoot "logs.txt"
            if (Test-Path $backupRoot) {
                $endTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "Backup completed successfully at $endTimestamp." | Out-File -FilePath $logFile -Append
            }
        }
    }
    else {
        $form.BackColor = [System.Drawing.Color]::FromArgb(255, 230, 230)
        $statusTextBox.AppendText("`r`nBackup completed with errors:`r`n")
        
        # Log errors to all log files
        foreach ($username in $selectedUsers) {
            $backupRoot = Join-Path $scriptDirectory "${username}_${date}"
            $logFile = Join-Path $backupRoot "logs.txt"
            if (Test-Path $backupRoot) {
                $endTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "Backup completed with errors at $endTimestamp." | Out-File -FilePath $logFile -Append
                foreach ($error in $errors) {
                    "$error" | Out-File -FilePath $logFile -Append
                }
            }
        }
        
        foreach ($error in $errors) {
            $statusTextBox.AppendText("$error`r`n")
        }
    }
})
$form.Controls.Add($backupButton)

# Show the form
$form.ShowDialog()
