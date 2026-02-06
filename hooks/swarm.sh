#!/bin/bash
# Kuark Swarm Management v2
# Manages .swarm/ directory lifecycle: init, task, sprint, handoff, status, repair
# Robust error handling - no silent failures

# Do NOT use set -e; handle errors explicitly
# set -e causes silent script death when combined with 2>/dev/null

KUARK_HOME="${KUARK_HOME:-$HOME/.kuark}"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SWARM_DIR=".swarm"
COMMAND="${1:-status}"
shift 2>/dev/null || true

# ─────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────
ensure_swarm() {
    if [ ! -d "$SWARM_DIR" ]; then
        echo -e "${RED}[SWARM]${NC} Not initialized. Run: bash hooks/swarm.sh init [project-name]"
        exit 1
    fi
}

# Safe jq write: validates output before replacing original
safe_jq_write() {
    local file="$1"
    shift
    local tmp="${file}.tmp"

    if ! jq "$@" "$file" > "$tmp" 2>/dev/null; then
        echo -e "${RED}[SWARM]${NC} jq error on $file" >&2
        rm -f "$tmp"
        return 1
    fi

    # Validate JSON
    if ! jq empty "$tmp" 2>/dev/null; then
        echo -e "${RED}[SWARM]${NC} Invalid JSON generated for $file" >&2
        rm -f "$tmp"
        return 1
    fi

    mv "$tmp" "$file"
    return 0
}

# Get real task counter by scanning existing files
get_real_task_counter() {
    local max=0
    for f in "$SWARM_DIR"/tasks/TASK-*.task.md; do
        [ -f "$f" ] || continue
        local num
        num=$(basename "$f" .task.md | sed 's/TASK-//' | sed 's/^0*//')
        if [ -n "$num" ] && [ "$num" -gt "$max" ] 2>/dev/null; then
            max=$num
        fi
    done
    echo "$max"
}

# Get real sprint counter by scanning existing files
get_real_sprint_counter() {
    local max=0
    for f in "$SWARM_DIR"/sprints/sprint-*.json; do
        [ -f "$f" ] || continue
        local num
        num=$(basename "$f" .json | sed 's/sprint-//' | sed 's/-.*//' | sed 's/^0*//')
        if [ -n "$num" ] && [ "$num" -gt "$max" ] 2>/dev/null; then
            max=$num
        fi
    done
    echo "$max"
}

# Sync counters: ensure project.json matches actual files
sync_counters() {
    local json_task_counter
    json_task_counter=$(jq -r '.taskCounter // 0' "$SWARM_DIR/project.json" 2>/dev/null || echo "0")
    local real_task_counter
    real_task_counter=$(get_real_task_counter)

    local json_sprint_counter
    json_sprint_counter=$(jq -r '.sprintCounter // 0' "$SWARM_DIR/project.json" 2>/dev/null || echo "0")
    local real_sprint_counter
    real_sprint_counter=$(get_real_sprint_counter)

    local fixed=0

    if [ "$real_task_counter" -gt "$json_task_counter" ] 2>/dev/null; then
        echo -e "${YELLOW}[SWARM]${NC} taskCounter stale ($json_task_counter -> $real_task_counter), fixing..."
        safe_jq_write "$SWARM_DIR/project.json" --argjson c "$real_task_counter" '.taskCounter = $c'
        fixed=1
    fi

    if [ "$real_sprint_counter" -gt "$json_sprint_counter" ] 2>/dev/null; then
        echo -e "${YELLOW}[SWARM]${NC} sprintCounter stale ($json_sprint_counter -> $real_sprint_counter), fixing..."
        safe_jq_write "$SWARM_DIR/project.json" --argjson c "$real_sprint_counter" '.sprintCounter = $c'
        fixed=1
    fi

    return $fixed
}

# Recalculate sprint metrics from actual task files
update_sprint_metrics() {
    local sprint_file="$SWARM_DIR/current-sprint.json"
    [ -f "$sprint_file" ] || return 0

    local planned=0 inprog=0 completed=0 blocked=0 review=0

    local task_ids
    task_ids=$(jq -r '.tasks[]?' "$sprint_file" 2>/dev/null)
    [ -z "$task_ids" ] && return 0

    for tid in $task_ids; do
        local tfile="$SWARM_DIR/tasks/${tid}.task.md"
        [ -f "$tfile" ] || continue
        local status
        status=$(grep "Durum:\*\*" "$tfile" 2>/dev/null | sed 's/.*\*\* //')
        case "$status" in
            planned)      planned=$((planned + 1)) ;;
            in-progress)  inprog=$((inprog + 1)) ;;
            review)       review=$((review + 1)) ;;
            done)         completed=$((completed + 1)) ;;
            blocked)      blocked=$((blocked + 1)) ;;
        esac
    done

    # review counts as inProgress for metrics
    inprog=$((inprog + review))

    safe_jq_write "$sprint_file" \
        --argjson p "$planned" --argjson i "$inprog" --argjson c "$completed" --argjson b "$blocked" \
        '.metrics.planned = $p | .metrics.inProgress = $i | .metrics.completed = $c | .metrics.blocked = $b'
}

# ─────────────────────────────────────────────────────────────
# INIT - Create .swarm/ directory structure
# ─────────────────────────────────────────────────────────────
swarm_init() {
    local project_name="${1:-$(basename "$(pwd)")}"
    local project_type="${2:-unknown}"

    if [ -d "$SWARM_DIR" ]; then
        echo -e "${YELLOW}[SWARM]${NC} .swarm/ already exists. Use 'reset' to reinitialize."
        return 0
    fi

    echo -e "${CYAN}[SWARM]${NC} Initializing swarm for: $project_name"

    mkdir -p "$SWARM_DIR"/{tasks,sprints,communications,context,handoffs/outputs}

    cat > "$SWARM_DIR/project.json" << EOF
{
  "name": "$project_name",
  "description": "",
  "status": "active",
  "type": "$project_type",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "techStack": {
    "backend": "nestjs",
    "frontend": "nextjs",
    "database": "postgresql",
    "queue": "bullmq",
    "cache": "redis"
  },
  "team": {
    "productOwner": true,
    "projectManager": true,
    "developers": []
  },
  "taskCounter": 0,
  "sprintCounter": 0,
  "storyCounter": 0
}
EOF

    cat > "$SWARM_DIR/backlog.json" << 'EOF'
{
  "items": [],
  "lastUpdated": null
}
EOF

    cat > "$SWARM_DIR/current-sprint.json" << 'EOF'
{
  "id": null,
  "name": null,
  "status": "not_started",
  "goal": null,
  "startDate": null,
  "endDate": null,
  "tasks": [],
  "metrics": {
    "planned": 0,
    "completed": 0,
    "inProgress": 0,
    "blocked": 0
  }
}
EOF

    cat > "$SWARM_DIR/context/decisions.json" << 'EOF'
{
  "decisions": [],
  "lastUpdated": null
}
EOF

    cat > "$SWARM_DIR/context/active-agent.json" << 'EOF'
{
  "current": null,
  "previous": null,
  "handoffChain": [],
  "lastUpdated": null
}
EOF

    if [ -f ".gitignore" ]; then
        if ! grep -q "^\.swarm/" ".gitignore" 2>/dev/null; then
            echo -e "\n# Kuark Swarm state\n.swarm/" >> ".gitignore"
        fi
    fi

    echo -e "${GREEN}[SWARM]${NC} Initialized successfully"
    echo -e "  ${GREEN}├${NC} project.json"
    echo -e "  ${GREEN}├${NC} backlog.json"
    echo -e "  ${GREEN}├${NC} current-sprint.json"
    echo -e "  ${GREEN}├${NC} tasks/"
    echo -e "  ${GREEN}├${NC} sprints/"
    echo -e "  ${GREEN}├${NC} communications/"
    echo -e "  ${GREEN}├${NC} handoffs/outputs/"
    echo -e "  ${GREEN}└${NC} context/"
}

# ─────────────────────────────────────────────────────────────
# TASK - Create, update, list tasks
# ─────────────────────────────────────────────────────────────
swarm_task() {
    local action="${1:-list}"
    shift 2>/dev/null || true

    ensure_swarm

    case "$action" in
        create)
            local title="${1:-Untitled Task}"
            local assignee="${2:-unassigned}"
            local priority="${3:-medium}"
            local story="${4:-}"

            # Sync counter from actual files first
            sync_counters 2>/dev/null

            # Read counter and increment
            local counter
            counter=$(jq -r '.taskCounter // 0' "$SWARM_DIR/project.json" 2>/dev/null)
            if [ -z "$counter" ] || [ "$counter" = "null" ]; then
                counter=$(get_real_task_counter)
            fi
            counter=$((counter + 1))

            # Double-check: ensure no file collision
            local task_id
            task_id=$(printf "TASK-%03d" "$counter")
            while [ -f "$SWARM_DIR/tasks/${task_id}.task.md" ]; do
                echo -e "${YELLOW}[SWARM]${NC} ${task_id} already exists, incrementing..."
                counter=$((counter + 1))
                task_id=$(printf "TASK-%03d" "$counter")
            done

            # Write counter back
            if ! safe_jq_write "$SWARM_DIR/project.json" --argjson c "$counter" '.taskCounter = $c'; then
                echo -e "${RED}[SWARM]${NC} Failed to update taskCounter"
                return 1
            fi

            local task_file="$SWARM_DIR/tasks/${task_id}.task.md"

            # Determine current sprint
            local current_sprint_name=""
            local current_sprint_status=""
            local sprint_label="Belirtilmedi"
            if [ -f "$SWARM_DIR/current-sprint.json" ]; then
                current_sprint_name=$(jq -r '.name // ""' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
                current_sprint_status=$(jq -r '.status // ""' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
                if [ "$current_sprint_status" = "active" ] && [ -n "$current_sprint_name" ] && [ "$current_sprint_name" != "null" ]; then
                    sprint_label="$current_sprint_name"
                fi
            fi

            cat > "$task_file" << EOF
# ${task_id}: ${title}

## Meta
- **User Story:** ${story:-Belirtilmedi}
- **Atanan:** ${assignee}
- **Durum:** planned
- **Oncelik:** ${priority}
- **Sprint:** ${sprint_label}
- **Olusturma:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
- **Guncelleme:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Aciklama
[Detayli aciklama ekleyin]

## Kabul Kriterleri
- [ ] Kriter 1
- [ ] Kriter 2

## Teknik Notlar
- [Dikkat edilmesi gerekenler]

## Bagimliliklar
- [Bagimlilik varsa belirtin]

## Checklist
- [ ] Kod yazildi
- [ ] Testler yazildi
- [ ] Dokumantasyon guncellendi
- [ ] Code review yapildi

## Log
- $(date -u +%Y-%m-%dT%H:%M:%SZ) | created | ${assignee} | Task olusturuldu
EOF

            # Verify file was created
            if [ ! -f "$task_file" ]; then
                echo -e "${RED}[SWARM]${NC} CRITICAL: Failed to create task file: $task_file"
                return 1
            fi

            # Add task to current sprint if active
            if [ "$current_sprint_status" = "active" ]; then
                if ! safe_jq_write "$SWARM_DIR/current-sprint.json" --arg tid "$task_id" \
                    '.tasks += [$tid] | .metrics.planned += 1'; then
                    echo -e "${YELLOW}[SWARM]${NC} Warning: Task created but failed to add to sprint"
                fi
            fi

            echo -e "${GREEN}[SWARM]${NC} Created: ${task_id} - ${title} -> ${assignee} (${sprint_label})"
            ;;

        update)
            local task_id="${1:-}"
            local new_status="${2:-}"

            if [ -z "$task_id" ] || [ -z "$new_status" ]; then
                echo -e "${RED}[SWARM]${NC} Usage: swarm task update TASK-XXX status"
                return 1
            fi

            local task_file="$SWARM_DIR/tasks/${task_id}.task.md"
            if [ ! -f "$task_file" ]; then
                echo -e "${RED}[SWARM]${NC} Task not found: $task_id"
                return 1
            fi

            # Validate status
            case "$new_status" in
                planned|in-progress|review|done|blocked) ;;
                *)
                    echo -e "${RED}[SWARM]${NC} Invalid status: $new_status (valid: planned, in-progress, review, done, blocked)"
                    return 1
                    ;;
            esac

            # Get old status
            local old_status
            old_status=$(grep "Durum:\*\*" "$task_file" | sed 's/.*\*\* //')

            if [ "$old_status" = "$new_status" ]; then
                echo -e "${YELLOW}[SWARM]${NC} ${task_id} is already ${new_status}"
                return 0
            fi

            # Update status in task file
            sed -i.bak "s/- \*\*Durum:\*\* .*/- **Durum:** ${new_status}/" "$task_file"
            sed -i.bak "s/- \*\*Guncelleme:\*\* .*/- **Guncelleme:** $(date -u +%Y-%m-%dT%H:%M:%SZ)/" "$task_file"
            rm -f "${task_file}.bak"

            # Append log entry
            echo "- $(date -u +%Y-%m-%dT%H:%M:%SZ) | status_change | ${old_status} -> ${new_status}" >> "$task_file"

            # Update sprint metrics if task belongs to current sprint
            if [ -f "$SWARM_DIR/current-sprint.json" ]; then
                local in_sprint
                in_sprint=$(jq --arg tid "$task_id" '.tasks | index($tid)' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
                if [ "$in_sprint" != "null" ] && [ -n "$in_sprint" ]; then
                    update_sprint_metrics
                fi
            fi

            echo -e "${GREEN}[SWARM]${NC} Updated: ${task_id} ${old_status} -> ${new_status}"
            ;;

        list)
            echo -e "${CYAN}[SWARM]${NC} Task Board:"
            echo ""

            for status in "planned" "in-progress" "review" "blocked" "done"; do
                local count=0
                local tasks=""
                for f in "$SWARM_DIR"/tasks/*.task.md; do
                    [ -f "$f" ] || continue
                    if grep -q "Durum:\*\* $status" "$f"; then
                        local id
                        id=$(basename "$f" .task.md)
                        local title
                        title=$(head -1 "$f" | sed 's/^# //')
                        local assignee
                        assignee=$(grep "Atanan:" "$f" | sed 's/.*\*\* //')
                        local sprint
                        sprint=$(grep "Sprint:" "$f" | sed 's/.*\*\* //')
                        tasks="$tasks  $id | $assignee | $sprint | $title\n"
                        count=$((count + 1))
                    fi
                done

                case "$status" in
                    planned)     echo -e "${YELLOW}[$status] ($count)${NC}" ;;
                    in-progress) echo -e "${CYAN}[$status] ($count)${NC}" ;;
                    review)      echo -e "${BLUE}[$status] ($count)${NC}" ;;
                    blocked)     echo -e "${RED}[$status] ($count)${NC}" ;;
                    done)        echo -e "${GREEN}[$status] ($count)${NC}" ;;
                esac

                if [ -n "$tasks" ]; then
                    echo -e "$tasks"
                fi
            done
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────
# SPRINT - Manage sprints
# ─────────────────────────────────────────────────────────────
swarm_sprint() {
    local action="${1:-status}"
    shift 2>/dev/null || true

    ensure_swarm

    case "$action" in
        start)
            local name="${1:-}"
            local goal="${2:-}"

            # FIRST: Archive current sprint if active (before counter change)
            local current_status
            current_status=$(jq -r '.status // "not_started"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            if [ "$current_status" = "active" ]; then
                local current_sprint_name
                current_sprint_name=$(jq -r '.name' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
                local current_sprint_id
                current_sprint_id=$(jq -r '.id // "0"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)

                # Recalculate final metrics
                update_sprint_metrics

                # Mark as completed
                safe_jq_write "$SWARM_DIR/current-sprint.json" \
                    '.status = "completed" | .endDate = (now | todate)'

                # Archive with sprint ID
                local archive_name
                archive_name=$(printf "sprint-%03d-%s" "$current_sprint_id" "${current_sprint_name// /-}")
                cp "$SWARM_DIR/current-sprint.json" "$SWARM_DIR/sprints/${archive_name}.json"
                echo -e "${YELLOW}[SWARM]${NC} Archived: $current_sprint_name -> sprints/${archive_name}.json"
            fi

            # THEN: Increment sprint counter
            sync_counters 2>/dev/null
            local counter
            counter=$(jq -r '.sprintCounter // 0' "$SWARM_DIR/project.json" 2>/dev/null)
            if [ -z "$counter" ] || [ "$counter" = "null" ]; then
                counter=$(get_real_sprint_counter)
            fi
            counter=$((counter + 1))

            if ! safe_jq_write "$SWARM_DIR/project.json" --argjson c "$counter" '.sprintCounter = $c'; then
                echo -e "${RED}[SWARM]${NC} Failed to update sprintCounter"
                return 1
            fi

            # Auto-generate name if not provided
            if [ -z "$name" ]; then
                name="Sprint $counter"
            fi

            # Create new sprint with ID
            cat > "$SWARM_DIR/current-sprint.json" << EOF
{
  "id": $counter,
  "name": "$name",
  "status": "active",
  "goal": "${goal:-Belirtilmedi}",
  "startDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "endDate": null,
  "tasks": [],
  "metrics": {
    "planned": 0,
    "completed": 0,
    "inProgress": 0,
    "blocked": 0
  }
}
EOF
            echo -e "${GREEN}[SWARM]${NC} Started: $name (Sprint #$counter)"
            ;;

        end)
            local current_status
            current_status=$(jq -r '.status' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            if [ "$current_status" != "active" ]; then
                echo -e "${YELLOW}[SWARM]${NC} No active sprint to end."
                return 0
            fi

            local current_name
            current_name=$(jq -r '.name' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            local sprint_id
            sprint_id=$(jq -r '.id // 0' "$SWARM_DIR/current-sprint.json" 2>/dev/null)

            # Recalculate final metrics
            update_sprint_metrics

            # Mark completed
            if ! safe_jq_write "$SWARM_DIR/current-sprint.json" \
                '.status = "completed" | .endDate = (now | todate)'; then
                echo -e "${RED}[SWARM]${NC} Failed to update sprint status"
                return 1
            fi

            # Archive
            local archive_name
            archive_name=$(printf "sprint-%03d-%s" "$sprint_id" "${current_name// /-}")
            cp "$SWARM_DIR/current-sprint.json" "$SWARM_DIR/sprints/${archive_name}.json"

            # Verify archive
            if [ ! -f "$SWARM_DIR/sprints/${archive_name}.json" ]; then
                echo -e "${RED}[SWARM]${NC} CRITICAL: Failed to archive sprint!"
                return 1
            fi

            echo -e "${GREEN}[SWARM]${NC} Ended & archived: $current_name -> sprints/${archive_name}.json"
            ;;

        status)
            local name
            name=$(jq -r '.name // "No active sprint"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            local status
            status=$(jq -r '.status // "unknown"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            local goal
            goal=$(jq -r '.goal // "N/A"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            local sprint_id
            sprint_id=$(jq -r '.id // "?"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)

            echo -e "${CYAN}[SWARM]${NC} Sprint #$sprint_id: $name ($status)"
            echo -e "  Goal: $goal"

            # Always recalculate from actual files
            if [ "$status" = "active" ]; then
                update_sprint_metrics
            fi

            # Count from sprint's task list
            local planned=0 inprog=0 review_count=0 done_count=0 blocked=0 missing=0
            local sprint_tasks
            sprint_tasks=$(jq -r '.tasks[]?' "$SWARM_DIR/current-sprint.json" 2>/dev/null)

            if [ -n "$sprint_tasks" ]; then
                for tid in $sprint_tasks; do
                    local tfile="$SWARM_DIR/tasks/${tid}.task.md"
                    if [ ! -f "$tfile" ]; then
                        missing=$((missing + 1))
                        continue
                    fi
                    local tstatus
                    tstatus=$(grep "Durum:\*\*" "$tfile" 2>/dev/null | sed 's/.*\*\* //')
                    case "$tstatus" in
                        planned)     planned=$((planned + 1)) ;;
                        in-progress) inprog=$((inprog + 1)) ;;
                        review)      review_count=$((review_count + 1)) ;;
                        done)        done_count=$((done_count + 1)) ;;
                        blocked)     blocked=$((blocked + 1)) ;;
                    esac
                done
            fi

            local total=$((planned + inprog + review_count + done_count + blocked))
            echo -e "  Tasks ($total): ${YELLOW}$planned planned${NC} | ${CYAN}$inprog active${NC} | ${BLUE}$review_count review${NC} | ${RED}$blocked blocked${NC} | ${GREEN}$done_count done${NC}"

            if [ "$missing" -gt 0 ]; then
                echo -e "  ${RED}Warning: $missing task file(s) missing!${NC}"
            fi

            # List task details
            if [ -n "$sprint_tasks" ]; then
                echo ""
                for tid in $sprint_tasks; do
                    local tfile="$SWARM_DIR/tasks/${tid}.task.md"
                    if [ ! -f "$tfile" ]; then
                        echo -e "  ${RED}?${NC} $tid (FILE MISSING)"
                        continue
                    fi
                    local tstatus
                    tstatus=$(grep "Durum:\*\*" "$tfile" 2>/dev/null | sed 's/.*\*\* //')
                    local tassignee
                    tassignee=$(grep "Atanan:" "$tfile" 2>/dev/null | sed 's/.*\*\* //')
                    local ttitle
                    ttitle=$(head -1 "$tfile" | sed 's/^# //')
                    local icon="?"
                    case "$tstatus" in
                        planned)     icon="⬜" ;;
                        in-progress) icon="🔄" ;;
                        review)      icon="👀" ;;
                        done)        icon="✅" ;;
                        blocked)     icon="🚫" ;;
                    esac
                    echo -e "  $icon $ttitle ($tassignee)"
                done
            fi
            ;;

        add-task)
            local task_id="${1:-}"
            if [ -z "$task_id" ]; then
                echo -e "${RED}[SWARM]${NC} Usage: swarm sprint add-task TASK-XXX"
                return 1
            fi

            local task_file="$SWARM_DIR/tasks/${task_id}.task.md"
            if [ ! -f "$task_file" ]; then
                echo -e "${RED}[SWARM]${NC} Task not found: $task_id"
                return 1
            fi

            local sprint_status
            sprint_status=$(jq -r '.status' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            if [ "$sprint_status" != "active" ]; then
                echo -e "${RED}[SWARM]${NC} No active sprint. Start one first."
                return 1
            fi

            # Check if already in sprint
            local already
            already=$(jq --arg tid "$task_id" '.tasks | index($tid)' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            if [ "$already" != "null" ] && [ -n "$already" ]; then
                echo -e "${YELLOW}[SWARM]${NC} $task_id is already in the current sprint."
                return 0
            fi

            # Add to sprint
            if ! safe_jq_write "$SWARM_DIR/current-sprint.json" --arg tid "$task_id" \
                '.tasks += [$tid]'; then
                echo -e "${RED}[SWARM]${NC} Failed to add task to sprint"
                return 1
            fi

            # Update sprint label in task file
            local sprint_name
            sprint_name=$(jq -r '.name' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            sed -i.bak "s/- \*\*Sprint:\*\* .*/- **Sprint:** ${sprint_name}/" "$task_file"
            rm -f "${task_file}.bak"

            # Recalculate metrics
            update_sprint_metrics

            echo -e "${GREEN}[SWARM]${NC} Added $task_id to current sprint"
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────
# HANDOFF - Agent-to-agent transition logging
# ─────────────────────────────────────────────────────────────
swarm_handoff() {
    local from_agent="${1:-}"
    local to_agent="${2:-}"
    local task_id="${3:-}"
    local summary="${4:-}"

    ensure_swarm

    if [ -z "$from_agent" ] || [ -z "$to_agent" ]; then
        echo -e "${RED}[SWARM]${NC} Usage: swarm handoff <from-agent> <to-agent> [task-id] [summary]"
        return 1
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local date_str
    date_str=$(date -u +%Y-%m-%d)

    # Log handoff
    local handoff_file="$SWARM_DIR/handoffs/${date_str}.json"
    if [ ! -f "$handoff_file" ]; then
        echo '{"handoffs":[]}' > "$handoff_file"
    fi

    # Build entry with proper null handling
    local task_val="null"
    if [ -n "$task_id" ]; then
        task_val="\"$task_id\""
    fi

    local entry="{\"timestamp\":\"$timestamp\",\"from\":\"$from_agent\",\"to\":\"$to_agent\",\"taskId\":$task_val,\"summary\":\"${summary:-Agent transition}\"}"

    if ! safe_jq_write "$handoff_file" --argjson entry "$entry" '.handoffs += [$entry]'; then
        echo -e "${RED}[SWARM]${NC} Failed to log handoff"
        return 1
    fi

    # Update active agent context
    if ! safe_jq_write "$SWARM_DIR/context/active-agent.json" \
        --arg from "$from_agent" --arg to "$to_agent" --arg ts "$timestamp" '
        .previous = .current |
        .current = $to |
        .handoffChain += [{"from": $from, "to": $to, "at": $ts}] |
        .lastUpdated = $ts
    '; then
        echo -e "${RED}[SWARM]${NC} Failed to update active-agent.json"
        return 1
    fi

    echo -e "${GREEN}[SWARM]${NC} Handoff: $from_agent -> $to_agent ${task_id:+(${task_id})}"
}

# ─────────────────────────────────────────────────────────────
# COMMUNICATE - Log inter-agent messages
# ─────────────────────────────────────────────────────────────
swarm_communicate() {
    ensure_swarm

    local input
    if [ -t 0 ]; then
        echo -e "${RED}[SWARM]${NC} Pipe a JSON message to this command"
        return 1
    fi

    input=$(cat)
    local date_str
    date_str=$(date -u +%Y-%m-%d)
    local comm_file="$SWARM_DIR/communications/${date_str}.json"

    if [ ! -f "$comm_file" ]; then
        echo '{"messages":[]}' > "$comm_file"
    fi

    local enriched
    enriched=$(echo "$input" | jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '. + {timestamp: $ts}' 2>/dev/null)
    if [ -z "$enriched" ]; then
        echo -e "${RED}[SWARM]${NC} Invalid JSON input"
        return 1
    fi

    if ! safe_jq_write "$comm_file" --argjson msg "$enriched" '.messages += [$msg]'; then
        echo -e "${RED}[SWARM]${NC} Failed to log message"
        return 1
    fi

    local from
    from=$(echo "$input" | jq -r '.from // "unknown"' 2>/dev/null)
    local to
    to=$(echo "$input" | jq -r '.to // "unknown"' 2>/dev/null)
    local msg_type
    msg_type=$(echo "$input" | jq -r '.type // "message"' 2>/dev/null)

    echo -e "${GREEN}[SWARM]${NC} Message logged: $from -> $to ($msg_type)"
}

# ─────────────────────────────────────────────────────────────
# STATUS - Overall swarm status
# ─────────────────────────────────────────────────────────────
swarm_status() {
    if [ ! -d "$SWARM_DIR" ]; then
        echo -e "${YELLOW}[SWARM]${NC} Not initialized. Run: bash hooks/swarm.sh init [project-name]"
        return 0
    fi

    local project_name
    project_name=$(jq -r '.name // "Unknown"' "$SWARM_DIR/project.json" 2>/dev/null)
    local project_status
    project_status=$(jq -r '.status // "unknown"' "$SWARM_DIR/project.json" 2>/dev/null)

    echo -e "${CYAN}[SWARM]${NC} Project: $project_name ($project_status)"

    # Counter health check
    sync_counters 2>/dev/null

    # Sprint info
    local sprint_name
    sprint_name=$(jq -r '.name // "None"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
    local sprint_status
    sprint_status=$(jq -r '.status // "none"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
    local sprint_id
    sprint_id=$(jq -r '.id // "?"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
    echo -e "  Sprint #$sprint_id: $sprint_name ($sprint_status)"

    # Recalculate metrics from actual files
    if [ "$sprint_status" = "active" ]; then
        update_sprint_metrics
    fi

    # Sprint task counts
    local sprint_task_count
    sprint_task_count=$(jq -r '.tasks | length' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
    local sprint_metrics
    sprint_metrics=$(jq -r '"\(.metrics.planned)p \(.metrics.inProgress)a \(.metrics.completed)d \(.metrics.blocked)b"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
    echo -e "  Sprint Tasks ($sprint_task_count): $sprint_metrics"

    # Total task counts (all tasks, all sprints)
    local total=0 planned=0 inprog=0 review=0 done=0 blocked=0
    for f in "$SWARM_DIR"/tasks/*.task.md; do
        [ -f "$f" ] || continue
        total=$((total + 1))
        if grep -q "Durum:\*\* planned" "$f"; then planned=$((planned + 1)); fi
        if grep -q "Durum:\*\* in-progress" "$f"; then inprog=$((inprog + 1)); fi
        if grep -q "Durum:\*\* review" "$f"; then review=$((review + 1)); fi
        if grep -q "Durum:\*\* done" "$f"; then done=$((done + 1)); fi
        if grep -q "Durum:\*\* blocked" "$f"; then blocked=$((blocked + 1)); fi
    done
    echo -e "  All Tasks: $total total | ${YELLOW}$planned${NC} planned | ${CYAN}$inprog${NC} active | ${BLUE}$review${NC} review | ${RED}$blocked${NC} blocked | ${GREEN}$done${NC} done"

    # Orphan tasks (not in any sprint)
    local orphan_count=0
    for f in "$SWARM_DIR"/tasks/*.task.md; do
        [ -f "$f" ] || continue
        if grep -q "Sprint:\*\* Belirtilmedi" "$f"; then
            orphan_count=$((orphan_count + 1))
        fi
    done
    if [ "$orphan_count" -gt 0 ]; then
        echo -e "  ${YELLOW}Warning: $orphan_count task(s) not assigned to any sprint${NC}"
    fi

    # Archived sprints
    local archive_count=0
    for f in "$SWARM_DIR"/sprints/sprint-*.json; do
        [ -f "$f" ] || continue
        archive_count=$((archive_count + 1))
    done
    echo -e "  Archived Sprints: $archive_count"

    # Active agent
    local active_agent
    active_agent=$(jq -r '.current // "none"' "$SWARM_DIR/context/active-agent.json" 2>/dev/null)
    echo -e "  Active Agent: $active_agent"

    # Recent handoffs
    local latest_handoff
    latest_handoff=$(ls -t "$SWARM_DIR"/handoffs/*.json 2>/dev/null | head -1)
    if [ -n "$latest_handoff" ]; then
        local last_from last_to
        last_from=$(jq -r '.handoffs[-1].from // "?"' "$latest_handoff" 2>/dev/null)
        last_to=$(jq -r '.handoffs[-1].to // "?"' "$latest_handoff" 2>/dev/null)
        echo -e "  Last Handoff: $last_from -> $last_to"
    fi

    # Counters
    local task_counter sprint_counter
    task_counter=$(jq -r '.taskCounter' "$SWARM_DIR/project.json" 2>/dev/null)
    sprint_counter=$(jq -r '.sprintCounter' "$SWARM_DIR/project.json" 2>/dev/null)
    echo -e "  Counters: tasks=$task_counter sprints=$sprint_counter"
}

# ─────────────────────────────────────────────────────────────
# REPAIR - Fix inconsistencies
# ─────────────────────────────────────────────────────────────
swarm_repair() {
    ensure_swarm

    echo -e "${CYAN}[SWARM]${NC} Running repair..."
    local fixes=0

    # 1. Fix counters
    local json_task_counter
    json_task_counter=$(jq -r '.taskCounter // 0' "$SWARM_DIR/project.json" 2>/dev/null || echo "0")
    local real_task_counter
    real_task_counter=$(get_real_task_counter)

    if [ "$real_task_counter" -gt "$json_task_counter" ] 2>/dev/null; then
        echo -e "  ${YELLOW}FIX${NC} taskCounter: $json_task_counter -> $real_task_counter"
        safe_jq_write "$SWARM_DIR/project.json" --argjson c "$real_task_counter" '.taskCounter = $c'
        fixes=$((fixes + 1))
    fi

    local json_sprint_counter
    json_sprint_counter=$(jq -r '.sprintCounter // 0' "$SWARM_DIR/project.json" 2>/dev/null || echo "0")
    local real_sprint_counter
    real_sprint_counter=$(get_real_sprint_counter)

    # Also check current sprint ID
    local current_sprint_id
    current_sprint_id=$(jq -r '.id // 0' "$SWARM_DIR/current-sprint.json" 2>/dev/null || echo "0")
    if [ "$current_sprint_id" -gt "$real_sprint_counter" ] 2>/dev/null; then
        real_sprint_counter=$current_sprint_id
    fi

    if [ "$real_sprint_counter" -gt "$json_sprint_counter" ] 2>/dev/null; then
        echo -e "  ${YELLOW}FIX${NC} sprintCounter: $json_sprint_counter -> $real_sprint_counter"
        safe_jq_write "$SWARM_DIR/project.json" --argjson c "$real_sprint_counter" '.sprintCounter = $c'
        fixes=$((fixes + 1))
    fi

    # 2. Check sprint tasks array vs actual files
    local sprint_status
    sprint_status=$(jq -r '.status' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
    if [ "$sprint_status" = "active" ]; then
        local sprint_tasks
        sprint_tasks=$(jq -r '.tasks[]?' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
        local missing_files=""

        for tid in $sprint_tasks; do
            if [ ! -f "$SWARM_DIR/tasks/${tid}.task.md" ]; then
                missing_files="$missing_files $tid"
            fi
        done

        if [ -n "$missing_files" ]; then
            echo -e "  ${RED}WARN${NC} Missing task files:$missing_files"
            echo -e "  ${YELLOW}FIX${NC} Removing missing tasks from sprint"
            for tid in $missing_files; do
                safe_jq_write "$SWARM_DIR/current-sprint.json" --arg tid "$tid" \
                    '.tasks = [.tasks[] | select(. != $tid)]'
                fixes=$((fixes + 1))
            done
        fi

        # 3. Find orphan tasks (tasks with current sprint name but not in sprint tasks array)
        local sprint_name
        sprint_name=$(jq -r '.name' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
        for f in "$SWARM_DIR"/tasks/*.task.md; do
            [ -f "$f" ] || continue
            local file_sprint
            file_sprint=$(grep "Sprint:\*\*" "$f" 2>/dev/null | sed 's/.*\*\* //')
            if [ "$file_sprint" = "$sprint_name" ]; then
                local tid
                tid=$(basename "$f" .task.md)
                local in_array
                in_array=$(jq --arg tid "$tid" '.tasks | index($tid)' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
                if [ "$in_array" = "null" ] || [ -z "$in_array" ]; then
                    echo -e "  ${YELLOW}FIX${NC} Adding orphan task $tid to sprint"
                    safe_jq_write "$SWARM_DIR/current-sprint.json" --arg tid "$tid" '.tasks += [$tid]'
                    fixes=$((fixes + 1))
                fi
            fi
        done

        # 4. Recalculate metrics
        update_sprint_metrics
        echo -e "  ${GREEN}OK${NC} Sprint metrics recalculated"
    fi

    # 5. Ensure active-agent.json exists and is valid
    if [ ! -f "$SWARM_DIR/context/active-agent.json" ] || ! jq empty "$SWARM_DIR/context/active-agent.json" 2>/dev/null; then
        echo -e "  ${YELLOW}FIX${NC} Recreating active-agent.json"
        cat > "$SWARM_DIR/context/active-agent.json" << 'EOF'
{
  "current": null,
  "previous": null,
  "handoffChain": [],
  "lastUpdated": null
}
EOF
        fixes=$((fixes + 1))
    fi

    # 6. Ensure decisions.json exists and is valid
    if [ ! -f "$SWARM_DIR/context/decisions.json" ] || ! jq empty "$SWARM_DIR/context/decisions.json" 2>/dev/null; then
        echo -e "  ${YELLOW}FIX${NC} Recreating decisions.json"
        cat > "$SWARM_DIR/context/decisions.json" << 'EOF'
{
  "decisions": [],
  "lastUpdated": null
}
EOF
        fixes=$((fixes + 1))
    fi

    if [ "$fixes" -eq 0 ]; then
        echo -e "${GREEN}[SWARM]${NC} No issues found - everything looks healthy"
    else
        echo -e "${GREEN}[SWARM]${NC} Repair complete: $fixes fix(es) applied"
    fi
}

# ─────────────────────────────────────────────────────────────
# RESET - Re-initialize (with confirmation)
# ─────────────────────────────────────────────────────────────
swarm_reset() {
    if [ -d "$SWARM_DIR" ]; then
        echo -e "${YELLOW}[SWARM]${NC} Removing existing .swarm/ directory..."
        rm -rf "$SWARM_DIR"
    fi
    swarm_init "$@"
}

# ─────────────────────────────────────────────────────────────
# ROUTER
# ─────────────────────────────────────────────────────────────
case "$COMMAND" in
    init)        swarm_init "$@" ;;
    reset)       swarm_reset "$@" ;;
    task)        swarm_task "$@" ;;
    sprint)      swarm_sprint "$@" ;;
    handoff)     swarm_handoff "$@" ;;
    communicate) swarm_communicate "$@" ;;
    status)      swarm_status ;;
    repair)      swarm_repair ;;
    *)
        echo -e "${CYAN}[SWARM]${NC} Usage:"
        echo "  swarm init [project-name] [type]  - Initialize .swarm/"
        echo "  swarm reset [project-name]        - Reset .swarm/"
        echo "  swarm task create <title> [assignee] [priority] [story]"
        echo "  swarm task update <TASK-XXX> <status>"
        echo "  swarm task list"
        echo "  swarm sprint start [name] [goal]"
        echo "  swarm sprint end"
        echo "  swarm sprint status"
        echo "  swarm sprint add-task <TASK-XXX>"
        echo "  swarm handoff <from> <to> [task-id] [summary]"
        echo "  swarm communicate (pipe JSON)"
        echo "  swarm status"
        echo "  swarm repair                      - Fix inconsistencies"
        ;;
esac
