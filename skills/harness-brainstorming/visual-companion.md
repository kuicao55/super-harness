# Visual Companion Guide

Browser-based visual brainstorming companion for `claude-codex-harness:harness-brainstorming`. Shows mockups, diagrams, and design options in an interactive browser UI.

## When to Use

Decide per-question, not per-session. The test: **would the user understand this better by seeing it than reading it?**

**Use the browser** when the content is visual:

- **UI mockups** — wireframes, layouts, navigation structures, component designs
- **Architecture diagrams** — system components, data flow, relationship maps
- **Side-by-side visual comparisons** — comparing two layouts or design directions
- **Spatial relationships** — state machines, flowcharts, entity relationships

**Use the terminal** when content is text or tabular:

- **Requirements and scope questions** — "what does X mean?"
- **Conceptual A/B/C choices** — picking between approaches described in words
- **Tradeoff lists** — pros/cons, comparison tables
- **Technical decisions** — API design, data modeling
- **Clarifying questions** — anything where the answer is words, not a visual preference

## How It Works

The server watches a directory for HTML files and serves the newest one to the browser. Write HTML to `screen_dir`, the user sees it in the browser and can click to select options. Selections are recorded to `state_dir/events` that you read on the next turn.

## Starting a Session

```bash
# Start server with persistence (mockups saved to project)
skills/harness-brainstorming/scripts/start-server.sh --project-dir /path/to/project

# Returns: {"type":"server-started","port":52341,"url":"http://localhost:52341",
#           "screen_dir":"/path/to/project/.harness/brainstorm/12345-1706000000/content",
#           "state_dir":"/path/to/project/.harness/brainstorm/12345-1706000000/state"}
```

Save `screen_dir` and `state_dir` from the response. Tell the user to open the URL.

**Note:** Pass `--project-dir` so mockups persist in `.harness/brainstorm/`. Remind the user to add `.harness/` to `.gitignore`.

**Platform notes:**

- **macOS / Linux**: Default mode works — the script backgrounds the server
- **Windows**: Script auto-detects and uses foreground mode; set `run_in_background: true` on the tool call
- **Codex**: Script auto-detects `CODEX_CI` and uses foreground mode

## The Loop

1. **Write HTML** to a new file in `screen_dir`:
   - Check `$STATE_DIR/server-info` exists before writing (server may have shut down after 30 min idle)
   - Use semantic filenames: `platform.html`, `layout.html`, `data-model.html`
   - Never reuse filenames — each screen gets a fresh file
   - Server automatically serves the newest file

2. **Tell user what to expect** and end your turn:
   - Remind them of the URL every step
   - Give a brief text summary of what's on screen
   - Ask them to respond in terminal

3. **On next turn** — read `$STATE_DIR/events` if it exists:
   - Contains browser interactions as JSON lines
   - Terminal message is primary; events provide structured interaction data

4. **Iterate or advance** — write new versions with `-v2.html` suffix if needed

5. **Unload when returning to terminal** — push a waiting screen:
   ```html
   <div
     style="display:flex;align-items:center;justify-content:center;min-height:60vh"
   >
     <p class="subtitle">Continuing in terminal...</p>
   </div>
   ```

## Writing Content Fragments

The server auto-wraps content in the frame template. Write just the content:

```html
<h2>Which architecture fits better?</h2>
<p class="subtitle">
  Consider your team's experience and deployment requirements
</p>

<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>Microservices</h3>
      <p>Independent deployments, service mesh required</p>
    </div>
  </div>
  <div class="option" data-choice="b" onclick="toggleSelect(this)">
    <div class="letter">B</div>
    <div class="content">
      <h3>Monolith with modules</h3>
      <p>Simple deployment, clear internal boundaries</p>
    </div>
  </div>
</div>
```

No `<html>`, no CSS, no `<script>` needed — the server provides all of that.

## CSS Classes

### Options (A/B/C choices)

```html
<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>Title</h3>
      <p>Description</p>
    </div>
  </div>
</div>
```

Multi-select: `<div class="options" data-multiselect>`

### Cards (visual designs)

```html
<div class="cards">
  <div class="card" data-choice="design1" onclick="toggleSelect(this)">
    <div class="card-image"><!-- mockup content --></div>
    <div class="card-body">
      <h3>Name</h3>
      <p>Description</p>
    </div>
  </div>
</div>
```

### Mockup container

```html
<div class="mockup">
  <div class="mockup-header">Preview: Dashboard Layout</div>
  <div class="mockup-body"><!-- your mockup HTML --></div>
</div>
```

### Split view (side-by-side)

```html
<div class="split">
  <div class="mockup"><!-- left --></div>
  <div class="mockup"><!-- right --></div>
</div>
```

### Pros/Cons

```html
<div class="pros-cons">
  <div class="pros">
    <h4>Pros</h4>
    <ul>
      <li>Benefit</li>
    </ul>
  </div>
  <div class="cons">
    <h4>Cons</h4>
    <ul>
      <li>Drawback</li>
    </ul>
  </div>
</div>
```

## Stopping the Server

```bash
skills/harness-brainstorming/scripts/stop-server.sh $SESSION_DIR
```

Mockup files persist in `.harness/brainstorm/` when using `--project-dir`.

## Reference

- Frame template (CSS): `scripts/frame-template.html`
- Client helper: `scripts/helper.js`
- Server: `scripts/server.cjs`
