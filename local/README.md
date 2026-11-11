# Local build files

- `install/Play Farpoint (Steam).bat`: the target of the Steam shortcut.
- `work/build-farpoint.cmd`: builds `build\win-us\shadps4.exe` with clang-cl 23 and VS 2022 at idle priority.
- `work/build-and-install-when-idle.ps1`: waits until no emulator is running, then builds and installs, keeping the previous executable.

The scripts expect this layout:

| Folder | Contents |
|---|---|
| `C:\Games\Farpoint` | the PC VR release |
| `C:\Games\Farpoint-src` | this repository |
| `C:\Games\farpoint-work` | the work folder |

`C:\Users\<user>` stands for the Windows profile folder.
