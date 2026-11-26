-- utils/remote-os.lua
-- Which machine is this pane actually ssh'd into, and what runs on it?
--
-- The pane title is not a usable source: zsh only publishes the cwd basename
-- (~), and behind tmux it becomes the session name (yuez:1.0 zsh), so a remote
-- shell that never emits OSC 0/2 leaves a stale *local* title behind. Instead
-- we read the foreground process' argv — for ssh/mosh the destination is right
-- there, nesting resolves to the innermost client, and it costs one syscall.
--
-- OS knowledge is a curated table, never a live probe: the aliases are ours,
-- and each entry below was checked against /etc/os-release on the host itself
-- (2026-11-26). Anything unrecognised degrades to a generic ssh glyph instead
-- of guessing — a wrong icon is worse than a vague one.

local wezterm = require('wezterm')
local nf = wezterm.nerdfonts

local M = {}

-- os id -> glyph. `fallback` means "remote, but unknown", not "not remote".
local GLYPH = {
   debian = nf.dev_debian, -- U+E77D
   ubuntu = nf.dev_ubuntu, -- U+E73A
   arch = nf.linux_archlinux, -- U+F303  (nf.dev_archlinux does not exist in 20240203)
   centos = nf.linux_centos, -- U+F304
   synology = nf.md_nas, -- U+F08F3
   openwrt = nf.md_router_network, -- U+F1087
   linux = nf.linux_tux, -- U+F31A
   fallback = nf.md_ssh, -- U+F08C0
}

-- Hosts whose OS was read straight off the box. Keyed by the name you type.
local HOST_OS = {
   -- homelab
   dsm = 'synology', -- DSM 7.2.1 — no /etc/os-release, /etc.defaults/VERSION says DSM
   router = 'openwrt', -- OpenWrt 23.05.5
   ['router-proxy'] = 'openwrt',
   pve = 'debian', -- Proxmox VE 9 / Debian 13 (trixie), kernel 6.17.13-2-pve
   ['pve-253'] = 'debian',
   ['pi-hole'] = 'debian',
   ['192.168.3.3'] = 'arch', -- EndeavourOS
   ['192.168.3.250'] = 'centos', -- CentOS Linux 7 (Core), OpenSSH 7.4
   -- cloud boxes
   jp1 = 'ubuntu', -- Lightsail
   la1 = 'ubuntu',
   bj2 = 'ubuntu',
   clawbuntu = 'ubuntu',
}

-- Conservative name heuristics for everything not in the table above.
-- Ordered: first match wins. Never guess an OS from an IP address.
local RULES = {
   { '^k3s', 'debian' }, -- k3sserver01 / k3sagent01..04-2, Debian 12
   { '^pve', 'debian' },
   { '^dsm', 'synology' },
   { '^nas', 'synology' },
   { '^router', 'openwrt' },
   { 'wrt', 'openwrt' },
   { 'ubuntu', 'ubuntu' },
   { 'centos', 'centos' },
   { '^pi%-?hole', 'debian' },
   { '^la%d', 'ubuntu' },
   { '^jp%d', 'ubuntu' },
   { '^bj%d', 'ubuntu' },
}

-- Interactive ssh-family clients. The first non-flag argv token is the
-- destination for all of them (ssh [opts] destination [command]).
local CLIENTS = {
   ssh = true,
   ['ssh.exe'] = true,
   mosh = true,
   autossh = true,
   dbclient = true, -- dropbear
   dropbear = true,
}

-- Flags that consume the FOLLOWING argv token, so the token after them is not
-- the destination (`ssh -J bj2 clawbuntu`, `ssh -p 2222 host`). Attached forms
-- (-p22, -oproxy=jump) never match exactly and need no skip.
local VALUE_FLAGS = {}
for _, f in ipairs({
   '-b', '-c', '-D', '-E', '-e', '-F', '-I', '-i', '-J', '-L', '-l', '-m',
   '-O', '-o', '-p', '-Q', '-R', '-S', '-W', '-w', '-B', '-M',
   '--ssh', '--port', '--client-port', '--predict', '--server', '--family', '--bind-server',
}) do
   VALUE_FLAGS[f] = true
end

local function client_name(executable)
   if type(executable) ~= 'string' or executable == '' then return nil end
   local name = executable:gsub('.*[/\\]', ''):gsub('%.exe$', ''):lower()
   return CLIENTS[name] and name or nil
end

local function first_positional(argv, from)
   local i = from
   while i <= #argv do
      local tok = argv[i]
      if tok == '--' then return argv[i + 1] end
      if tok:sub(1, 1) == '-' then
         i = i + (VALUE_FLAGS[tok] and 2 or 1)
      else
         return tok
      end
   end
   return nil
end

-- `user@host`, `[::1]:22`, `host` -> host
local function normalize(dest)
   if type(dest) ~= 'string' or dest == '' then return nil end
   dest = dest:gsub('^.*@', '')
   dest = dest:gsub('^%[([^%]]+)%].*$', '%1')
   if dest == '' then return nil end
   return dest
end

--- Pure classification, no pane involved (unit-testable).
--- @param argv table|nil  foreground process argv, e.g. { 'ssh', '-p', '2222', 'pve' }
--- @param executable string|nil  absolute path or bare name of argv[0]
--- @return table|nil  { host = 'pve', os = 'debian' }
function M.detect(argv, executable)
   if type(argv) ~= 'table' or #argv < 2 then return nil end

   -- argv[0] may be a login-shell placeholder; fall back to the basename of
   -- argv[0] when `executable` is unavailable.
   local name = client_name(executable) or client_name(argv[1])
   if not name then return nil end

   local host = normalize(first_positional(argv, 2))
   if not host then return nil end
   return { host = host, os = M.os_for(host) }
end

--- @param host string
--- @return string os id (never nil — unknown resolves to 'fallback')
function M.os_for(host)
   local key = host:lower()
   if HOST_OS[key] then return HOST_OS[key] end
   for _, rule in ipairs(RULES) do
      if key:find(rule[1]) then return rule[2] end
   end
   return 'fallback'
end

--- @param os string|nil
--- @return string single-column nerd font glyph
function M.glyph(os)
   return GLYPH[os or 'fallback'] or GLYPH.fallback
end

-- get_foreground_process_info() is a syscall (libproc on macOS, /proc on
-- Linux) and format-tab-title runs on every redraw, so memoise per pane for a
-- couple of seconds. The TTL is short enough that `exit` re-renders as local
-- almost immediately.
local cache = {}

-- Exposed so tests can force expiry without sleeping.
M.ttl = 2

local function pane_id_of(pane)
   if type(pane) ~= 'table' and type(pane) ~= 'userdata' then return nil end
   local ok, id = pcall(function() return pane:pane_id() end)
   if ok and type(id) == 'number' then return id end
   return nil
end

--- Classify a pane's foreground process. Three outcomes, and conflating the
--- last two is what makes a pane lose its icon while it is still remote:
---   link table -> remote (host + os)
---   false      -> positively local: a foreground process was read, it is not ssh
---   'unknown'  -> the process could not be read at all (dying pane, no procfs)
local function inspect(pane)
   local ok, proc = pcall(function() return pane:get_foreground_process_info() end)
   if not ok or type(proc) ~= 'table' or type(proc.argv) ~= 'table' then
      return 'unknown'
   end
   return M.detect(proc.argv, proc.executable) or false
end

--- @param pane Pane
--- @return table|nil { host = ..., os = ... } — nil for local panes
function M.info(pane)
   if not pane then return nil end

   local id = pane_id_of(pane)
   local now = os.time()
   local hit = id and cache[id] or nil
   if hit and (now - hit.at) < M.ttl then return hit.link end

   local result = inspect(pane)
   if result == 'unknown' then
      -- Keep the last identity while the pane is unreadable, and re-arm the
      -- TTL so a dead pane does not cost a syscall on every single redraw.
      if hit then
         hit.at = now
         return hit.link
      end
      return nil
   end

   local link = result or nil
   if id then cache[id] = { at = now, link = link } end
   return link
end

--- Uncached lookup, for tests and for a forced refresh.
function M.probe(pane)
   if not pane then return nil end
   local result = inspect(pane)
   if result == 'unknown' then return nil end
   return result or nil
end

return M
