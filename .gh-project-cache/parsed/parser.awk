BEGIN {
    phase_num = 0
    section_num = 0
    in_task_list = 0
    current_section = ""
}

# Match Phase headers (## Phase N: Title)
/^## Phase [0-9]+:/ {
    phase_num++
    section_num = 0
    in_task_list = 0
    
    # Extract phase title
    phase_title = $0
    gsub(/^## Phase [0-9]+: /, "", phase_title)
    
    # Extract duration if present
    duration = ""
    if (match($0, /\*\*Duration: ([^*]+)\*\*/, arr)) {
        duration = arr[1]
    }
    
    print "PHASE|" phase_num "|" phase_title "|" duration > phases_file
}

# Match Section headers (### N.N Section Title)
/^### [0-9]+\.[0-9]+ / {
    section_num++
    in_task_list = 0
    current_section = $0
    gsub(/^### [0-9]+\.[0-9]+ /, "", current_section)
    
    print "SECTION|" phase_num "|" section_num "|" current_section > sections_file
}

# Match task lists under "Implementation Tasks:"
/^#### Implementation Tasks:/ {
    in_task_list = 1
    next
}

# End task list on next header
/^####/ {
    in_task_list = 0
}

# Capture tasks (lines starting with -)
in_task_list && /^- / {
    task = $0
    gsub(/^- /, "", task)
    print "TASK|" phase_num "|" section_num "|" task > tasks_file
}
