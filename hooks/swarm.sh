#!/bin/bash
# Kuark Swarm Management
# Manages .swarm/ directory lifecycle: init, task, sprint, handoff, status

set -e

# Global kuark-system installation path
KUARK_HOME="${KUARK_HOME:-$HOME/.kuark}"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SWARM_DIR=".swarm"
COMMAND="${1:-status}"
shift 2>/dev/null || true

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

    # Create directory structure
    mkdir -p "$SWARM_DIR"/{tasks,sprints,communications,context,handoffs/outputs}

    # Create project.json
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

    # Create empty backlog
    cat > "$SWARM_DIR/backlog.json" << 'EOF'
{
  "items": [],
  "lastUpdated": null
}
EOF

    # Create initial sprint placeholder
    cat > "$SWARM_DIR/current-sprint.json" << 'EOF'
{
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

    # Create context/decisions.json for ADRs
    cat > "$SWARM_DIR/context/decisions.json" << 'EOF'
{
  "decisions": [],
  "lastUpdated": null
}
EOF

    # Create context/active-agent.json for handoff tracking
    cat > "$SWARM_DIR/context/active-agent.json" << 'EOF'
{
  "current": null,
  "previous": null,
  "handoffChain": [],
  "lastUpdated": null
}
EOF

    # Add .swarm to .gitignore if not already there
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

            # Increment task counter
            local counter
            counter=$(jq -r '.taskCounter' "$SWARM_DIR/project.json")
            counter=$((counter + 1))
            jq ".taskCounter = $counter" "$SWARM_DIR/project.json" > "$SWARM_DIR/project.json.tmp"
            mv "$SWARM_DIR/project.json.tmp" "$SWARM_DIR/project.json"

            local task_id
            task_id=$(printf "TASK-%03d" "$counter")
            local task_file="$SWARM_DIR/tasks/${task_id}.task.md"

            # Determine current sprint name
            local current_sprint_name
            current_sprint_name=$(jq -r '.name // ""' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            local current_sprint_status
            current_sprint_status=$(jq -r '.status' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
            local sprint_label="Belirtilmedi"
            if [ "$current_sprint_status" = "active" ] && [ -n "$current_sprint_name" ] && [ "$current_sprint_name" != "null" ]; then
                sprint_label="$current_sprint_name"
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

            # Add task to current sprint if active
            if [ "$current_sprint_status" = "active" ]; then
                jq --arg tid "$task_id" '
                  .tasks += [$tid] |
                  .metrics.planned += 1
                ' "$SWARM_DIR/current-sprint.json" > "$SWARM_DIR/current-sprint.json.tmp"
                mv "$SWARM_DIR/current-sprint.json.tmp" "$SWARM_DIR/current-sprint.json"
            fi

            echo -e "${GREEN}[SWARM]${NC} Created: ${task_id} - ${title} -> ${assignee}${current_sprint_status:+ (${sprint_label})}"
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

            # Get old status before updating
            local old_status
            old_status=$(grep "Durum:\*\*" "$task_file" | sed 's/.*\*\* //')

            # Update status in task file
            sed -i.bak "s/- \*\*Durum:\*\* .*/- **Durum:** ${new_status}/" "$task_file"
            sed -i.bak "s/- \*\*Guncelleme:\*\* .*/- **Guncelleme:** $(date -u +%Y-%m-%dT%H:%M:%SZ)/" "$task_file"
            rm -f "${task_file}.bak"

            # Append log entry
            echo "- $(date -u +%Y-%m-%dT%H:%M:%SZ) | status_change | ${new_status}" >> "$task_file"

            # Update sprint metrics if task belongs to current sprint
            if [ -f "$SWARM_DIR/current-sprint.json" ]; then
                local in_sprint
                in_sprint=$(jq --arg tid "$task_id" '.tasks | index($tid)' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
                if [ "$in_sprint" != "null" ] && [ -n "$in_sprint" ]; then
                    update_sprint_metrics
                fi
            fi

            echo -e "${GREEN}[SWARM]${NC} Updated: ${task_id} -> ${new_status}"
            ;;

        list)
            echo -e "${CYAN}[SWARM]${NC} Task Board:"
            echo ""

            for status in "planned" "in-progress" "review" "done"; do
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
                        tasks="$tasks  $id | $assignee | $title\n"
                        count=$((count + 1))
                    fi
                done

                case "$status" in
                    planned)     echo -e "${YELLOW}[$status] ($count)${NC}" ;;
                    in-progress) echo -e "${CYAN}[$status] ($count)${NC}" ;;
                    review)      echo -e "${BLUE}[$status] ($count)${NC}" ;;
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
            local name="${1:-Sprint $(jq -r '.sprintCounter + 1' "$SWARM_DIR/project.json")}"
            local goal="${2:-}"

            # Increment sprint counter
            local counter
            counter=$(jq -r '.sprintCounter' "$SWARM_DIR/project.json")
            counter=$((counter + 1))
            jq ".sprintCounter = $counter" "$SWARM_DIR/project.json" > "$SWARM_DIR/project.json.tmp"
            mv "$SWARM_DIR/project.json.tmp" "$SWARM_DIR/project.json"

            # Archive current sprint if active
            local current_status
            current_status=$(jq -r '.status' "$SWARM_DIR/current-sprint.json")
            if [ "$current_status" = "active" ]; then
                # Recalculate metrics before archiving
                update_sprint_metrics
                local current_name
                current_name=$(jq -r '.name' "$SWARM_DIR/current-sprint.json")
                local prev_counter
                prev_counter=$(jq -r '.sprintCounter' "$SWARM_DIR/project.json")
                local archive_name
                archive_name=$(printf "sprint-%03d-%s" "$prev_counter" "${current_name// /-}")
                jq '.status = "completed" | .endDate = (now | todate)' "$SWARM_DIR/current-sprint.json" > "$SWARM_DIR/current-sprint.json.tmp"
                mv "$SWARM_DIR/current-sprint.json.tmp" "$SWARM_DIR/current-sprint.json"
                cp "$SWARM_DIR/current-sprint.json" "$SWARM_DIR/sprints/${archive_name}.json"
                echo -e "${YELLOW}[SWARM]${NC} Archived: $current_name -> sprints/${archive_name}.json"
            fi

            # Create new sprint
            cat > "$SWARM_DIR/current-sprint.json" << EOF
{
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
            echo -e "${GREEN}[SWARM]${NC} Started: $name"
            ;;

        end)
            local current_name
            current_name=$(jq -r '.name' "$SWARM_DIR/current-sprint.json")

            # Recalculate final metrics before archiving
            update_sprint_metrics

            jq '.status = "completed" | .endDate = (now | todate)' "$SWARM_DIR/current-sprint.json" > "$SWARM_DIR/current-sprint.json.tmp"
            mv "$SWARM_DIR/current-sprint.json.tmp" "$SWARM_DIR/current-sprint.json"

            # Archive to sprints/ with sprint counter
            local sprint_counter
            sprint_counter=$(jq -r '.sprintCounter' "$SWARM_DIR/project.json")
            local archive_name
            archive_name=$(printf "sprint-%03d-%s" "$sprint_counter" "${current_name// /-}")
            cp "$SWARM_DIR/current-sprint.json" "$SWARM_DIR/sprints/${archive_name}.json"

            echo -e "${GREEN}[SWARM]${NC} Ended & archived: $current_name -> sprints/${archive_name}.json"
            ;;

        status)
            local name
            name=$(jq -r '.name // "No active sprint"' "$SWARM_DIR/current-sprint.json")
            local status
            status=$(jq -r '.status' "$SWARM_DIR/current-sprint.json")
            local goal
            goal=$(jq -r '.goal // "N/A"' "$SWARM_DIR/current-sprint.json")

            echo -e "${CYAN}[SWARM]${NC} Sprint: $name ($status)"
            echo -e "  Goal: $goal"

            # Count tasks by status - only tasks in current sprint
            local planned=0 inprog=0 review=0 done_count=0
            local sprint_tasks
            sprint_tasks=$(jq -r '.tasks[]' "$SWARM_DIR/current-sprint.json" 2>/dev/null)

            if [ -n "$sprint_tasks" ]; then
                for tid in $sprint_tasks; do
                    local tfile="$SWARM_DIR/tasks/${tid}.task.md"
                    [ -f "$tfile" ] || continue
                    if grep -q "Durum:\*\* planned" "$tfile"; then planned=$((planned + 1)); fi
                    if grep -q "Durum:\*\* in-progress" "$tfile"; then inprog=$((inprog + 1)); fi
                    if grep -q "Durum:\*\* review" "$tfile"; then review=$((review + 1)); fi
                    if grep -q "Durum:\*\* done" "$tfile"; then done_count=$((done_count + 1)); fi
                done
            fi

            local total=$((planned + inprog + review + done_count))
            echo -e "  Tasks ($total): ${YELLOW}$planned planned${NC} | ${CYAN}$inprog active${NC} | ${BLUE}$review review${NC} | ${GREEN}$done_count done${NC}"

            # List task details
            if [ -n "$sprint_tasks" ]; then
                echo ""
                for tid in $sprint_tasks; do
                    local tfile="$SWARM_DIR/tasks/${tid}.task.md"
                    [ -f "$tfile" ] || continue
                    local tstatus
                    tstatus=$(grep "Durum:\*\*" "$tfile" | sed 's/.*\*\* //')
                    local tassignee
                    tassignee=$(grep "Atanan:" "$tfile" | sed 's/.*\*\* //')
                    local ttitle
                    ttitle=$(head -1 "$tfile" | sed 's/^# //')
                    local icon="⬜"
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
            sprint_status=$(jq -r '.status' "$SWARM_DIR/current-sprint.json")
            if [ "$sprint_status" != "active" ]; then
                echo -e "${RED}[SWARM]${NC} No active sprint. Start one first."
                return 1
            fi

            # Check if already in sprint
            local already
            already=$(jq --arg tid "$task_id" '.tasks | index($tid)' "$SWARM_DIR/current-sprint.json")
            if [ "$already" != "null" ]; then
                echo -e "${YELLOW}[SWARM]${NC} $task_id is already in the current sprint."
                return 0
            fi

            # Add to sprint
            jq --arg tid "$task_id" '.tasks += [$tid]' "$SWARM_DIR/current-sprint.json" > "$SWARM_DIR/current-sprint.json.tmp"
            mv "$SWARM_DIR/current-sprint.json.tmp" "$SWARM_DIR/current-sprint.json"

            # Update sprint label in task file
            local sprint_name
            sprint_name=$(jq -r '.name' "$SWARM_DIR/current-sprint.json")
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

    local entry
    entry=$(cat << EOF
{
  "timestamp": "$timestamp",
  "from": "$from_agent",
  "to": "$to_agent",
  "taskId": "${task_id:-null}",
  "summary": "${summary:-Agent transition}"
}
EOF
)
    jq ".handoffs += [$entry]" "$handoff_file" > "${handoff_file}.tmp" 2>/dev/null
    mv "${handoff_file}.tmp" "$handoff_file"

    # Update active agent context
    jq --arg from "$from_agent" --arg to "$to_agent" --arg ts "$timestamp" '
      .previous = .current |
      .current = $to |
      .handoffChain += [{"from": $from, "to": $to, "at": $ts}] |
      .lastUpdated = $ts
    ' "$SWARM_DIR/context/active-agent.json" > "$SWARM_DIR/context/active-agent.json.tmp" 2>/dev/null
    mv "$SWARM_DIR/context/active-agent.json.tmp" "$SWARM_DIR/context/active-agent.json"

    echo -e "${GREEN}[SWARM]${NC} Handoff: $from_agent -> $to_agent ${task_id:+(${task_id})}"
}

# ─────────────────────────────────────────────────────────────
# COMMUNICATE - Log inter-agent messages
# ─────────────────────────────────────────────────────────────
swarm_communicate() {
    ensure_swarm

    # Read message from stdin (JSON)
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
    enriched=$(echo "$input" | jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '. + {timestamp: $ts}')
    jq ".messages += [$enriched]" "$comm_file" > "${comm_file}.tmp" 2>/dev/null
    mv "${comm_file}.tmp" "$comm_file"

    local from
    from=$(echo "$input" | jq -r '.from // "unknown"')
    local to
    to=$(echo "$input" | jq -r '.to // "unknown"')
    local msg_type
    msg_type=$(echo "$input" | jq -r '.type // "message"')

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

    # Sprint info
    local sprint_name
    sprint_name=$(jq -r '.name // "None"' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
    local sprint_status
    sprint_status=$(jq -r '.status' "$SWARM_DIR/current-sprint.json" 2>/dev/null)
    echo -e "  Sprint: $sprint_name ($sprint_status)"

    # Task counts
    local total=0 planned=0 inprog=0 review=0 done=0
    for f in "$SWARM_DIR"/tasks/*.task.md; do
        [ -f "$f" ] || continue
        total=$((total + 1))
        if grep -q "Durum:\*\* planned" "$f"; then planned=$((planned + 1)); fi
        if grep -q "Durum:\*\* in-progress" "$f"; then inprog=$((inprog + 1)); fi
        if grep -q "Durum:\*\* review" "$f"; then review=$((review + 1)); fi
        if grep -q "Durum:\*\* done" "$f"; then done=$((done + 1)); fi
    done
    echo -e "  Tasks: $total total | ${YELLOW}$planned${NC} planned | ${CYAN}$inprog${NC} active | ${GREEN}$done${NC} done"

    # Active agent
    local active_agent
    active_agent=$(jq -r '.current // "none"' "$SWARM_DIR/context/active-agent.json" 2>/dev/null)
    echo -e "  Active Agent: $active_agent"

    # Recent handoffs
    local latest_handoff
    latest_handoff=$(ls -t "$SWARM_DIR"/handoffs/*.json 2>/dev/null | head -1)
    if [ -n "$latest_handoff" ]; then
        local last_from last_to last_ts
        last_from=$(jq -r '.handoffs[-1].from // "?"' "$latest_handoff" 2>/dev/null)
        last_to=$(jq -r '.handoffs[-1].to // "?"' "$latest_handoff" 2>/dev/null)
        echo -e "  Last Handoff: $last_from -> $last_to"
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
# HELPERS
# ─────────────────────────────────────────────────────────────
ensure_swarm() {
    if [ ! -d "$SWARM_DIR" ]; then
        echo -e "${RED}[SWARM]${NC} Not initialized. Run: bash hooks/swarm.sh init [project-name]"
        exit 1
    fi
}

# Recalculate sprint metrics from task files
update_sprint_metrics() {
    local sprint_file="$SWARM_DIR/current-sprint.json"
    [ -f "$sprint_file" ] || return 0

    local planned=0 inprog=0 completed=0 blocked=0

    # Read task IDs from sprint
    local task_ids
    task_ids=$(jq -r '.tasks[]' "$sprint_file" 2>/dev/null)

    for tid in $task_ids; do
        local tfile="$SWARM_DIR/tasks/${tid}.task.md"
        [ -f "$tfile" ] || continue
        local status
        status=$(grep "Durum:\*\*" "$tfile" | sed 's/.*\*\* //')
        case "$status" in
            planned)      planned=$((planned + 1)) ;;
            in-progress)  inprog=$((inprog + 1)) ;;
            review)       inprog=$((inprog + 1)) ;;
            done)         completed=$((completed + 1)) ;;
            blocked)      blocked=$((blocked + 1)) ;;
        esac
    done

    jq --argjson p "$planned" --argjson i "$inprog" --argjson c "$completed" --argjson b "$blocked" '
      .metrics.planned = $p |
      .metrics.inProgress = $i |
      .metrics.completed = $c |
      .metrics.blocked = $b
    ' "$sprint_file" > "${sprint_file}.tmp"
    mv "${sprint_file}.tmp" "$sprint_file"
}

# ─────────────────────────────────────────────────────────────
# ROUTER
# ─────────────────────────────────────────────────────────────
case "$COMMAND" in
    init)       swarm_init "$@" ;;
    reset)      swarm_reset "$@" ;;
    task)       swarm_task "$@" ;;
    sprint)     swarm_sprint "$@" ;;
    handoff)    swarm_handoff "$@" ;;
    communicate) swarm_communicate "$@" ;;
    status)     swarm_status ;;
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
        ;;
esac
