GO_DIRS=("/usr/local/go", "/opt/go")

for DIR in $GO_DIRS[@]; do
  if [ -d "${DIR}" ]; then
    export PATH="${PATH}:${DIR}/bin"
  fi
done

command -v go &>/dev/null && export PATH="$PATH:$(go env GOPATH)/bin"

# Go Version Manager
# https://github.com/moovweb/gvm

GVMRC="${HOME}/.gvm/scripts/gvm"

[[ -s "${GVMRC}" ]] && source "${GVMRC}"
