-- Monitors. See https://wiki.hypr.land/Configuring/Basics/Monitors/

-- Fallback for any monitor not matched below
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- External display
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
