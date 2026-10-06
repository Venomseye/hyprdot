-- Environment variables and autostart.
-- Waybar, Mako and auto-reload.sh are gone: Quickshell replaces all three.

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- All cursor sizes must agree with the setcursor call below.
hl.env("XCURSOR_SIZE", "30")
hl.env("HYPRCURSOR_SIZE", "30")

-- ~/.local/bin holds dot-reload, dot-wallpaper, dot-updates ... A session started
-- from a display manager or a TTY often doesn't have it on PATH, which showed up as
-- "dot-reload is not installed" in the menu.
do
	local bin = (os.getenv("HOME") or "") .. "/.local/bin"
	local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin"
	if not (":" .. path .. ":"):find(":" .. bin .. ":", 1, true) then
		hl.env("PATH", bin .. ":" .. path)
	end
end

hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
-- Qt6 apps with qt6ct installed: hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Qt apps: Wayland first, X11 only as a fallback. (Quickshell itself is
-- started below with a strict "wayland" so a missing qt6-wayland shows up as
-- an error in ~/.cache/quickshell.log instead of a silent fall-back to X11.)
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-- No usable GPU for clients (a VM without 3D acceleration, or no access to
-- /dev/dri/renderD*)? Qt Quick then fails with
--   "KMS: DRM_IOCTL_MODE_CREATE_DUMB failed: Permission denied"
-- and draws nothing, so there is no bar. The software renderer needs no GL.
-- It turns on automatically inside a VM, or when you create
-- ~/.config/hypr/software-render (or export DOT_SOFTWARE_RENDER=1).
local function wants_software_render()
	if os.getenv("DOT_SOFTWARE_RENDER") == "1" then
		return true
	end
	local base = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
	local marker = io.open(base .. "/hypr/software-render", "r")
	if marker then
		marker:close()
		return true
	end
	local ok, virt = pcall(function()
		local p = io.popen("systemd-detect-virt --vm 2>/dev/null")
		if not p then
			return ""
		end
		local out = p:read("*l") or ""
		p:close()
		return out
	end)
	return ok and virt ~= "" and virt ~= "none"
end

if wants_software_render() then
	hl.env("QT_QUICK_BACKEND", "software")
end

-------------------
---- AUTOSTART ----
-------------------

-- Run `cmd` only if `bin` exists; otherwise say so instead of failing silently.
local function guarded(bin, cmd)
	return "if command -v "
		.. bin
		.. " >/dev/null 2>&1; then "
		.. cmd
		.. "; else command -v notify-send >/dev/null 2>&1 && notify-send -u critical 'Autostart' '"
		.. bin
		.. " is not installed'; fi"
end

hl.on("hyprland.start", function()
	-- Order matters: wpaperd fires the matugen hook, which writes fresh
	-- colours; Quickshell then reads them on launch.
	hl.exec_cmd(guarded("wpaperd", "wpaperd -d"))
	-- Quickshell's output goes to ~/.cache/quickshell.log (read it when the bar
	-- is missing; `dot-doctor` prints it for you).
	hl.exec_cmd(guarded("quickshell",
		"pgrep -x quickshell >/dev/null || { mkdir -p \"$HOME/.cache\" && QT_QPA_PLATFORM=wayland quickshell >>\"$HOME/.cache/quickshell.log\" 2>&1; }"))

	-- Delayed startup tasks live in ~/.config/hooks/.d/post-boot.d/. They sleep
	-- and poll, so run them detached rather than inline.
	hl.exec_cmd("[ -x \"${XDG_CONFIG_HOME:-$HOME/.config}/hooks/run-hooks\" ] && \"${XDG_CONFIG_HOME:-$HOME/.config}/hooks/run-hooks\" post-boot")

	hl.exec_cmd(guarded("hyprctl", "hyprctl setcursor Bibata-Modern-Ice 30"))
	hl.exec_cmd(guarded("playerctld", "playerctld daemon"))
	hl.exec_cmd(guarded("wl-paste", "wl-paste --watch cliphist store"))
	hl.exec_cmd(guarded("hypridle", "hypridle"))
	hl.exec_cmd(guarded("blueman-applet", "blueman-applet"))
	hl.exec_cmd(guarded("gsettings", "gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'"))
end)
