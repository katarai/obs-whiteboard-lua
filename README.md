# Whiteboard Source for OBS Studio (Windows only)
This script adds a new whiteboard source to OBS Studio that allows users to display live drawings on top of their sources.

Each scene can have its own whiteboard, though the pencil settings (color, size, etc.) are shared.

# How to Use
0. Add the whiteboard script (whiteboard.lua) to OBS.
1. Place a whiteboard source at the top of a scene. *(Note: you may have to toggle the visibility of the whiteboard on/off once to activate it)*
2. Project your *scene* with either Windowed or Fullscreen Projector.
3. Draw on your projected screen by left-clicking!

You can add hotkeys for the following actions in the OBS settings:
- Cycle colors (Yellow, Red, Green, Blue, White, Custom)
- Cycle sizes (this cycles through all the even pixel sizes, e.g. 2, 4, 6, etc.)
- Toggle eraser on/off
- Clear canvas

These settings are also exposed in the script properties, visible in OBS Studio's script menu when selecting the whiteboard plugin. Users can set more precise sizes and define the custom color, here.

# Known Issues
- Script settings windows does not update when hotkeys are used.
  * This is due to two limitations with the OBS script library:
   1) There does not appear to be a *safe* way to access and update the settings object outside of particular functions. 
   2) The script settings in the script window do not refresh themselves in the UI when changed (notably, per-source properties don't have this problem).
   
- Whiteboard source doesn't accept inputs after being added to a scene, or after the script is refreshed.
  * This is because the source is only interactable when it's active. There's unfortunately no way to check whether a source is currently active, so we rely on the triggers on transition between active and deactive to determine when to enable interaction. Certain situations do not trigger this transition (e.g. adding a new source, refreshing the script, etc.), hence the source never knows it's active.


# Authors
**mwelsh** *([TILT forums](http://tiltforums.com/u/mwelsh))*  
**Tari**
