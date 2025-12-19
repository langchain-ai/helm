#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Collects Kubernetes debugging information for a given namespace.

.DESCRIPTION
    This script collects comprehensive debugging information from a Kubernetes namespace,
    including resource summaries, events, pod metrics, and container logs. Output is
    bundled into a compressed archive.

.PARAMETER Namespace
    Kubernetes namespace to collect debugging information from (required).

.EXAMPLE
    .\get_k8s_debugging_info.ps1 -Namespace "langsmith"

.NOTES
    - Requires kubectl to be installed and configured
    - Output directory is created in $env:TEMP
    - Logs are collected for the last 24 hours by default
    - Previous logs are collected for containers that have restarted
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Namespace
)

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

# Validate kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "kubectl not found in PATH"
    exit 1
}

# Validate namespace exists
try {
    $null = kubectl get namespace $Namespace 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Namespace '$Namespace' does not exist or you do not have access."
        exit 1
    }
} catch {
    Write-ErrorMsg "Failed to validate namespace: $_"
    exit 1
}

# Create output directory
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$dir = Join-Path $env:TEMP "langchain-debugging-$timestamp"

Write-Info "Starting to pull debugging info. Creating directory $dir..."
New-Item -ItemType Directory -Path $dir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $dir "logs") -Force | Out-Null

# Helper function to capture command output
function Capture-Output {
    param(
        [string]$Description,
        [string]$Command,
        [string]$OutputFile
    )
    
    Write-Info "Pulling $Description..."
    $outputPath = Join-Path $dir $OutputFile
    
    try {
        $result = Invoke-Expression $Command 2>&1
        if ($LASTEXITCODE -eq 0) {
            $result | Out-File -FilePath $outputPath -Encoding utf8
            Write-Success "Saved: $OutputFile"
        } else {
            Write-Warn "Failed to capture $Description (exit code: $LASTEXITCODE)"
            $result | Out-File -FilePath $outputPath -Encoding utf8
        }
    } catch {
        Write-Warn "Failed to capture $Description (see $OutputFile)"
        "Error: $_" | Out-File -FilePath $outputPath -Encoding utf8
    }
}

# Capture resource summaries
Capture-Output "summary of resources" "kubectl get all -n '$Namespace' -o wide" "resources_summary.txt"

# Capture resource details
Capture-Output "details of all resources" "kubectl get all -n '$Namespace' -o yaml" "resources_details.yaml"

# Capture events
Capture-Output "kubernetes events" "kubectl get events -n '$Namespace' --sort-by=.lastTimestamp" "events.txt"

# Capture pod resource usage
try {
    $null = kubectl top pods -n $Namespace --containers 2>&1
    if ($LASTEXITCODE -eq 0) {
        Capture-Output "resource usage for all pods" "kubectl top pods -n '$Namespace' --containers" "pod-resource-usage.txt"
    } else {
        Write-Warn "Metrics not available for pods (metrics-server likely missing). Skipping pod-resource-usage.txt"
    }
} catch {
    Write-Warn "Failed to get pod metrics: $_"
}

# Get all pods
Write-Info "Pulling container logs for all pods. Also pulling previous logs from restarted containers..."
$pods = @()
try {
    $podsJson = kubectl get pods -n $Namespace -o json 2>&1
    if ($LASTEXITCODE -eq 0 -and $podsJson) {
        $podsObj = $podsJson | ConvertFrom-Json
        if ($podsObj.items) {
            $pods = $podsObj.items | ForEach-Object { $_.metadata.name }
        }
    } else {
        Write-Warn "Failed to get pods (exit code: $LASTEXITCODE)"
    }
} catch {
    Write-Warn "Failed to get pods: $_"
}

if ($pods.Count -eq 0) {
    Write-Warn "No pods found in namespace $Namespace; skipping logs."
} else {
    foreach ($pod in $pods) {
        try {
            # Get containers for this pod
            $podJson = kubectl get pod $pod -n $Namespace -o json 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "Failed to get pod $pod details: $podJson"
                continue
            }
            
            $podObj = $podJson | ConvertFrom-Json
            $containers = $podObj.spec.containers | ForEach-Object { $_.name }
            
            foreach ($container in $containers) {
                Write-Info "Pulling current container logs (last 24h) for ${pod}/${container}..."
                $currentLogPath = Join-Path $dir "logs" "${pod}_${container}_current.log"
                
                try {
                    $logs = kubectl logs -n $Namespace $pod -c $container --since=24h 2>&1
                    $logs | Out-File -FilePath $currentLogPath -Encoding utf8
                } catch {
                    Write-Warn "Failed to get current logs for ${pod}/${container}: $_"
                }
                
                # Check restart count and get previous logs if needed
                $restartCount = 0
                try {
                    if ($podObj.status -and $podObj.status.containerStatuses) {
                        $containerStatus = $podObj.status.containerStatuses | Where-Object { $_.name -eq $container }
                        if ($containerStatus -and $null -ne $containerStatus.restartCount) {
                            $restartCount = [int]$containerStatus.restartCount
                        }
                    }
                } catch {
                    Write-Warn "Failed to check restart count for ${pod}/${container}: $_"
                }
                
                if ($restartCount -gt 0) {
                    Write-Info "  ${pod}/${container} restarted ($restartCount times) - grabbing previous logs..."
                    $previousLogPath = Join-Path $dir "logs" "${pod}_${container}_previous.log"
                    
                    try {
                        $previousLogs = kubectl logs -n $Namespace $pod -c $container --previous 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $previousLogs | Out-File -FilePath $previousLogPath -Encoding utf8
                        } else {
                            Write-Warn "Failed to get previous logs for ${pod}/${container} (exit code: $LASTEXITCODE)"
                        }
                    } catch {
                        Write-Warn "Failed to get previous logs for ${pod}/${container}: $_"
                    }
                }
            }
        } catch {
            Write-Warn "Error processing pod $pod : $_"
        }
    }
}

# Compress directory
Write-Info "Compressing directory..."
$zipPath = "$dir.zip"

try {
    # Use PowerShell's Compress-Archive (available in PowerShell 5.0+)
    Compress-Archive -Path $dir -DestinationPath $zipPath -Force
    Write-Success "Bundle written to $zipPath"
} catch {
    Write-Warn "Failed to create zip archive: $_"
    Write-Warn "Attempting to use tar (if available)..."
    
    try {
        # Try tar (available in Windows 10 1803+ and Windows Server 2019+)
        $tarPath = "$dir.tar.gz"
        $parentDir = Split-Path -Parent $dir
        $dirName = Split-Path -Leaf $dir
        
        Push-Location $parentDir
        tar -czf $tarPath $dirName 2>&1 | Out-Null
        Pop-Location
        
        if (Test-Path $tarPath) {
            Write-Success "Bundle written to $tarPath"
        } else {
            Write-ErrorMsg "Failed to create archive. Please ensure Compress-Archive or tar is available."
            exit 1
        }
    } catch {
        Write-ErrorMsg "Unable to create archive. Please ensure Compress-Archive (PowerShell 5.0+) or tar (Windows 10 1803+) is available."
        exit 1
    }
}

Write-Success "Diagnostics capture complete."
Write-Info "Output directory: $dir"
$archivePath = if (Test-Path $zipPath) { $zipPath } else { "$dir.tar.gz" }
Write-Info "Archive: $archivePath"

