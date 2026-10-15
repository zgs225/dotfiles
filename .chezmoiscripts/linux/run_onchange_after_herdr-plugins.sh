#!/bin/sh
# herdr plugins — declarative (re)install.
#
# This script is the single source of truth for WHICH herdr plugins should be
# installed. Edit PLUGINS below, commit, then `chezmoi apply`: chezmoi re-runs
# this script whenever its content changes (run_onchange_after_*), nothing else
# needs to be done manually.
#
# Boundary: it only drives the `herdr plugin` CLI. Everything under
# ~/.config/herdr (plugins.json, plugins/github-installations/**, *.sock,
# *.log, session*.json, sessions/) and ~/.local/state/herdr/** is machine-local
# runtime state and is deliberately NOT tracked by chezmoi — plugins.json holds
# absolute paths and is rewritten by the CLI on every install. See docs/herdr.md.

set -e

# Not installed (e.g. other machine, fresh host): nothing to declare yet.
command -v herdr >/dev/null 2>&1 || exit 0

# Entries: <plugin_id>:<OWNER/REPO[/SUBDIR]>:<ref>
#   - plugin_id must match the "plugin_id" value reported by `herdr plugin list`.
#   - ref may be a branch, tag or commit; a commit is preferred (see heeler note).
#   - subdir is required when the plugin manifest is not at the repo root.
#
# heeler: pinned to the currently installed commit instead of `main` so rebuilds
#         are reproducible and upstream rewrites cannot silently change what
#         `npm ci`/build produces (plugin needs node >= 20). To upgrade: bump the
#         ref here and re-apply, or uninstall + `herdr plugin update heeler`.
PLUGINS="
heeler:ZingerLittleBee/Heeler/plugin:3e6d3269c0ef2146087e655faf43a06cfcdd198d
"

installed="$(herdr plugin list --json 2>/dev/null || true)"

failed=0
installed_any=0
for entry in $PLUGINS; do
	id="${entry%%:*}"
	rest="${entry#*:}"
	source="${rest%:*}"
	ref="${rest##*:}"

	if printf '%s' "$installed" | grep -q "\"plugin_id\":\"${id}\""; then
		echo "herdr plugin '${id}': already installed, skipping"
		continue
	fi

	echo "herdr plugin '${id}': installing ${source} (ref ${ref})"
	if herdr plugin install "$source" --ref "$ref" -y; then
		echo "herdr plugin '${id}': installed"
		installed_any=1
	else
		echo "herdr plugin '${id}': INSTALL FAILED" >&2
		failed=1
	fi
done

# A freshly installed plugin is only picked up by the running server after a
# config reload. Harmless when no server is running.
if [ "$installed_any" -eq 1 ]; then
	herdr server reload-config >/dev/null 2>&1 || true
fi

exit "$failed"
