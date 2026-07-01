---
name: "Add Terraform Module Tests"
description: "Add positive and negative Terraform tests for a module, placing them in a module-local tests folder with file names aligned to the module name."
argument-hint: "module path or module name"
agent: "agent"
model: "GPT-5 (copilot)"
---
Add or expand automated tests for the Terraform module identified by `$ARGUMENTS`.

Requirements:
- Resolve the target module from the provided module name or path. Prefer an exact module directory under `modules/`.
- Create the tests under the target module's `tests/` folder.
- Use native `terraform test` files and conventions.
- Name new test files close to the module name, using native Terraform test naming such as `<module-name>.tftest.hcl` when practical.
- Add both positive and negative tests.
- Aim for strong coverage of the module's behavior, especially:
  - required inputs and variable validation
  - expected resources, counts, and key arguments
  - output shape and important derived values
  - failure paths for invalid or missing inputs
- Reuse any existing repository conventions that are compatible with native `terraform test`.
- Keep the change focused on the target module and only add supporting files when they are required for the tests to run.

Execution guidance:
1. Inspect the target module's `main.tf`, `variables.tf`, `outputs.tf`, `data.tf`, and any nearby README.
2. Implement native `terraform test` files in the module-local `tests/` folder.
3. If the module needs small validation or structure changes to support meaningful negative tests, make the smallest necessary module change.
4. Include representative positive cases and negative cases with clear names.
5. Run the narrowest available validation for the added tests and fix issues if the validation fails.
6. Summarize what was added, what coverage was achieved, and how to run the tests.

Output expectations:
- Make the code changes directly.
- Keep test names descriptive.
- Report any assumptions, especially if the module lacks validation blocks or needs small refactors to make negative tests meaningful with native `terraform test`.

Examples:
- `/add-terraform-module-tests private-subnets`
- `/add-terraform-module-tests site-to-site-vpn/firsvpn`