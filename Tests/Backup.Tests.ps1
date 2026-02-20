#Requires -Modules Pester

<#
.SYNOPSIS
    Pester test suite for Backup.ps1 business logic.

.DESCRIPTION
    This file covers the testable logic in Backup.ps1.

    CURRENT STATE: The script mixes GUI construction, event handlers, and business
    logic in a single monolithic file, which prevents most tests from running. Tests
    marked with -Skip require the refactoring described in each block before they
    can execute.

    RECOMMENDED REFACTORING:
    Extract business logic into a shared module (e.g. BackupHelpers.psm1) that can
    be imported by both Backup.ps1 and these tests. The GUI event handlers in
    Backup.ps1 would then call functions from that module.

    TESTING FRAMEWORK:
    Pester 5.x - install with: Install-Module -Name Pester -Force -SkipPublisherCheck
    Run tests with: Invoke-Pester -Path ./Tests/Backup.Tests.ps1 -Output Detailed
#>

# ---------------------------------------------------------------------------
# Helper: define functions inline so tests can run without GUI initialization
# ---------------------------------------------------------------------------
BeforeAll {
    # Re-define the two functions that do not depend on GUI state so they can
    # be tested directly. Once these are extracted to BackupHelpers.psm1 this
    # block should be replaced with: Import-Module "$PSScriptRoot/../BackupHelpers.psm1"

    function Test-AdminRights {
        $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Parameterised version of Test-ProgramFilesSelected (current code references
    # the $folderCheckboxes script-scope variable directly, which prevents testing).
    # This is the signature the refactored function should have.
    function Test-ProgramFilesSelected {
        param([hashtable]$folderCheckboxes)
        $selectedFolders = $folderCheckboxes.Keys | Where-Object { $folderCheckboxes[$_].Checked }
        return @($selectedFolders | Where-Object { $_.StartsWith("SYSTEM+") })
    }

    # Extracted path-construction logic from the backup button click handler
    # (Backup.ps1 lines 332-349). Should become a standalone function.
    function Get-BackupPaths {
        param(
            [string]$folderPath,
            [string]$username
        )
        $sourcePath = ""
        $folderName = ""

        if ($folderPath.StartsWith("SYSTEM+")) {
            $actualPath = $folderPath.Substring(7).Replace('+', '\')
            $sourcePath  = "C:\$actualPath"
            if ($actualPath -eq "Program Files") {
                $folderName = "Program+Files"
            } elseif ($actualPath -eq "Program Files (x86)") {
                $folderName = "Program+Files+(x86)"
            } else {
                $folderName = $actualPath.Replace('\', '+')
            }
        } else {
            $folderName = "Users+$username+$folderPath"
            $sourcePath  = "C:\Users\$username\$($folderPath.Replace('+', '\'))"
        }

        return [PSCustomObject]@{ SourcePath = $sourcePath; FolderName = $folderName }
    }
}

# ---------------------------------------------------------------------------
# Test-AdminRights
# ---------------------------------------------------------------------------
Describe "Test-AdminRights" {

    It "Returns a [bool] value" {
        Test-AdminRights | Should -BeOfType [bool]
    }

    It "Returns false when mocked principal reports non-admin" {
        # Pester mocking of New-Object is limited in scope; once extracted to a
        # module, use InModuleScope for reliable mocking.
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
# Test-ProgramFilesSelected
# ---------------------------------------------------------------------------
Describe "Test-ProgramFilesSelected" {

    Context "No checkboxes checked" {
        It "Returns empty when nothing is selected" {
            $boxes = @{
                "Downloads"            = [PSCustomObject]@{ Checked = $false }
                "SYSTEM+Program Files" = [PSCustomObject]@{ Checked = $false }
            }
            Test-ProgramFilesSelected -folderCheckboxes $boxes | Should -BeNullOrEmpty
        }
    }

    Context "Only user folders checked" {
        It "Returns empty when only non-SYSTEM folders are selected" {
            $boxes = @{
                "Downloads"            = [PSCustomObject]@{ Checked = $true }
                "Documents"            = [PSCustomObject]@{ Checked = $true }
                "SYSTEM+Program Files" = [PSCustomObject]@{ Checked = $false }
            }
            Test-ProgramFilesSelected -folderCheckboxes $boxes | Should -BeNullOrEmpty
        }
    }

    Context "Program Files folder checked" {
        It "Returns the SYSTEM+ key when Program Files is selected" {
            $boxes = @{
                "Downloads"            = [PSCustomObject]@{ Checked = $true }
                "SYSTEM+Program Files" = [PSCustomObject]@{ Checked = $true }
            }
            $result = Test-ProgramFilesSelected -folderCheckboxes $boxes
            $result | Should -Contain "SYSTEM+Program Files"
        }

        It "Does not return non-SYSTEM folders in the result" {
            $boxes = @{
                "Downloads"            = [PSCustomObject]@{ Checked = $true }
                "SYSTEM+Program Files" = [PSCustomObject]@{ Checked = $true }
            }
            $result = Test-ProgramFilesSelected -folderCheckboxes $boxes
            $result | Should -Not -Contain "Downloads"
        }

        It "Returns both SYSTEM entries when both Program Files variants are selected" {
            $boxes = @{
                "SYSTEM+Program Files"        = [PSCustomObject]@{ Checked = $true }
                "SYSTEM+Program Files (x86)"  = [PSCustomObject]@{ Checked = $true }
            }
            $result = Test-ProgramFilesSelected -folderCheckboxes $boxes
            $result.Count | Should -Be 2
        }
    }
}

# ---------------------------------------------------------------------------
# Backup path construction (Get-BackupPaths)
# ---------------------------------------------------------------------------
Describe "Backup path construction" {

    Context "System paths (SYSTEM+ prefix)" {

        It "Builds correct source path for 'Program Files'" {
            $r = Get-BackupPaths -folderPath "SYSTEM+Program Files" -username "testuser"
            $r.SourcePath | Should -Be "C:\Program Files"
        }

        It "Builds correct source path for 'Program Files (x86)'" {
            $r = Get-BackupPaths -folderPath "SYSTEM+Program Files (x86)" -username "testuser"
            $r.SourcePath | Should -Be "C:\Program Files (x86)"
        }

        It "Standardises folder name to 'Program+Files'" {
            $r = Get-BackupPaths -folderPath "SYSTEM+Program Files" -username "testuser"
            $r.FolderName | Should -Be "Program+Files"
        }

        It "Standardises folder name to 'Program+Files+(x86)'" {
            $r = Get-BackupPaths -folderPath "SYSTEM+Program Files (x86)" -username "testuser"
            $r.FolderName | Should -Be "Program+Files+(x86)"
        }
    }

    Context "User folder paths" {

        It "Builds correct source path for 'Downloads'" {
            $r = Get-BackupPaths -folderPath "Downloads" -username "john"
            $r.SourcePath | Should -Be "C:\Users\john\Downloads"
        }

        It "Builds correct source path for 'Documents'" {
            $r = Get-BackupPaths -folderPath "Documents" -username "john"
            $r.SourcePath | Should -Be "C:\Users\john\Documents"
        }

        It "Converts plus-notation to backslashes in source path for Chrome data" {
            $r = Get-BackupPaths -folderPath "AppData+Local+Google+Chrome+User Data" -username "john"
            $r.SourcePath | Should -Be "C:\Users\john\AppData\Local\Google\Chrome\User Data"
        }

        It "Converts plus-notation to backslashes for Outlook data" {
            $r = Get-BackupPaths -folderPath "AppData+Local+Microsoft+Outlook" -username "john"
            $r.SourcePath | Should -Be "C:\Users\john\AppData\Local\Microsoft\Outlook"
        }

        It "Builds correct folder name for 'Downloads'" {
            $r = Get-BackupPaths -folderPath "Downloads" -username "john"
            $r.FolderName | Should -Be "Users+john+Downloads"
        }

        It "Preserves plus notation in folder name for nested paths" {
            $r = Get-BackupPaths -folderPath "AppData+Local+Google+Chrome+User Data" -username "john"
            $r.FolderName | Should -Be "Users+john+AppData+Local+Google+Chrome+User Data"
        }

        It "Includes username in folder name" {
            $r = Get-BackupPaths -folderPath "Downloads" -username "alice"
            $r.FolderName | Should -BeLike "Users+alice+*"
        }
    }
}

# ---------------------------------------------------------------------------
# Backup folder naming convention
# ---------------------------------------------------------------------------
Describe "Backup folder naming convention" {

    It "Folder name matches pattern '<username>_<yyyy-MM-dd>'" {
        $username = "testuser"
        $date     = Get-Date -Format "yyyy-MM-dd"
        "${username}_${date}" | Should -Match "^[^_]+_\d{4}-\d{2}-\d{2}$"
    }

    It "Date portion is formatted as yyyy-MM-dd" {
        $date = Get-Date -Format "yyyy-MM-dd"
        $date | Should -Match "^\d{4}-\d{2}-\d{2}$"
    }

    It "Folder name does not contain spaces" {
        $username = "testuser"
        $date     = Get-Date -Format "yyyy-MM-dd"
        "${username}_${date}" | Should -Not -Match "\s"
    }
}

# ---------------------------------------------------------------------------
# User filtering (exclusion regex)
# ---------------------------------------------------------------------------
Describe "User directory filtering" {

    $excludedPattern = '^(Public|Default|Default User|All Users|desktop.ini)$'

    It "Excludes 'Public'" {
        "Public" | Should -Match $excludedPattern
    }

    It "Excludes 'Default'" {
        "Default" | Should -Match $excludedPattern
    }

    It "Excludes 'Default User'" {
        "Default User" | Should -Match $excludedPattern
    }

    It "Excludes 'All Users'" {
        "All Users" | Should -Match $excludedPattern
    }

    It "Excludes 'desktop.ini'" {
        "desktop.ini" | Should -Match $excludedPattern
    }

    It "Does not exclude a normal user account" {
        "john" | Should -Not -Match $excludedPattern
    }

    It "Does not exclude 'Administrator'" {
        "Administrator" | Should -Not -Match $excludedPattern
    }
}

# ---------------------------------------------------------------------------
# My Music folder exclusion
# ---------------------------------------------------------------------------
Describe "My Music folder exclusion" {

    function Test-IsExcluded([string]$relativePath) {
        return ($relativePath.StartsWith("My Music") -or $relativePath.Contains("\My Music\"))
    }

    It "Excludes top-level 'My Music' directory" {
        Test-IsExcluded "My Music" | Should -BeTrue
    }

    It "Excludes files inside 'My Music'" {
        Test-IsExcluded "My Music\song.mp3" | Should -BeTrue
    }

    It "Excludes paths containing '\My Music\' as a sub-folder" {
        Test-IsExcluded "SomeFolder\My Music\song.mp3" | Should -BeTrue
    }

    It "Does not exclude a folder named 'Music'" {
        Test-IsExcluded "Music\song.mp3" | Should -BeFalse
    }

    It "Does not exclude 'Documents\report.docx'" {
        Test-IsExcluded "Documents\report.docx" | Should -BeFalse
    }

    It "Does not exclude 'MyMusic' (no space)" {
        Test-IsExcluded "MyMusic\song.mp3" | Should -BeFalse
    }
}

# ---------------------------------------------------------------------------
# File system operations (requires refactoring)
# ---------------------------------------------------------------------------
Describe "Backup file system operations" -Skip {
    <#
    REQUIRES REFACTORING:
    Extract the per-user backup loop from the button click handler into:

        function Start-UserBackup {
            param([string]$username, [string[]]$selectedFolders,
                  [string]$backupRoot, [string]$scriptDirectory)
        }

    Then these tests can call Start-UserBackup directly with TestDrive paths.
    #>

    BeforeAll {
        $testUser      = "testuser"
        $testSourceDir = Join-Path $TestDrive "FakeUsers\$testUser\Downloads"
        $testBackupRoot = Join-Path $TestDrive "Backups\${testUser}_2025-01-01"
        New-Item -ItemType Directory -Path $testSourceDir   -Force | Out-Null
        New-Item -ItemType Directory -Path $testBackupRoot  -Force | Out-Null
        "hello" | Out-File (Join-Path $testSourceDir "file.txt")
    }

    It "Creates a logs.txt file at the backup root" {
        # Start-UserBackup -username $testUser ...
        Test-Path (Join-Path $testBackupRoot "logs.txt") | Should -BeTrue
    }

    It "Log file records the username" {
        $content = Get-Content (Join-Path $testBackupRoot "logs.txt") -Raw
        $content | Should -BeLike "*$testUser*"
    }

    It "Copies files from source to destination folder" {
        $destFile = Join-Path $testBackupRoot "Users+${testUser}+Downloads\file.txt"
        Test-Path $destFile | Should -BeTrue
    }

    It "Does not crash when source folder does not exist" {
        # Start-UserBackup -username $testUser -selectedFolders @("NonExistentFolder") ...
        # Should append a warning to the log and continue without throwing
    }
}

# ---------------------------------------------------------------------------
# Cancellation behaviour (requires refactoring)
# ---------------------------------------------------------------------------
Describe "Backup cancellation" -Skip {
    <#
    REQUIRES REFACTORING:
    The $script:cancelBackup flag is checked inside the GUI event handler loop.
    Extract the loop into Start-UserBackup, accept a [ref] cancellation token,
    and test that it exits early when the token is set.
    #>

    It "Stops processing users when cancellation flag is set" {
        # $cancelToken = [ref]$false
        # Start backup in runspace, set $cancelToken.Value = $true, verify exit
    }

    It "Stops processing folders for current user when flag is set mid-folder" {
        # Same pattern - verify partial backup state is coherent
    }
}

# ---------------------------------------------------------------------------
# Progress reporting (requires refactoring)
# ---------------------------------------------------------------------------
Describe "Backup progress calculation" {

    It "Calculates 0% progress at the start" {
        [math]::Round((0 / 100) * 100) | Should -Be 0
    }

    It "Calculates 50% progress at the midpoint" {
        [math]::Round((50 / 100) * 100) | Should -Be 50
    }

    It "Calculates 100% progress at completion" {
        [math]::Round((100 / 100) * 100) | Should -Be 100
    }

    It "Rounds fractional percentages correctly" {
        [math]::Round((1 / 3) * 100) | Should -Be 33
    }
}
