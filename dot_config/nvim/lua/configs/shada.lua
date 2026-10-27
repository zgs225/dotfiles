-- ShaDa file hygiene (E138: All .../main.shada.tmp.X files exist).
--
-- Every nvim on this host shares ~/.local/state/nvim/shada/main.shada.
-- shada_write_file() creates `main.shada.tmp.a` … `.tmp.z` with O_EXCL (one
-- letter per attempt) and then renames over main.shada. Two nvim processes
-- exiting at the same time race inside that window:
--
--   * vim_rename() unlinks the destination *before* rename (nvim <= 0.12.6,
--     upstream #41940 / fix #42152). A peer's "is main.shada writable?" fstat
--     then sees ENOENT -> "E137: ShaDa file is not writable" -> it bails out
--     and *keeps* its temp file (shada.c: shada_write_file_did_not_remove).
--   * the post-rename os_remove(tempname) can delete a temp file another
--     process just created -> that peer's rename fails with "E136: Can't
--     rename ShaDa file" and its temp file is left behind as well.
--
-- A leaked file permanently burns one of the 26 names, and nvim never
-- reclaims stale ones (upstream #11955). After 26 leaks every exit fails with
-- E138 and ShaDa stops being saved at all (history/registers/marks/oldfiles).
--
-- Guards:
--   1. Instance with no UI at startup (nvim --embed subsessions, --headless
--      scripts and tests) neither reads nor writes ShaDa: far fewer writers.
--   2. Stale `main.shada.tmp.[a-z]` leftovers are pruned on VimEnter and right
--      before our own write (VimLeavePre), so leaks cannot accumulate.
--      A real ShaDa write lasts ~1 ms, so a 5 s age gate never hits a live
--      writer.
local M = {}

local SHADA_DIR = vim.fn.stdpath "state" .. "/shada"
local MAX_AGE_SEC = 5

function M.prune()
  local now = os.time()
  local ok, scan = pcall(vim.uv.fs_scandir, SHADA_DIR)
  if not ok or not scan then
    return
  end
  while true do
    local name = vim.uv.fs_scandir_next(scan)
    if not name then
      break
    end
    if name:match "^main%.shada%.tmp%.[a-z]$" then
      local stat = vim.uv.fs_stat(SHADA_DIR .. "/" .. name)
      if stat and now - stat.mtime.sec > MAX_AGE_SEC then
        pcall(vim.uv.fs_unlink, SHADA_DIR .. "/" .. name)
      end
    end
  end
end

if #vim.api.nvim_list_uis() == 0 then
  -- ephemeral instance (--embed / --headless / -l): keep the shared file alone
  vim.o.shada = ""
else
  vim.api.nvim_create_autocmd({ "VimEnter", "VimLeavePre" }, {
    group = vim.api.nvim_create_augroup("ShadaTmpPrune", { clear = true }),
    callback = M.prune,
    desc = "remove stale main.shada.tmp.[a-z] leftovers",
  })
end

return M
