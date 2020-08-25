#!/bin/sh

set -e

yush_resolv_v4() {
    _server=
    [ "$#" -ge "2" ] && _server=$2
    _host=
    _rx_ip='[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
    if [ -z "$_host" ] && command -v dig 2>1 >/dev/null; then
        if [ -n "$_server" ]; then
            _host=$(dig +short @"$_server" "$1" | grep -Eo -e "$_rx_ip" | tail -n 1)
        else
            _host=$(dig +short "$1" | grep -Eo -e "$_rx_ip" | tail -n 1)
        fi
    fi
    if [ -z "$_host" ] && command -v getent 2>1 >/dev/null; then
        _host=$({ getent ahostsv4 "$1" 2>/dev/null || true; } | grep -Eo -e "$_rx_ip" | head -n 1)
    fi
    if [ -z "$_host" ] && command -v nslookup 2>1 >/dev/null; then
        if [ -n "$_server" ]; then
            _host=$({ nslookup "$1" "$_server" 2>/dev/null || true; } | grep -Eo -e "$_rx_ip" | head -n 1)
        else
            _host=$({ nslookup "$1" 2>/dev/null || true; } | grep -Eo -e "$_rx_ip" | head -n 1)
        fi
    fi
    if [ -z "$_host" ] && command -v host 2>1 >/dev/null; then
        _host=$(host "$1" | grep -Eo -e "$_rx_ip" | head -n 1)
    fi
    printf %s\\n "$_host"    
}