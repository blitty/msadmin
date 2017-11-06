# MIT License
#
# Copyright (c) 2017 Matthew Bonner
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

$minchar = 3

$cont = $true

while ($cont) {

    $search = Read-Host -Prompt 'Search for user'

    if ($search.Length -eq 0) {
        $cont = $false
        continue
    }

    if ($search.Length -lt $minchar) {
        Write-Host "Please enter at least $minchar characters as a search filter"
        continue
    }

    [array]$results = Get-ADUser -Filter {anr -eq $search}

    foreach ($user in $results) {
        Write-Host "[$($results.IndexOf($user)+1)] $($user.Name) ($($user.SamAccountName.toLower()))"
    }

    if ($results.count -gt 0) {
        $unlock = -1
        while ($unlock -eq -1) {
            $raw = Read-Host -Prompt 'Unlock user (Enter to cancel)'
            if (!$raw) {
                break
            }
            if (($raw -as [int]) -ne $null) {
                $unlock = [int]$raw
                if ($unlock -lt 1 -or $unlock -gt $results.count) {
                    $unlock = -1
                } else {
                    $target = $results[$unlock-1]
                    Write-Host "Unlocking $($target.Name)"
                    try {
                        $target | Unlock-ADAccount -ErrorAction Stop
                    } catch {
                        Write-Host 'Could not unlock account. Ensure you are running this script with suitable privilege.'
                    }
                }
            }
        }
    } else {
        Write-Host 'No users found'
    }

}
