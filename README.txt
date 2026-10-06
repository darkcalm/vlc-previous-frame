VLC previous-frame hotkey backup

Contains the Lua startup script and its four required VLC settings.

Restore:
1. Quit VLC completely. It can overwrite config edits made while running.
2. Copy vlc-previous-frame-hotkey.lua into:
   ~/Library/Application Support/org.videolan.vlc/lua/intf/
   Create this folder if needed.
3. Open ~/Library/Preferences/org.videolan.vlc/vlcrc in a plain-text editor.
   Apply the four lines in required-vlc-settings.txt. Replace any existing
   active line for each setting, or append it if absent. Lines starting with
   # are comments. Keep exactly one active line per setting.
   If extraintf already lists other interfaces, preserve them and add
   luaintf to its colon-separated list.
4. Ensure ffprobe is installed at /opt/homebrew/bin/ffprobe. It is included
   with FFmpeg. On another Mac, adjust this path in the Lua script if needed.
5. Reopen VLC. With the video focused: W backward, E forward.

This is a feature backup, not a backup of all VLC preferences or videos.
The script supports local video files.
