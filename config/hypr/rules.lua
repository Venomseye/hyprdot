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

-- Bar-launched utility windows (Quickshell bar spawns these by title/class):
-- float + centre instead of tiling into the layout.
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

hl.window_rule({
	name = "float-dot-update",
	match = { title = "dot-update" },

	float = true,
	center = true,
	size = "70% 60%",
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
	size = "55% 70%",
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
		ignore_alpha = 0.3,
	})
end)
