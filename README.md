# File Backup and Restore System

This system allows you to backup and restore important user files and application data across Windows systems. It features a modern, user-friendly interface with comprehensive backup and restore capabilities.

## Supported Content for Backup

- **User Data**:
  - Downloads folder
  - Documents folder
  - Desktop folder
  - Personal files and folders
- **Application Data**:
  - Chrome profiles (bookmarks, history, extensions)
  - Outlook data files (.pst, .ost, .nst)
- **System Files** (requires administrator privileges):
  - Program Files
  - Program Files (x86)

## Features

### Backup Features
- Modern, user-friendly graphical interface
- Multi-user backup support with checkbox selection
- Selective folder backup options
- Custom backup location selection
- Detailed progress tracking with status updates
- Ability to cancel ongoing backups
- Color-coded status indicators (green for success, red for errors)
- Automatic date-based backup folder naming
- Administrator mode for backing up system folders

### Restore Features
- Selective restoration from backups
- Multi-user restore support
- Target user selection (restore to original or different user)
- Folder selection for granular restore control
- Detailed progress tracking in the main window
- Ability to cancel ongoing restore operations
- Automatic detection of the latest backup for each user
- Cross-user restoration capabilities

## How to Use

### To Create a Backup:

1. Double-click `Backup.bat` to start the backup application
2. **Select Users**: Choose which user profiles to backup
   - Use "Select All Users" to check all users
   - Use "Deselect All Users" to uncheck all users
3. **Select Folders**: Choose which folders to include in the backup
   - Standard user folders (Downloads, Documents, Desktop)
   - Application data (Chrome, Outlook)
   - System folders (requires administrator privileges)
4. **Choose Backup Location**: 
   - Click "Browse" to select the backup destination drive
   - By default, backups are saved in the same directory as the application
5. **Start Backup**: 
   - Click "Start Backup" to begin the backup process
   - Monitor progress in the status text box
   - Use "Cancel Backup" button if needed to stop the operation

### To Restore from Backup:

1. Double-click `Restore.bat` to start the restore application
2. **Select Backup Location**:
   - Click "Browse folder" to select the drive containing your backups
   - The system will automatically detect available backups
3. **Select Users and Target**:
   - Check the users whose backups you want to restore
   - For each user, select which backup to use from the dropdown
   - Choose the target user to restore to (can be different from source)
4. **Start Restore**:
   - Click "Start Restore" to begin the restore process
   - In the folder selection window, choose which folders to restore
   - Monitor progress in the status text box
   - Use "Cancel Restore" button if needed to stop the operation

## Technical Details

- **Backup Naming Convention**: `username_yyyy-MM-dd` (e.g., `john_2025-03-02`)
- **Path Structure**: Full paths are preserved using '+' as separator
  - Example: `C:\Users\username\Documents` becomes `Users+username+Documents`
- **Backup Overwrite Policy**: Multiple backups on the same day for the same user will overwrite previous backups
- **Restore Selection**: The system automatically identifies and offers the most recent backup for each user
- **Administrator Requirements**:
  - Admin privileges required to backup/restore Program Files
  - Admin privileges required to restore to a different user's profile

## Best Practices

- **Before Backup/Restore**:
  - Close Chrome before backing up or restoring Chrome profiles
  - Close Outlook before backing up or restoring Outlook data files
  - Ensure sufficient disk space at the backup location
- **During Operation**:
  - Do not close the application if it appears unresponsive - it may be processing large files
  - Check the status text box for real-time progress updates
- **After Completion**:
  - Verify backup/restore success through the status messages
  - Check color indicators (green for success, red for errors)

## Troubleshooting

- **Application Requires Administrator**: If backing up Program Files, right-click the batch file and select "Run as administrator"
- **Backup Not Found**: Ensure you've selected the correct backup location containing valid backups
- **Restore Fails**: Check if target locations are accessible and not locked by running applications
- **Performance Issues**: Large files (especially from Chrome and Outlook) may take longer to process

## System Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or higher
- Sufficient disk space for backups
- Administrator privileges to backup and restore backup system folders (Program Files, Program Files (x86))
