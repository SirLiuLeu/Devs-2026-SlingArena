1. Never skip any requested functionality.
2. Runtime must never crash due to missing Instances or UI.
3. Do NOT remove logic just because an Instance or UI is missing.
4. UI must NEVER be created using code (forbidden: Instance.new("ScreenGui"), Instance.new("TextButton"), etc.).
5. If a required UI or Instance is missing:
   - keep the full logic
   - use warn() to notify
   - allow runtime to continue safely.

6. Whenever a feature requires a UI or Instance, write a manual creation guide in comments.
7. Every required UI or Instance must be documented in ProjectTreeSpec.lua with its full hierarchy path.
8. The UI creation guide must include:
   - instance type
   - instance name
   - full hierarchy path.

9. Example UI guide format:

   -- [UI_CREATION_GUIDE]
   -- Create in Studio:
   -- StarterGui
   --   ArenaUI (ScreenGui)
   --       JoinArenaButton (TextButton)
   --       LeaveArenaButton (TextButton)

10. Example ProjectTreeSpec entry:

   -- [PROJECT_TREE_SPEC]
   -- StarterGui
   --   ArenaUI
   --       JoinArenaButton
   --       LeaveArenaButton

11. Never early-return because of missing UI.

12. Incorrect behavior example:
   if not button then return end

13. Correct behavior example:
   if not button then
       warn("JoinArenaButton missing")
   else
       button.MouseButton1Click:Connect(...)
   end

14. Every feature must include unit tests for quick validation.

15. Unit tests should test core logic such as:
   - charge calculation
   - damage formula
   - spawn system
   - teleport system.

16. Code must run successfully in one build without runtime crashes.

17. If something is missing:
   - warn()
   - document the path
   - request manual creation
   - never crash runtime.