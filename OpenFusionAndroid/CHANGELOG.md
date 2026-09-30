# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/).

**Project:** OpenFusion AutoHotkey Launcher  
**Author:** Mark Morrison  
**Language:** AutoHotkey v2  
**Last Updated:** 2026-03-12  
___

## [2.2.0] - 2026-07-26
### Added
- Added online play
- Adjusted the config parameters and expected config file
- Added restart loop for ffrunner if its stuck on loading screen
___

## [2.1.0] - 2026-05-10
- Added 'fps_limit' parameter to config file to allow users to set a custom FPS limit for the game. If not specified, it defaults to 60 FPS.
- Added 'dxvk_hud' parameter to config file to allow users to enable or disable the DXVK HUD for performance monitoring. Defaults to 'off'.
- Disabled 'WINE_FULLSCREEN_FSR' and 'WINE_FULLSCREEN_FSR_MODE' environment variables by default to prevent conflicts with other display enhancements.
- Changed the name for the param of the gamre client from 'launcher' to 'client'.
- Adjusted the fullscreen handling logic.

## [2.0.0] - 2026-03-12
### Added
- In-memory logging buffer with timestamped log entries and flush-to-disk support (writes to debug_log.txt).
- Centralized process launcher wrapper `RunCMD()` that starts detached processes and returns PIDs.
- Robust INI parser (`LoadIniFile`) and improved config loader (`LoadConfig`) supporting launcher selection (`launcher:*`) and sensible fallbacks.
- Relative-to-absolute path resolution helper (`resolvePath`) and `cache_dir_url` generation to produce file:/// asset URLs.
- Graceful wrapper shutdown with `ShutdownWrapper()` that flushes logs and exits cleanly.
- Tracking of server and client PIDs to allow non-blocking startup and basic crash detection.

### Changed
- Client and server are launched detached (non-blocking) using `RunCMD()` and their PIDs are captured instead of using blocking waits.
- Client command-line assembly (`BuildClientArgs()`) updated to use accept a verbose flag.
- Fullscreen handling improved: attempts borderless, always-on-top maximize, uses safer detection (tries ahk_pid, ahk_exe, or window title) and guarded with try/catch.
- Log formatting now includes ISO-like timestamps and level tags.
- Startup flow simplified: wrapper records start time and proceeds without blocking waits; main loop detects server crash and exits gracefully.

___

## [1.9.0] - 2026-02-26
### Added
- Optional `startup_delay` parameter to mitigate the stuck on loading screen issue. The default is 50ms.

### Changed
- Reduced server log line wait timeout from 5 seconds to 3 seconds to shorten startup latency while keeping reliable readiness detection.
- Improved fullscreen handling to further reduce focus flicker and launcher window wait times.
- Cleaner default logs and clearer startup messages to the output pane.

---

## [1.8.0] - 2026-02-22
### Changed
- Updated fullscreen handling to reduce wait times for the launcher window.
- Reduced server log line wait timeout from 15 seconds to 5 seconds since 15 is unnecessary
- Changed application icon

## [1.7.0] - 2025-11-21
### Added
- Fullscreen mode support via `--fullscreen` parameter.
- Resolved path issues for asset_url and offline_cache in config file.

## [1.5.0] - 2025-10-28
### Changed
- Fully restructured launcher for improved compatibility with **GameHub** and **Winlator**.
- Simplified process flow:
  - No longer attempts to monitor or close server processes on exit.
- Eliminated blocking calls that caused freezing in Wine environments.
- Removed `--force-vulkan` from launch parameters for improved compatibility with D3D-based renderers on Wine/Android.
___

## [1.4.0] - 2025-10-27
### Added
- Automatic port detection by parsing the `[login]` section of `config.ini`.

### Changed
- Removed unnecessary sleeps and debug file output.
- Simplified command building and improved code readability.
- Simplified process handling to improve stability on Winlator and GameHub.
- Server (`winfusion.exe`) now starts only if not already running.
- Changed process launch behavior:
  - Replaced `RunWait` with detached `Run` to prevent AutoHotkey from freezing the game.
  - Added short delay and graceful `ExitApp` to ensure proper release of input focus under Wine.
- Removed unnecessary port checks and startup delays.
- A config file is now expected in the same directory as the OpenFusion executable.
- All paths in the config file can be **relative** to the OpenFusion executable directory.
- Username, token, width, and height are now optional and read from `[launcher]` section if present.

--- 

## [1.3.0] - 2025-10-26
### Added
- Parser for `OpenFusionServer/config.ini` to extract login port dynamically.

### Changed
- Replaced static port `23000` with dynamic detection.
- Fallback to default if no valid port found.
- Eliminated experimental waits and tooltips.
- Enhanced formatting and section comments for maintainability.
- Refactored repetitive logic into concise expressions.
- Removed unused variables and redundant conditions.
- Combined command-line parameters into a single `Format()` call.

--- 

## [1.2.0] - 2025-10-25
### Added
- Pipe reading to capture `winfusion.exe` output.
- Detection of `"Starting shard server at"` readiness message.

### Changed
- Continued automatically once server startup was detected.
- Consolidated multiple file-missing alerts into one message box.
- Enhanced cleanup using `ProcessClose()` with `taskkill` fallback.
- Improved user-facing error formatting.
- Ensured consistent exit behavior.

--- 

## [1.1.0] - 2025-10-24
### Added
- Confirmed hidden server startup works reliably.
- Automatic detection of screen resolution for launcher window.
- File and directory integrity checks for:
  - `OpenFusionServer`
  - `winfusion.exe`
  - `OpenFusionLauncher`
  - `offline_cache`
  - `main.unity3d`
- Displayed missing files via formatted message box.

--- 

## [1.0.0] - 2025-10-23
### Added
- Initial launcher functionality:
  - Start `OpenFusionServer`.
  - Launch `ffrunner` in Vulkan mode.
  - Terminate server on exit.
- Established base structure for future updates.
