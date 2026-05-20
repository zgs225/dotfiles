#!/usr/bin/env lua

-- sync-tmux-colors.lua
-- Reads the single-source palette from config/wezterm/colors/palette.lua
-- and regenerates the tmux colour_N assignments inside tmux.conf.local.

local function resolve_root()
   local script = arg and arg[0] or debug.getinfo(1, "S").source:sub(2)
   return script:match("^(.*)/scripts/") or os.getenv("HOME") .. "/dotfiles"
end

local root = resolve_root()
local palette_mod = dofile(root .. "/config/wezterm/colors/palette.lua")
local palette = palette_mod.palette
local mapping = palette_mod.tmux_mapping

local colour_lines = {}
for i = 1, 17 do
   local key = "colour_" .. i
   local palette_key = mapping[key]
   local color = palette[palette_key]
   if not color then
      io.stderr:write("ERROR: no palette entry for '" .. palette_key .. "' (tmux " .. key .. ")\n")
      os.exit(1)
   end
   table.insert(colour_lines, string.format('tmux_conf_theme_%s="%s"', key, color))
end

local begin_marker = "# -- tmux colours: auto-generated begin (sync from config/wezterm/colors/palette.lua) --"
local end_marker   = "# -- tmux colours: auto-generated end --"
local replacement  = begin_marker .. "\n"
                   .. table.concat(colour_lines, "\n")
                   .. "\n" .. end_marker

local function escape(str)
   return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local tmux_local = root .. "/tmux.conf.local"
local f = io.open(tmux_local, "r")
if not f then
   io.stderr:write("ERROR: cannot read " .. tmux_local .. "\n")
   os.exit(1)
end
local content = f:read("*a")
f:close()

local b_start = content:find(escape(begin_marker))
local _, e_end = content:find(escape(end_marker))
if not b_start or not e_end then
   io.stderr:write("ERROR: sentinel markers not found in " .. tmux_local .. "\n")
   os.exit(1)
end

local new_content = content:sub(1, b_start - 1) .. replacement .. content:sub(e_end + 1)

f = io.open(tmux_local, "w")
f:write(new_content)
f:close()

print(string.format("Synced %d tmux colour variables in %s", #colour_lines, tmux_local))
