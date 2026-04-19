# 🔥 CODING RULES & PROJECT CONSTRAINTS (FINAL)

# 1. CORE PRINCIPLES
- Never skip any requested functionality.
- Code must run successfully in one build without runtime crashes.
- Runtime must never crash due to missing Instances or UI.
- Do NOT remove logic just because an Instance or UI is missing.
- Do NOT provide unnecessary explanations in output.

# 2. UI & INSTANCE RULES
- UI must NEVER be created using code (forbidden: Instance.new("ScreenGui"), Instance.new("TextButton"), etc.).
- Never early-return because of missing UI or Instance.

# 3. MISSING INSTANCE HANDLING
- If a required UI or Instance is missing:
  - Keep the full logic intact.
  - Use warn() to notify.
  - Allow runtime to continue safely.
  - Document the full hierarchy path.
  - Request manual creation via comments.

# 4. VALIDATION EXAMPLES

## ❌ Incorrect
if not button then return end

## ✅ Correct
if not button then
    warn("JoinArenaButton missing")
else
    button.MouseButton1Click:Connect(...)
end

# 5. DOCUMENTATION RULES
- Every required UI or Instance must be documented in ProjectTreeSpec.lua with its full hierarchy path.
- Whenever a feature requires a UI or Instance, include a manual creation guide in comments.

# 6. AI CONTEXT WORKFLOW
- Whenever the project changes, update AI_Context.md.
- Use AI_Context.md as the main input for new chat sessions instead of the full source code.

# 7. RUNTIME SAFETY GUARANTEE
- If something is missing:
  - warn()
  - document the path
  - request manual creation
  - never crash runtime