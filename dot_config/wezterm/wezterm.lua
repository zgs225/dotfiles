local Config = require('config')

require('utils.backdrops'):set_files():random()

-- require('events.right-status').setup()
require('events.left-status').setup()
require('events.tab-title').setup()
require('events.new-tab-button').setup()

-- Per-output font size: X11 has one global Xft.dpi, so the terminal is the one
-- surface that can still keep a constant physical text size when the window is
-- moved to a panel with a different DPI (tmux re-flows via SIGWINCH).
require('events.dpi').setup()

return Config:init()
   :append(require('config.appearance'))
   :append(require('config.bindings'))
   :append(require('config.domains'))
   :append(require('config.fonts'))
   :append(require('config.general'))
   :append(require('config.launch')).options
