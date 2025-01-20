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

# Status TextBox
$statusTextBox = New-Object System.Windows.Forms.TextBox
$statusTextBox.Location = New-Object System.Drawing.Point(10,400)
$statusTextBox.Size = New-Object System.Drawing.Size(560,200)
$statusTextBox.Multiline = $true
$statusTextBox.ScrollBars = "Vertical"
$statusTextBox.BackColor = $textBoxBackColor
$statusTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($statusTextBox)

# Location Label
$locationLabel = New-Object System.Windows.Forms.Label
$locationLabel.Location = New-Object System.Drawing.Point(10,340)
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
$selectAllUsersButton = New-Button "Select All Users" (New-Object System.Drawing.Point(10,620)) (New-Object System.Drawing.Size(135,30))
$selectAllUsersButton.Add_Click({
    foreach ($checkbox in $userCheckboxes.Values) {
        $checkbox.Checked = $true
    }
})
$form.Controls.Add($selectAllUsersButton)

# Deselect All Users Button
$deselectAllUsersButton = New-Button "Deselect All Users" (New-Object System.Drawing.Point(150,620)) (New-Object System.Drawing.Size(135,30))
$deselectAllUsersButton.Add_Click({
    foreach ($checkbox in $userCheckboxes.Values) {
        $checkbox.Checked = $false
    }
})
$form.Controls.Add($deselectAllUsersButton)

# Select All Folders Button
$selectAllFoldersButton = New-Button "Select All Folders" (New-Object System.Drawing.Point(295,620)) (New-Object System.Drawing.Size(135,30))
$selectAllFoldersButton.Add_Click({
    foreach ($checkbox in $folderCheckboxes.Values) {
        $checkbox.Checked = $true
    }
})
$form.Controls.Add($selectAllFoldersButton)

# Deselect All Folders Button
$deselectAllFoldersButton = New-Button "Deselect All Folders" (New-Object System.Drawing.Point(435,620)) (New-Object System.Drawing.Size(135,30))
$deselectAllFoldersButton.Add_Click({
    foreach ($checkbox in $folderCheckboxes.Values) {
        $checkbox.Checked = $false
    }
})
$form.Controls.Add($deselectAllFoldersButton)

# Backup Button
$backupButton = New-Button "Start Backup" (New-Object System.Drawing.Point(10,660)) (New-Object System.Drawing.Size(560,30))
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

    $form.BackColor = $backgroundColor
    $statusTextBox.Clear()
    $errors = @()
    
    # Create date string for backup folder
    $date = Get-Date -Format "yyyy-MM-dd"
    
    foreach ($username in $selectedUsers) {
        $statusTextBox.AppendText("`r`nProcessing user: $username`r`n")
        
        # Create backup folder for this user
        $backupRoot = Join-Path $scriptDirectory "${username}_${date}"
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        
        foreach ($folderPath in $selectedFolders) {
            $folderName = "Users+$username+$folderPath"
            $sourcePath = "C:\Users\$username\$($folderPath.Replace('+', '\'))"
            $destPath = Join-Path $backupRoot $folderName
            
            $statusTextBox.AppendText("Processing $folderName...`r`n")
            
            if (Test-Path $sourcePath) {
                try {
                    # Create a temporary directory to store filtered items
                    $tempPath = Join-Path $backupRoot "temp_$folderName"
                    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
                    
                    # Copy items to temp directory, excluding My Music folder
                    Get-ChildItem -Path $sourcePath -Recurse | Where-Object {
                        $relativePath = $_.FullName.Substring($sourcePath.Length + 1)
                        -not $relativePath.StartsWith("My Music") -and -not $relativePath.Contains("\My Music\")
                    } | ForEach-Object {
                        $targetPath = Join-Path $tempPath $_.FullName.Substring($sourcePath.Length + 1)
                        $targetDir = Split-Path -Parent $targetPath
                        if (-not (Test-Path $targetDir)) {
                            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                        }
                        Copy-Item -Path $_.FullName -Destination $targetPath -Force
                    }
                    
                    # Move from temp to final destination
                    Move-Item -Path $tempPath -Destination $destPath -Force
                    $statusTextBox.AppendText("Successfully backed up $folderName (excluding My Music folder)`r`n")
                }
                catch {
                    $errors += "$folderName`: $_"
                    $statusTextBox.AppendText("Error backing up $folderName`: $_`r`n")
                }
            }
            else {
                $errors += "$folderName`: Source path not found"
                $statusTextBox.AppendText("Warning: $folderName path not found`r`n")
            }
        }
    }
    
    if ($errors.Count -eq 0) {
        $form.BackColor = [System.Drawing.Color]::FromArgb(230, 255, 230)
        $statusTextBox.AppendText("`r`nBackup completed successfully!`r`n")
    }
    else {
        $form.BackColor = [System.Drawing.Color]::FromArgb(255, 230, 230)
        $statusTextBox.AppendText("`r`nBackup completed with errors:`r`n")
        foreach ($error in $errors) {
            $statusTextBox.AppendText("$error`r`n")
        }
    }
})
$form.Controls.Add($backupButton)

# Show the form
$form.ShowDialog()
