Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Show-Usage {
  @"
Usage:
  run_content_critique.ps1 --draft-file <path> --output-dir <path> [--workdir <path>] [--models-file <path>] [--timeout-sec <seconds>] [--retries <count>] [--input-volume <small|medium|large>] [--detail-level <compact|balanced|diagnostic>] [--allow-non-git]
"@
}

function Resolve-PathFromBase {
  param(
    [Parameter(Mandatory = $true)][string]$PathValue,
    [Parameter(Mandatory = $true)][string]$BasePath
  )
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $BasePath $PathValue))
}

function Write-FallbackBlockedReport {
  param(
    [Parameter(Mandatory = $true)][string]$ReportPath,
    [Parameter(Mandatory = $true)][string]$Workdir,
    [Parameter(Mandatory = $true)][string]$TaskType,
    [Parameter(Mandatory = $true)][string]$ModelRole,
    [Parameter(Mandatory = $true)][string]$Summary,
    [Parameter(Mandatory = $true)][string]$Reason
  )
  $content = @(
    "BEGIN_REPORT",
    "STATUS: BLOCKED",
    "SUMMARY: $Summary",
    "WORKDIR: $Workdir",
    "MODEL: default",
    "TASK_TYPE: $TaskType",
    "MODEL_ROLE: $ModelRole",
    "TARGET_MODEL: auto",
    "INPUT_VOLUME: medium",
    "REQUIRES_STRATEGY: no",
    "ROUTER_MODE: auto",
    "ROUTING_REASON: fallback blocked report created by run_content_critique",
    "DETAIL_LEVEL: balanced",
    "CONFIDENCE: low",
    "RISK: medium",
    "NEEDS_MORE_CONTEXT: yes",
    "HOOK_TRIGGER: none",
    "HOOK_LEAD_TYPE: none",
    "HOOK_FORMULA: none",
    "HOOK_WORD_LIMIT: none",
    "GATE_STAGE: human_recommendation",
    "GATE_DECISION_BASIS: fallback blocked report due to delegate failure",
    "APPROVAL_MODE_RECOMMENDATION: inline",
    "REQUIRES_INLINE_REVIEW_REASON: delegate execution failed",
    "CRITIQUE_SCORE: 0",
    "HOOK_15S_SCORE: none",
    "HOOK_WORD_COUNT: none",
    "HOOK_ANTIPATTERN_FLAGS: none",
    "TOP_ISSUES:",
    "- delegate execution failure",
    "RECOMMENDED_EDITS:",
    "- rerun with explicit model mapping",
    "ARTIFACTS: none",
    "RAW_EXCERPT: none",
    "RAW_LOG: none",
    "CHECKS:",
    "- fallback report created",
    "BLOCKERS:",
    "- $Reason",
    "END_REPORT"
  ) -join "`n"
  Set-Content -Path $ReportPath -Value $content -NoNewline
}

$draftFile = ""
$outputDir = ""
$workdir = ""
$modelsFile = ""
$timeoutSec = 600
$retries = 1
$inputVolume = "medium"
$detailLevel = "balanced"
$allowNonGit = $false

$argsList = [System.Collections.Generic.List[string]]::new()
foreach ($a in $args) {
  $argsList.Add([string]$a) | Out-Null
}

$idx = 0
while ($idx -lt $argsList.Count) {
  $arg = $argsList[$idx]
  switch ($arg) {
    "--draft-file" {
      if ($idx + 1 -ge $argsList.Count) { throw "Missing value for --draft-file" }
      $draftFile = $argsList[$idx + 1]
      $idx += 2
    }
    "--output-dir" {
      if ($idx + 1 -ge $argsList.Count) { throw "Missing value for --output-dir" }
      $outputDir = $argsList[$idx + 1]
      $idx += 2
    }
    "--workdir" {
      if ($idx + 1 -ge $argsList.Count) { throw "Missing value for --workdir" }
      $workdir = $argsList[$idx + 1]
      $idx += 2
    }
    "--models-file" {
      if ($idx + 1 -ge $argsList.Count) { throw "Missing value for --models-file" }
      $modelsFile = $argsList[$idx + 1]
      $idx += 2
    }
    "--timeout-sec" {
      if ($idx + 1 -ge $argsList.Count) { throw "Missing value for --timeout-sec" }
      $timeoutSec = [int]$argsList[$idx + 1]
      $idx += 2
    }
    "--retries" {
      if ($idx + 1 -ge $argsList.Count) { throw "Missing value for --retries" }
      $retries = [int]$argsList[$idx + 1]
      $idx += 2
    }
    "--input-volume" {
      if ($idx + 1 -ge $argsList.Count) { throw "Missing value for --input-volume" }
      $inputVolume = $argsList[$idx + 1]
      $idx += 2
    }
    "--detail-level" {
      if ($idx + 1 -ge $argsList.Count) { throw "Missing value for --detail-level" }
      $detailLevel = $argsList[$idx + 1]
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
      throw "Unknown argument: $arg"
    }
  }
}

if ([string]::IsNullOrWhiteSpace($draftFile) -or [string]::IsNullOrWhiteSpace($outputDir)) {
  Show-Usage | Write-Output
  throw "Required args missing: --draft-file and --output-dir"
}

if ($timeoutSec -le 0) {
  throw "--timeout-sec must be a positive integer"
}

if ($retries -lt 0) {
  throw "--retries must be a non-negative integer"
}

if ($inputVolume -notin @("small", "medium", "large")) {
  throw "--input-volume must be one of: small, medium, large"
}

if ($detailLevel -notin @("compact", "balanced", "diagnostic")) {
  throw "--detail-level must be one of: compact, balanced, diagnostic"
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
  throw "WORKDIR not found: $workdir"
}

$draftFile = Resolve-PathFromBase -PathValue $draftFile -BasePath $workdir
$outputDir = Resolve-PathFromBase -PathValue $outputDir -BasePath $workdir
if (-not (Test-Path -Path $draftFile -PathType Leaf)) {
  throw "Draft file not found: $draftFile"
}

if (-not (Test-Path -Path $outputDir -PathType Container)) {
  New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

$delegateScript = Join-Path $PSScriptRoot "delegate_task.ps1"
if (-not (Test-Path -Path $delegateScript -PathType Leaf)) {
  throw "delegate_task.ps1 not found at: $delegateScript"
}

$modelMap = @{
  factual_critic = ""
  clarity_critic = ""
  voice_critic = ""
  hook_critic = ""
  risk_critic = ""
  generic_detector = ""
  rhythm_analyzer = ""
  personal_anchor_critic = ""
}

if (-not [string]::IsNullOrWhiteSpace($modelsFile)) {
  $modelsFile = Resolve-PathFromBase -PathValue $modelsFile -BasePath $workdir
  if (-not (Test-Path -Path $modelsFile -PathType Leaf)) {
    throw "models file not found: $modelsFile"
  }
  $json = Get-Content -Raw -Path $modelsFile | ConvertFrom-Json
  foreach ($key in $modelMap.Keys) {
    if ($null -ne $json.$key -and -not [string]::IsNullOrWhiteSpace([string]$json.$key)) {
      $modelMap[$key] = [string]$json.$key
    }
  }
}

$runId = (Get-Date).ToString("yyyyMMdd-HHmmss")

$critics = @(
  @{
    id = "factual_critic"
    taskType = "content-risk-check"
    objective = "Validate factual claims, identify unsupported statements, and flag overclaims."
    actions = @(
      "Compare each factual statement to provided evidence or source links.",
      "List unsupported or weakly supported claims.",
      "Suggest safer rewrites that preserve meaning."
    )
  },
  @{
    id = "clarity_critic"
    taskType = "content-polish"
    objective = "Improve clarity, structure, and readability without changing core meaning."
    actions = @(
      "Find unclear or dense sentences.",
      "Suggest concise rewrites.",
      "Check paragraph flow and transitions."
    )
  },
  @{
    id = "voice_critic"
    taskType = "content-polish"
    objective = "Preserve founder voice and remove generic AI style."
    actions = @(
      "Detect robotic or generic phrasing.",
      "Propose voice-consistent alternatives.",
      "Keep tone aligned with Build in Public style."
    )
  },
  @{
    id = "generic_detector"
    taskType = "content-generic-detection"
    objective = "Find generic AI markers and abstract filler that should be removed."
    actions = @(
      "List marker phrases with exact excerpts.",
      "Flag lines that need deletion vs concrete rewrite.",
      "Report generic marker count before rewrite."
    )
  },
  @{
    id = "rhythm_analyzer"
    taskType = "content-rhythm-analysis"
    objective = "Detect monotone cadence and repetitive sentence patterns."
    actions = @(
      "Identify repeated sentence openings.",
      "Assess sentence-length variance.",
      "Provide rhythm variance score and fixes."
    )
  },
  @{
    id = "personal_anchor_critic"
    taskType = "content-personal-anchor-check"
    objective = "Ensure text includes grounded human anchors."
    actions = @(
      "Mark where anchors are missing.",
      "Suggest anchor slots (experience/date/name/opinion).",
      "Report personal anchor count."
    )
  },
  @{
    id = "hook_critic"
    taskType = "content-critique"
    objective = "Improve first-15-seconds hook strength and CTA relevance."
    actions = @(
      "Score opening hook for trigger/lead/formula fit and first-15-seconds continuation pressure.",
      "Suggest 2-3 stronger opening variants with explicit trigger, lead type, and formula.",
      "Check opening word count vs 30-word target and flag generic opener anti-patterns."
    )
  },
  @{
    id = "risk_critic"
    taskType = "content-risk-check"
    objective = "Classify legal/policy/reputation risk and approval mode."
    actions = @(
      "Classify risk as low/medium/high.",
      "Mark approval lane as batch or inline.",
      "Highlight phrases needing softening."
    )
  }
)

$results = New-Object System.Collections.Generic.List[object]

foreach ($critic in $critics) {
  $criticId = [string]$critic.id
  $taskPath = Join-Path $outputDir "$runId.$criticId.task.md"
  $reportPath = Join-Path $outputDir "$runId.$criticId.report.md"
  $model = $modelMap[$criticId]

  $packet = @(
    "# OpenCode Content Task Packet",
    "",
    "## Objective",
    $critic.objective,
    "",
    "## Workspace",
    "- WORKDIR: $workdir",
    "- DETAIL_LEVEL: $detailLevel",
    "",
    "## Critic Role",
    "- MODEL_ROLE: $criticId",
    "",
    "## Routing Inputs",
    "- TASK_TYPE: $($critic.taskType)",
    "- INPUT_VOLUME: $inputVolume",
    "- REQUIRES_STRATEGY: no",
    "- HOOK_TRIGGER: none",
    "- HOOK_LEAD_TYPE: none",
    "- HOOK_FORMULA: none",
    "- HOOK_WORD_LIMIT: 30",
    "",
    "## Allowed Scope",
    "- none (read-only critique)",
    "",
    "## Forbidden Scope",
    "- No publishing actions",
    "- No strategy decisions",
    "- No file edits",
    "",
    "## Inputs",
    "- Draft file: $draftFile",
    "",
    "## Required Actions",
    "1. $($critic.actions[0])",
    "2. $($critic.actions[1])",
    "3. $($critic.actions[2])",
    "",
    "## Completion Criteria",
    "- Provide specific issues and concrete edits",
    "- Return the output contract exactly",
    "",
    "## Output Contract (mandatory)",
    "Return only:",
    "",
    "BEGIN_REPORT",
    "STATUS: DONE|BLOCKED",
    "SUMMARY: <one line>",
    "WORKDIR: <absolute workspace used for execution>",
    "MODEL: <provider/model or default>",
    "TASK_TYPE: <task classification>",
    "MODEL_ROLE: $criticId",
    "TARGET_MODEL: <selected model>",
    "INPUT_VOLUME: <small|medium|large>",
    "REQUIRES_STRATEGY: <yes|no>",
    "ROUTER_MODE: <auto|manual>",
    "ROUTING_REASON: <one line>",
    "DETAIL_LEVEL: <compact|balanced|diagnostic>",
    "HOOK_TRIGGER: <CuriosityGap|Identity|Tension|ROMO|FOMO|SocialProof|none>",
    "HOOK_LEAD_TYPE: <Zinger|FirstPerson|Question|Scene|none>",
    "HOOK_FORMULA: <SPY|PAS|APP|Custom|none>",
    "HOOK_WORD_LIMIT: <integer or none>",
    "GATE_STAGE: <formal|llm_judge|human_recommendation>",
    "GATE_DECISION_BASIS: <one line>",
    "APPROVAL_MODE_RECOMMENDATION: <batch|inline>",
    "REQUIRES_INLINE_REVIEW_REASON: <text or none>",
    "CONFIDENCE: <high|medium|low>",
    "RISK: <low|medium|high>",
    "NEEDS_MORE_CONTEXT: <yes|no>",
    "CRITIQUE_SCORE: <0-100>",
    "HOOK_15S_SCORE: <0-100 or none>",
    "HOOK_WORD_COUNT: <integer or none>",
    "HOOK_ANTIPATTERN_FLAGS: <integer or none>",
    "TOP_ISSUES:",
    "- <issue>",
    "- <issue>",
    "RECOMMENDED_EDITS:",
    "- <edit>",
    "- <edit>",
    "ARTIFACTS: <comma-separated absolute paths or none>",
    "RAW_EXCERPT: <absolute path or none>",
    "RAW_LOG: <absolute path or none>",
    "CHECKS:",
    "- <check result>",
    "- <check result>",
    "BLOCKERS:",
    "- <blocker or none>",
    "END_REPORT"
  ) -join "`n"

  Set-Content -Path $taskPath -Value $packet -NoNewline

  $delegateArgs = New-Object System.Collections.Generic.List[string]
  $delegateArgs.Add("--task-file") | Out-Null
  $delegateArgs.Add($taskPath) | Out-Null
  $delegateArgs.Add("--report-file") | Out-Null
  $delegateArgs.Add($reportPath) | Out-Null
  $delegateArgs.Add("--workdir") | Out-Null
  $delegateArgs.Add($workdir) | Out-Null
  $delegateArgs.Add("--task-type") | Out-Null
  $delegateArgs.Add([string]$critic.taskType) | Out-Null
  $delegateArgs.Add("--input-volume") | Out-Null
  $delegateArgs.Add($inputVolume) | Out-Null
  $delegateArgs.Add("--requires-strategy") | Out-Null
  $delegateArgs.Add("no") | Out-Null
  $delegateArgs.Add("--detail-level") | Out-Null
  $delegateArgs.Add($detailLevel) | Out-Null
  $delegateArgs.Add("--timeout-sec") | Out-Null
  $delegateArgs.Add([string]$timeoutSec) | Out-Null
  $delegateArgs.Add("--retries") | Out-Null
  $delegateArgs.Add([string]$retries) | Out-Null
  $delegateArgs.Add("--raw-policy") | Out-Null
  $delegateArgs.Add("on-blocked") | Out-Null
  $delegateArgs.Add("--excerpt-lines") | Out-Null
  $delegateArgs.Add("80") | Out-Null

  if ($allowNonGit) {
    $delegateArgs.Add("--allow-non-git") | Out-Null
  }

  if (-not [string]::IsNullOrWhiteSpace($model) -and -not $model.StartsWith("provider/")) {
    $delegateArgs.Add("--router") | Out-Null
    $delegateArgs.Add("manual") | Out-Null
    $delegateArgs.Add("--model") | Out-Null
    $delegateArgs.Add($model) | Out-Null
  } else {
    $delegateArgs.Add("--router") | Out-Null
    $delegateArgs.Add("auto") | Out-Null
  }

  $exitCode = 1
  try {
    & $delegateScript @delegateArgs
    $exitCode = $LASTEXITCODE
  } catch {
    $exitCode = 1
    if (-not (Test-Path -Path $reportPath -PathType Leaf)) {
      Write-FallbackBlockedReport `
        -ReportPath $reportPath `
        -Workdir $workdir `
        -TaskType ([string]$critic.taskType) `
        -ModelRole $criticId `
        -Summary "Delegate execution failed before report generation" `
        -Reason $_.Exception.Message
    }
  }

  $status = "BLOCKED"
  $summary = "report missing"
  $modelUsed = "unknown"
  if (Test-Path -Path $reportPath -PathType Leaf) {
    $reportText = Get-Content -Raw -Path $reportPath
    $mStatus = [regex]::Match($reportText, "(?m)^STATUS:\s*(DONE|BLOCKED)\s*$")
    $mSummary = [regex]::Match($reportText, "(?m)^SUMMARY:\s*(.+)$")
    $mModel = [regex]::Match($reportText, "(?m)^MODEL:\s*(.+)$")
    if ($mStatus.Success) { $status = $mStatus.Groups[1].Value.Trim() }
    if ($mSummary.Success) { $summary = $mSummary.Groups[1].Value.Trim() }
    if ($mModel.Success) { $modelUsed = $mModel.Groups[1].Value.Trim() }
  }

  $results.Add([pscustomobject]@{
      critic = $criticId
      task_type = [string]$critic.taskType
      requested_model = if ([string]::IsNullOrWhiteSpace($model)) { "auto" } else { $model }
      model_used = $modelUsed
      status = $status
      exit_code = $exitCode
      report_file = $reportPath
      task_file = $taskPath
      summary = $summary
    }) | Out-Null
}

$summaryJsonPath = Join-Path $outputDir "$runId.content-critique.summary.json"
$results | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryJsonPath

$allDone = ($results | Where-Object { $_.status -ne "DONE" }).Count -eq 0
$overall = if ($allDone) { "DONE" } else { "BLOCKED" }
$summaryMdPath = Join-Path $outputDir "$runId.content-critique.summary.md"

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Content Critique Summary") | Out-Null
$md.Add("") | Out-Null
$md.Add("- RUN_ID: $runId") | Out-Null
$md.Add("- OVERALL_STATUS: $overall") | Out-Null
$md.Add("- DRAFT_FILE: $draftFile") | Out-Null
$md.Add("- WORKDIR: $workdir") | Out-Null
$md.Add("- SUMMARY_JSON: $summaryJsonPath") | Out-Null
$md.Add("") | Out-Null
$md.Add("## Critics") | Out-Null
foreach ($r in $results) {
  $md.Add("- [$($r.critic)] status=$($r.status); requested_model=$($r.requested_model); model_used=$($r.model_used); report=$($r.report_file)") | Out-Null
  $md.Add("  summary: $($r.summary)") | Out-Null
}

Set-Content -Path $summaryMdPath -Value ($md -join "`n")
Write-Output "SUMMARY_MD=$summaryMdPath"
Write-Output "SUMMARY_JSON=$summaryJsonPath"
Write-Output "OVERALL_STATUS=$overall"

if ($allDone) {
  exit 0
}

exit 10


