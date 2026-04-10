#!/bin/bash
# Lists all open PRs for loopandlearn/LoopFollow in a compact format.
# Requires: gh (GitHub CLI), jq

REPO="loopandlearn/LoopFollow"

gh pr list --repo "$REPO" --state open --limit 100 --json number,title,author,reviewDecision,statusCheckRollup,baseRefName \
  --jq '.[] | {
    number,
    title,
    author: .author.login,
    base: .baseRefName,
    approved: (if .reviewDecision == "APPROVED" then "approved"
               elif .reviewDecision == "CHANGES_REQUESTED" then "changes requested"
               elif .reviewDecision == "REVIEW_REQUIRED" then "review required"
               else "no review"
               end),
    checks: (if (.statusCheckRollup | length) == 0 then "no checks"
             elif ([.statusCheckRollup[] | select(.conclusion == "FAILURE")] | length) > 0 then "failing"
             elif ([.statusCheckRollup[] | select(.conclusion == "SUCCESS")] | length) == (.statusCheckRollup | length) then "passing"
             else "pending"
             end)
  } | "#\(.number)\t\(.title)\t(\(.author))\t\(.approved)\t\(.checks)\t→ \(.base)"' \
| column -t -s $'\t'
