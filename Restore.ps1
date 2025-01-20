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
$form.Text = "File Restore System"
$form.Size = New-Object System.Drawing.Size(600,700)
$form.StartPosition = "CenterScreen"
$form.BackColor = $backgroundColor
$form.Font = $defaultFont

# Create a custom GroupBox style
function Create-GroupBox {
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
function Create-Button {
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
$locationGroupBox = Create-GroupBox "Backup Location" (New-Object System.Drawing.Point(10,20)) (New-Object System.Drawing.Size(560,80))
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
$browseButton = Create-Button "Browse folder" (New-Object System.Drawing.Point(460,47)) (New-Object System.Drawing.Size(90,23))
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
$usersPanel.Size = New-Object System.Drawing.Size(560,150)
$usersPanel.AutoScroll = $false
$usersPanel.BackColor = $backgroundColor
$form.Controls.Add($usersPanel)

# Create Users GroupBox
$usersGroupBox = Create-GroupBox "Select Backup Source and Target User" (New-Object System.Drawing.Point(0,0)) (New-Object System.Drawing.Size(540,150))
$usersPanel.Controls.Add($usersGroupBox)

# Create Users Scroll Panel
$usersScrollPanel = New-Object System.Windows.Forms.Panel
$usersScrollPanel.Location = New-Object System.Drawing.Point(10,20)
$usersScrollPanel.Size = New-Object System.Drawing.Size(520,120)
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
        }
    }
}

# Initial backup update
Update-UserBackups

# Status TextBox
$statusTextBox = New-Object System.Windows.Forms.TextBox
$statusTextBox.Location = New-Object System.Drawing.Point(10,270)
$statusTextBox.Size = New-Object System.Drawing.Size(560,280)
$statusTextBox.Multiline = $true
$statusTextBox.ScrollBars = "Vertical"
$statusTextBox.BackColor = $textBoxBackColor
$statusTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($statusTextBox)

# Select All Button
$selectAllButton = Create-Button "Select All Users" (New-Object System.Drawing.Point(10,560)) (New-Object System.Drawing.Size(270,30))
$selectAllButton.Add_Click({
    foreach ($controls in $userControls.Values) {
        $controls["Checkbox"].Checked = $true
    }
})
$form.Controls.Add($selectAllButton)

# Deselect All Button
$deselectAllButton = Create-Button "Deselect All Users" (New-Object System.Drawing.Point(290,560)) (New-Object System.Drawing.Size(280,30))
$deselectAllButton.Add_Click({
    foreach ($controls in $userControls.Values) {
        $controls["Checkbox"].Checked = $false
    }
})
$form.Controls.Add($deselectAllButton)

# Restore Button
$restoreButton = Create-Button "Start Restore" (New-Object System.Drawing.Point(10,600)) (New-Object System.Drawing.Size(560,30))
$restoreButton.Add_Click({
    $selectedUsers = $userControls.Keys | Where-Object { $userControls[$_]["Checkbox"].Checked }
    
    if ($selectedUsers.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one user to restore.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $form.BackColor = $backgroundColor
    $statusTextBox.Clear()
    $errors = @()
    
    foreach ($username in $selectedUsers) {
        $statusTextBox.AppendText("`r`nProcessing backup from user: $username`r`n")
        
        # Get selected backup
        $selectedIndex = $userControls[$username]["ComboBox"].SelectedIndex
        $selectedBackup = $userControls[$username]["Backups"][$selectedIndex]
        
        if ($null -eq $selectedBackup) {
            $errors += "$username : No backup selected"
            $statusTextBox.AppendText("Error: No backup selected for $username`r`n")
            continue
        }

        # Get target user
        $targetUser = $userControls[$username]["TargetUserComboBox"].SelectedItem
        $statusTextBox.AppendText("Using backup: $($selectedBackup.Name)`r`n")
        $statusTextBox.AppendText("Restoring to user: $targetUser`r`n")
        
        # Get list of folders in the backup
        $backupFolders = Get-ChildItem -Path $selectedBackup.FullName -Directory
        
        foreach ($folder in $backupFolders) {
            $sourcePath = $folder.FullName
            # Extract the relative path after the username and reconstruct it for the target user
            $folderNameParts = $folder.Name -split '\+'
            $relativePath = $folderNameParts[2..$($folderNameParts.Length-1)] -join '\'
            $destPath = "C:\Users\$targetUser\$relativePath"
            
            $statusTextBox.AppendText("Processing $($folder.Name)...`r`n")
            
            if (Test-Path $sourcePath) {
                try {
                    # Create the parent directory if it doesn't exist
                    $parentDir = Split-Path -Parent $destPath
                    if (-not (Test-Path $parentDir)) {
                        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                    }
                    
                    Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force -ErrorAction Stop
                    $statusTextBox.AppendText("Successfully restored to $destPath`r`n")
                }
                catch {
                    $errors += "$($folder.Name): $_"
                    $statusTextBox.AppendText("Error restoring $($folder.Name): $_`r`n")
                }
            }
            else {
                $errors += "$($folder.Name): Backup not found"
                $statusTextBox.AppendText("Warning: $($folder.Name) backup not found`r`n")
            }
        }
    }
    
    if ($errors.Count -eq 0) {
        $form.BackColor = [System.Drawing.Color]::FromArgb(230, 255, 230)
        $statusTextBox.AppendText("`r`nRestore completed successfully!`r`n")
    }
    else {
        $form.BackColor = [System.Drawing.Color]::FromArgb(255, 230, 230)
        $statusTextBox.AppendText("`r`nRestore completed with errors:`r`n")
        foreach ($error in $errors) {
            $statusTextBox.AppendText("$error`r`n")
        }
    }
})
$form.Controls.Add($restoreButton)

# Show the form
$form.ShowDialog()
