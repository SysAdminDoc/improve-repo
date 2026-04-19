Stack: PowerShell (scripts / tooling / WPF + WinForms UIs).

Prioritize:
- `#Requires -Version 5.1` (or -Version 7) at top; `-RunAsAdministrator` when elevation is needed
- No emoji/unicode in output — causes encoding errors on Windows PowerShell 5.1
- `sc.exe start/stop` instead of `Start-Service`/`Stop-Service` in silent automation (the cmdlets block with a progress dialog that bypasses `*>$null`)
- `-LiteralPath` for registry operations with wildcard characters
- `[System.Windows.Markup.XamlReader]::Parse()` with single-quoted here-strings for XAML
- WPF ComboBox dark mode REQUIRES full ControlTemplate (popup + togglebutton + items) — partial theming leaks system chrome
- `[PowerShell]::Create()` + `BeginInvoke()` + `DispatcherTimer` polling for async work off the UI thread
- Auto-elevate via ShellExecute "runas" verb; hide console with P/Invoke `ShowWindow(0)`
- `StringBuilder` for exportable output (faster than string concatenation)
- `Start-Transcript` for unattended automation runs
- Error handling: `try/catch`, `$ErrorActionPreference = 'Stop'`, non-zero exit codes on failure
- No "Do you want to continue? Y/N" prompts in automation tools — act + notify via toast/status bar
- Settings location: `$env:APPDATA\<AppName>\`
- Catppuccin Mocha / GitHub Dark as default theme for WPF; AMOLED-equivalent when practical

Avoid: aliases in scripts (`ls` vs `Get-ChildItem`), positional parameters without names, Write-Host for returnable data.
