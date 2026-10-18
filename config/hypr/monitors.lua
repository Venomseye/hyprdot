-- Monitors. See https://wiki.hypr.land/Configuring/Basics/Monitors/

-- Fallback for any monitor not matched below
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- External display on HDMI. (dot-doctor shows this machine's outputs are HDMI-A-1 and eDP-1;
-- the DP-1 rule below only applies if you plug into a DisplayPort output.)
-- If the bar and borders look tiny here, check `hyprctl monitors`: on a 4K screen use
-- scale = "1.5" (27") or "2" (24" and smaller) instead of "auto".
hl.monitor({
	output = "HDMI-A-1",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- External display on DisplayPort
hl.monitor({
	output = "DP-1",
	mode = "preferred",
	position = "auto",
	scale = "2",
})

-- Laptop panel
hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto",
	scale = "1",
	disabled = false,
})
