-- Hyprland master entry point.
-- All real configuration lives in the sibling modules below.
--
-- Modules are loaded with pcall(dofile, ...) rather than require():
--   * dofile re-reads the file every time, so `hyprctl reload` picks up edits
--     (require caches, and would keep serving stale modules).
--   * pcall isolates failures: a typo in bindings.lua can't stop monitors,
--     input and looknfeel from loading. You get a notification and a stderr
--     line instead of a half-dead session.

local config_dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/"

-- Order matters: rules/autostart/bindings may assume the look is applied.
local modules = {
	"monitors",
	"input",
	"looknfeel",
	"rules",
	"autostart",
	"bindings",
}

for _, name in ipairs(modules) do
	local ok, err = pcall(dofile, config_dir .. name .. ".lua")
	if not ok then
		local msg = tostring(err):gsub("[^%w%s%p]", ""):gsub("'", "")
		io.stderr:write("[hyprland.lua] failed to load " .. name .. ": " .. msg .. "\n")
		hl.exec_cmd(
			"command -v notify-send >/dev/null 2>&1 && notify-send -u critical 'Hyprland config error' '"
				.. name
				.. ".lua: "
				.. msg:sub(1, 300)
				.. "'"
		)
	end
end
