
# 🖥️ ScreenSentinel

**ScreenSentinel** is a PowerShell script that automatically adjusts your laptop’s display mode and lid behavior based on which screens are currently connected. It's especially useful if you switch between setups like home, office, or docking stations.

---

### 🔧 Features

- Detects external monitor connections in real-time.
- Automatically switches between display modes:
  - Internal only
  - Extend
  - Duplicate
  - External only
- Changes lid-close action depending on context (e.g., mobile vs stationary setups).
- Supports both specific setups (by monitor serials) and general ones (by number of screens).
- Modular config – reuse across multiple machines and environments.

---
## Requirements

- PowerShell 5.1 or later
- `PSFramework` module
- Administrator privileges (for powercfg and scheduled task operations)

Install PSFramework with:
```powershell
Install-Module PSFramework -Scope CurrentUser
```

---
### 🗂️ Configuration

Create a `config.json` file containing:

- `LaptopScreenSerialId`: The serial ID of your built-in screen.
- `Specific_Setups`: Use this when you want exact control over a known group of connected monitors, identified by their serial numbers.
- `Generic_Setups`: These are more flexible setups triggered based on the number of external monitors, regardless of their specific identity.
- `Default_Setup`: This is used if neither a specific nor a generic setup matches the current screen configuration. It's a fallback for unknown or unconfigured setups.

#### Enum Values Meaning

| Property                | Values                                    |
|-------------------------|--------------------------------------------|
| `LidAction`             | `0` = Do Nothing, `1` = Sleep, `2` = Hibernate, `3` = Shutdown |
| `LidOpenedDisplayMode`  | `1` = Internal, `2` = Clone, `3` = Extend, `4` = External |
| `LidClosedDisplayMode`  | Same as above                             |

---

### 🔍 How to Get Monitor Serial IDs

You can get the serial IDs of all connected monitors using this PowerShell snippet:

```powershell
Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
  ($_.SerialNumberID | ForEach-Object { [char]$_ }) -join ''
}
```

- Run it with just your laptop screen on to identify `LaptopScreenSerialId`.
- Connect additional screens one by one and rerun to discover their serials.

---

### ▶️ How to Run

Use PowerShell directly or register the script as a service using a tool like NSSM.
If you're running it as a Windows service (e.g., via NSSM), add this to your config:
```json
"RunAsService": true
```
This enables a workaround where `DisplaySwitch.exe` is run through a scheduled task to avoid limitations when running headless or in a background session. If you're running manually or via a Task Scheduler task in a user session, you can omit or set this to false.

#### Example Execution

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\ScreenSentinel.ps1" -ConfigPath "C:\Path\To\config.json"
```

You can pass a custom config path using the `-ConfigPath` parameter.
