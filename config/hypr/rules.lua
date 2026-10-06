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

hl.workspace_rule({
	workspace = "2",
	layout = "scrolling",
})

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

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})
