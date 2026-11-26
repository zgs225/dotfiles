-- Regression test for the tab-title remote indicator.
--   dot_config/wezterm/utils/remote-os.lua   (argv -> host -> os)
--   dot_config/wezterm/events/tab-title.lua  (cells: [jie-yin] [glyph] host)
--
-- Run through scripts/tests/verify-wezterm-tab-title.sh, or directly:
--   wezterm --config-file <this file> ls-fonts 2>&1 | grep -c 'ALL CHECKS PASSED'
-- The report is emitted via error() because wezterm's CLI only surfaces config
-- output on stderr; a passing run still exits non-zero, hence the wrapper.
--
-- Everything here is offline: panes are plain tables, so no GUI, no ssh, no
-- live host is touched.

local cfg_dir = os.getenv('WEZTERM_CONFIG_DIR') or (os.getenv('HOME') .. '/.config/wezterm')
package.path = cfg_dir .. '/?.lua;' .. cfg_dir .. '/?/init.lua;' .. package.path

local wezterm = require('wezterm')
local remote = require('utils.remote-os')
local tabtitle = require('events.tab-title')
tabtitle.setup()

local out = {}
local failures = 0

local function check(label, got, want)
   local ok = (got == want)
   if not ok then failures = failures + 1 end
   out[#out + 1] = string.format('%s %-46s %s', ok and 'PASS' or 'FAIL', label,
      ok and tostring(got) or ('got=' .. tostring(got) .. ' want=' .. tostring(want)))
end

check('os.time exists', type(os.time), 'function')
check('emit exists', type(wezterm.emit), 'function')

-- argv classification ------------------------------------------------------
local function d(argv, exe)
   local r = remote.detect(argv, exe)
   if not r then return 'nil' end
   return r.host .. '/' .. r.os
end

check('ssh pve', d({ 'ssh', 'pve' }, '/usr/bin/ssh'), 'pve/debian')
check('ssh -p 2222 root@ip', d({ 'ssh', '-p', '2222', 'root@192.168.3.250' }, '/usr/bin/ssh'), '192.168.3.250/centos')
check('ssh -J bj2 clawbuntu (jump not host)', d({ 'ssh', '-J', 'bj2', 'clawbuntu' }, '/usr/bin/ssh'), 'clawbuntu/ubuntu')
check('ssh -i key u@host', d({ 'ssh', '-i', '/k/id_rsa', 'yuez@dsm' }, '/usr/bin/ssh'), 'dsm/synology')
check('ssh host + remote cmd (first positional)', d({ 'ssh', 'dsm', 'uname -a' }, '/usr/bin/ssh'), 'dsm/synology')
check('ssh -- host', d({ 'ssh', '--', 'router' }, '/usr/bin/ssh'), 'router/openwrt')
check('ssh -p22 host (attached value)', d({ 'ssh', '-p22', 'router' }, '/usr/bin/ssh'), 'router/openwrt')
check('mosh --ssh=... host', d({ 'mosh', '--ssh=ssh -p 2222', 'dsm' }, '/opt/homebrew/bin/mosh'), 'dsm/synology')
check('autossh -M 0 router', d({ 'autossh', '-M', '0', 'router' }, '/usr/bin/autossh'), 'router/openwrt')
check('ssh unknown host -> fallback', d({ 'ssh', 'sh-prod3' }, '/usr/bin/ssh'), 'sh-prod3/fallback')
check('ssh k3sagent04-2 -> debian', d({ 'ssh', 'k3sagent04-2' }, '/usr/bin/ssh'), 'k3sagent04-2/debian')
check('ssh ipv6 [::1]', d({ 'ssh', 'root@[::1]' }, '/usr/bin/ssh'), '::1/fallback')
check('local zsh is not remote', d({ 'zsh', '-l' }, '/bin/zsh'), 'nil')
check('kubectl exec is not remote', d({ 'kubectl', 'exec', '-it', 'pod', '--', 'bash' }, '/usr/bin/kubectl'), 'nil')
check('docker exec is not remote', d({ 'docker', 'exec', '-it', 'ct', 'sh' }, '/usr/bin/docker'), 'nil')
check('ssh alone (no dest)', d({ 'ssh' }, '/usr/bin/ssh'), 'nil')
check('argv with ssh as a plain arg', d({ 'less', 'ssh' }, '/usr/bin/less'), 'nil')

-- os_for / glyph -----------------------------------------------------------
check('os_for(192.168.3.3)', remote.os_for('192.168.3.3'), 'arch')
check('os_for(pve-253)', remote.os_for('pve-253'), 'debian')
check('os_for(myubuntu)', remote.os_for('myubuntu'), 'ubuntu')
check('os_for(unknown ip)', remote.os_for('10.9.9.9'), 'fallback')
check('glyph fallback is md_ssh', remote.glyph(nil), wezterm.nerdfonts.md_ssh)
check('glyph(arch)', remote.glyph('arch'), wezterm.nerdfonts.linux_archlinux)

-- rendering through the real handler --------------------------------------
local next_id = 100
local function fake_tab(argv, exe, title, active, id)
   if not id then
      next_id = next_id + 1
      id = next_id
   end
   local pane = {
      title = title,
      foreground_process_name = exe or argv[1],
      has_unseen_output = false,
      get_foreground_process_info = function(self) return { argv = argv, executable = exe } end,
      get_title = function(self) return title or '' end,
      pane_id = function(self) return id end,
   }
   return { active_pane = pane, panes = { pane }, is_active = active and true or false, tab_index = 0 }
end

local function render(tab, hover, width)
   local cells = tabtitle.render(tab, hover, width or 40)
   if type(cells) ~= 'table' then return '<no cells: ' .. type(cells) .. '>' end
   local text = {}
   for _, cell in ipairs(cells) do
      if cell.Text then text[#text + 1] = cell.Text end
   end
   return table.concat(text)
end

local BAR = '\u{258E}'
local NAS = wezterm.nerdfonts.md_nas
local DEB = wezterm.nerdfonts.dev_debian
local SSH = wezterm.nerdfonts.md_ssh
local RT = wezterm.nerdfonts.md_router_network

check('render local active', render(fake_tab({ 'zsh' }, '/bin/zsh', '~', true)), BAR .. ' ~ ')
check('render local idle', render(fake_tab({ 'zsh' }, '/bin/zsh', '~', false)), ' ~ ')
check('render remote active', render(fake_tab({ 'ssh', 'dsm' }, '/usr/bin/ssh', '~', true)), BAR .. ' ' .. NAS .. ' dsm ')
check('render remote idle', render(fake_tab({ 'ssh', 'pve' }, '/usr/bin/ssh', 'root@pve: ~', false)), ' ' .. DEB .. ' pve ')
check('render remote unknown', render(fake_tab({ 'ssh', 'sh-prod3' }, '/usr/bin/ssh', '~', false)), ' ' .. SSH .. ' sh-prod3 ')
check('render remote hover', render(fake_tab({ 'ssh', 'router' }, '/usr/bin/ssh', '~', false), true), ' ' .. RT .. ' router ')

-- real panes expose title = nil until something emits OSC 0/2 (found live)
check('render remote with nil title', render(fake_tab({ 'ssh', 'dsm' }, '/usr/bin/ssh', nil, false)), ' ' .. NAS .. ' dsm ')
check('render local with nil title uses proc', render(fake_tab({ 'bash' }, '/bin/bash', nil, false)), ' bash ')
-- ...and the title only exists behind get_title(); the property read is nil
check('render local uses get_title()', render(fake_tab({ 'zsh' }, '/bin/zsh', '~', false)), ' ~ ')

-- truncation: max_width must cap the label, not let the tab overflow
local longhost = string.rep('x', 60)
check('truncated label fits budget', wezterm.column_width(
   render(fake_tab({ 'ssh', longhost }, '/usr/bin/ssh', '~', false), false, 20)) <= 20, true)

-- per-pane cache ----------------------------------------------------------
local tab1 = fake_tab({ 'zsh' }, '/bin/zsh', '~', true, 9001)
local p1 = tab1.active_pane
local function host_of(fn, pane)
   local r = fn(pane or p1)
   return r and r.host or 'nil'
end

check('cache: initial local', host_of(remote.info), 'nil')
p1.get_foreground_process_info = function(self) return { argv = { 'ssh', 'dsm' }, executable = '/usr/bin/ssh' } end
check('cache: info() within TTL still local', host_of(remote.info), 'nil')
check('cache: probe() bypasses cache', host_of(remote.probe), 'dsm')

-- a pane that stops reporting its process keeps the identity it had, and only
-- a positively-read non-ssh process clears it
local tab2 = fake_tab({ 'ssh', 'dsm' }, '/usr/bin/ssh', '~', false, 9002)
local p2 = tab2.active_pane
check('sticky: remote first', host_of(remote.info, p2), 'dsm')
local saved_ttl = remote.ttl
remote.ttl = 0 -- force expiry on every call
p2.get_foreground_process_info = function(self) return nil end
check('sticky: unreadable keeps dsm', host_of(remote.info, p2), 'dsm')
p2.get_foreground_process_info = function(self) return { argv = { 'zsh' }, executable = '/bin/zsh' } end
check('sticky: local process clears', host_of(remote.info, p2), 'nil')
remote.ttl = saved_ttl

out[#out + 1] = ''
out[#out + 1] = failures == 0 and 'ALL CHECKS PASSED' or (failures .. ' CHECK(S) FAILED')
error(table.concat(out, '\n'), 0)
