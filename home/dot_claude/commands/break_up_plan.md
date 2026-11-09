The file $ARGUMENTS contains a plan for how to implement the requirements for a goal. However, the plan has many milestones.

I want you to create a new Markdown file for each milestone. Name each file `milestone_XX.md` with `XX` being the milestone number. For example, the first file will be `milestone_01.md`. These files will be in the same directory as $ARGUMENTS

**IMPORTANT:** DO NOT MODIFY $ARGUMENTS

**IMPORTANT:** WHEN WRITING A MILESTONE'S DETAILS IN A MILESTONE FILE, DO NOT MODIFY ANY PART OF THE MILESTONE OR ITS STEPS. EACH MILESTONE AND STEP MUST REMAIN EXACTLY AS IT IS DEFINED IN $ARGUMENTS

The "Executive Summary" section must be at the top of each milestone file.

The milestone in each file must end with the following steps. Make sure to give these steps sequential numbers like the other steps in the milestone.

- Step: Linting and Type Checking
  - Run and fix all linting issues:
    - `npm run lint` passes without warnings
    - TypeScript compilation succeeds
    - No `any` types unless absolutely necessary
    - Consistent code formatting
- Step: User Code Review
  - Stop making changes to files
  - Ask the user to review the code
  - Proceed to the next step once the user has finished reviewing the code
- Step: Commit the Changes
  - Use the `git commit` command to commit the changes to the Git repository
  - Write a concise commit message that captures the name of the step and a summary of the changes
