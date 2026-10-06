-- Look and feel: gaps, borders, rounding, blur, animations, layouts, misc.
--
-- Visual standard: 4px inner / 8px outer gaps, 1px border, 10px rounding,
-- active border = matugen primary, blur passes = 3.

------------------------
---- WALLPAPER COLOURS -
------------------------

-- Fallback palette. matugen overwrites ~/.config/hypr/colors-matugen.lua on
-- every wallpaper change; the guarded pcall(dofile) means a missing or
-- malformed generated file just leaves these defaults in place.
local palette = {
	primary = "#33ccff",
	secondary = "#00ff99",
	tertiary = "#a277ff",
	outline = "#595959",
	surface = "#18181b",
	error = "#e35149",
}

do
	local base = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
	local ok, result = pcall(dofile, base .. "/hypr/colors-matugen.lua")
	if ok and type(result) == "table" then
		for key, value in pairs(result) do
			if type(value) == "string" then
				palette[key] = value
			end
		end
	end
end

-- "#75f1fa" + "ee" -> "rgba(75f1faee)"
-- Parens around gsub matter: it returns two values.
local function rgba(hex, alpha)
	return "rgba(" .. (hex:gsub("^#", "")) .. alpha .. ")"
end

---------------------
---- GENERAL/DECO ---
---------------------

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 8,

		border_size = 1,

		col = {
			active_border = rgba(palette.primary, "ff"),
			inactive_border = rgba(palette.outline, "aa"),
		},

		resize_on_border = false,

		-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ first
		allow_tearing = false,

		-- keep same outer gaps for single/maximized windows
		float_gaps = -1,

		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,

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
			passes = 3,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},
})

----------------------
---- ANIMATIONS ------
----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

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

------------------
---- LAYOUTS -----
------------------

hl.config({
	dwindle = {
		preserve_split = true,
	},
})

hl.config({
	master = {
		new_status = "master",
	},
})

hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
	},
})

----------------
----  MISC  ----
----------------

-- wpaperd owns the wallpaper, so both the default wallpaper and logo are off.
hl.config({
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
})
