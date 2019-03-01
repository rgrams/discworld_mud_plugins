
# Ross's MUSHclient Plugins
_**For the Discworld MUD.**_ (mostly)

The plugins here should all work, but some of them are works in progress, so they may have bugs I haven't found and fixed yet, or be missing some features. If you use any of them and find problems or have suggestions, please open an Issue.

# User Plugins
Plugins that do things a normal user will care about. (As opposed to "back-end" plugins that only make life easier for other plugins.)

## Easy Hotkeys
This plugin lets you bind any hotkeys you want from within the MUSHclient, without doing any scripting. The MUSHclient normally only allows you to use a limited set of hotkeys (from the World Properties > Input > Macros window) and with limited options for how they work. From a plugin script you can use almost any key or combination of keys, as well as the full list of "Send To:" options, like you have with a trigger or alias. This plugin simply provides an interface for users to add and remove hotkeys without having to edit and reload a plugin, or have any knowledge of scripting whatsoever. This plugin is not Discworld-specific.

There are built-in instructions, so you just need to add the plugin via the Plugins window (File > Plugins...). It will tell you to type "hotkey help" when it loads.

Hotkeys set with this plugin will generally override any functionality the given key combo had before. Such as: Ctrl+C for copy, Ctrl+M for minimize, etc. They will go back to normal if the hotkey is removed or the plugin is uninstalled or disabled.

## Vitals Display
A status bar display for some or all of your character's "vital" stats (Hp, Gp, Xp, Burden, and Alignment). Can also send text notifications when any of these stats change. You can set various options through the window's right-click menu.

This is almost identical to Quow's vitals bars, only you can fully choose which stats to display, and you can have notifications for the gain or loss of each stat, with any threshold value you like for each. It doesn't have much in the way of visual customization right now, but I will add more in the future.

#### Features:
* Uses GMCP to update your stats whenever you send a command to the MUD.
   * Including when you send a blank line - i.e. just pressing enter.
* Simulates Hp and Gp regeneration every heartbeat when you are idle.
   * With configureable regen rates.
* Toggle on or off the display of each stat.
* Enable text notifications for when stats change.
   * Separate toggles and thresholds for the gain and loss of each stat.


Also see the `window` module below for the features of the display window. (It can be moved around and resized and such.)

#### Dependencies:
* GMCP Interface Plugin
* window module.
* RGBToInt module.

# Helper Plugins & Modules
Plugins and Lua modules that handle features that might otherwise be duplicated between multiple plugins.

## GMCP Interface
A mostly-generic GMCP handler & subscription interface for other plugins. It enables and handles all the GMCP packet types that the Discworld MUD uses, and sends each one out to any plugins that requested it.

* Use the "gmcpdebug <mode> <packetNameFilter>" command to debug on the fly.
* Other plugins call "subscribe" with their plugin ID and a callback name to get GMCP packets.
* Other plugins can call "unsubscribe" to stop recieving certain packets
   * If a subscribed plugin is disabled or removed, it will be automatically unsubscribed.

## Plugin Reloader
A tiny plugin for reloading other plugins by typing a command or pressing a hotkey combination.

Type "`reload plugin <plugin_name>`" to reload any other installed plugin.
You can also press <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> to reload the last plugin you reloaded. The last plugin name is saved between sessions.

## window
A Lua module to help manage miniwindows inside the client window that plugins can use to show stuff. The ones created by this module will already be set up with some common features:

* Drag the main area to move the window.
* Drag the edges or corners to resize the window.
* Snapping to the edges of other windows when moving or resizing (even windows made without this module).
   * Hold Control while dragging to disable snapping.
* A right-click menu with a couple preset options.
   * Lock the window position and size.
   * A few ways to change the window draw-order (whether it's above or below other windows).
* A callback and some helper functions to make it much easier to deal with right-click menus.


## RGBToInt
A tiny module--only one function--to convert three 0-255 RGB into a single integer color.

```Lua
-- Require it - Use your own local path from the MUSHclient folder of course.
local RGBToInt = require "your_folder.RGBToInt"

-- Then call it as a function, in one of three different ways:

-- Three inputs: R, G, and B.
RGBtoInt(255, 125, 55) -->  3636735  (Some sort of light pumpkin-y color.)

-- A single input gives you a grey of that value.
RGBToInt(100) -->  6579300  (A medium-ish grey.)

-- No inputs gives you black.
RGBToInt() -->  0  (Black.)
```
