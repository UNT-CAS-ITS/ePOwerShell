[string]           $projectDirectoryName = 'ePOwerShell'
[IO.FileInfo]      $pesterFile = [io.fileinfo] ([string] (Resolve-Path -Path $MyInvocation.MyCommand.Path))
[IO.DirectoryInfo] $projectRoot = Split-Path -Parent $pesterFile.Directory
[IO.DirectoryInfo] $projectDirectory = Join-Path -Path $projectRoot -ChildPath $projectDirectoryName -Resolve
[IO.DirectoryInfo] $exampleDirectory = [IO.DirectoryInfo] ([String] (Resolve-Path (Get-ChildItem (Join-Path -Path $ProjectRoot -ChildPath 'Examples' -Resolve) -Filter (($pesterFile.Name).Split('.')[0]) -Directory).FullName))
[IO.FileInfo]      $testFile = Join-Path -Path $projectDirectory -ChildPath (Join-Path -Path 'Public' -ChildPath ($pesterFile.Name -replace '\.Tests\.', '.')) -Resolve
. $testFile

. $(Join-Path -Path $projectDirectory -ChildPath (Join-Path -Path 'Private' -ChildPath 'Invoke-ePORequest.ps1') -Resolve)
. $(Join-Path -Path $projectDirectory -ChildPath (Join-Path -Path 'Public' -ChildPath 'Find-ePOwerShellComputerSystem.ps1') -Resolve)

[System.Collections.ArrayList] $tests = @()
$examples = Get-ChildItem $exampleDirectory -Filter "$($testFile.BaseName).*.psd1" -File

foreach ($example in $examples) {
    [hashtable] $test = @{
        Name = $example.BaseName.Replace("$($testFile.BaseName).$verb", '').Replace('_', ' ')
    }
    Write-Verbose "Test: $($test | ConvertTo-Json)"

    foreach ($exampleData in (Import-PowerShellDataFile -LiteralPath $example.FullName).GetEnumerator()) {
        $test.Add($exampleData.Name, $exampleData.Value) | Out-Null
    }

    Write-Verbose "Test: $($test | ConvertTo-Json)"
    $tests.Add($test) | Out-Null
}

Describe $testFile.Name {
    foreach ($test in $tests) {
        Mock Find-ePOwerShellComputerSystem {
            if ($Test.FailsToFindComputer) {
                Throw "Failed to find computer"
            }

            $File = Get-ChildItem (Join-Path -Path $exampleDirectory -ChildPath 'References' -Resolve) -Filter ('{0}.html' -f $ComputerName) -File
            return (Get-Content $File.FullName | Out-String).Substring(3).Trim()  | ConvertFrom-Json
        }

        Mock Invoke-ePORequest {
            if ($Query.epoLeafNodeId) {
                $File = Get-ChildItem (Join-Path -Path $exampleDirectory -ChildPath 'References' -Resolve) -Filter ('{0}.html' -f $Query.epoLeafNodeId) -File
            } else {
                $File = Get-ChildItem (Join-Path -Path $exampleDirectory -ChildPath 'References' -Resolve) -Filter ('{0}.html' -f $Query.serialNumber) -File
            }

            if ($File) {
                return (Get-Content $File.FullName | Out-String).Substring(3).Trim()
            }

            Throw "Failed to find file"
        }

        Mock Write-Warning {
            Write-Verbose $Message
        }

        Remove-Variable -Scope 'Script' -Name 'RequestResponse' -Force -ErrorAction SilentlyContinue

        Context $test.Name {
            [hashtable] $parameters = $test.Parameters

            if ($Test.Output.Throws) {
                It "Get-ePOwerShellMneRecoveryKey Throws" {
                    { $script:RequestResponse = Get-ePOwerShellMneRecoveryKey @parameters } | Should Throw
                }
                continue
            }

            if ($Test.Pipeline) {
                It "Get-ePOwerShellMneRecoveryKey Does Not Throws" {
                    { $script:RequestResponse = $Parameters.ComputerName | Get-ePOwerShellMneRecoveryKey } | Should Not Throw
                }
            } else {
                It "Get-ePOwerShellMneRecoveryKey Does Not Throws" {
                    { $script:RequestResponse = Get-ePOwerShellMneRecoveryKey @parameters } | Should Not Throw
                }
            }


            It "Output Type: $($test.Output.Type)" {
                if ($test.Output.Type -eq 'System.Void') {
                    $script:RequestResponse | Should BeNullOrEmpty
                } else {
                    $script:RequestResponse.GetType().FullName | Should Be $test.Output.Type
                }
            }
        }
    }
}