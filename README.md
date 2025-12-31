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

## Languages other than english
If you use OBS in another language, this script will not work properly. To fix this change the following properties:
- Preview
- Program
- Projector

From the How to Use instructions, check the title for the projected window. The part before the hyphen (-) should go in the "Projector" field. 
The part after the hyphen will go into either the "Preview" or "Program" field, depending on if you're projecting the preview window (available in both studio and non-studio) or live window (only available in studio mode).
In English, for example, the projector window titles would look like this:
    * Projector - Preview
    * Projector - Program

### Spanish
In spanish you can set the values as follows:
- Preview: Vista Previa
- Program: Programa
- Projector: Proyector

# Known Issues
- Script settings windows does not update when hotkeys are used.
  * This is due to two limitations with the OBS script library:
   1) There does not appear to be a *safe* way to access and update the settings object outside of particular functions. 
   2) The script settings in the script window do not refresh themselves in the UI when changed (notably, per-source properties don't have this problem).
   
- Whiteboard source doesn't accept inputs after being added to a scene, or after the script is refreshed.
  * This is because the source is only interactable when it's active. There's unfortunately no way to check whether a source is currently active, so we rely on the triggers on transition between active and deactive to determine when to enable interaction. Certain situations do not trigger this transition (e.g. adding a new source, refreshing the script, etc.), hence the source never knows it's active.
  
- Whiteboard source starts minimized sometimes.
  * Some users have reported that newly added whiteboard sources show up minimized. Setting its size to 'Fit to Screen' seems to resolve this.

- Whiteboard source does not work after reloading script.
  * Existing sources may need to be toggled off/on to get them to respect the new settings. Alternatively, restarting OBS or switching scenes should also fix the issue.
  
- Whiteboard source appears in red text in the list of sources.
  * This appears to be a limitation of OBS, unfortunately. The sources are checked at startup only, and the whiteboard sources aren't activated at that time, so they permanently appear red, even when functioning correctly.
  * See https://obsproject.com/forum/threads/lua-script-plugin-type-obs_source_type_input-shown-in-red-on-obs-32.191001/#post-693786 for a short discussion on this.
  

# Authors
**mwelsh** *([TILT forums](http://tiltforums.com/u/mwelsh))*  *([github](https://github.com/Herschel/obs-whiteboard))*  
**Tari**
