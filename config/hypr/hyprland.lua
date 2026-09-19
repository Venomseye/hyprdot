-- Hyprland configuration
-- https://wiki.hypr.land/Configuring/Start/
--
-- CHANGES FROM THE PREVIOUS VERSION ARE MARKED WITH:  -- [FIX] / -- [NEW]

------------------------
---- WALLPAPER COLOURS -
------------------------

-- [NEW] Border colours follow the wallpaper via matugen.
--
-- The palette below is the fallback. matugen overwrites
-- ~/.config/hypr/colors-matugen.lua on every wallpaper change; we load it with
-- a guarded pcall(dofile, ...) so a missing or malformed generated file can
-- never take your whole session down - you just keep these defaults.
--
-- dofile (rather than require) is deliberate: require caches modules, so
-- `hyprctl reload` would keep serving the stale palette.

local palette = {
	primary = "#33ccff",
	secondary = "#00ff99",
	tertiary = "#a277ff",
	outline = "#595959",
	surface = "#18181b",
	error = "#e35149",
}

do
	local generated = os.getenv("HOME") .. "/.config/hypr/colors-matugen.lua"
	local ok, result = pcall(dofile, generated)
	if ok and type(result) == "table" then
		for key, value in pairs(result) do
			if type(value) == "string" then
				palette[key] = value
			end
		end
	end
end

-- "#75f1fa" + "ee"  ->  "rgba(75f1faee)"
-- The extra parens around the gsub matter: gsub returns two values, and the
-- second would otherwise be consumed as a format argument.
local function rgba(hex, alpha)
	return "rgba(" .. (hex:gsub("^#", "")) .. alpha .. ")"
end

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

hl.monitor({
	output = "DP-1",
	mode = "preferred",
	position = "auto",
	scale = "2",
})

hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto",
	scale = "1",
	disabled = false,
})

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
local fileManager = "nautilus"
local browser = "firefox"
local music = "spotify"

local ai = browser .. " --app=https://chatgpt.com"

-- rofi
local launcher = "rofi -show drun -show-icons"
local runner = "rofi -show run"
local calculator = "rofi -show calc -modi calc -no-show-match -no-sort"
local emojiSearch = "rofi -modi emoji -show emoji"
local clipboardHistory = "cliphist list | rofi -dmenu | cliphist decode | wl-copy"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
	-- [FIX] These used to be one string joined with `&`. Split up so a failure
	-- in one doesn't swallow the other, and so wpaperd (which fires the matugen
	-- hook) starts first - waybar then reads freshly generated colours.
	hl.exec_cmd("wpaperd -d")
	hl.exec_cmd("waybar")

	hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 30")
	hl.exec_cmd("playerctld daemon")
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("mako")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("blueman-applet")
	hl.exec_cmd("~/.config/waybar/auto-reload.sh")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- [FIX] These were 24 / 30 / 30, which gave XWayland apps a visibly smaller
-- cursor than native Wayland ones. All three must agree - if you change one,
-- change the setcursor line in the autostart block too.
hl.env("XCURSOR_SIZE", "30")
hl.env("HYPRCURSOR_SIZE", "30")

hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
-- If you run Qt6 apps and have qt6ct installed, use this instead:
-- hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Permission changes require a full Hyprland RESTART. They are deliberately
-- not applied on a reload, for security reasons.

hl.config({
	ecosystem = {
		enforce_permissions = true,
	},
})

hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
hl.permission("/usr/(bin|local/bin)/satty", "screencopy", "allow")

-- [FIX] This was missing. hyprlock.conf uses `path = screenshot` for its
-- background, which is a screencopy request. With enforce_permissions on and
-- no grant here, the lock screen renders black (or throws a permission popup
-- you can't interact with, because the screen is locked).
hl.permission("/usr/(bin|local/bin)/hyprlock", "screencopy", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 10,

		border_size = 3,

		-- [NEW] Borders now follow the wallpaper palette (see top of file).
		col = {
			active_border = {
				colors = { rgba(palette.primary, "ee"), rgba(palette.secondary, "ee") },
				angle = 45,
			},
			inactive_border = rgba(palette.outline, "aa"),
		},

		-- Set to true to enable resizing windows by clicking and dragging on borders and gaps
		resize_on_border = false,

		-- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
		allow_tearing = false,

		-- keep same outer gaps for single/maximized windows
		float_gaps = -1,

		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,

		-- Change transparency of focused and unfocused windows
		active_opacity = 1.0,
		inactive_opacity = 0.95,

		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a,
		},

		blur = {
			enabled = true,
			size = 3,
			passes = 2,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- Default springs
hl.curve("easy", { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
	dwindle = {
		preserve_split = true, -- You probably want this
	},
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
	master = {
		new_status = "master",
	},
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
	},
})

----------------
----  MISC  ----
----------------

hl.config({
	misc = {
		-- [FIX] These two contradicted each other: force_default_wallpaper = 0
		-- means "no default wallpaper", but disable_hyprland_logo = false left
		-- the logo drawing on top of it. wpaperd owns the wallpaper, so both
		-- should be off.
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
})

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		repeat_rate = 25,
		repeat_delay = 300,

		follow_mouse = 1,

		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

		touchpad = {
			natural_scroll = false,
			scroll_factor = 0.2, -- make scrolling with touchpad slower
		},
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier
local secondMod = "SUPER + SHIFT" -- Sets "Windows" + "SHIFT" key as second modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

-- [NEW] Lock the screen on demand. hypridle only locked on a 5 minute timeout,
-- so there was no way to lock deliberately before walking away.
-- loginctl (rather than calling hyprlock directly) keeps systemd's session
-- state in sync, which is what before_sleep_cmd in hypridle.conf relies on.
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))

-- rofi menus
hl.bind(mainMod .. " + CTRL + RETURN", hl.dsp.exec_cmd(launcher))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(runner))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(calculator))
--hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(emojiSearch))
hl.bind(secondMod .. " + C", hl.dsp.exec_cmd(clipboardHistory))

-- apps
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
--hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(music))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(ai))

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle only
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mainMod .. " + K", hl.dsp.layout("swapsplit")) -- dwindle only

-- Move focus with mainMod + arrow keys
--hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
--hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))

local function workspaceIsScrolling()
	return hl.get_active_workspace().tiled_layout == "scrolling"
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

local function workspaceIsMonocle()
	return hl.get_active_workspace().tiled_layout == "monocle"
end

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

-- Move window with mainMod + CTRL + arrow keys
hl.bind(mainMod .. " + CTRL + LEFT", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + CTRL + RIGHT", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + UP", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + CTRL + DOWN", hl.dsp.window.move({ direction = "down" }))

-- Toggle window maximization / true fullscreen.
-- action defaults to "toggle" so it's fine to omit, matching your original bind.
-- Known upstream quirk (Hyprland 0.55+, tracked in several open discussions):
-- toggling out of maximized doesn't always restore the exact previous size on
-- the scrolling layout, and gaps can stick at 0 after leaving true fullscreen.
-- That's a compositor-side bug, not a config mistake - nothing to fix here.
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
-- True fullscreen
hl.bind(secondMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- toggle floating
hl.bind(secondMod .. " + T", hl.dsp.window.float({ action = "toggle" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(secondMod .. " + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
-- [FIX] was written as mainMod .. " + SHIFT + S", which is the same chord as
-- secondMod .. " + S". Spelled consistently now so it's greppable.
hl.bind(secondMod .. " + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Resize windows with secondMod + arrow
hl.bind(
	secondMod .. " + right",
	hl.dsp.window.resize({ x = 100, y = 0, relative = true }),
	{ repeating = true, description = "Increase window width with keyboard" }
)
hl.bind(
	secondMod .. " + left",
	hl.dsp.window.resize({ x = -100, y = 0, relative = true }),
	{ repeating = true, description = "Reduce window width with keyboard" }
)
hl.bind(
	secondMod .. " + down",
	hl.dsp.window.resize({ x = 0, y = 100, relative = true }),
	{ repeating = true, description = "Increase window height with keyboard" }
)
hl.bind(
	secondMod .. " + up",
	hl.dsp.window.resize({ x = 0, y = -100, relative = true }),
	{ repeating = true, description = "Reduce window height with keyboard" }
)

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Submaps

-- power binds
hl.bind(secondMod .. " + P", hl.dsp.submap("⏻"))

hl.define_submap("⏻", function()
	-- sleep
	hl.bind("s", function()
		hl.dispatch(hl.dsp.exec_cmd("systemctl suspend"))
		hl.dispatch(hl.dsp.submap("reset"))
	end)

	-- lock
	hl.bind("l", function()
		hl.dispatch(hl.dsp.exec_cmd("loginctl lock-session"))
		hl.dispatch(hl.dsp.submap("reset"))
	end)

	-- shutdown
	hl.bind("p", hl.dsp.exec_cmd("hyprshutdown --post-cmd 'systemctl poweroff'"))

	-- reboot
	hl.bind("r", hl.dsp.exec_cmd("hyprshutdown --post-cmd 'systemctl reboot'"))

	-- logout
	hl.bind("SHIFT + l", hl.dsp.exec_cmd("hyprshutdown --post-cmd 'loginctl terminate-user $USER'"))

	-- Use `reset` to go back to the global submap
	hl.bind("escape", hl.dsp.submap("reset"))
end)

-- wallpaper binds
--
-- [FIX] This submap's name was an empty/invisible glyph (a Nerd Font icon
-- codepoint that doesn't render in most contexts - it shows as truly blank).
-- That meant waybar's #submap indicator, whose entire job is to warn you a
-- submap is active, displayed NOTHING while you were in here. If you ever
-- fat-fingered SUPER+SHIFT+W (or a stuck/ghost modifier key fired it for
-- you), you'd land in a mode where l/h/space stop typing and start changing
-- wallpapers, with zero visible sign why. Renamed to plain text so it's
-- unmissable in the bar. Escape still exits back to normal typing either way.
hl.bind(secondMod .. " + W", hl.dsp.submap("wallpaper"))

hl.define_submap("wallpaper", function()
	-- [FIX] wpaperctl's real subcommands are "next-wallpaper" / "previous-wallpaper" /
	-- "toggle-pause-wallpaper" (confirmed against `man wpaperctl`). The original
	-- config called plain "next" / "previous", which don't exist as wpaperctl
	-- subcommands - the command failed silently on every press, so these two
	-- binds have likely never actually changed the wallpaper.

	-- next wallpaper
	hl.bind("l", hl.dsp.exec_cmd("wpaperctl next-wallpaper"))

	-- previous wallpaper
	hl.bind("h", hl.dsp.exec_cmd("wpaperctl previous-wallpaper"))

	-- pause/resume automatic rotation
	hl.bind("space", hl.dsp.exec_cmd("wpaperctl toggle-pause-wallpaper"))

	-- Use `reset` to go back to the global submap
	hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Laptop multimedia keys for volume and LCD brightness
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Requires playerctl.
-- -i playerctld keeps the daemon's own proxy player out of the selection; it
-- mirrors whatever is actually playing, so acting on it directly is redundant.
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl -i playerctld next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl -i playerctld play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl -i playerctld play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl -i playerctld previous"), { locked = true })

-- Screenshots (requires grim, slurp, satty)
-- Full screen -> saved + copied to clipboard
hl.bind(
	"PRINT",
	hl.dsp.exec_cmd(
		"mkdir -p ~/Pictures/Screenshots && "
			.. "f=~/Pictures/Screenshots/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png && "
			.. "grim - | tee \"$f\" | wl-copy && "
			.. "notify-send 'Screenshot saved' \"$(basename \"$f\")\""
	)
)
-- Region select with annotation -> saved via satty's save dialog
hl.bind(
	mainMod .. " + CTRL + S",
	hl.dsp.exec_cmd(
		"mkdir -p ~/Pictures/Screenshots && grim -g \"$(slurp)\" - | "
			.. "satty --filename - --output-filename ~/Pictures/Screenshots/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
	)
)

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Workspace rules
hl.workspace_rule({
	workspace = "2",
	layout = "scrolling",
})

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

hl.window_rule({
	name = "kitty",
	match = { class = "kitty" },

	-- opacity = "0.9 override 0.8 override",
})

-- Waybar-launched utility windows: float + center instead of tiling into the layout
hl.window_rule({
	name = "float-blueman-manager",
	match = { class = "blueman-manager" },

	float = true,
	center = true,
	size = "50% 50%",
})

hl.window_rule({
	name = "float-nmtui",
	match = { title = "nmtui" },

	float = true,
	center = true,
	size = "45% 55%",
})

hl.window_rule({
	name = "float-btop",
	match = { title = "btop" },

	float = true,
	center = true,
	size = "99% 50%",
})

hl.window_rule({
	name = "float-htop",
	match = { title = "htop" },

	float = true,
	center = true,
	size = "60% 65%",
})

hl.window_rule({
	name = "float-pavucontrol",
	match = { class = "org.pulseaudio.pavucontrol" },

	float = true,
	center = true,
	size = "40% 50%",
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})
