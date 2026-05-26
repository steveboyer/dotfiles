## Environment
- macOS 26, Xcode 26.3
- Apple Silicon
- Shell: zsh
- Package managers: Homebrew, CocoaPods, npm, pip

## Preferences
- Prefer concise explanations
- Always use absolute paths in scripts
- Use zsh syntax for shell scripts
- If ~/.claude/settings.json denies your ability to run a command, DO NOT try another command to work around it 

## Java
- Prefer Java 21 (LTS) unless the project explicitly requires another version.
- Keep package names lowercase and avoid the default package.
- Prefer clear, small methods and immutable data where practical.
- Add or update automated tests for behavior changes (prefer JUnit 5 conventions).
- Do not swallow exceptions; either handle them with context or propagate them.
- Maven projects
  - Run `mvn spotless:apply` after making any code changes

## Python
- Prefer Python 3.12+ unless the project specifies another version.
- Prefer `uv` for Python environment and dependency management (`uv venv`, `uv sync`, `uv run ...`) unless the project already standardizes on another tool.
- Use a project-local virtual environment (`.venv`) instead of the system interpreter.
- Use absolute imports within packages and keep module names lowercase with underscores.
- Add or update automated tests for behavior changes (prefer `pytest` conventions).
- Prefer type hints for public functions and return values.
- Raise specific exceptions with clear messages; avoid bare `except:` blocks.

## Git
Never add "Co-Authored-By" lines to commit messages.

## Xcode
Always run and test on my physical devices, not simulators. Use the
XcodeBuildMCP device tools (build_device, build_run_device, test_device,
install_app_device, launch_app_device, list_devices, start_device_log_cap,
etc.) rather than the *_sim variants. Only fall back to a simulator if I
explicitly ask for it or no paired device is available.

**A code change is NOT done until the new build is installed AND launched
on the device.** A successful `build_device` only produces a binary on the
host — the device keeps running the previously installed app, so my manual
testing will appear to show the change didn't work. Default sequence for
any iOS / watchOS change: `build_device` → `install_app_device` →
`launch_app_device`, or use `build_run_device` which does all three in one
step. This applies even when "just verifying it compiles" if there is any
chance I will check behavior on-device after the turn. Only skip
install/launch if I explicitly say compile-check only, or the change is
purely tooling / docs / SPM-only that the device never runs.
