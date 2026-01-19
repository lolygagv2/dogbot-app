# WIM-Z Session Start Command

## Initialization Protocol

### 1. Load Project Context
- Read `.claude/CLAUDE.md` for development rules
- Read `.claude/DEVELOPMENT_PROTOCOL.md` for development protocol when working and completing.
- **Check `.claude/resume_chat.md` for previous session history**

- Read Directory Knowledge: `.claude/WIM-Z_Project_Directory_Structure.md` - ALWAYS check the structure document first and verify actual file existence before claiming something doesn't exist. to not recreate, duplicate or misunderstand progress

- Review `.claude/product_roadmap.md` for current phase
- Check `.claude/development_todos.md` for active tasks

### 2. Verify Protected Files
Check that these files exist and are unmodified:
- `notes.txt` (user notes - READ ONLY)
- `/docs/` directory contents
- `.claude/product_roadmap.md`

### 3. Review Previous Session
**Previous Session Summary:**
- Read last 50-100 lines from `.claude/resume_chat.md`
- Note any unfinished tasks or issues
- Check for any warnings or critical fixes made

### 4. System Status Check
Display the following:

**Git Status:**
```bash
git status --short
git branch --show-current
git log --oneline -3
```

**Uncommitted Changes:**
- Count modified files
- List new untracked files
- Identify any files outside proper directories

**Project Health:**
- Battery level (if hardware connected)
- Last successful test run timestamp
- Any error logs from last session
- Check for saved detection results or test outputs

### 5. Flutter Environment Check
Verify development environment:
```bash
flutter doctor --verbose | head -30
flutter devices
```

### 6. Ask User for Session Goal
Present options:
```
What are we working on today?

A. UI/UX Development (screens, widgets, theme)
B. State Management (Riverpod providers, data flow)
C. Networking (REST API, WebSocket, MJPEG stream)
D. Models & Data (Freezed classes, JSON parsing)
E. Navigation & Routing (GoRouter, screen flow)
F. Testing (unit tests, widget tests, integration)
G. Build & Deploy (APK, iOS, Codemagic)
H. General Development (specify task)
I. Code Review/Refactoring

Enter letter or describe custom task:
```

### 7. Set Session Constraints
Based on user goal, establish boundaries:

**Example - UI/UX Development (A):**
- Working directory: `lib/presentation/` primarily
- May create new widgets in `lib/presentation/widgets/`
- Run `dart run build_runner build --delete-conflicting-outputs` after model changes
- Test on device/emulator before committing

**Example - State Management (B):**
- Working directory: `lib/domain/providers/`
- Remember to regenerate code after @riverpod changes
- Test provider behavior with connected device if possible

**Example - Code Review (I):**
- READ ONLY mode for all files
- No file creation or modification
- Only analysis and recommendations

### 8. Final Confirmation
```
✅ Session initialized for: [USER GOAL]
✅ Protected files verified
✅ Git status: [CLEAN / X uncommitted files]
✅ Current branch: [BRANCH NAME]

Ready to begin. Proceed? (yes/no)
```

---

## Usage
Call this command at the start of every Claude Code session:
```bash
/project:session-start
```

Or in VS Code extension: Type `/session-start` in chat

---

## CRITICAL RULES
- NEVER skip protected file verification
- NEVER assume session goal - always ask
- NEVER make changes before user confirmation
- ALWAYS show git status first