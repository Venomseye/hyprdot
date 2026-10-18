-- Keybindings.

local mainMod = "SUPER"
local secondMod = "SUPER + SHIFT"

---------------------
---- HELPERS --------
---------------------

-- Build a shell command that only runs if every binary in `bins` exists,
-- and tells you which one is missing otherwise.
local function guarded(bins, cmd)
	if type(bins) == "string" then
		bins = { bins }
	end
	local checks = {}
	for _, b in ipairs(bins) do
		checks[#checks + 1] = "command -v " .. b .. " >/dev/null 2>&1 || { miss=" .. b .. "; }"
	end
	return "miss=''; "
		.. table.concat(checks, "; ")
		.. "; if [ -z \"$miss\" ]; then "
		.. cmd
		.. "; else command -v notify-send >/dev/null 2>&1 && notify-send -u critical 'Keybind failed' \"$miss is not installed\"; fi"
end

-- Quickshell IPC: `qs ipc call <target> <function>`.
-- Needs a matching IpcHandler { target: "<target>" } in the QML.
local function qs_ipc(target, fn)
	return guarded("qs", "qs ipc call " .. target .. " " .. fn)
end

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
-- Nautilus is single-instance (D-Bus activated): plain `nautilus` just re-activates the
-- running one. --new-window forces a fresh window every time.
local fileManager = "nautilus --new-window"
local browser = "firefox"

---------------------
---- CORE BINDS -----
---------------------

hl.bind(mainMod .. " + Q", hl.dsp.window.close())

-- Quickshell menu: apps + commands, nested, fuzzy (replaces rofi)
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(qs_ipc("shell", "toggle menu")))

-- Notifications: history of the last ten / Do Not Disturb
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(qs_ipc("shell", "toggle history")))
hl.bind(secondMod .. " + N", hl.dsp.exec_cmd(qs_ipc("shell", "toggle dnd")))

-- Terminal
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(guarded("kitty", terminal)))

-- Lock. dot-power uses loginctl (so hypridle's before_sleep_cmd stays in sync) and
-- falls back to starting hyprlock directly if hypridle isn't running.
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(guarded("dot-power", "dot-power lock")))

-- Power / session menu (lock, suspend, log out, reboot, shut down - each asks to confirm).
hl.bind(secondMod .. " + P", hl.dsp.exec_cmd(qs_ipc("shell", "menu System")))

-- Wallpaper: next / previous. Plain binds - there are no submaps any more (see below).
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd(guarded("dot-wallpaper", "dot-wallpaper next")))
hl.bind(mainMod .. " + CTRL + SHIFT + W", hl.dsp.exec_cmd(guarded("dot-wallpaper", "dot-wallpaper prev")))

-- Other apps
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(guarded("firefox", browser)))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(guarded("nautilus", fileManager)))

-- Clipboard history and calculator live in the same menu:
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(qs_ipc("shell", "menu Clipboard")))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(qs_ipc("shell", "calc")))

-- Quick settings (volume, brightness, Wi-Fi, Bluetooth, toggles) and the wallpaper picker.
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(qs_ipc("shell", "toggle quick")))
hl.bind(secondMod .. " + W", hl.dsp.exec_cmd(qs_ipc("shell", "toggle wallpapers")))

---------------------
---- WINDOW MGMT ----
---------------------

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle only
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mainMod .. " + K", hl.dsp.layout("swapsplit")) -- dwindle only

local function workspaceIsScrolling()
	return hl.get_active_workspace().tiled_layout == "scrolling"
end

local function workspaceIsMonocle()
	return hl.get_active_workspace().tiled_layout == "monocle"
end

hl.bind(mainMod .. " + RIGHT", function()
	if workspaceIsScrolling() then
		hl.dispatch(hl.dsp.layout("focus r"))
	else
		hl.dispatch(hl.dsp.focus({ direction = "right" }))
	end
end)

hl.bind(mainMod .. " + LEFT", function()
	if workspaceIsScrolling() then
		hl.dispatch(hl.dsp.layout("focus l"))
	else
		hl.dispatch(hl.dsp.focus({ direction = "left" }))
	end
end)

hl.bind(mainMod .. " + DOWN", function()
	if workspaceIsMonocle() then
		hl.dispatch(hl.dsp.layout("cyclenext"))
	else
		hl.dispatch(hl.dsp.focus({ direction = "down" }))
	end
end)

hl.bind(mainMod .. " + UP", function()
	if workspaceIsMonocle() then
		hl.dispatch(hl.dsp.layout("cycleprev"))
	else
		hl.dispatch(hl.dsp.focus({ direction = "up" }))
	end
end)

-- Move window
hl.bind(mainMod .. " + CTRL + LEFT", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + CTRL + RIGHT", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + UP", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + CTRL + DOWN", hl.dsp.window.move({ direction = "down" }))

-- Maximize / fullscreen / float
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(secondMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(secondMod .. " + T", hl.dsp.window.float({ action = "toggle" }))

-- Resize with keyboard
hl.bind(
	secondMod .. " + RIGHT",
	hl.dsp.window.resize({ x = 100, y = 0, relative = true }),
	{ repeating = true, description = "Increase window width with keyboard" }
)
hl.bind(
	secondMod .. " + LEFT",
	hl.dsp.window.resize({ x = -100, y = 0, relative = true }),
	{ repeating = true, description = "Reduce window width with keyboard" }
)
hl.bind(
	secondMod .. " + DOWN",
	hl.dsp.window.resize({ x = 0, y = 100, relative = true }),
	{ repeating = true, description = "Increase window height with keyboard" }
)
hl.bind(
	secondMod .. " + UP",
	hl.dsp.window.resize({ x = 0, y = -100, relative = true }),
	{ repeating = true, description = "Reduce window height with keyboard" }
)

-- Mouse move/resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

---------------------
---- WORKSPACES -----
---------------------

for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(secondMod .. " + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(secondMod .. " + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

---------------------
---- SUBMAPS --------
---------------------

-- There are deliberately no submaps. While one is active every other key is
-- swallowed, and nothing on screen says so: the old power submap would suspend or
-- shut down on a stray "s"/"p"/"r", and the wallpaper one left you typing "l" and
-- "h" into the void. Their jobs are plain keybinds now:
--   Super+Shift+P         power menu (asks to confirm)
--   Super+Ctrl+W          next wallpaper
--   Super+Ctrl+Shift+W    previous wallpaper

---------------------
---- MEDIA KEYS -----
---------------------

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(guarded("wpctl", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd(guarded("wpctl", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd(guarded("wpctl", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")),
	{ locked = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd(guarded("wpctl", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")),
	{ locked = true }
)
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd(guarded("brightnessctl", "brightnessctl -e4 -n2 set 5%+")),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd(guarded("brightnessctl", "brightnessctl -e4 -n2 set 5%-")),
	{ locked = true, repeating = true }
)

-- Media keys go through Quickshell, so they control the same player the bar shows (a playing one
-- first). If the shell isn't running they fall back to playerctl.
local function media_key(action, playerctl_cmd)
	return "qs ipc call shell media " .. action .. " >/dev/null 2>&1 || { command -v playerctl >/dev/null 2>&1 && playerctl -i playerctld "
		.. playerctl_cmd .. "; }"
end

hl.bind("XF86AudioNext", hl.dsp.exec_cmd(media_key("next", "next")), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(media_key("playpause", "play-pause")), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(media_key("playpause", "play-pause")), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(media_key("previous", "previous")), { locked = true })

---------------------
---- SCREENSHOTS ----
---------------------

-- dot-screenshot saves to ~/Pictures/Screenshots, copies to the clipboard and notifies.
hl.bind("PRINT", hl.dsp.exec_cmd(guarded("dot-screenshot", "dot-screenshot screen")))               -- the display you're on
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(guarded("dot-screenshot", "dot-screenshot all")))          -- everything
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd(guarded("dot-screenshot", "dot-screenshot region")))        -- drag a selection
hl.bind("ALT + PRINT", hl.dsp.exec_cmd(guarded("dot-screenshot", "dot-screenshot window")))         -- focused window
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd(guarded("dot-screenshot", "dot-screenshot region --edit")))  -- selection + annotate

---------------------------------------
---- WORKSPACES AND MONITORS (ML4W) ----
---------------------------------------

-- Cycle workspaces; jump to the first empty one.
hl.bind(mainMod .. " + TAB", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(secondMod .. " + TAB", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + TAB", hl.dsp.focus({ workspace = "empty" }))

-- Send a window to a workspace WITHOUT following it (Super+Shift+N follows).
for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Monitor focus: Super+Alt+Arrows (or Super+, / Super+. to go to the previous / next one).
hl.bind(mainMod .. " + ALT + LEFT", hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + ALT + RIGHT", hl.dsp.focus({ monitor = "r" }))
hl.bind(mainMod .. " + ALT + UP", hl.dsp.focus({ monitor = "u" }))
hl.bind(mainMod .. " + ALT + DOWN", hl.dsp.focus({ monitor = "d" }))
hl.bind(mainMod .. " + comma", hl.dsp.focus({ monitor = "-1" }))
hl.bind(mainMod .. " + period", hl.dsp.focus({ monitor = "+1" }))

-- Move the focused window to another monitor: Super+Alt+Shift+Arrows (or Super+Shift+, / .).
hl.bind(mainMod .. " + ALT + SHIFT + LEFT", hl.dsp.window.move({ monitor = "l" }))
hl.bind(mainMod .. " + ALT + SHIFT + RIGHT", hl.dsp.window.move({ monitor = "r" }))
hl.bind(mainMod .. " + ALT + SHIFT + UP", hl.dsp.window.move({ monitor = "u" }))
hl.bind(mainMod .. " + ALT + SHIFT + DOWN", hl.dsp.window.move({ monitor = "d" }))
hl.bind(secondMod .. " + comma", hl.dsp.window.move({ monitor = "-1" }))
hl.bind(secondMod .. " + period", hl.dsp.window.move({ monitor = "+1" }))
