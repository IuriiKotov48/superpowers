Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Show-Usage {
  @"
Usage:
  delegate_task.ps1 --task-file <path> --report-file <path> [--workdir <path>] [--router <auto|manual>] [--task-type <name>] [--input-volume <small|medium|large>] [--requires-strategy <yes|no>] [--model <provider/model>] [--flash-model <provider/model>] [--k2-model <provider/model>] [--frontend-model <provider/model>] [--coordinator-model <provider/model>] [--external-coordinator-model <provider/model>] [--local-coordinator-label <label>] [--allow-external-coordinator <yes|no>] [--detail-level <compact|balanced|diagnostic>] [--timeout-sec <seconds>] [--retries <count>] [--raw-policy <always|on-blocked|never>] [--excerpt-lines <count>] [--allow-path <pattern>] [--allow-non-git]
"@
}

function Resolve-PathFromWorkdir {
  param(
    [Parameter(Mandatory = $true)][string]$PathValue,
    [Parameter(Mandatory = $true)][string]$Workdir
  )
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Workdir $PathValue))
}

function Get-GitChanges {
  param([Parameter(Mandatory = $true)][string]$Workdir)
  $lines = git -C $Workdir status --porcelain=v1 --untracked-files=all 2>$null
  $items = @()
  foreach ($line in $lines) {
    if ($line.Length -lt 4) { continue }
    $entry = $line.Substring(3)
    $arrowIndex = $entry.IndexOf(" -> ")
    if ($arrowIndex -ge 0) {
      $entry = $entry.Substring($arrowIndex + 4)
    }
    if (-not [string]::IsNullOrWhiteSpace($entry)) {
      $items += ($entry -replace "\\", "/")
    }
  }
  return $items | Sort-Object -Unique
}

function Write-BlockedReport {
  param(
    [Parameter(Mandatory = $true)][string]$ReportFile,
    [Parameter(Mandatory = $true)][string]$Summary,
    [Parameter(Mandatory = $true)][string]$Workdir,
    [Parameter(Mandatory = $true)][string]$ModelLabel,
    [string[]]$Blockers = @()
  )
  $content = @()
  $content += "BEGIN_REPORT"
  $content += "STATUS: BLOCKED"
  $content += "SUMMARY: $Summary"
  $content += "WORKDIR: $Workdir"
  $content += "MODEL: $ModelLabel"
  $content += "TASK_TYPE: $taskType"
  $content += "MODEL_ROLE: $modelRole"
  $content += "TARGET_MODEL: $targetModel"
  $content += "INPUT_VOLUME: $inputVolume"
  $content += "REQUIRES_STRATEGY: $requiresStrategy"
  $content += "ROUTER_MODE: $routerMode"
  $content += "ROUTING_REASON: $routingReason"
  $content += "LOCAL_COORDINATOR: $localCoordinatorLabel"
  $content += "EXTERNAL_COORDINATOR_MODEL: $coordinatorModel"
  $content += "EXTERNAL_COORDINATOR_ALLOWED: $allowExternalCoordinator"
  $content += "DETAIL_LEVEL: $detailLevel"
  $content += "CONFIDENCE: low"
  $content += "RISK: medium"
  $content += "NEEDS_MORE_CONTEXT: yes"
  $content += "ARTIFACTS: none"
  $content += "RAW_EXCERPT: none"
  $content += "RAW_LOG: none"
  $content += "CHECKS:"
  $content += "- workdir=$Workdir"
  $content += "- model=$ModelLabel"
  $content += "BLOCKERS:"
  if ($Blockers.Count -eq 0) {
    $content += "- none"
  } else {
    foreach ($b in $Blockers) {
      $content += "- $b"
    }
  }
  $content += "END_REPORT"
  Set-Content -Path $ReportFile -Value ($content -join "`n") -NoNewline
}

function Ensure-Field {
  param(
    [Parameter(Mandatory = $true)][string[]]$Lines,
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][string]$Value,
    [Parameter(Mandatory = $true)][string]$InsertAfterPrefix
  )
  if ($Lines -match "^$([regex]::Escape($Prefix))") {
    return ,$Lines
  }
  $out = New-Object System.Collections.Generic.List[string]
  $inserted = $false
  foreach ($line in $Lines) {
    $out.Add($line)
    if (-not $inserted -and $line -match "^$([regex]::Escape($InsertAfterPrefix))") {
      $out.Add("$Prefix$Value")
      $inserted = $true
    }
  }
  if (-not $inserted) {
    $out.Add("$Prefix$Value")
  }
  return ,$out.ToArray()
}

function Set-OrInsertField {
  param(
    [Parameter(Mandatory = $true)][string[]]$Lines,
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][string]$Value
  )
  $out = New-Object System.Collections.Generic.List[string]
  $updated = $false
  foreach ($line in $Lines) {
    if ($line -match "^$([regex]::Escape($Prefix))") {
      $out.Add("$Prefix$Value")
      $updated = $true
      continue
    }
    if (-not $updated -and $line -eq "END_REPORT") {
      $out.Add("$Prefix$Value")
      $updated = $true
    }
    $out.Add($line)
  }
  if (-not $updated) {
    $out.Add("$Prefix$Value")
  }
  return ,$out.ToArray()
}

function Get-FieldValue {
  param(
    [Parameter(Mandatory = $true)][string[]]$Lines,
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][string]$DefaultValue
  )
  $line = $Lines | Where-Object { $_ -match "^$([regex]::Escape($Prefix))" } | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($line)) {
    return $DefaultValue
  }
  return ($line.Substring($Prefix.Length)).Trim()
}

function Write-RawExcerpt {
  param(
    [Parameter(Mandatory = $true)][string]$RawFile,
    [Parameter(Mandatory = $true)][string]$ExcerptFile,
    [Parameter(Mandatory = $true)][int]$ExcerptLines
  )
  if (-not (Test-Path -Path $RawFile -PathType Leaf)) {
    return $false
  }
  $all = Get-Content -Path $RawFile
  if ($all.Count -le ($ExcerptLines * 2)) {
    Set-Content -Path $ExcerptFile -Value ($all -join "`n") -NoNewline
    return $true
  }
  $head = $all | Select-Object -First $ExcerptLines
  $tail = $all | Select-Object -Last $ExcerptLines
  $out = @()
  $out += $head
  $out += "--- TRUNCATED ---"
  $out += $tail
  Set-Content -Path $ExcerptFile -Value ($out -join "`n") -NoNewline
  return $true
}

function Remove-RawArtifacts {
  param([Parameter(Mandatory = $true)][string]$RawFile)
  if (Test-Path -Path $RawFile -PathType Leaf) {
    Remove-Item -Path $RawFile -Force -ErrorAction SilentlyContinue
  }
  $attemptFiles = Get-ChildItem -Path "$RawFile.attempt*" -File -ErrorAction SilentlyContinue
  foreach ($f in $attemptFiles) {
    Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
  }
}

function Get-ModelRouting {
  param(
    [Parameter(Mandatory = $true)][string]$RouterMode,
    [Parameter(Mandatory = $true)][string]$TaskType,
    [Parameter(Mandatory = $true)][string]$InputVolume,
    [Parameter(Mandatory = $true)][string]$RequiresStrategy,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$ExplicitModel,
    [Parameter(Mandatory = $true)][string]$FlashModel,
    [Parameter(Mandatory = $true)][string]$K2Model,
    [Parameter(Mandatory = $true)][string]$FrontendModel,
    [Parameter(Mandatory = $true)][string]$ExternalCoordinatorModel,
    [Parameter(Mandatory = $true)][string]$LocalCoordinatorLabel,
    [Parameter(Mandatory = $true)][string]$AllowExternalCoordinator
  )

  if (-not [string]::IsNullOrWhiteSpace($ExplicitModel)) {
    return [PSCustomObject]@{
      TargetModel = $ExplicitModel
      ModelRole = "manual-override"
      RoutingReason = "Explicit --model was provided"
      RequiresCoordinatorDecision = $false
    }
  }

  if ($RouterMode -eq "manual") {
    return [PSCustomObject]@{
      TargetModel = "default"
      ModelRole = "manual-selection"
      RoutingReason = "router=manual with no explicit model"
      RequiresCoordinatorDecision = $false
    }
  }

  if ($RequiresStrategy -eq "yes") {
    return [PSCustomObject]@{
      TargetModel = "none"
      ModelRole = "coordinator-required"
      RoutingReason = "requires_strategy=yes; local coordinator decision required"
      RequiresCoordinatorDecision = $true
    }
  }

  $normalizedTask = $TaskType.ToLowerInvariant()
  switch ($normalizedTask) {
    "big-context-analysis" {
      return [PSCustomObject]@{
        TargetModel = $FlashModel
        ModelRole = "context-synthesizer"
        RoutingReason = "Large-context summarization task routed to Flash"
        RequiresCoordinatorDecision = $false
      }
    }
    "log-parsing" {
      return [PSCustomObject]@{
        TargetModel = $FlashModel
        ModelRole = "data-extractor"
        RoutingReason = "Log parsing routed to Flash"
        RequiresCoordinatorDecision = $false
      }
    }
    "metric-aggregation" {
      return [PSCustomObject]@{
        TargetModel = $FlashModel
        ModelRole = "data-extractor"
        RoutingReason = "Metric aggregation routed to Flash"
        RequiresCoordinatorDecision = $false
      }
    }
    "checklist-execution" {
      return [PSCustomObject]@{
        TargetModel = $FlashModel
        ModelRole = "mechanical-operator"
        RoutingReason = "Checklist execution routed to Flash"
        RequiresCoordinatorDecision = $false
      }
    }
    "report-formatting" {
      return [PSCustomObject]@{
        TargetModel = $FlashModel
        ModelRole = "formatter"
        RoutingReason = "Report formatting routed to Flash"
        RequiresCoordinatorDecision = $false
      }
    }
    "mechanical-code-edit" {
      return [PSCustomObject]@{
        TargetModel = $K2Model
        ModelRole = "code-executor"
        RoutingReason = "Deterministic code edit routed to K2"
        RequiresCoordinatorDecision = $false
      }
    }
    "test-scaffolding" {
      return [PSCustomObject]@{
        TargetModel = $K2Model
        ModelRole = "code-executor"
        RoutingReason = "Test scaffolding routed to K2"
        RequiresCoordinatorDecision = $false
      }
    }
    "frontend-implementation" {
      return [PSCustomObject]@{
        TargetModel = $FrontendModel
        ModelRole = "frontend-specialist"
        RoutingReason = "Frontend implementation routed to DeepSeek V3.2"
        RequiresCoordinatorDecision = $false
      }
    }
    "frontend-styling" {
      return [PSCustomObject]@{
        TargetModel = $FrontendModel
        ModelRole = "frontend-specialist"
        RoutingReason = "Frontend styling routed to DeepSeek V3.2"
        RequiresCoordinatorDecision = $false
      }
    }
    "frontend-bugfix" {
      return [PSCustomObject]@{
        TargetModel = $FrontendModel
        ModelRole = "frontend-specialist"
        RoutingReason = "Frontend bugfix routed to DeepSeek V3.2"
        RequiresCoordinatorDecision = $false
      }
    }
    "architecture-decision" {
      return [PSCustomObject]@{
        TargetModel = "none"
        ModelRole = "coordinator-required"
        RoutingReason = "architecture-decision requires local coordinator"
        RequiresCoordinatorDecision = $true
      }
    }
    "strategy-decision" {
      return [PSCustomObject]@{
        TargetModel = "none"
        ModelRole = "coordinator-required"
        RoutingReason = "strategy-decision requires local coordinator"
        RequiresCoordinatorDecision = $true
      }
    }
    "complex-refactor-planning" {
      return [PSCustomObject]@{
        TargetModel = "none"
        ModelRole = "coordinator-required"
        RoutingReason = "complex-refactor-planning requires local coordinator"
        RequiresCoordinatorDecision = $true
      }
    }
    "external-coordinator-consult" {
      if ($AllowExternalCoordinator -eq "yes") {
        return [PSCustomObject]@{
          TargetModel = $ExternalCoordinatorModel
          ModelRole = "expert-consultant"
          RoutingReason = "External coordinator consult explicitly enabled"
          RequiresCoordinatorDecision = $false
        }
      }
      return [PSCustomObject]@{
        TargetModel = "none"
        ModelRole = "coordinator-required"
        RoutingReason = "External coordinator consult requested but disabled; local coordinator required"
        RequiresCoordinatorDecision = $true
      }
    }
    default {
      if ($InputVolume -eq "large") {
        return [PSCustomObject]@{
          TargetModel = $FlashModel
          ModelRole = "context-synthesizer"
          RoutingReason = "Auto fallback to Flash because input_volume=large"
          RequiresCoordinatorDecision = $false
        }
      }
      return [PSCustomObject]@{
        TargetModel = $K2Model
        ModelRole = "general-mechanical-executor"
        RoutingReason = "Auto fallback to K2 for bounded mechanical work"
        RequiresCoordinatorDecision = $false
      }
    }
  }
}

$workdir = ""
$taskFile = ""
$reportFile = ""
$routerMode = "auto"
$taskType = "generic-mechanical"
$inputVolume = "medium"
$requiresStrategy = "no"
$model = ""
$flashModel = "openrouter/z-ai/glm-4.7-flash"
$k2Model = "kimi-for-coding/k2p5"
$frontendModel = "openrouter/deepseek/deepseek-v3.2"
$coordinatorModel = "openrouter/deepseek/deepseek-v3.2"
$localCoordinatorLabel = "codex-orchestrator"
$allowExternalCoordinator = "no"
$detailLevel = "balanced"
$timeoutSec = 600
$retries = 1
$rawPolicy = "on-blocked"
$excerptLines = 60
$allowNonGit = $false
$allowPaths = New-Object System.Collections.Generic.List[string]
$modelRole = "unassigned"
$targetModel = "default"
$routingReason = "not-routed"
$requiresCoordinatorDecision = $false
$modelForRun = ""

$argsList = [System.Collections.Generic.List[string]]::new()
foreach ($a in $args) {
  $argsList.Add([string]$a) | Out-Null
}
$idx = 0
while ($idx -lt $argsList.Count) {
  $arg = $argsList[$idx]
  switch ($arg) {
    "--workdir" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --workdir" }
      $workdir = $argsList[$idx + 1]
      $idx += 2
    }
    "--router" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --router" }
      $routerMode = $argsList[$idx + 1]
      $idx += 2
    }
    "--task-type" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --task-type" }
      $taskType = $argsList[$idx + 1]
      $idx += 2
    }
    "--input-volume" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --input-volume" }
      $inputVolume = $argsList[$idx + 1]
      $idx += 2
    }
    "--requires-strategy" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --requires-strategy" }
      $requiresStrategy = $argsList[$idx + 1]
      $idx += 2
    }
    "--task-file" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --task-file" }
      $taskFile = $argsList[$idx + 1]
      $idx += 2
    }
    "--report-file" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --report-file" }
      $reportFile = $argsList[$idx + 1]
      $idx += 2
    }
    "--model" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --model" }
      $model = $argsList[$idx + 1]
      $idx += 2
    }
    "--flash-model" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --flash-model" }
      $flashModel = $argsList[$idx + 1]
      $idx += 2
    }
    "--k2-model" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --k2-model" }
      $k2Model = $argsList[$idx + 1]
      $idx += 2
    }
    "--frontend-model" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --frontend-model" }
      $frontendModel = $argsList[$idx + 1]
      $idx += 2
    }
    "--coordinator-model" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --coordinator-model" }
      $coordinatorModel = $argsList[$idx + 1]
      $idx += 2
    }
    "--external-coordinator-model" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --external-coordinator-model" }
      $coordinatorModel = $argsList[$idx + 1]
      $idx += 2
    }
    "--local-coordinator-label" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --local-coordinator-label" }
      $localCoordinatorLabel = $argsList[$idx + 1]
      $idx += 2
    }
    "--allow-external-coordinator" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --allow-external-coordinator" }
      $allowExternalCoordinator = $argsList[$idx + 1]
      $idx += 2
    }
    "--detail-level" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --detail-level" }
      $detailLevel = $argsList[$idx + 1]
      $idx += 2
    }
    "--timeout-sec" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --timeout-sec" }
      $timeoutSec = [int]$argsList[$idx + 1]
      $idx += 2
    }
    "--retries" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --retries" }
      $retries = [int]$argsList[$idx + 1]
      $idx += 2
    }
    "--raw-policy" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --raw-policy" }
      $rawPolicy = $argsList[$idx + 1]
      $idx += 2
    }
    "--excerpt-lines" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --excerpt-lines" }
      $excerptLines = [int]$argsList[$idx + 1]
      $idx += 2
    }
    "--allow-path" {
      if ($idx + 1 -ge $argsList.Count) { Write-Error "Missing value for --allow-path" }
      $allowPaths.Add($argsList[$idx + 1]) | Out-Null
      $idx += 2
    }
    "--allow-non-git" {
      $allowNonGit = $true
      $idx += 1
    }
    "-h" {
      Show-Usage
      exit 0
    }
    "--help" {
      Show-Usage
      exit 0
    }
    default {
      Write-Error "Unknown argument: $arg"
    }
  }
}

if ([string]::IsNullOrWhiteSpace($taskFile) -or [string]::IsNullOrWhiteSpace($reportFile)) {
  Write-Error "Missing required args: --task-file and --report-file"
}

$routerMode = $routerMode.Trim().ToLowerInvariant()
$inputVolume = $inputVolume.Trim().ToLowerInvariant()
$requiresStrategy = $requiresStrategy.Trim().ToLowerInvariant()
$allowExternalCoordinator = $allowExternalCoordinator.Trim().ToLowerInvariant()
$detailLevel = $detailLevel.Trim().ToLowerInvariant()
$rawPolicy = $rawPolicy.Trim().ToLowerInvariant()
$taskType = $taskType.Trim()
$localCoordinatorLabel = $localCoordinatorLabel.Trim()
if ([string]::IsNullOrWhiteSpace($taskType)) {
  $taskType = "generic-mechanical"
}

if ($timeoutSec -le 0) {
  Write-Error "--timeout-sec must be a positive integer"
}

if ($retries -lt 0) {
  Write-Error "--retries must be a non-negative integer"
}

if ($routerMode -notin @("auto", "manual")) {
  Write-Error "--router must be one of: auto, manual"
}

if ($inputVolume -notin @("small", "medium", "large")) {
  Write-Error "--input-volume must be one of: small, medium, large"
}

if ($requiresStrategy -notin @("yes", "no")) {
  Write-Error "--requires-strategy must be one of: yes, no"
}

if ($allowExternalCoordinator -notin @("yes", "no")) {
  Write-Error "--allow-external-coordinator must be one of: yes, no"
}

if ([string]::IsNullOrWhiteSpace($flashModel)) {
  Write-Error "--flash-model must be non-empty"
}

if ([string]::IsNullOrWhiteSpace($k2Model)) {
  Write-Error "--k2-model must be non-empty"
}

if ([string]::IsNullOrWhiteSpace($frontendModel)) {
  Write-Error "--frontend-model must be non-empty"
}

if ([string]::IsNullOrWhiteSpace($coordinatorModel)) {
  Write-Error "--coordinator-model/--external-coordinator-model must be non-empty"
}

if ([string]::IsNullOrWhiteSpace($localCoordinatorLabel)) {
  Write-Error "--local-coordinator-label must be non-empty"
}

if ($detailLevel -notin @("compact", "balanced", "diagnostic")) {
  Write-Error "--detail-level must be one of: compact, balanced, diagnostic"
}

if ($rawPolicy -notin @("always", "on-blocked", "never")) {
  Write-Error "--raw-policy must be one of: always, on-blocked, never"
}

if ($excerptLines -le 0) {
  Write-Error "--excerpt-lines must be a positive integer"
}

if ([string]::IsNullOrWhiteSpace($workdir)) {
  try {
    $workdir = (git rev-parse --show-toplevel 2>$null).Trim()
  } catch {
    $workdir = (Get-Location).Path
  }
}

$workdir = [System.IO.Path]::GetFullPath($workdir)
if (-not (Test-Path -Path $workdir -PathType Container)) {
  Write-Error "WORKDIR not found: $workdir"
}

$taskFile = Resolve-PathFromWorkdir -PathValue $taskFile -Workdir $workdir
$reportFile = Resolve-PathFromWorkdir -PathValue $reportFile -Workdir $workdir
$route = Get-ModelRouting `
  -RouterMode $routerMode `
  -TaskType $taskType `
  -InputVolume $inputVolume `
  -RequiresStrategy $requiresStrategy `
  -ExplicitModel $model `
  -FlashModel $flashModel `
  -K2Model $k2Model `
  -FrontendModel $frontendModel `
  -ExternalCoordinatorModel $coordinatorModel `
  -LocalCoordinatorLabel $localCoordinatorLabel `
  -AllowExternalCoordinator $allowExternalCoordinator
$targetModel = $route.TargetModel
$modelRole = $route.ModelRole
$routingReason = $route.RoutingReason
$requiresCoordinatorDecision = [bool]$route.RequiresCoordinatorDecision
$modelLabel = if ([string]::IsNullOrWhiteSpace($targetModel)) { "default" } else { $targetModel }
$modelForRun = ""
if (-not [string]::IsNullOrWhiteSpace($modelLabel) -and $modelLabel -ne "default" -and $modelLabel -ne "none") {
  $modelForRun = $modelLabel
}

if (-not (Test-Path -Path $taskFile -PathType Leaf)) {
  Write-Error "TASK_FILE not found: $taskFile"
}

$reportDir = Split-Path -Path $reportFile -Parent
if (-not (Test-Path -Path $reportDir -PathType Container)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$rawFile = "$reportFile.raw.txt"
$excerptFile = "$reportFile.excerpt.txt"
$reportTmp = "$reportFile.tmp"
Remove-Item -Path $rawFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$rawFile.attempt*" -Force -ErrorAction SilentlyContinue
Remove-Item -Path $excerptFile -Force -ErrorAction SilentlyContinue

if ($requiresCoordinatorDecision) {
  Write-BlockedReport `
    -ReportFile $reportFile `
    -Summary "Task requires strategy decision by coordinator" `
    -Workdir $workdir `
    -ModelLabel $modelLabel `
    -Blockers @(
      "task_type=$taskType",
      "routing_reason=$routingReason",
      "Use local coordinator ($localCoordinatorLabel) for architecture/tradeoff decisions before delegation",
      "Use external coordinator only for rare consultation when explicitly enabled"
    )
  exit 10
}

$isGitRepo = $false
try {
  git -C $workdir rev-parse --is-inside-work-tree *> $null
  if ($LASTEXITCODE -eq 0) { $isGitRepo = $true }
} catch {
  $isGitRepo = $false
}

if (-not $allowNonGit -and -not $isGitRepo) {
  Write-BlockedReport `
    -ReportFile $reportFile `
    -Summary "Strict git mode blocked execution" `
    -Workdir $workdir `
    -ModelLabel $modelLabel `
    -Blockers @(
      "Workspace is not a git repository: $workdir",
      "Run from a git repository, pass --workdir <git-repo>, or use --allow-non-git"
    )
  exit 10
}

$before = @()
if ($isGitRepo) {
  $before = Get-GitChanges -Workdir $workdir
}

$taskBody = Get-Content -Raw -Path $taskFile

$prompt = @"
You are a low-cost mechanical executor running inside OpenCode.
Follow instructions strictly. Do not invent requirements.

Hard rules:
1) Stay within declared scope.
2) If input is missing, return BLOCKED.
3) Do not add architecture decisions.
4) Return ONLY the contract block.
5) Work only inside this workspace: $workdir
6) Respect detail level: $detailLevel (balanced by default).
7) Be compact, but include enough diagnostics when confidence is low or context is missing.
8) Do not override routing intent. This run is for model role: $modelRole.

Routing context:
TASK_TYPE: $taskType
MODEL_ROLE: $modelRole
TARGET_MODEL: $modelLabel
INPUT_VOLUME: $inputVolume
REQUIRES_STRATEGY: $requiresStrategy
ROUTER_MODE: $routerMode
ROUTING_REASON: $routingReason
LOCAL_COORDINATOR: $localCoordinatorLabel
EXTERNAL_COORDINATOR_MODEL: $coordinatorModel
EXTERNAL_COORDINATOR_ALLOWED: $allowExternalCoordinator

Output contract:
BEGIN_REPORT
STATUS: DONE|BLOCKED
SUMMARY: <one line>
WORKDIR: $workdir
MODEL: $modelLabel
TASK_TYPE: $taskType
MODEL_ROLE: $modelRole
TARGET_MODEL: $modelLabel
INPUT_VOLUME: $inputVolume
REQUIRES_STRATEGY: $requiresStrategy
ROUTER_MODE: $routerMode
ROUTING_REASON: <one line>
LOCAL_COORDINATOR: $localCoordinatorLabel
EXTERNAL_COORDINATOR_MODEL: $coordinatorModel
EXTERNAL_COORDINATOR_ALLOWED: $allowExternalCoordinator
DETAIL_LEVEL: $detailLevel
CONFIDENCE: <high|medium|low>
RISK: <low|medium|high>
NEEDS_MORE_CONTEXT: <yes|no>
ARTIFACTS: <comma-separated absolute paths or none>
RAW_EXCERPT: <absolute path or none>
RAW_LOG: <absolute path or none>
CHECKS:
- <check result>
- <check result>
BLOCKERS:
- <blocker or 'none'>
END_REPORT

Task packet:
$taskBody
"@

$maxAttempts = $retries + 1
$attempt = 1
$runExit = 1

while ($attempt -le $maxAttempts) {
  $attemptRaw = "$rawFile.attempt$attempt"
  $attemptStdErr = "$attemptRaw.stderr"
  $runTimedOut = $false

  $cmdArgs = New-Object System.Collections.Generic.List[string]
  $cmdArgs.Add("run") | Out-Null
  if (-not [string]::IsNullOrWhiteSpace($modelForRun)) {
    $cmdArgs.Add("--model") | Out-Null
    $cmdArgs.Add($modelForRun) | Out-Null
  }
  $cmdArgs.Add($prompt) | Out-Null

  try {
    $proc = Start-Process `
      -FilePath "opencode" `
      -ArgumentList $cmdArgs.ToArray() `
      -WorkingDirectory $workdir `
      -RedirectStandardOutput $attemptRaw `
      -RedirectStandardError $attemptStdErr `
      -NoNewWindow `
      -PassThru

    if (-not $proc.WaitForExit($timeoutSec * 1000)) {
      $runTimedOut = $true
      Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
      $runExit = 124
    } else {
      $runExit = $proc.ExitCode
    }
  } catch {
    $runExit = 1
  }

  $stdout = if (Test-Path $attemptRaw) { Get-Content -Raw $attemptRaw } else { "" }
  $stderr = if (Test-Path $attemptStdErr) { Get-Content -Raw $attemptStdErr } else { "" }
  $combined = if ([string]::IsNullOrWhiteSpace($stderr)) { $stdout } else { "$stdout`n$stderr" }
  Set-Content -Path $attemptRaw -Value $combined -NoNewline
  Set-Content -Path $rawFile -Value $combined -NoNewline

  if (-not $runTimedOut -and $runExit -eq 0) {
    break
  }

  if ($attempt -lt $maxAttempts) {
    Start-Sleep -Seconds 1
  }
  $attempt++
}

if ($runExit -ne 0) {
  $failureExcerpt = "none"
  if (Write-RawExcerpt -RawFile $rawFile -ExcerptFile $excerptFile -ExcerptLines $excerptLines) {
    $failureExcerpt = $excerptFile
  }

  $keepFailureRaw = $true
  if ($rawPolicy -eq "never") {
    $keepFailureRaw = $false
  }
  $failureRawValue = $rawFile
  if (-not $keepFailureRaw) {
    $failureRawValue = "none"
    Remove-RawArtifacts -RawFile $rawFile
  }

  Write-BlockedReport `
    -ReportFile $reportFile `
    -Summary "OpenCode execution failed" `
    -Workdir $workdir `
    -ModelLabel $modelLabel `
    -Blockers @(
      "exit_code=$runExit",
      "attempts=$maxAttempts",
      "timeout_sec=$timeoutSec",
      "raw_output=$failureRawValue",
      "raw_excerpt=$failureExcerpt",
      "raw_policy=$rawPolicy"
    )
  $failureLines = Get-Content -Path $reportFile
  $failureLines = Set-OrInsertField -Lines $failureLines -Prefix "RAW_EXCERPT: " -Value $failureExcerpt
  $failureLines = Set-OrInsertField -Lines $failureLines -Prefix "RAW_LOG: " -Value $failureRawValue
  Set-Content -Path $reportFile -Value ($failureLines -join "`n") -NoNewline
  exit 10
}

$rawText = Get-Content -Raw -Path $rawFile
$reportMatch = [regex]::Match($rawText, "(?ms)^BEGIN_REPORT\r?\n.*?^END_REPORT\s*$")
if (-not $reportMatch.Success) {
  Write-Error "Invalid report format. Raw output: $rawFile"
  exit 11
}

$reportBlock = $reportMatch.Value.TrimEnd("`r", "`n")
$lines = $reportBlock -split "`r?`n"
$lines = Ensure-Field -Lines $lines -Prefix "WORKDIR: " -Value $workdir -InsertAfterPrefix "SUMMARY:"
$lines = Ensure-Field -Lines $lines -Prefix "MODEL: " -Value $modelLabel -InsertAfterPrefix "WORKDIR:"
$lines = Ensure-Field -Lines $lines -Prefix "TASK_TYPE: " -Value $taskType -InsertAfterPrefix "MODEL:"
$lines = Ensure-Field -Lines $lines -Prefix "MODEL_ROLE: " -Value $modelRole -InsertAfterPrefix "TASK_TYPE:"
$lines = Ensure-Field -Lines $lines -Prefix "TARGET_MODEL: " -Value $modelLabel -InsertAfterPrefix "MODEL_ROLE:"
$lines = Ensure-Field -Lines $lines -Prefix "INPUT_VOLUME: " -Value $inputVolume -InsertAfterPrefix "TARGET_MODEL:"
$lines = Ensure-Field -Lines $lines -Prefix "REQUIRES_STRATEGY: " -Value $requiresStrategy -InsertAfterPrefix "INPUT_VOLUME:"
$lines = Ensure-Field -Lines $lines -Prefix "ROUTER_MODE: " -Value $routerMode -InsertAfterPrefix "REQUIRES_STRATEGY:"
$lines = Ensure-Field -Lines $lines -Prefix "ROUTING_REASON: " -Value $routingReason -InsertAfterPrefix "ROUTER_MODE:"
$lines = Ensure-Field -Lines $lines -Prefix "LOCAL_COORDINATOR: " -Value $localCoordinatorLabel -InsertAfterPrefix "ROUTING_REASON:"
$lines = Ensure-Field -Lines $lines -Prefix "EXTERNAL_COORDINATOR_MODEL: " -Value $coordinatorModel -InsertAfterPrefix "LOCAL_COORDINATOR:"
$lines = Ensure-Field -Lines $lines -Prefix "EXTERNAL_COORDINATOR_ALLOWED: " -Value $allowExternalCoordinator -InsertAfterPrefix "EXTERNAL_COORDINATOR_MODEL:"
$lines = Ensure-Field -Lines $lines -Prefix "DETAIL_LEVEL: " -Value $detailLevel -InsertAfterPrefix "EXTERNAL_COORDINATOR_ALLOWED:"
$lines = Ensure-Field -Lines $lines -Prefix "CONFIDENCE: " -Value "medium" -InsertAfterPrefix "DETAIL_LEVEL:"
$lines = Ensure-Field -Lines $lines -Prefix "RISK: " -Value "medium" -InsertAfterPrefix "CONFIDENCE:"
$lines = Ensure-Field -Lines $lines -Prefix "NEEDS_MORE_CONTEXT: " -Value "no" -InsertAfterPrefix "RISK:"

$statusLine = ($lines | Where-Object { $_ -match "^STATUS:\s*(DONE|BLOCKED)\s*$" } | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($statusLine)) {
  Write-Error "Missing STATUS in report: $reportFile"
  exit 11
}
$statusValue = ($statusLine -replace "^STATUS:\s*", "").Trim()
$confidenceValue = (Get-FieldValue -Lines $lines -Prefix "CONFIDENCE: " -DefaultValue "medium").ToLowerInvariant()
$needsMoreContextValue = (Get-FieldValue -Lines $lines -Prefix "NEEDS_MORE_CONTEXT: " -DefaultValue "no").ToLowerInvariant()

$shouldKeepRaw = $false
switch ($rawPolicy) {
  "always" { $shouldKeepRaw = $true }
  "on-blocked" {
    if ($statusValue -eq "BLOCKED" -or $confidenceValue -eq "low" -or $needsMoreContextValue -eq "yes") {
      $shouldKeepRaw = $true
    }
  }
  "never" { $shouldKeepRaw = $false }
}

$rawExcerptValue = "none"
if ($statusValue -eq "BLOCKED" -or $confidenceValue -eq "low" -or $needsMoreContextValue -eq "yes") {
  if (Write-RawExcerpt -RawFile $rawFile -ExcerptFile $excerptFile -ExcerptLines $excerptLines) {
    $rawExcerptValue = $excerptFile
  }
}

$rawLogValue = "none"
if ($shouldKeepRaw) {
  $rawLogValue = $rawFile
}

$lines = Set-OrInsertField -Lines $lines -Prefix "RAW_EXCERPT: " -Value $rawExcerptValue
$lines = Set-OrInsertField -Lines $lines -Prefix "RAW_LOG: " -Value $rawLogValue

Set-Content -Path $reportTmp -Value ($lines -join "`n") -NoNewline
Copy-Item -Path $reportTmp -Destination $reportFile -Force

if ($isGitRepo) {
  $after = Get-GitChanges -Workdir $workdir
  $delta = @($after | Where-Object { $_ -notin $before })

  $reportRel = ""
  $rawRel = ""
  $excerptRel = ""
  $tmpRel = ""
  if ($reportFile.StartsWith($workdir, [System.StringComparison]::OrdinalIgnoreCase)) {
    $reportRel = $reportFile.Substring($workdir.Length).TrimStart("\", "/") -replace "\\", "/"
  }
  if ($rawFile.StartsWith($workdir, [System.StringComparison]::OrdinalIgnoreCase)) {
    $rawRel = $rawFile.Substring($workdir.Length).TrimStart("\", "/") -replace "\\", "/"
  }
  if ($excerptFile.StartsWith($workdir, [System.StringComparison]::OrdinalIgnoreCase)) {
    $excerptRel = $excerptFile.Substring($workdir.Length).TrimStart("\", "/") -replace "\\", "/"
  }
  if ($reportTmp.StartsWith($workdir, [System.StringComparison]::OrdinalIgnoreCase)) {
    $tmpRel = $reportTmp.Substring($workdir.Length).TrimStart("\", "/") -replace "\\", "/"
  }

  $filtered = New-Object System.Collections.Generic.List[string]
  foreach ($changed in $delta) {
    if ([string]::IsNullOrWhiteSpace($changed)) { continue }
    if ($reportRel -and $changed -eq $reportRel) { continue }
    if ($tmpRel -and $changed -eq $tmpRel) { continue }
    if ($rawRel -and ($changed -eq $rawRel -or $changed -like "$rawRel.attempt*")) { continue }
    if ($excerptRel -and $changed -eq $excerptRel) { continue }
    $filtered.Add($changed) | Out-Null
  }

  if ($filtered.Count -gt 0 -and $allowPaths.Count -eq 0) {
    Write-BlockedReport `
      -ReportFile $reportFile `
      -Summary "Changed files detected but no allowlist was provided" `
      -Workdir $workdir `
      -ModelLabel $modelLabel `
      -Blockers @(
        "Provide --allow-path patterns for expected edits",
        "Changed files: $($filtered -join " ")"
      )
    if ($rawPolicy -eq "never") {
      Remove-RawArtifacts -RawFile $rawFile
    }
    exit 10
  }

  $violations = New-Object System.Collections.Generic.List[string]
  foreach ($changed in $filtered) {
    $matched = $false
    $changedRel = $changed -replace "\\", "/"
    $changedAbs = (Join-Path $workdir $changedRel) -replace "\\", "/"

    foreach ($pattern in $allowPaths) {
      $patternNorm = $pattern -replace "\\", "/"
      if ([System.IO.Path]::IsPathRooted($pattern)) {
        if ($changedAbs -like $patternNorm) {
          $matched = $true
          break
        }
      } else {
        if ($changedRel -like $patternNorm) {
          $matched = $true
          break
        }
      }
    }
    if (-not $matched) {
      $violations.Add($changedRel) | Out-Null
    }
  }

  if ($violations.Count -gt 0) {
    Write-BlockedReport `
      -ReportFile $reportFile `
      -Summary "Changed files outside allowlist" `
      -Workdir $workdir `
      -ModelLabel $modelLabel `
      -Blockers @(
        "Allowed patterns: $($allowPaths -join " ")", 
        "Violations: $($violations -join " ")"
      )
    if ($rawPolicy -eq "never") {
      Remove-RawArtifacts -RawFile $rawFile
    }
    exit 10
  }
}

if (-not $shouldKeepRaw) {
  Remove-RawArtifacts -RawFile $rawFile
}

if ($statusValue -eq "DONE") {
  exit 0
}
if ($statusValue -eq "BLOCKED") {
  exit 10
}

Write-Error "Unexpected STATUS value: $statusValue"
exit 11
