#!/usr/bin/env bash

register_module google "g" direct "" "搜索"

google_direct() {
    local q="$1"
    [ -z "$q" ] && return 0
    open_target "https://www.google.com/search?q=$(urlencode "$q")"
}
