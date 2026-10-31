-- Permissions, workspace rules and window rules.

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Permission changes require a full Hyprland RESTART, not a reload.
hl.config({
	ecosystem = {
		enforce_permissions = true,
	},
})

hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
hl.permission("/usr/(bin|local/bin)/satty", "screencopy", "allow")
-- hyprlock's `path = screenshot` background is a screencopy request.
hl.permission("/usr/(bin|local/bin)/hyprlock", "screencopy", "allow")

------------------------
---- WORKSPACE RULES ---
------------------------

-- Every workspace uses the default layout (dwindle, set in looknfeel.lua).
-- Workspace 2 used to be forced to "scrolling"; that rule is gone on purpose.
-- Per-workspace layouts can be added back here, e.g.:
--   hl.workspace_rule({ workspace = "3", layout = "master" })

----------------------
---- WINDOW RULES ----
----------------------

-- Ignore maximize requests from all apps.
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
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

-- Window sizes. Hyprland's Lua API does NOT understand "60% 70%" (that was the old hyprlang
-- syntax: such a rule is silently ignored and the window keeps its default size, which is why
-- these windows never changed size no matter what number was written here). `size` takes numbers
-- or expressions: monitor_w / monitor_h are the monitor's logical size. pct(w, h) = w% x h%.
local function pct(w, h)
	return { string.format("(monitor_w*%.2f)", w / 100), string.format("(monitor_h*%.2f)", h / 100) }
end

-- Bar-launched utility windows (Quickshell bar spawns these by title/class):
-- float + centre instead of tiling into the layout.
-- Sizes are pct(w, h): a percentage of the monitor's LOGICAL size (resolution / scale). btop needs
-- at least 80x24 cells and pavucontrol's tabs need width, so these are generous. Raise a number
-- to make a window bigger (95 is about the most that still leaves a visible border).
hl.window_rule({
	name = "float-blueman-manager",
	match = { class = "blueman-manager" },

	float = true,
	center = true,
	size = pct(40, 65),
})

-- Terminal tools launched from the bar and menu (btop, nmtui, the updater ...).
-- The launchers pass `kitty --class=dot-<name>` so the rule can match a dedicated class; the title
-- match stays as a fallback (hand-started `kitty --title=btop`, other terminals).
local function float_tool(id, w, h)
	local class = id:match("^dot%-") and id or ("dot-" .. id) -- btop -> dot-btop, dot-update stays
	for _, match in ipairs({ { class = "^" .. class .. "$" }, { title = "^" .. id .. "$" } }) do
		hl.window_rule({
			name = "float-" .. id .. (match.class and "-class" or "-title"),
			match = match,

			float = true,
			center = true,
			size = pct(w, h),
		})
	end
end

float_tool("nmtui", 50, 60)
float_tool("btop", 80, 64)
float_tool("htop", 92, 90)
float_tool("dot-keys", 85, 90)
float_tool("dot-update", 92, 88)

hl.window_rule({
	name = "float-pavucontrol",
	match = { class = "org.pulseaudio.pavucontrol" },

	float = true,
	center = true,
	size = pct(45, 60),
})

-- File chooser (Upload / Open / Save from Firefox, Discord, ...). It comes from
-- xdg-desktop-portal-gtk and used to open as tall as the parent window.
-- The portal's window class is "xdg-desktop-portal-gtk" on older builds and
-- "org.freedesktop.impl.portal.desktop.gtk" (or .gnome / .kde) on newer ones, so match all.
-- Check yours with: sleep 5; dot-doctor   (then open the dialog) - see the "windows" section.
hl.window_rule({
	name = "float-file-chooser",
	match = { class = "^(xdg-desktop-portal-gtk|org\\.freedesktop\\.impl\\.portal\\.desktop\\.(gtk|gnome|kde))$" },

	float = true,
	center = true,
	size = pct(75, 85),
})

-- Other small utility dialogs
hl.window_rule({
	name = "float-gtk-dialogs",
	match = { class = "^(org.gnome.Loupe|org.gnome.Calculator|nm-connection-editor|blueman-assistant|org.gnome.FileRoller)$" },

	float = true,
	center = true,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})

-- Blur behind Quickshell's panels (bar, menu, quick settings, notifications...). Every
-- window sets a "qs-..." layer namespace for this. Wrapped in pcall so a wrong key can
-- never take the rest of the config down; if panels stay flat, check `hyprctl configerrors`
-- and your Hyprland version's layer-rule syntax.
pcall(function()
	hl.layer_rule({
		name = "quickshell-blur",
		match = { namespace = "^qs-.*" },
		blur = true,
		-- Only blur pixels that are at least this opaque. The panels' dimming scrim is ~35-40%
		-- over the WHOLE screen: with 0.3 Hyprland blurred the entire display (both monitors)
		-- on every open, which made opening laggy. The cards are 90% opaque, so 0.5 keeps their blur.
		ignore_alpha = 0.5,
	})
end)
