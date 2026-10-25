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

-- nmtui, whiptail and other "newt" text UIs use fixed ANSI colour names (blue background, lightgray
-- window, red title). The matugen terminal palette fills almost every ANSI slot with a light pastel,
-- so those defaults came out pink-on-pink (title contrast 1.00:1). This palette only ever puts the
-- dark slot (black = surface) behind the light ones, so it stays readable in dark AND light mode.
-- (kitty.conf sets the same value, so it also applies to kitty windows opened before a restart.)
hl.env("NEWT_COLORS",
	"root=white,black roottext=lightgray,black window=white,black border=lightgray,black shadow=black,black title=blue,black button=blue,black actbutton=black,blue compactbutton=white,black checkbox=white,black actcheckbox=black,blue entry=black,lightgray disentry=gray,black label=white,black listbox=white,black actlistbox=white,black sellistbox=blue,black actsellistbox=black,blue textbox=white,black acttextbox=black,blue helpline=black,lightgray emptyscale=gray,black fullscale=blue,black")
-- nmtui ALSO hard-codes a few colours of its own (plain labels, error labels, disabled buttons, text
-- boxes: black on lightgray ...) that NEWT_COLORS cannot reach; it reads NMT_NEWT_COLORS for those.
-- Without this they show as light-grey patches inside the dark window.
hl.env("NMT_NEWT_COLORS", "plainLabel=white,black badLabel=red,black disabledButton=gray,black textboxWithBackground=black,lightgray")

-- Qt apps take their colours from qt6ct/qt5ct (matugen writes the scheme; `dot-theme init`
-- writes their config). Prefer qt6ct when its plugin is installed - most Qt apps are Qt6.
do
	local f = io.open("/usr/lib/qt6/plugins/platformthemes/libqt6ct.so", "r")
	if f then
		f:close()
		hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
	else
		hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
	end
end
-- Qt6 apps with qt6ct installed: hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Qt prints "Trying to disable <surface> but 0x0 is focused" (qt.qpa.wayland.textinput) each time a
-- Quickshell popup closes. Harmless, but it floods ~/.cache/quickshell.log; silence that category only.
hl.env("QT_LOGGING_RULES", "qt.qpa.wayland.textinput.warning=false")

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
	-- `dot-reload boot` checks the QML first, starts Quickshell, and if the config does not load
	-- falls back to the last copy that did (see `dot-reload --help`). It also trims the log. Without
	-- dot-reload (a bare checkout) the old direct start is used.
	hl.exec_cmd(guarded("quickshell",
		"if command -v dot-reload >/dev/null 2>&1; then dot-reload boot; else pgrep -x quickshell >/dev/null || { pkill -x mako 2>/dev/null; pkill -x dunst 2>/dev/null; mkdir -p \"$HOME/.cache\" && QT_QPA_PLATFORM=wayland quickshell >>\"$HOME/.cache/quickshell.log\" 2>&1; }; fi"))

	-- Delayed startup tasks live in ~/.config/hooks/.d/post-boot.d/. They sleep
	-- and poll, so run them detached rather than inline.
	hl.exec_cmd("[ -x \"${XDG_CONFIG_HOME:-$HOME/.config}/hooks/run-hooks\" ] && \"${XDG_CONFIG_HOME:-$HOME/.config}/hooks/run-hooks\" post-boot")

	hl.exec_cmd(guarded("hyprctl", "hyprctl setcursor Bibata-Modern-Ice 30"))
	-- (no `playerctld daemon`: Quickshell's media service picks the active player itself, and the
	-- daemon's proxy player only filled ~/.cache/quickshell.log with "NoActivePlayer" warnings)
	hl.exec_cmd(guarded("wl-paste", "wl-paste --watch cliphist store"))
	hl.exec_cmd(guarded("hypridle", "hypridle"))
	hl.exec_cmd(guarded("blueman-applet", "blueman-applet"))
	hl.exec_cmd(guarded("gsettings", "gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'"))
end)
