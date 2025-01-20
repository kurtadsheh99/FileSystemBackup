# File Backup and Restore System

This system allows you to backup and restore important user files including:
- Downloads folder
- Documents folder
- Desktop folder
- Chrome profile
- Outlook files (.pst, .ost, .nst)

## How to Use

### To Create a Backup:
1. Double-click `Backup.bat` to start the backup application
2. Select the users you want to backup from the checkbox list
   - Use "Select All Users" to check all users
   - Use "Deselect All Users" to uncheck all users
3. Click "Browse" to select the backup destination drive
4. Click "Start Backup" to begin the backup process

### To Restore from Backup:
1. Double-click `Restore.bat` to start the restore application
2. Select the users you want to restore from the checkbox list
   - Use "Select All Users" to check all users
   - Use "Deselect All Users" to uncheck all users
3. Click "Browse" to select the drive containing your backups
4. Click "Start Restore" to begin the restore process
   - The system will automatically find and use the latest backup for each selected user

## Features

- Separate applications for backup and restore operations
- Multi-user backup and restore support with checkbox selection
- Automatic detection of latest backup for each user
- User-friendly graphical interface
- Visual feedback with color-coded status (green for success, red for errors)
- Detailed status updates during backup/restore process
- Preserves full path structure using '+' as separator (e.g., "Users+username+Documents")
- Simple backup folder naming with username and date

## Notes

- If the script shows to responding don't close the application, it is still running in the background
- The backup process will create folders with the format: `username_yyyy-MM-dd`
  For example: `john_2025-01-18`
- Each backed-up folder will maintain its full path structure with '+' separators
  For example: `C:\Users\username\Documents` becomes `Users+username+Documents`
- If you run multiple backups on the same day for the same user, the newer backup will overwrite the older one
- The restore process will automatically find and use the most recent backup for each selected user
- Make sure to close Chrome and Outlook before backing up or restoring their respective folders
- Requires administrative privileges to restore backup to a different user
- Only real user profiles with a Desktop folder are shown in the selection list
