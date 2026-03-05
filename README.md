# Devs-2026-SlingArena
1) Never skip any requested functionality.
2) Runtime must never crash due to missing instances.
3) If UI instances cannot be created programmatically, 
   still write full logic and leave path comments in file ProjectTreeSpec:
   -- [REVIEW_REQUIRED] Path: PlayerGui.XYZ...

4) Do NOT remove logic just because instance is missing.
5) If possible, create basic UI programmatically.
6) If not possible, reference the path and comment clearly.
7) Code must run in one build.