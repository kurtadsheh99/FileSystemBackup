Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create a global variable to track cancellation
$script:cancelRestore = $false

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
$form.Text = "File Restore System"
$form.Size = New-Object System.Drawing.Size(600,800)
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

# Create Backup Location GroupBox
$locationGroupBox = New-GroupBox "Backup Location" (New-Object System.Drawing.Point(10,20)) (New-Object System.Drawing.Size(560,80))
$form.Controls.Add($locationGroupBox)

# Default Location Label
$defaultLocationLabel = New-Object System.Windows.Forms.Label
$defaultLocationLabel.Location = New-Object System.Drawing.Point(10,25)
$defaultLocationLabel.Size = New-Object System.Drawing.Size(100,20)
$defaultLocationLabel.Text = "Default Location:"
$defaultLocationLabel.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
$locationGroupBox.Controls.Add($defaultLocationLabel)

# Default Location Path
$defaultLocationPath = New-Object System.Windows.Forms.Label
$defaultLocationPath.Location = New-Object System.Drawing.Point(110,25)
$defaultLocationPath.Size = New-Object System.Drawing.Size(440,20)
$defaultLocationPath.Text = $scriptDirectory
$defaultLocationPath.ForeColor = $accentColor
$locationGroupBox.Controls.Add($defaultLocationPath)

# Backup Location Label
$backupLocationLabel = New-Object System.Windows.Forms.Label
$backupLocationLabel.Location = New-Object System.Drawing.Point(10,50)
$backupLocationLabel.Size = New-Object System.Drawing.Size(100,20)
$backupLocationLabel.Text = "Backup Location:"
$backupLocationLabel.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
$locationGroupBox.Controls.Add($backupLocationLabel)

# Backup Location TextBox
$customLocationTextBox = New-Object System.Windows.Forms.TextBox
$customLocationTextBox.Location = New-Object System.Drawing.Point(110,48)
$customLocationTextBox.Size = New-Object System.Drawing.Size(340,20)
$customLocationTextBox.BackColor = $textBoxBackColor
$customLocationTextBox.ReadOnly = $true
$locationGroupBox.Controls.Add($customLocationTextBox)

# Browse Button
$browseButton = New-Button "Browse folder" (New-Object System.Drawing.Point(460,47)) (New-Object System.Drawing.Size(90,23))
$browseButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select the folder containing your backups"
    $folderBrowser.SelectedPath = if ($customLocationTextBox.Text) { $customLocationTextBox.Text } else { $scriptDirectory }
    
    $result = $folderBrowser.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $customLocationTextBox.Text = $folderBrowser.SelectedPath
        $customLocationTextBox.SelectionStart = $customLocationTextBox.Text.Length
        Update-UserBackups
    }
})
$locationGroupBox.Controls.Add($browseButton)

# Get list of all users
$allUsers = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @("Public", "Default", "Default User", "All Users") } | Select-Object -ExpandProperty Name

# Create Users Panel
$usersPanel = New-Object System.Windows.Forms.Panel
$usersPanel.Location = New-Object System.Drawing.Point(10,110)
$usersPanel.Size = New-Object System.Drawing.Size(560,250)
$usersPanel.AutoScroll = $false
$usersPanel.BackColor = $backgroundColor
$form.Controls.Add($usersPanel)

# Create Users GroupBox
$usersGroupBox = New-GroupBox "Select Backup Source and Target User" (New-Object System.Drawing.Point(0,0)) (New-Object System.Drawing.Size(540,250))
$usersPanel.Controls.Add($usersGroupBox)

# Create Users Scroll Panel
$usersScrollPanel = New-Object System.Windows.Forms.Panel
$usersScrollPanel.Location = New-Object System.Drawing.Point(10,20)
$usersScrollPanel.Size = New-Object System.Drawing.Size(520,220)
$usersScrollPanel.AutoScroll = $true
$usersGroupBox.Controls.Add($usersScrollPanel)

# Initialize controls dictionary
$userControls = @{}
$yPos = 10

# Create controls for each user
Get-ChildItem $scriptDirectory -Directory | Where-Object { $_.Name -match "^[^_]+_\d{4}-\d{2}-\d{2}$" } | ForEach-Object {
    $username = ($_.Name -split "_")[0]
    if (-not $userControls.ContainsKey($username)) {
        # Checkbox
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Location = New-Object System.Drawing.Point(0,$yPos)
        $checkbox.Size = New-Object System.Drawing.Size(100,20)
        $checkbox.Text = $username
        $checkbox.BackColor = $groupBoxBackColor
        $usersScrollPanel.Controls.Add($checkbox)

        # ComboBox for backup selection
        $comboBox = New-Object System.Windows.Forms.ComboBox
        $comboBox.Location = New-Object System.Drawing.Point(110,$yPos)
        $comboBox.Size = New-Object System.Drawing.Size(200,20)
        $comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $comboBox.BackColor = $textBoxBackColor
        $usersScrollPanel.Controls.Add($comboBox)

        # Label for target user
        $targetLabel = New-Object System.Windows.Forms.Label
        $targetLabel.Location = New-Object System.Drawing.Point(320,$yPos)
        $targetLabel.Size = New-Object System.Drawing.Size(70,20)
        $targetLabel.Text = "Restore to:"
        $targetLabel.BackColor = $groupBoxBackColor
        $usersScrollPanel.Controls.Add($targetLabel)

        # ComboBox for target user selection
        $targetUserComboBox = New-Object System.Windows.Forms.ComboBox
        $targetUserComboBox.Location = New-Object System.Drawing.Point(390,$yPos)
        $targetUserComboBox.Size = New-Object System.Drawing.Size(120,20)
        $targetUserComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $targetUserComboBox.BackColor = $textBoxBackColor
        $targetUserComboBox.Items.AddRange($allUsers)
        $targetUserComboBox.SelectedItem = $username
        $usersScrollPanel.Controls.Add($targetUserComboBox)

        # Get backups for this user
        $backups = Get-ChildItem $scriptDirectory -Directory | Where-Object { $_.Name -match "^$username`_\d{4}-\d{2}-\d{2}$" } | Sort-Object Name -Descending
        
        $userControls[$username] = @{
            "Checkbox" = $checkbox
            "ComboBox" = $comboBox
            "TargetUserComboBox" = $targetUserComboBox
            "Backups" = $backups
        }

        # Add backups to combo box
        $comboBox.Items.AddRange($backups)
        if ($comboBox.Items.Count -gt 0) {
            $comboBox.SelectedIndex = 0
        }

        $yPos += 30
    }
}

# Function to update user backups based on selected location
function Update-UserBackups {
    $backupLocation = if ($customLocationTextBox.Text) { $customLocationTextBox.Text } else { $scriptDirectory }
    
    foreach ($username in $userControls.Keys) {
        $comboBox = $userControls[$username]["ComboBox"]
        $comboBox.Items.Clear()
        
        # Get available backups for this user
        $backups = Get-ChildItem -Path $backupLocation -Directory | 
            Where-Object { $_.Name -match "^$username`_\d{4}-\d{2}-\d{2}$" } | 
            Sort-Object Name -Descending
            
        $userControls[$username]["Backups"] = $backups
        
        if ($backups.Count -gt 0) {
            foreach ($backup in $backups) {
                $backupDate = $backup.Name -replace "^$username`_"
                $comboBox.Items.Add("Backup from $backupDate") | Out-Null
            }
            $comboBox.SelectedIndex = 0
        } else {
            $comboBox.Items.Add("No backups found")
            $comboBox.SelectedIndex = 0
            $userControls[$username]["Backups"] = @()
        }
    }
}

# Initial backup update
Update-UserBackups

# Create a function to check if the script is running with admin rights
function Test-AdminRights {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check if backup contains Program Files
function Test-ContainsProgramFiles {
    param(
        [string]$backupPath
    )
    
    if (-not (Test-Path $backupPath)) {
        return $false
    }
    
    $programFilesBackups = Get-ChildItem -Path $backupPath -Directory | Where-Object { 
        $_.Name -like "Program+Files*" 
    }
    
    return $programFilesBackups.Count -gt 0
}

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10,375)
$statusLabel.Size = New-Object System.Drawing.Size(560,20)
$statusLabel.Text = "Status and Progress:"
$statusLabel.ForeColor = $accentColor
$statusLabel.Font = $titleFont
$form.Controls.Add($statusLabel)

# Status TextBox
$statusTextBox = New-Object System.Windows.Forms.TextBox
$statusTextBox.Location = New-Object System.Drawing.Point(10,400)
$statusTextBox.Size = New-Object System.Drawing.Size(560,180)
$statusTextBox.Multiline = $true
$statusTextBox.ScrollBars = "Vertical"
$statusTextBox.BackColor = $textBoxBackColor
$statusTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$statusTextBox.ReadOnly = $true
$form.Controls.Add($statusTextBox)

# Function to restore files
function Restore-Files {
    param(
        [string]$backupPath,
        [string]$targetUser,
        [array]$selectedFolders = @()
    )
    
    # Show the cancel button in the main form
    $cancelRestoreButton.Visible = $true
    $cancelRestoreButton.Enabled = $true
    $cancelRestoreButton.Text = "Cancel Restore"
    
    # Reset cancel flag
    $script:cancelRestore = $false
    
    $errors = @()
    $skippedFolders = @()
    
    # Get all directories in the backup (each represents a backed-up folder)
    $backupDirs = Get-ChildItem -Path $backupPath -Directory | Where-Object { $_.Name -ne "temp" }
    
    if ($backupDirs.Count -eq 0) {
        $statusTextBox.AppendText("No folders found in the backup.`r`n")
        return
    }
    
    # Filter directories based on selected folders if any are specified
    if ($selectedFolders.Count -gt 0) {
        $statusTextBox.AppendText("Restoring only selected folders: $($selectedFolders -join ', ')`r`n")
        $filteredDirs = @()
        
        foreach ($dir in $backupDirs) {
            $folderType = ""
            $folderName = ""
            
            # Check if this is a Program Files folder
            if ($dir.Name -eq "Program+Files" -or $dir.Name -eq "Program+Files+(x86)" -or $dir.Name -match "^Program\+Files") {
                $folderType = "Program Files"
                if ($dir.Name -match "\(x86\)") {
                    $folderName = "Program Files (x86)"
                } else {
                    $folderName = "Program Files"
                }
            } 
            # Check if this is a user folder
            elseif ($dir.Name -match "^Users\+") {
                $parts = $dir.Name -split "\+"
                if ($parts.Count -ge 3) {
                    $folderType = "User Folder"
                    $folderName = $parts[2]
                }
            }
            
            # Add to filtered list if selected
            if ($folderType -and $selectedFolders -contains $folderName) {
                $filteredDirs += $dir
                $statusTextBox.AppendText("Selected for restore: $folderName ($($dir.Name))`r`n")
            }
        }
        
        # Update the list of directories to process
        $backupDirs = $filteredDirs
        $statusTextBox.AppendText("Total folders to restore: $($backupDirs.Count)`r`n")
        
        if ($backupDirs.Count -eq 0) {
            $statusTextBox.AppendText("No matching folders found for the selected items.`r`n")
            return
        }
    }
    
    $totalDirs = $backupDirs.Count
    $processedDirs = 0
    
    foreach ($dir in $backupDirs) {
        # Check for cancellation
        if ($script:cancelRestore) {
            $statusTextBox.AppendText("`r`nRestore cancelled by user.`r`n")
            break
        }
        
        $processedDirs++
        $progress = [math]::Round(($processedDirs / $totalDirs) * 100)
        $statusTextBox.AppendText("`r`nProcessing folder $processedDirs of $totalDirs ($progress%): $($dir.Name)`r`n")
        
        # Force UI update
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            # Determine if this is a system folder or user folder
            if ($dir.Name -eq "Program+Files" -or $dir.Name -eq "Program+Files+(x86)" -or $dir.Name -match "^Program\+Files") {
                # Skip Program Files if we don't have admin rights
                if (-not (Test-AdminRights)) {
                    $statusTextBox.AppendText("Skipping system folder (requires administrator rights): $($dir.Name)`r`n")
                    continue
                }
                
                # System folder (Program Files)
                $targetPath = "C:\$($dir.Name.Replace('+', ' '))"
                $statusTextBox.AppendText("Restoring to system folder: $targetPath`r`n")
            } 
            elseif ($dir.Name.StartsWith("Program+Files")) {
                # This is for backward compatibility with older backups that might have different formats
                # Skip Program Files if we don't have admin rights
                if (-not (Test-AdminRights)) {
                    $statusTextBox.AppendText("Skipping system folder (requires administrator rights): $($dir.Name)`r`n")
                    continue
                }
                
                # Try to determine the correct Program Files path
                if ($dir.Name -match "Program\+Files\+\(x86\)") {
                    $targetPath = "C:\Program Files (x86)"
                } else {
                    $targetPath = "C:\Program Files"
                }
                $statusTextBox.AppendText("Restoring to system folder: $targetPath`r`n")
            } else {
                # Regular user folder
                $parts = $dir.Name -split "\+"
                if ($parts.Count -lt 3) {
                    $statusTextBox.AppendText("Invalid folder format: $($dir.Name). Skipping.`r`n")
                    $skippedFolders += "Folder '$($dir.Name)' has invalid format"
                    continue
                }
                $folderPath = $parts[2..($parts.Length-1)] -join "\"
                $targetPath = "C:\Users\$targetUser\$folderPath"
                $statusTextBox.AppendText("Restoring to user folder: $targetPath`r`n")
            }
            
            # Create target directory if it doesn't exist
            if (-not (Test-Path $targetPath)) {
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                $statusTextBox.AppendText("Created target directory: $targetPath`r`n")
            }
            
            # Get source path
            $sourcePath = Join-Path $backupPath $dir.Name
            
            if (-not (Test-Path $sourcePath)) {
                $statusTextBox.AppendText("Source path does not exist: $sourcePath. Skipping.`r`n")
                $skippedFolders += "Source path for '$($dir.Name)' does not exist"
                continue
            }
            
            # Get all items to copy
            $items = Get-ChildItem -Path $sourcePath -Recurse
            $totalItems = $items.Count
            
            if ($totalItems -eq 0) {
                $statusTextBox.AppendText("No items found in $sourcePath. Skipping.`r`n")
                $skippedFolders += "No items found in '$($dir.Name)'"
                continue
            }
            
            $processedItems = 0
            
            foreach ($item in $items) {
                # Check for cancellation periodically
                $processedItems++
                if ($processedItems % 50 -eq 0) {
                    if ($script:cancelRestore) {
                        throw "Restore cancelled by user"
                    }
                    # Update progress
                    $itemProgress = [math]::Round(($processedItems / $totalItems) * 100)
                    $statusTextBox.AppendText("Progress: $itemProgress% ($processedItems of $totalItems items)`r")
                    # Refresh the UI
                    [System.Windows.Forms.Application]::DoEvents()
                }
                
                $relativePath = $item.FullName.Substring($sourcePath.Length + 1)
                $destPath = Join-Path $targetPath $relativePath
                
                if ($item.PSIsContainer) {
                    # Create directory
                    if (-not (Test-Path $destPath)) {
                        New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                    }
                } else {
                    # Create parent directory if it doesn't exist
                    $destDir = Split-Path -Parent $destPath
                    if (-not (Test-Path $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }
                    # Copy file
                    Copy-Item -Path $item.FullName -Destination $destPath -Force
                }
            }
            
            $statusTextBox.AppendText("`r`nSuccessfully restored $($dir.Name) to $targetPath`r`n")
        }
        catch {
            if ($_.ToString() -eq "Restore cancelled by user") {
                $statusTextBox.AppendText("`r`nRestore of $($dir.Name) was cancelled.`r`n")
                break
            } else {
                $errors += "${dir.Name}: $($_.ToString().Replace(':', '\:'))"
                $statusTextBox.AppendText("Error restoring $($dir.Name): $($_.ToString().Replace(':', '\:'))`r`n")
            }
        }
    }
    
    if ($script:cancelRestore) {
        $statusTextBox.AppendText("`r`nRestore operation was cancelled by user.`r`n")
    }
    elseif ($errors.Count -eq 0 -and $skippedFolders.Count -eq 0) {
        $statusTextBox.AppendText("`r`nRestore completed successfully!`r`n")
    }
    else {
        $statusTextBox.AppendText("`r`nRestore completed with issues:`r`n")
        
        if ($skippedFolders.Count -gt 0) {
            $statusTextBox.AppendText("`r`nSkipped folders:`r`n")
            $statusTextBox.SelectionColor = [System.Drawing.Color]::Red
            foreach ($folder in $skippedFolders) {
                $statusTextBox.AppendText("- $folder`r`n")
            }
        }
        
        if ($errors.Count -gt 0) {
            $statusTextBox.AppendText("`r`nErrors:`r`n")
            $statusTextBox.SelectionColor = [System.Drawing.Color]::Red
            foreach ($error in $errors) {
                $statusTextBox.AppendText("- $error`r`n")
            }
        }
    }
    
    # Hide the cancel button in the main form
    $cancelRestoreButton.Visible = $false
    $cancelRestoreButton.Enabled = $true
    $cancelRestoreButton.Text = "Cancel Restore"
}

# Select All Button
$selectAllButton = New-Button "Select All Users" (New-Object System.Drawing.Point(10,590)) (New-Object System.Drawing.Size(270,30))
$selectAllButton.Add_Click({
    foreach ($controls in $userControls.Values) {
        $controls["Checkbox"].Checked = $true
    }
})
$form.Controls.Add($selectAllButton)

# Deselect All Button
$deselectAllButton = New-Button "Deselect All Users" (New-Object System.Drawing.Point(290,590)) (New-Object System.Drawing.Size(280,30))
$deselectAllButton.Add_Click({
    foreach ($controls in $userControls.Values) {
        $controls["Checkbox"].Checked = $false
    }
})
$form.Controls.Add($deselectAllButton)

# Restore Button
$restoreButton = New-Button "Start Restore" (New-Object System.Drawing.Point(10,630)) (New-Object System.Drawing.Size(560,30))
$restoreButton.Add_Click({
    # Reset cancel flag at the beginning of a new restore operation
    $script:cancelRestore = $false
    
    $selectedUsers = @()
    $selectedFolders = @()
    foreach ($username in $userControls.Keys) {
        if ($userControls[$username]["Checkbox"].Checked) {
            $selectedUsers += $username
            $selectedBackupText = $userControls[$username]["ComboBox"].SelectedItem
            $targetUser = $userControls[$username]["TargetUserComboBox"].SelectedItem
            
            if (-not $selectedBackupText -or $selectedBackupText -eq "No backups found") {
                $selectedUsers = $selectedUsers | Where-Object { $_ -ne $username }
                continue
            }
            
            if (-not $targetUser) {
                $selectedUsers = $selectedUsers | Where-Object { $_ -ne $username }
                continue
            }
            
            # Get the actual backup folder based on the selected text
            $backupIndex = $userControls[$username]["ComboBox"].SelectedIndex
            $selectedBackup = $userControls[$username]["Backups"][$backupIndex]
            
            if (-not $selectedBackup -or -not (Test-Path $selectedBackup.FullName)) {
                $selectedUsers = $selectedUsers | Where-Object { $_ -ne $username }
                continue
            }
        }
    }
    
    if ($selectedUsers.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one user to restore.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    # Create folder selection dialog
    $folderSelectionForm = New-Object System.Windows.Forms.Form
    $folderSelectionForm.Text = "Select Folders to Restore"
    $folderSelectionForm.Size = New-Object System.Drawing.Size(400, 500)
    $folderSelectionForm.StartPosition = "CenterScreen"
    $folderSelectionForm.FormBorderStyle = "FixedDialog"
    $folderSelectionForm.MaximizeBox = $false
    $folderSelectionForm.MinimizeBox = $false
    $folderSelectionForm.TopMost = $true
    
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(380, 40)
    $label.Text = "Select the folders you want to restore. If none are selected, all folders will be restored."
    $folderSelectionForm.Controls.Add($label)
    
    $folderListBox = New-Object System.Windows.Forms.CheckedListBox
    $folderListBox.Location = New-Object System.Drawing.Point(10, 60)
    $folderListBox.Size = New-Object System.Drawing.Size(360, 300)
    $folderListBox.CheckOnClick = $true
    $folderSelectionForm.Controls.Add($folderListBox)
    
    $selectAllButton = New-Object System.Windows.Forms.Button
    $selectAllButton.Location = New-Object System.Drawing.Point(10, 370)
    $selectAllButton.Size = New-Object System.Drawing.Size(175, 30)
    $selectAllButton.Text = "Select All"
    $selectAllButton.Add_Click({
        for ($i = 0; $i -lt $folderListBox.Items.Count; $i++) {
            $folderListBox.SetItemChecked($i, $true)
        }
    })
    $folderSelectionForm.Controls.Add($selectAllButton)
    
    $deselectAllButton = New-Object System.Windows.Forms.Button
    $deselectAllButton.Location = New-Object System.Drawing.Point(195, 370)
    $deselectAllButton.Size = New-Object System.Drawing.Size(175, 30)
    $deselectAllButton.Text = "Deselect All"
    $deselectAllButton.Add_Click({
        for ($i = 0; $i -lt $folderListBox.Items.Count; $i++) {
            $folderListBox.SetItemChecked($i, $false)
        }
    })
    $folderSelectionForm.Controls.Add($deselectAllButton)
    
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(10, 410)
    $okButton.Size = New-Object System.Drawing.Size(175, 30)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $folderSelectionForm.Controls.Add($okButton)
    $folderSelectionForm.AcceptButton = $okButton
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(195, 410)
    $cancelButton.Size = New-Object System.Drawing.Size(175, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $folderSelectionForm.Controls.Add($cancelButton)
    $folderSelectionForm.CancelButton = $cancelButton
    
    # Get all available folders from the selected backups
    $availableFolders = @{}
    
    foreach ($username in $selectedUsers) {
        $backupIndex = $userControls[$username]["ComboBox"].SelectedIndex
        $selectedBackup = $userControls[$username]["Backups"][$backupIndex]
        
        $backupDirs = Get-ChildItem -Path $selectedBackup.FullName -Directory | Where-Object { $_.Name -ne "temp" }
        foreach ($dir in $backupDirs) {
            $folderType = ""
            $folderName = ""
            
            # Check if this is a Program Files folder
            if ($dir.Name -eq "Program+Files" -or $dir.Name -eq "Program+Files+(x86)" -or $dir.Name -match "^Program\+Files") {
                $folderType = "Program Files"
                if ($dir.Name -match "\(x86\)") {
                    $folderName = "Program Files (x86)"
                } else {
                    $folderName = "Program Files"
                }
            } 
            # Check if this is a user folder
            elseif ($dir.Name -match "^Users\+") {
                $parts = $dir.Name -split "\+"
                if ($parts.Count -ge 3) {
                    $folderType = "User Folder"
                    $folderName = $parts[2]
                }
            }
            
            if ($folderType -and -not $availableFolders.ContainsKey($folderName)) {
                $availableFolders[$folderName] = $folderType
            }
        }
    }
    
    # Add folders to the list box
    foreach ($folder in $availableFolders.Keys | Sort-Object) {
        $folderListBox.Items.Add($folder, $true)  # Add checked by default
    }
    
    # Show the form
    $result = $folderSelectionForm.ShowDialog()
    
    # Process the result
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedFolders = @()
        for ($i = 0; $i -lt $folderListBox.Items.Count; $i++) {
            if ($folderListBox.GetItemChecked($i)) {
                $selectedFolders += $folderListBox.Items[$i]
            }
        }
    } else {
        return  # User cancelled
    }
    
    # If no folders selected, restore all
    if ($selectedFolders.Count -eq 0) {
        $restoreAll = [System.Windows.Forms.MessageBox]::Show(
            "No folders were selected. Do you want to restore all folders?",
            "Restore All Folders",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        
        if ($restoreAll -eq [System.Windows.Forms.DialogResult]::No) {
            return
        }
    }
    
    # Disable selection controls during restore
    $selectAllButton.Enabled = $false
    $deselectAllButton.Enabled = $false
    $browseButton.Enabled = $false
    
    # Disable checkboxes during restore
    foreach ($controls in $userControls.Values) {
        $controls["Checkbox"].Enabled = $false
        $controls["ComboBox"].Enabled = $false
        $controls["TargetUserComboBox"].Enabled = $false
    }

    # Show the cancel button in the main form
    $cancelRestoreButton.Visible = $true
    
    $form.BackColor = $backgroundColor
    $errors = @()
    
    foreach ($username in $selectedUsers) {
        # Check for cancellation
        if ($script:cancelRestore) {
            break
        }
        
        $controls = $userControls[$username]
        $selectedBackupText = $controls["ComboBox"].SelectedItem
        $targetUser = $controls["TargetUserComboBox"].SelectedItem
        
        if (-not $selectedBackupText -or $selectedBackupText -eq "No backups found") {
            $errors += "${username}: No valid backup selected"
            continue
        }
        
        if (-not $targetUser) {
            $errors += "${username}: No target user selected"
            continue
        }
        
        # Get the actual backup folder based on the selected text
        $backupIndex = $controls["ComboBox"].SelectedIndex
        $selectedBackup = $controls["Backups"][$backupIndex]
        
        if (-not $selectedBackup -or -not (Test-Path $selectedBackup.FullName)) {
            $errors += "${username}: Cannot find backup folder at $($selectedBackup.FullName)"
           continue
        }
        
        Restore-Files -backupPath $selectedBackup.FullName -targetUser $targetUser -selectedFolders $selectedFolders
    }
    
    # Re-enable UI controls
    $restoreButton.Enabled = $true
    $selectAllButton.Enabled = $true
    $deselectAllButton.Enabled = $true
    $browseButton.Enabled = $true
    
    # Hide and reset the cancel button
    $cancelRestoreButton.Visible = $false
    $cancelRestoreButton.Enabled = $true
    $cancelRestoreButton.Text = "Cancel Restore"
    
    # Reset the cancel flag
    $script:cancelRestore = $false
    
    foreach ($controls in $userControls.Values) {
        $controls["Checkbox"].Enabled = $true
        $controls["ComboBox"].Enabled = $true
        $controls["TargetUserComboBox"].Enabled = $true
    }
})
$form.Controls.Add($restoreButton)

# Cancel Restore Button
$cancelRestoreButton = New-Button "Cancel Restore" (New-Object System.Drawing.Point(10,670)) (New-Object System.Drawing.Size(560,30))
$cancelRestoreButton.BackColor = [System.Drawing.Color]::FromArgb(232, 17, 35)
$cancelRestoreButton.Visible = $false
$cancelRestoreButton.Add_MouseEnter({
    $this.BackColor = [System.Drawing.Color]::FromArgb(173, 26, 39)
})
$cancelRestoreButton.Add_MouseLeave({
    $this.BackColor = [System.Drawing.Color]::FromArgb(232, 17, 35)
})
$cancelRestoreButton.Add_Click({
    $script:cancelRestore = $true
    $cancelRestoreButton.Enabled = $false
    $cancelRestoreButton.Text = "Cancelling..."
})
$form.Controls.Add($cancelRestoreButton)

# Show the form
$form.ShowDialog()
