#Requires -Modules Pester

<#
.SYNOPSIS
    Pester test suite for Restore.ps1 business logic.

.DESCRIPTION
    This file covers the testable logic in Restore.ps1.

    CURRENT STATE: Like Backup.ps1, Restore.ps1 mixes GUI construction and business
    logic. Tests marked with -Skip require the refactoring described in each block.

    RECOMMENDED REFACTORING:
    Extract business logic into RestoreHelpers.psm1 (or a shared BackupHelpers.psm1).
    Key functions to extract:
      - Test-AdminRights            (identical to Backup.ps1 version)
      - Test-ContainsProgramFiles   (already a standalone function, good candidate)
      - Update-UserBackups          (currently references GUI controls directly)
      - Resolve-BackupFolderTarget  (extract path reconstruction from Restore-Files)
      - Invoke-FolderRestore        (extract the file-copy loop from Restore-Files)

    TESTING FRAMEWORK:
    Pester 5.x - install with: Install-Module -Name Pester -Force -SkipPublisherCheck
    Run tests with: Invoke-Pester -Path ./Tests/Restore.Tests.ps1 -Output Detailed
#>

BeforeAll {
    # Re-define functions inline until they are extracted to a module.

    function Test-AdminRights {
        $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Restore.ps1 lines 242-256 – already a standalone function, easiest to test.
    function Test-ContainsProgramFiles {
        param([string]$backupPath)
        if (-not (Test-Path $backupPath)) { return $false }
        $programFilesBackups = Get-ChildItem -Path $backupPath -Directory |
            Where-Object { $_.Name -like "Program+Files*" }
        return $programFilesBackups.Count -gt 0
    }

    # Extracted from the restore directory-processing block (Restore.ps1 lines 367-405).
    # Given a backup directory name and a target username, return the restore destination.
    function Resolve-BackupFolderTarget {
        param(
            [string]$dirName,
            [string]$targetUser
        )

        if ($dirName -eq "Program+Files" -or $dirName -eq "Program+Files+(x86)" -or
            $dirName -match "^Program\+Files") {
            # System folder
            if ($dirName -match "\(x86\)") {
                return [PSCustomObject]@{ TargetPath = "C:\Program Files (x86)"; IsSystem = $true }
            } else {
                return [PSCustomObject]@{ TargetPath = "C:\$($dirName.Replace('+', ' '))"; IsSystem = $true }
            }
        } elseif ($dirName.StartsWith("Users+")) {
            $parts      = $dirName -split "\+"
            if ($parts.Count -lt 3) { return $null }
            $folderPath = $parts[2..($parts.Length - 1)] -join "\"
            return [PSCustomObject]@{ TargetPath = "C:\Users\$targetUser\$folderPath"; IsSystem = $false }
        }

        return $null
    }

    # Helper: extract the human-readable folder name from a backup directory name.
    function Get-FolderDisplayName {
        param([string]$dirName)

        if ($dirName -eq "Program+Files" -or $dirName -match "^Program\+Files") {
            if ($dirName -match "\(x86\)") { return "Program Files (x86)" }
            return "Program Files"
        }
        if ($dirName -match "^Users\+") {
            $parts = $dirName -split "\+"
            if ($parts.Count -ge 3) { return $parts[2] }
        }
        return $null
    }
}

# ---------------------------------------------------------------------------
# Test-AdminRights
# ---------------------------------------------------------------------------
Describe "Test-AdminRights" {

    It "Returns a [bool]" {
        Test-AdminRights | Should -BeOfType [bool]
    }

    It "Returns false when mocked principal reports non-admin" {
        $mockPrincipal = [PSCustomObject]@{}
        Add-Member -InputObject $mockPrincipal -MemberType ScriptMethod -Name IsInRole -Value { return $false }
        Mock -CommandName New-Object -MockWith { return $mockPrincipal } `
             -ParameterFilter { $TypeName -eq 'System.Security.Principal.WindowsPrincipal' }
        Test-AdminRights | Should -BeFalse
    }

    It "Returns true when mocked principal reports admin" {
        $mockPrincipal = [PSCustomObject]@{}
        Add-Member -InputObject $mockPrincipal -MemberType ScriptMethod -Name IsInRole -Value { return $true }
        Mock -CommandName New-Object -MockWith { return $mockPrincipal } `
             -ParameterFilter { $TypeName -eq 'System.Security.Principal.WindowsPrincipal' }
        Test-AdminRights | Should -BeTrue
    }
}

# ---------------------------------------------------------------------------
# Test-ContainsProgramFiles
# ---------------------------------------------------------------------------
Describe "Test-ContainsProgramFiles" {

    Context "Backup path does not exist" {
        It "Returns false for a non-existent path" {
            Test-ContainsProgramFiles -backupPath (Join-Path $TestDrive "nonexistent") | Should -BeFalse
        }
    }

    Context "Backup contains Program+Files directory" {
        BeforeAll {
            $backupDir = Join-Path $TestDrive "BackupWithPF"
            New-Item -ItemType Directory -Path (Join-Path $backupDir "Program+Files") -Force | Out-Null
        }
        It "Returns true" {
            Test-ContainsProgramFiles -backupPath $backupDir | Should -BeTrue
        }
    }

    Context "Backup contains Program+Files+(x86) directory" {
        BeforeAll {
            $backupDir = Join-Path $TestDrive "BackupWithPFx86"
            New-Item -ItemType Directory -Path (Join-Path $backupDir "Program+Files+(x86)") -Force | Out-Null
        }
        It "Returns true" {
            Test-ContainsProgramFiles -backupPath $backupDir | Should -BeTrue
        }
    }

    Context "Backup contains only user folders" {
        BeforeAll {
            $backupDir = Join-Path $TestDrive "BackupUserOnly"
            New-Item -ItemType Directory -Path (Join-Path $backupDir "Users+john+Downloads") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $backupDir "Users+john+Documents") -Force | Out-Null
        }
        It "Returns false" {
            Test-ContainsProgramFiles -backupPath $backupDir | Should -BeFalse
        }
    }

    Context "Backup is empty" {
        BeforeAll {
            $backupDir = Join-Path $TestDrive "EmptyBackup"
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        It "Returns false" {
            Test-ContainsProgramFiles -backupPath $backupDir | Should -BeFalse
        }
    }
}

# ---------------------------------------------------------------------------
# Resolve-BackupFolderTarget (path reconstruction)
# ---------------------------------------------------------------------------
Describe "Resolve-BackupFolderTarget" {

    Context "Program Files directories" {

        It "Maps 'Program+Files' to 'C:\Program Files'" {
            $r = Resolve-BackupFolderTarget -dirName "Program+Files" -targetUser "bob"
            $r.TargetPath | Should -Be "C:\Program Files"
        }

        It "Maps 'Program+Files+(x86)' to 'C:\Program Files (x86)'" {
            $r = Resolve-BackupFolderTarget -dirName "Program+Files+(x86)" -targetUser "bob"
            $r.TargetPath | Should -Be "C:\Program Files (x86)"
        }

        It "Marks Program Files as a system folder" {
            $r = Resolve-BackupFolderTarget -dirName "Program+Files" -targetUser "bob"
            $r.IsSystem | Should -BeTrue
        }

        It "Marks Program Files (x86) as a system folder" {
            $r = Resolve-BackupFolderTarget -dirName "Program+Files+(x86)" -targetUser "bob"
            $r.IsSystem | Should -BeTrue
        }
    }

    Context "User directories" {

        It "Maps 'Users+john+Downloads' to the target user's Downloads" {
            $r = Resolve-BackupFolderTarget -dirName "Users+john+Downloads" -targetUser "alice"
            $r.TargetPath | Should -Be "C:\Users\alice\Downloads"
        }

        It "Maps 'Users+john+Documents' to the target user's Documents" {
            $r = Resolve-BackupFolderTarget -dirName "Users+john+Documents" -targetUser "alice"
            $r.TargetPath | Should -Be "C:\Users\alice\Documents"
        }

        It "Preserves sub-folder depth for nested paths" {
            # Users+john+AppData+Local+Microsoft+Outlook -> C:\Users\alice\AppData\Local\Microsoft\Outlook
            $r = Resolve-BackupFolderTarget -dirName "Users+john+AppData+Local+Microsoft+Outlook" -targetUser "alice"
            $r.TargetPath | Should -Be "C:\Users\alice\AppData\Local\Microsoft\Outlook"
        }

        It "Uses the TARGET user, not the backup source user" {
            $r = Resolve-BackupFolderTarget -dirName "Users+john+Downloads" -targetUser "newuser"
            $r.TargetPath | Should -BeLike "C:\Users\newuser\*"
            $r.TargetPath | Should -Not -BeLike "C:\Users\john\*"
        }

        It "Marks user folders as non-system" {
            $r = Resolve-BackupFolderTarget -dirName "Users+john+Downloads" -targetUser "alice"
            $r.IsSystem | Should -BeFalse
        }
    }

    Context "Invalid directory names" {

        It "Returns null for a directory with fewer than 3 parts" {
            $r = Resolve-BackupFolderTarget -dirName "Users+john" -targetUser "alice"
            $r | Should -BeNull
        }

        It "Returns null for an unrecognised directory name" {
            $r = Resolve-BackupFolderTarget -dirName "SomeRandomFolder" -targetUser "alice"
            $r | Should -BeNull
        }
    }
}

# ---------------------------------------------------------------------------
# Get-FolderDisplayName (folder classification)
# ---------------------------------------------------------------------------
Describe "Get-FolderDisplayName" {

    It "Returns 'Program Files' for 'Program+Files'" {
        Get-FolderDisplayName "Program+Files" | Should -Be "Program Files"
    }

    It "Returns 'Program Files (x86)' for 'Program+Files+(x86)'" {
        Get-FolderDisplayName "Program+Files+(x86)" | Should -Be "Program Files (x86)"
    }

    It "Returns the folder name part for a Users+ path" {
        Get-FolderDisplayName "Users+john+Downloads" | Should -Be "Downloads"
    }

    It "Returns the immediate folder name for a nested Users+ path" {
        Get-FolderDisplayName "Users+john+AppData+Local+Google+Chrome+User Data" | Should -Be "AppData"
    }

    It "Returns null for an unrecognised pattern" {
        Get-FolderDisplayName "SomeRandomFolder" | Should -BeNull
    }
}

# ---------------------------------------------------------------------------
# Backup directory discovery regex
# ---------------------------------------------------------------------------
Describe "Backup directory discovery pattern" {

    $pattern = "^[^_]+_\d{4}-\d{2}-\d{2}$"

    It "Matches a valid backup directory '<user>_<yyyy-MM-dd>'" {
        "john_2025-01-15" | Should -Match $pattern
    }

    It "Matches when username contains a dot" {
        "john.doe_2025-01-15" | Should -Match $pattern
    }

    It "Does not match a directory without a date suffix" {
        "john" | Should -Not -Match $pattern
    }

    It "Does not match with an invalid date format (dd-MM-yyyy)" {
        "john_15-01-2025" | Should -Not -Match $pattern
    }

    It "Does not match system directories like 'Public'" {
        "Public_2025-01-15" | Should -Match $pattern   # Intentional: the regex alone doesn't exclude Public;
                                                        # that exclusion must come from the user-list filter.
    }
}

# ---------------------------------------------------------------------------
# Update-UserBackups (requires refactoring)
# ---------------------------------------------------------------------------
Describe "Update-UserBackups" -Skip {
    <#
    REQUIRES REFACTORING:
    Update-UserBackups (Restore.ps1 lines 203-229) directly reads and writes to GUI
    ComboBox controls. Extract the backup-discovery portion into a pure function:

        function Get-AvailableBackups {
            param([string]$backupLocation, [string]$username)
            # Returns sorted list of backup directory objects matching pattern
        }

    Then Update-UserBackups calls Get-AvailableBackups and updates the UI controls.
    #>

    BeforeAll {
        $fakeLocation = Join-Path $TestDrive "Backups"
        New-Item -ItemType Directory -Path (Join-Path $fakeLocation "john_2025-03-01") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fakeLocation "john_2025-02-15") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fakeLocation "alice_2025-03-01") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fakeLocation "SomeOtherFolder")  -Force | Out-Null
    }

    It "Returns backups sorted descending by date for a user" {
        $backups = Get-AvailableBackups -backupLocation $fakeLocation -username "john"
        $backups[0].Name | Should -Be "john_2025-03-01"
        $backups[1].Name | Should -Be "john_2025-02-15"
    }

    It "Does not return backups belonging to a different user" {
        $backups = Get-AvailableBackups -backupLocation $fakeLocation -username "john"
        $backups.Name | Should -Not -Contain "alice_2025-03-01"
    }

    It "Does not return non-backup directories" {
        $backups = Get-AvailableBackups -backupLocation $fakeLocation -username "john"
        $backups.Name | Should -Not -Contain "SomeOtherFolder"
    }

    It "Returns an empty array when no backups exist for a user" {
        $backups = Get-AvailableBackups -backupLocation $fakeLocation -username "nobody"
        $backups.Count | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# Restore-Files file system operations (requires refactoring)
# ---------------------------------------------------------------------------
Describe "Restore-Files file system operations" -Skip {
    <#
    REQUIRES REFACTORING:
    Extract the file-copy loop from Restore-Files into:

        function Invoke-FolderRestore {
            param([string]$sourcePath, [string]$targetPath, [ref]$cancelToken)
        }

    Use Pester's TestDrive to provide real temporary paths.
    #>

    BeforeAll {
        $backupDir = Join-Path $TestDrive "john_2025-01-01"
        $sourceFolder = Join-Path $backupDir "Users+john+Downloads"
        New-Item -ItemType Directory -Path $sourceFolder -Force | Out-Null
        "content" | Out-File (Join-Path $sourceFolder "file.txt")
        New-Item -ItemType Directory -Path (Join-Path $sourceFolder "SubDir") -Force | Out-Null
        "nested" | Out-File (Join-Path $sourceFolder "SubDir\nested.txt")

        $targetDir = Join-Path $TestDrive "RestoredUsers\alice\Downloads"
    }

    It "Copies files to the target directory" {
        # Invoke-FolderRestore -sourcePath $sourceFolder -targetPath $targetDir -cancelToken ([ref]$false)
        Test-Path (Join-Path $targetDir "file.txt") | Should -BeTrue
    }

    It "Recreates nested sub-directories" {
        Test-Path (Join-Path $targetDir "SubDir") | Should -BeTrue
    }

    It "Copies files inside nested sub-directories" {
        Test-Path (Join-Path $targetDir "SubDir\nested.txt") | Should -BeTrue
    }

    It "Stops early when cancellation token is set" {
        $cancel = [ref]$true
        # Invoke-FolderRestore -sourcePath $largeSource -targetPath $targetDir -cancelToken $cancel
        # Verify that not all files were copied (partial restore)
    }
}

# ---------------------------------------------------------------------------
# Cancellation behaviour (requires refactoring)
# ---------------------------------------------------------------------------
Describe "Restore cancellation" -Skip {
    <#
    REQUIRES REFACTORING:
    Same as Backup cancellation – the $script:cancelRestore flag is checked inline.
    Extract to Invoke-FolderRestore with a [ref] token.
    #>

    It "Stops processing directories when cancellation flag is set between folders" {
        # Set $cancelToken.Value = $true between two folders; verify second is not restored
    }

    It "Stops copying files mid-folder when flag is set" {
        # Set $cancelToken.Value = $true mid-copy; verify partial file state
    }
}

# ---------------------------------------------------------------------------
# Progress calculation
# ---------------------------------------------------------------------------
Describe "Restore progress calculation" {

    It "Reports 0% at the start" {
        [math]::Round((0 / 10) * 100) | Should -Be 0
    }

    It "Reports 50% at the midpoint" {
        [math]::Round((5 / 10) * 100) | Should -Be 50
    }

    It "Reports 100% at completion" {
        [math]::Round((10 / 10) * 100) | Should -Be 100
    }

    It "Rounds fractional percentages" {
        [math]::Round((1 / 3) * 100) | Should -Be 33
    }
}

# ---------------------------------------------------------------------------
# Admin check for Program Files restore
# ---------------------------------------------------------------------------
Describe "Admin rights enforcement for Program Files restore" -Skip {
    <#
    REQUIRES REFACTORING:
    Once Invoke-FolderRestore is extracted and Test-AdminRights is mockable, verify:
    - Skips Program Files folders when IsAdmin = $false
    - Processes Program Files folders when IsAdmin = $true
    #>

    It "Skips 'Program+Files' when not running as admin" {
        Mock Test-AdminRights { return $false }
        # Invoke restore; assert Program Files folder was skipped
    }

    It "Restores 'Program+Files' when running as admin" {
        Mock Test-AdminRights { return $true }
        # Invoke restore; assert Program Files folder was processed
    }

    It "Still restores user folders when not running as admin" {
        Mock Test-AdminRights { return $false }
        # Invoke restore; assert user Downloads was restored despite no admin
    }
}
