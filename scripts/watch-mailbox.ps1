#Requires -Version 5.1
<#
.SYNOPSIS
    Offset-based watcher for a shared file mailbox (Windows PowerShell / PowerShell 7+).

.DESCRIPTION
    Prints only the bytes appended since the last check, and filters out FYI lines
    (that level was never meant to wake you).

    Why not Get-Content -Wait: if the other side rewrites or truncates the file, a
    tailing reader replays the entire history into your context. This script
    realigns its offset to the new length instead, so nothing is replayed.

    Trade-off: if the other side does rewrite the file to something shorter, that
    rewrite's content is skipped. That is deliberate - losing one message beats
    replaying twenty. The real fix is for both sides to only ever append.

    Claude-to-Claude does not need this: anything worth a wake-up goes through
    SendMessage. This is for peers that cannot receive it, such as a non-Claude
    agent writing into a shared file.

    This is the native-Windows counterpart of watch-mailbox.sh. Inside WSL 2, use
    the shell script instead.

.PARAMETER Path
    One or more mailbox files to watch.

.PARAMETER IntervalSeconds
    Seconds between checks. Defaults to 2.

.EXAMPLE
    .\watch-mailbox.ps1 C:\mailbox\peer-to-me.md

.EXAMPLE
    .\watch-mailbox.ps1 -IntervalSeconds 5 C:\mailbox\peer-to-me.md C:\mailbox\other.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path,

    [ValidateRange(1, 3600)]
    [int]$IntervalSeconds = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A missing file counts as 0, the same as the shell version.
function Get-MailboxSize {
    param([string]$File)
    try {
        return (Get-Item -LiteralPath $File -Force -ErrorAction Stop).Length
    }
    catch {
        return [long]0
    }
}

# Read [offset, offset+count) without locking out the writer.
function Read-MailboxRange {
    param([string]$File, [long]$Offset, [int]$Count)
    $buffer = New-Object byte[] $Count
    $stream = [System.IO.File]::Open(
        $File,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite
    )
    try {
        [void]$stream.Seek($Offset, [System.IO.SeekOrigin]::Begin)
        $read = $stream.Read($buffer, 0, $Count)
    }
    finally {
        $stream.Dispose()
    }
    return [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
}

$fyiPattern = '^\[[A-Za-z0-9_-]+ [0-9:]+\]\s*FYI'

$offsets = @{}
foreach ($file in $Path) {
    $offsets[$file] = Get-MailboxSize -File $file
}

while ($true) {
    foreach ($file in $Path) {
        $size = Get-MailboxSize -File $file
        $offset = $offsets[$file]

        if ($size -gt $offset) {
            $chunk = Read-MailboxRange -File $file -Offset $offset -Count ([int]($size - $offset))
            foreach ($line in ($chunk -split "`r?`n")) {
                # Keep message lines, drop FYI.
                if ($line.StartsWith('[') -and $line -notmatch $fyiPattern) {
                    Write-Output $line
                }
            }
            $offsets[$file] = $size
        }
        elseif ($size -lt $offset) {
            # Truncated or replaced: realign, do not replay.
            $offsets[$file] = $size
        }
    }
    Start-Sleep -Seconds $IntervalSeconds
}
