## Environment
- macOS 26, Xcode 26.3
- Apple Silicon
- Shell: zsh
- Package managers: Homebrew, CocoaPods, npm, pip

## Preferences
- Prefer concise explanations
- Always use absolute paths in scripts
- Use zsh syntax for shell scripts

## Git
Never add "Co-Authored-By" lines to commit messages.

## Xcode
Always run and test on my physical devices, not simulators. Use the
XcodeBuildMCP device tools (build_device, build_run_device, test_device,
install_app_device, launch_app_device, list_devices, start_device_log_cap,
etc.) rather than the *_sim variants. Only fall back to a simulator if I
explicitly ask for it or no paired device is available.
