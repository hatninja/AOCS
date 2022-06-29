#!/bin/sh
cd "$(dirname "$0")"
lua init.lua monitor_proc monitor_sock debug
