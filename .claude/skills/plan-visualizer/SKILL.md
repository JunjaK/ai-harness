---
name: plan-visualizer
description: "Generate interactive HTML visualization of team plans. Use after plan is finalized in /team, /team-run, or /team-brainstorm. Creates a visual diagram showing team composition, phase flow, file assignments, and dependency graph. Saves HTML alongside the plan .md file."
---

# Plan Visualizer

Generate an interactive HTML diagram from a finalized team plan. The HTML file is saved in the same directory as the plan .md file.

## When to Use

- After Phase 1 (Planning) completes in `/team`, `/team-run`, or `/team-brainstorm`
- After plan updates (post-escalation re-planning)

## Input

The orchestrator provides:
- Plan document content (from `_docs/{category}/plan-{feature}.md`)
- Team composition (which roles are involved)
- File assignments (Designer → file mapping)

## Output

Save HTML file at: `_docs/{category}/plan-{feature}.visual.html`
Add link in plan .md under the title:

```markdown
# [Task Name]

> Status: Planning
> [View Plan Diagram](./plan-{feature}.visual.html)
```

## HTML Template

Generate a self-contained HTML file (no external dependencies) with these sections:

### 1. Header
- Task name
- Status badge
- Team members involved
- Generation timestamp

### 2. Team Composition Panel
- Each role as a card with icon, name, and responsibility
- Highlight which roles are active for this task
- Show parallel vs sequential relationships

### 3. Phase Flow Diagram
- 5 phases as connected nodes
- Highlight which phases will execute
- Show conditional phases (UI/UX) with dashed borders
- Show escalation paths with red arrows
- Leader Approval Gate as diamond shape

### 4. File Assignment Table
- Designer ID → files → scope
- Color-coded by Designer for easy identification
- Worktree branch names (if determined)

### 5. Dependency Graph
- Components/stores/APIs as nodes
- Arrows showing data flow direction
- Color-coded by domain (frontend=green, backend=blue, shared=yellow)

### 6. Risk Summary (if plan-review was done)
- CRITICAL/HIGH items highlighted in red/orange
- Each with brief description and recommendation

## Styling Guidelines

```css
/* Color scheme */
--bg: #0a0a0a;
--surface: #1a1a2e;
--border: #2a2a4a;
--text: #e0e0e0;
--text-muted: #888;

/* Role colors */
--leader: #ffd700;
--arch-fe: #7fff7f;
--arch-be: #7fbfff;
--arch-infra: #ff7f7f;
--uiux: #ff7fff;
--designer: #ffbf7f;
--tester: #7fffff;

/* Phase colors */
--phase-planning: #ffd700;
--phase-uiux: #ff7fff;
--phase-impl: #ffbf7f;
--phase-verify: #7fffff;
--phase-security: #ff7f7f;
--escalation: #ff4444;
```

## HTML Structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>[Task Name] — Team Plan</title>
  <style>
    /* Dark theme, self-contained CSS */
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: var(--bg);
      color: var(--text);
      padding: 40px;
      max-width: 1200px;
      margin: 0 auto;
    }

    .header { margin-bottom: 32px; }
    .header h1 { font-size: 28px; margin-bottom: 8px; }
    .status-badge {
      display: inline-block;
      padding: 4px 12px;
      border-radius: 4px;
      font-size: 12px;
      font-weight: bold;
    }

    .section { margin-bottom: 32px; }
    .section h2 {
      font-size: 18px;
      margin-bottom: 16px;
      padding-bottom: 8px;
      border-bottom: 1px solid var(--border);
    }

    .team-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
      gap: 12px;
    }
    .role-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 16px;
      text-align: center;
    }
    .role-card.inactive { opacity: 0.4; }

    .phase-flow {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
      padding: 20px 0;
    }
    .phase-node {
      padding: 12px 20px;
      border-radius: 8px;
      border: 2px solid;
      font-size: 13px;
      font-weight: bold;
    }
    .phase-arrow { color: var(--text-muted); font-size: 20px; }
    .phase-node.conditional { border-style: dashed; }
    .phase-node.gate {
      transform: rotate(0deg);
      border-radius: 4px;
      border-style: dashed;
    }

    .file-table { width: 100%; border-collapse: collapse; }
    .file-table th, .file-table td {
      padding: 8px 12px;
      border: 1px solid var(--border);
      text-align: left;
      font-size: 13px;
    }
    .file-table th { background: var(--surface); }

    .risk-item {
      padding: 12px;
      margin-bottom: 8px;
      border-radius: 6px;
      border-left: 4px solid;
    }
    .risk-critical { border-color: #ff4444; background: #1a0a0a; }
    .risk-high { border-color: #ff8844; background: #1a1a0a; }
    .risk-medium { border-color: #ffcc44; background: #1a1a0a; }

    .dep-graph {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 20px;
      min-height: 200px;
    }
    .dep-node {
      display: inline-block;
      padding: 8px 16px;
      border-radius: 6px;
      margin: 4px;
      font-size: 12px;
      border: 1px solid;
    }

    .meta {
      font-size: 11px;
      color: var(--text-muted);
      margin-top: 40px;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>[Task Name]</h1>
    <span class="status-badge" style="background: [status-color]; color: #000;">
      [STATUS]
    </span>
    <p style="margin-top: 8px; color: var(--text-muted);">[Task description]</p>
  </div>

  <!-- Section 1: Team Composition -->
  <div class="section">
    <h2>Team Composition</h2>
    <div class="team-grid">
      <!-- Active roles get full opacity, inactive get .inactive class -->
      <div class="role-card" style="border-color: var(--leader);">
        <div style="font-size: 24px;">👑</div>
        <div style="color: var(--leader); font-weight: bold;">Leader</div>
        <div style="font-size: 11px; color: var(--text-muted);">Coordination</div>
      </div>
      <!-- Repeat for each role... -->
    </div>
  </div>

  <!-- Section 2: Phase Flow -->
  <div class="section">
    <h2>Workflow Phases</h2>
    <div class="phase-flow">
      <!-- Phases as colored nodes connected by arrows -->
    </div>
  </div>

  <!-- Section 3: File Assignment -->
  <div class="section">
    <h2>File Assignment</h2>
    <table class="file-table">
      <thead><tr><th>Designer</th><th>Files</th><th>Scope</th></tr></thead>
      <tbody>
        <!-- Rows per designer -->
      </tbody>
    </table>
  </div>

  <!-- Section 4: Dependency Graph -->
  <div class="section">
    <h2>Dependencies</h2>
    <div class="dep-graph">
      <!-- Component/store/API nodes with arrows -->
    </div>
  </div>

  <!-- Section 5: Risks (if available) -->
  <div class="section">
    <h2>Risk Summary</h2>
    <!-- Risk items with severity coloring -->
  </div>

  <div class="meta">
    Generated by AI Harness Team Workflow · [timestamp]
  </div>
</body>
</html>
```

## Generation Rules

1. **Self-contained**: No external CSS/JS/fonts — everything inline
2. **Dark theme**: Consistent with the design color tokens above
3. **Responsive**: Works on desktop and tablet
4. **Dynamic content**: Fill sections based on actual plan data
5. **Skip empty sections**: If no file assignments yet, omit that section
6. **Same directory**: Save HTML next to the plan .md file
7. **Link in .md**: Always add `[View Plan Diagram](./filename.visual.html)` link

## Integration Points

### /team-brainstorm
Generate after Step 7 (Save plan). This is the final output.

### /team (interactive)
Generate after Phase 1 + Phase 2 (before Leader Gate). Update after each phase completion.

### /team-run (autonomous)
Generate after Phase 1. Update after Phase 3, 4, 5 completion with progress indicators.

### Update on Escalation
When escalation causes re-planning, regenerate the HTML with:
- Updated phase flow (highlight current re-entry point)
- Escalation log section showing history
