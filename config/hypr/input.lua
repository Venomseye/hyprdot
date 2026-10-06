-- Input devices and gestures.

-- Compose key (used by ~/.XCompose, see config/xcompose/). Default: Right Alt.
-- To change it without touching this file:
--     echo compose:rctrl > ~/.config/hypr/compose-key
-- Others: compose:menu  compose:caps  compose:lwin  compose:prsc  compose:ralt
-- (any xkb "compose:*" option; several can be given, comma separated).
local compose_option = "compose:ralt"
do
	local base = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
	local f = io.open(base .. "/hypr/compose-key", "r")
	if f then
		local line = f:read("*l")
		f:close()
		if line and line:match("^[%w:_,%-]+$") then
			compose_option = line
		end
	end
end

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = compose_option,
		kb_rules = "",

		repeat_rate = 25,
		repeat_delay = 300,

		follow_mouse = 1,

		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

		touchpad = {
			natural_scroll = false,
			scroll_factor = 0.2, -- slower touchpad scrolling
		},
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})
