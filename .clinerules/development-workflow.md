## Brief overview
This rule file outlines the preferred development workflow and guidelines for working on this project, including the use of the Memory Bank, planning process, and coding preferences.

## Memory Bank usage
- when explicitly requested by the user, read all memory bank files (`projectbrief.md`, `productContext.md`, `systemPatterns.md`, `techContext.md`, `activeContext.md`, `progress.md`) to understand the project context and history.
- Use the memory bank to track project goals, technical decisions, current focus, recent changes, next steps, and known issues.
- Update memory bank files whenever significant changes are made or when explicitly requested by the user.

## Development workflow
- For complex tasks, use PLAN MODE and sequential thinking to break down the task into smaller steps and create a detailed plan.
- Present the plan to the user for approval before switching to ACT MODE for implementation.
- In ACT MODE, work through the plan iteratively, using tools one at a time and waiting for user confirmation after each step.
- Address user feedback and bug fixes by analyzing the issue, updating the plan (if necessary), and implementing the fixes in ACT MODE.

## Coding preferences
- For iOS native development, use Objective-C.
- Use `NSISO8601DateFormatter` with `ISO8601DateFormatWithInternetDateTime | ISO8601DateFormatWithFractionalSeconds` for date formatting.

## Error handling
- When encountering errors, analyze the error message and context to identify the root cause.
- Consult documentation or common patterns to find the correct approach for resolving the error.
- Implement the fix in ACT MODE and verify that the error is resolved.
