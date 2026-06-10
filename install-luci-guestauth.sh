#!/bin/sh
set -eu

APP_NAME="guestauth"
HELPER_DIR="/usr/libexec/guestauth"
HELPER="$HELPER_DIR/guestauth.sh"
LUA_DIR="/usr/lib/lua/luci"
CTRL_DIR="$LUA_DIR/controller"
VIEW_DIR="$LUA_DIR/view/guestauth"
CTRL_FILE="$CTRL_DIR/guestauth.lua"
VIEW_FILE="$VIEW_DIR/index.htm"
ETC_DIR="/etc/guestauth"
SETTINGS_FILE="$ETC_DIR/settings.conf"

mkdir -p "$HELPER_DIR" "$CTRL_DIR" "$VIEW_DIR" "$ETC_DIR"

if [ ! -f "$SETTINGS_FILE" ]; then
	cat >"$SETTINGS_FILE" <<'EOF_SETTINGS'
probe_url=http://www.baidu.com/
manual_url=
EOF_SETTINGS
fi

cat >"$HELPER" <<'EOF_HELPER'
#!/bin/sh
set -eu

BASE_DIR="/tmp/guestauth"
STATE_DIR="$BASE_DIR/state"
COOKIE_JAR="$BASE_DIR/cookies.txt"
HEADER_FILE="$BASE_DIR/probe.headers"
BODY_FILE="$BASE_DIR/probe.body"
ETC_DIR="/etc/guestauth"
SETTINGS_FILE="$ETC_DIR/settings.conf"

mkdir -p "$STATE_DIR" "$ETC_DIR"

if [ ! -f "$SETTINGS_FILE" ]; then
	cat >"$SETTINGS_FILE" <<'EOF_DEFAULTS'
probe_url=http://www.baidu.com/
manual_url=
EOF_DEFAULTS
fi

load_settings() {
probe_url="$(sed -n 's/^probe_url=//p' "$SETTINGS_FILE" | head -n 1)"
manual_url="$(sed -n 's/^manual_url=//p' "$SETTINGS_FILE" | head -n 1)"
: "${probe_url:=http://www.baidu.com/}"
: "${manual_url:=}"
}

write_state() {
	key="$1"
	value="$2"
	printf '%s' "$value" >"$STATE_DIR/$key"
}

save_setting() {
	key="$1"
	value="$2"
	tmp="$(mktemp)"
	found=0
	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
			"$key="*)
				printf '%s=%s\n' "$key" "$value" >>"$tmp"
				found=1
				;;
			*)
				printf '%s\n' "$line" >>"$tmp"
				;;
		esac
	done <"$SETTINGS_FILE"
	if [ "$found" -eq 0 ]; then
		printf '%s=%s\n' "$key" "$value" >>"$tmp"
	fi
	mv "$tmp" "$SETTINGS_FILE"
}

extract_portal_from_headers() {
	if [ -f "$HEADER_FILE" ]; then
		sed -n 's/^[Ll]ocation:[[:space:]]*//p' "$HEADER_FILE" | tr -d '\r' | grep -Ei '/ess/(common|guest)auth' | tail -n 1 || true
	fi
}

extract_portal_from_body() {
	if [ -f "$BODY_FILE" ]; then
		grep -aoE 'https?://[^"'\''<> ]+/ess/(common|guest)auth[^"'\''<> ]*' "$BODY_FILE" | head -n 1 || true
	fi
}

extract_embedded_portal() {
	if [ -f "$BODY_FILE" ] && grep -Eaq 'action="\./(common|guest)auth"' "$BODY_FILE"; then
		host="$(sed -n 's/.*id="sccpServerIp"[^>]*value="\([^"]*\)".*/\1/p' "$BODY_FILE" | head -n 1)"
		action_name="$(grep -aoE 'action="\./(common|guest)auth"' "$BODY_FILE" | head -n 1 | sed 's/.*\.\///; s/"$//')"
		: "${action_name:=commonauth}"
		if [ -n "$host" ]; then
			printf 'http://%s/ess/%s\n' "$host" "$action_name"
		else
			printf 'http://192.168.110.10/ess/%s\n' "$action_name"
		fi
	fi
}


count_portal_hints() {
	input="$1"
	count=0
	for key in wlanuserip wlanacname ssid mac nasip; do
		if printf '%s' "$input" | grep -q "$key="; then
			count=$((count + 1))
		fi
	done
	printf '%s\n' "$count"
}

extract_portal_from_hint_url() {
	if [ -f "$BODY_FILE" ]; then
		grep -aoE "https?://[^\"<> ]+" "$BODY_FILE" | while IFS= read -r candidate; do
			hits="$(count_portal_hints "$candidate")"
			if [ "$hits" -ge 3 ]; then
				printf '%s\n' "$candidate"
				exit 0
			fi
		done | head -n 1 || true
	fi
}

probe() {
	load_settings
	url="${1:-$probe_url}"
	rm -f "$HEADER_FILE" "$BODY_FILE"
	effective_url="$(curl -A 'Mozilla/5.0' -sS -L -D "$HEADER_FILE" -o "$BODY_FILE" --max-time 15 "$url" -w '%{url_effective}' || true)"
	portal_url=""
	need_auth="0"
	detect_mode="normal"

	if printf '%s' "$effective_url" | grep -Eqi '/ess/(common|guest)auth'; then
		portal_url="$effective_url"
	fi

	if [ -z "$portal_url" ]; then
		portal_url="$(extract_portal_from_headers)"
	fi

	if [ -z "$portal_url" ]; then
		portal_url="$(extract_portal_from_body)"
	fi

	if [ -z "$portal_url" ]; then
		portal_url="$(extract_embedded_portal)"
	fi

	if [ -z "$portal_url" ]; then
		hint_hits="$(count_portal_hints "$effective_url")"
		if [ "$hint_hits" -ge 3 ]; then
			portal_url="$effective_url"
			detect_mode="portal-hints-url"
		fi
	fi

	if [ -z "$portal_url" ]; then
		portal_url="$(extract_portal_from_hint_url)"
		if [ -n "$portal_url" ] && [ "$detect_mode" = "normal" ]; then
			detect_mode="portal-hints-body"
		fi
	fi

	if [ -n "$portal_url" ]; then
		need_auth="1"
		if [ "$detect_mode" = "normal" ]; then
			detect_mode="portal-url"
		fi
	fi

	if [ -f "$BODY_FILE" ] && grep -Eaq 'action="\./(common|guest)auth"' "$BODY_FILE"; then
		need_auth="1"
		if [ "$detect_mode" = "normal" ]; then
			detect_mode="portal-page"
		fi
	fi

	write_state "last_probe_time" "$(date '+%Y-%m-%d %H:%M:%S %z')"
	write_state "last_probe_url" "$url"
	write_state "last_effective_url" "$effective_url"
	write_state "last_need_auth" "$need_auth"
	write_state "last_detect_mode" "$detect_mode"
	write_state "last_body_hint" "$(grep -Eaq 'action="\./(common|guest)auth"' "$BODY_FILE" && printf 'portal-form' || printf 'normal')"

	if [ -n "$portal_url" ]; then
		write_state "last_portal_url" "$portal_url"
	fi
}

current_url() {
	load_settings
	if [ -n "${manual_url:-}" ]; then
		printf '%s\n' "$manual_url"
	elif [ -f "$STATE_DIR/last_portal_url" ]; then
		cat "$STATE_DIR/last_portal_url"
	fi
}

case "${1:-}" in
	probe)
		shift
		probe "${1:-}"
		;;
	set-manual-url)
		shift
		save_setting "manual_url" "${1:-}"
		;;
	set-probe-url)
		shift
		save_setting "probe_url" "${1:-http://www.baidu.com/}"
		;;
	current-url)
		current_url
		;;
	clear-cookies)
		rm -f "$COOKIE_JAR"
		;;
	*)
		echo "usage: $0 {probe [url]|set-manual-url url|set-probe-url url|current-url|clear-cookies}" >&2
		exit 1
		;;
esac
EOF_HELPER
chmod 0755 "$HELPER"

cat >"$CTRL_FILE" <<'EOF_CTRL'
module("luci.controller.guestauth", package.seeall)

local http = require "luci.http"
local sys = require "luci.sys"
local tpl = require "luci.template"
local fs = require "nixio.fs"

local HELPER = "/usr/libexec/guestauth/guestauth.sh"
local SETTINGS_FILE = "/etc/guestauth/settings.conf"
local STATE_DIR = "/tmp/guestauth/state"
local COOKIE_JAR = "/tmp/guestauth/cookies.txt"

function index()
	entry({"admin", "services", "guestauth"}, call("action_index"), _("GuestAuth"), 95).dependent = true
	entry({"admin", "services", "guestauth", "detect"}, call("action_detect")).leaf = true
	entry({"admin", "services", "guestauth", "save"}, call("action_save")).leaf = true
	entry({"admin", "services", "guestauth", "clear"}, call("action_clear")).leaf = true
	entry({"admin", "services", "guestauth", "open"}, call("action_open")).leaf = true
	entry({"admin", "services", "guestauth", "proxy"}, call("action_proxy")).leaf = true
	entry({"guestauth", "proxy"}, call("action_proxy_public")).leaf = true
end

local function trim(s)
	if not s then
		return ""
	end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function readfile(path)
	local f = io.open(path, "rb")
	if not f then
		return ""
	end
	local data = f:read("*a") or ""
	f:close()
	return trim(data)
end

local function parse_settings()
	local out = {
		probe_url = "http://www.baidu.com/",
		manual_url = ""
	}
	local f = io.open(SETTINGS_FILE, "r")
	if not f then
		return out
	end
	for line in f:lines() do
		local key, value = line:match("^([%w_]+)=(.*)$")
		if key then
			out[key] = value
		end
	end
	f:close()
	return out
end

local function state_value(name)
	return readfile(STATE_DIR .. "/" .. name)
end

local function build_state()
	if state_value("last_probe_time") == "" then
		sys.call(HELPER .. " probe >/dev/null 2>&1")
	end
	local settings = parse_settings()
	local current_url = settings.manual_url
	if current_url == "" then
		current_url = state_value("last_portal_url")
	end
	return {
		settings = settings,
		current_url = current_url,
		last_portal_url = state_value("last_portal_url"),
		last_effective_url = state_value("last_effective_url"),
		last_need_auth = state_value("last_need_auth"),
		last_probe_time = state_value("last_probe_time"),
		last_probe_url = state_value("last_probe_url"),
		last_detect_mode = state_value("last_detect_mode"),
		last_body_hint = state_value("last_body_hint"),
		cookie_jar_exists = fs.access(COOKIE_JAR) and "1" or "0"
	}
end

local function shell_quote(s)
	return string.format("%q", s or "")
end

local function redirect_with_msg(msg)
	local base = luci.dispatcher.build_url("admin", "services", "guestauth")
	if msg and msg ~= "" then
		http.redirect(base .. "?msg=" .. http.urlencode(msg))
	else
		http.redirect(base)
	end
end

function action_index()
	tpl.render("guestauth/index", {
		state = build_state(),
		msg = http.formvalue("msg") or ""
	})
end

function action_detect()
	local probe_url = trim(http.formvalue("probe_url") or "")
	if probe_url ~= "" then
		sys.call(HELPER .. " set-probe-url " .. shell_quote(probe_url))
	end
	sys.call(HELPER .. " probe >/dev/null 2>&1")
	redirect_with_msg("Detection finished")
end

function action_save()
	local probe_url = trim(http.formvalue("probe_url") or "")
	local manual_url = trim(http.formvalue("manual_url") or "")
	if probe_url == "" then
		probe_url = "http://www.baidu.com/"
	end
	sys.call(HELPER .. " set-probe-url " .. shell_quote(probe_url))
	sys.call(HELPER .. " set-manual-url " .. shell_quote(manual_url))
	redirect_with_msg("Settings saved")
end

function action_clear()
	sys.call(HELPER .. " clear-cookies >/dev/null 2>&1")
	redirect_with_msg("Proxy cookies cleared")
end

function action_open()
	local current = trim(sys.exec(HELPER .. " current-url"))
	if current == "" then
		redirect_with_msg("No current portal URL. Run detection first or set manual URL.")
		return
	end
	http.redirect(luci.dispatcher.build_url("guestauth", "proxy") .. "?u=" .. http.urlencode(current))
end

local function parse_url(url)
	local scheme, rest = url:match("^(https?)://(.+)$")
	if not scheme then
		return nil
	end
	local authority, path = rest:match("^([^/]+)(/.*)$")
	if not authority then
		authority = rest
		path = "/"
	end
	local clean_path = path:match("^([^?#]*)") or "/"
	return {
		scheme = scheme,
		authority = authority,
		prefix = scheme .. "://" .. authority,
		path = clean_path
	}
end

local function dirname(path)
	return path:match("^(.*)/[^/]*$") or ""
end

local function normalize_path(path)
	local parts = {}
	for part in path:gmatch("[^/]+") do
		if part == ".." then
			if #parts > 0 then
				table.remove(parts)
			end
		elseif part ~= "." and part ~= "" then
			parts[#parts + 1] = part
		end
	end
	return "/" .. table.concat(parts, "/")
end

local function resolve_url(base_url, ref)
	if not ref or ref == "" then
		return ref
	end
	if ref:match("^[a-zA-Z][a-zA-Z0-9+.-]*:") then
		return ref
	end
	if ref:sub(1, 1) == "#" then
		return ref
	end
	local base = parse_url(base_url)
	if not base then
		return ref
	end
	if ref:sub(1, 2) == "//" then
		return base.scheme .. ":" .. ref
	end
	if ref:sub(1, 1) == "/" then
		return base.prefix .. ref
	end
	if ref:sub(1, 1) == "?" then
		return base.prefix .. base.path .. ref
	end
	local merged = dirname(base.path)
	if merged == "" then
		merged = "/"
	else
		merged = merged .. "/"
	end
	return base.prefix .. normalize_path(merged .. ref)
end

local function html_attr_escape(s)
	return (s:gsub("&", "&amp;"):gsub("\"", "&quot;"))
end

local function proxy_link(abs_url)
	return luci.dispatcher.build_url("guestauth", "proxy") .. "?u=" .. http.urlencode(abs_url)
end

local function should_rewrite(ref)
	if not ref or ref == "" then
		return false
	end
	if ref:match("^data:") or ref:match("^javascript:") or ref:match("^mailto:") or ref:match("^tel:") then
		return false
	end
	if ref:find("/admin/services/guestauth/proxy", 1, true) then
		return false
	end
	return true
end

local function rewrite_attr_blob(body, base_url)
	local function replace_attr(attr, quote, ref)
		if not should_rewrite(ref) then
			return attr .. "=" .. quote .. ref .. quote
		end
		local abs = resolve_url(base_url, ref)
		if not abs or abs == ref and not ref:match("^[./?]") and not ref:match("^/") then
			return attr .. "=" .. quote .. ref .. quote
		end
		return attr .. "=" .. quote .. html_attr_escape(proxy_link(abs)) .. quote
	end

	body = body:gsub("([Hh][Rr][Ee][Ff])=(['\"])(.-)%2", replace_attr)
	body = body:gsub("([Ss][Rr][Cc])=(['\"])(.-)%2", replace_attr)
	body = body:gsub("([Aa][Cc][Tt][Ii][Oo][Nn])=(['\"])(.-)%2", replace_attr)
	return body
end

local function rewrite_hidden_values(body, base_url)
	local targets = {
		loginActionName = true,
		loginUrl = true,
		findPswUrl = true
	}
	return body:gsub("(<input[^>]-id=\")(.-)(\"[^>]-value=\")(.-)(\"[^>]->)", function(prefix, id, mid, value, suffix)
		if not targets[id] or not should_rewrite(value) then
			return prefix .. id .. mid .. value .. suffix
		end
		local abs = resolve_url(base_url, value)
		return prefix .. id .. mid .. html_attr_escape(proxy_link(abs)) .. suffix
	end)
end

local function rewrite_css(body, base_url)
	return body:gsub("url%((['\"]?)(.-)%1%)", function(quote, ref)
		if not should_rewrite(ref) then
			return "url(" .. quote .. ref .. quote .. ")"
		end
		local abs = resolve_url(base_url, ref)
		return "url(" .. quote .. proxy_link(abs) .. quote .. ")"
	end)
end

local function protect_script_contents(body)
	local blocks = {}
	body = body:gsub("(<[Ss][Cc][Rr][Ii][Pp][Tt][^>]*>)(.-)(</[Ss][Cc][Rr][Ii][Pp][Tt]>)", function(open_tag, content, close_tag)
		local key = string.format("__GA_SCRIPT_CONTENT_%d__", #blocks + 1)
		blocks[#blocks + 1] = content
		return open_tag .. key .. close_tag
	end)
	return body, blocks
end

local function restore_script_contents(body, blocks)
	for i, block in ipairs(blocks) do
		body = body:gsub(string.format("__GA_SCRIPT_CONTENT_%d__", i), block, 1)
	end
	return body
end

local function rewrite_html(body, base_url)
	local script_blocks
	body, script_blocks = protect_script_contents(body)
	body = rewrite_attr_blob(body, base_url)
	body = rewrite_hidden_values(body, base_url)
	body = rewrite_css(body, base_url)
	body = restore_script_contents(body, script_blocks)
	if not body:find("<meta name=\"referrer\"", 1, true) then
		body = body:gsub("<head>", "<head><meta name=\"referrer\" content=\"no-referrer\">", 1)
	end
	return body
end

local function build_post_body()
	local form = http.formvaluetable("") or {}
	if next(form) == nil then
		local fallback = http.formvalue()
		if type(fallback) == "table" then
			form = fallback
		end
	end
	local pairs_out = {}
	for key, value in pairs(form) do
		if key ~= "u" and value ~= nil and type(value) ~= "table" then
			pairs_out[#pairs_out + 1] = http.urlencode(key) .. "=" .. http.urlencode(value)
		end
	end
	return table.concat(pairs_out, "&")
end

local function extract_content_type(header_blob)
	local ct = header_blob:match("[Cc]ontent%-[Tt]ype:%s*([^\r\n]+)")
	return trim(ct or "text/html; charset=UTF-8")
end

local function slurp(path, mode)
	local f = io.open(path, mode or "rb")
	if not f then
		return ""
	end
	local data = f:read("*a") or ""
	f:close()
	return data
end

local function append_proxy_log(line)
	local f = io.open("/tmp/guestauth/proxy-access.log", "a")
	if not f then
		return
	end
	f:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. line .. "\n")
	f:close()
end

local function serve_proxy()
	local target = trim(http.formvalue("u") or "")
	if target == "" then
		target = trim(sys.exec(HELPER .. " current-url"))
	end
	if target == "" or not target:match("^https?://") then
		http.status(400, "Bad Request")
		http.prepare_content("text/plain")
		http.write("No valid target URL")
		return
	end

	if not is_allowed_target(target) then
		http.status(403, "Forbidden")
		http.prepare_content("text/plain")
		http.write("Target host is not allowed")
		return
	end

	local tmp_base = trim(sys.exec("mktemp /tmp/guestauth/proxy.XXXXXX"))
	if tmp_base == "" then
		http.status(500, "Internal Server Error")
		http.prepare_content("text/plain")
		http.write("Failed to allocate proxy temp files")
		return
	end
	local header_path = tmp_base .. ".headers"
	local body_path = tmp_base .. ".body"
	local post_path = tmp_base .. ".post"
	fs.remove(tmp_base)
	local method = http.getenv("REQUEST_METHOD") or "GET"
	local cmd

	if method == "POST" then
		local post_body = build_post_body()
		local f = io.open(post_path, "wb")
		if f then
			f:write(post_body)
			f:close()
		end
		cmd = string.format(
			"curl -A 'Mozilla/5.0' -sS -L -D %s -o %s -b %s -c %s --max-time 20 -e %s -H 'Content-Type: application/x-www-form-urlencoded' --data-binary @%s %s",
			shell_quote(header_path),
			shell_quote(body_path),
			shell_quote(COOKIE_JAR),
			shell_quote(COOKIE_JAR),
			shell_quote(target),
			shell_quote(post_path),
			shell_quote(target)
		)
	else
		cmd = string.format(
			"curl -A 'Mozilla/5.0' -sS -L -D %s -o %s -b %s -c %s --max-time 20 %s",
			shell_quote(header_path),
			shell_quote(body_path),
			shell_quote(COOKIE_JAR),
			shell_quote(COOKIE_JAR),
			shell_quote(target)
		)
	end

	append_proxy_log(string.format("REQ method=%s target=%s", method, target))
	local rc = sys.call(cmd .. " >/dev/null 2>&1")
	if rc ~= 0 then
		append_proxy_log(string.format("ERR method=%s rc=%s target=%s", method, tostring(rc), target))
		fs.remove(header_path)
		fs.remove(body_path)
		fs.remove(post_path)
		http.status(502, "Bad Gateway")
		http.prepare_content("text/plain")
		http.write("Router failed to fetch portal content")
		return
	end

	local headers = slurp(header_path, "rb")
	local body = slurp(body_path, "rb")
	local content_type = extract_content_type(headers)

	if content_type:find("text/html", 1, true) then
		body = rewrite_html(body, target)
	elseif content_type:find("text/css", 1, true) then
		body = rewrite_css(body, target)
	end

	append_proxy_log(string.format("RES method=%s type=%s bytes=%d target=%s", method, content_type, #body, target))
	http.prepare_content(content_type)
	http.write(body)

	fs.remove(header_path)
	fs.remove(body_path)
	fs.remove(post_path)
end

function action_proxy()
	serve_proxy()
end

function action_proxy_public()
	serve_proxy()
end

function host_from_url(url)
	return (url or ""):match("^https?://([^/%?#]+)") or ""
end

function is_allowed_target(target)
	local host = host_from_url(target)
	if host == "" then
		return false
	end
	if host == "192.168.110.10" then
		return true
	end
	local current = trim(sys.exec(HELPER .. " current-url"))
	return host ~= "" and host == host_from_url(current)
end
EOF_CTRL

cat >"$VIEW_FILE" <<'EOF_VIEW'
<%+header%>
<%
local dispatcher = require "luci.dispatcher"
local state = state or {}
local settings = state.settings or {}
%>

<h2>GuestAuth</h2>
<style type="text/css">
	.ga-url {
		max-width: 100%;
		white-space: pre-wrap;
		overflow-wrap: anywhere;
		word-break: break-word;
	}
	.ga-url code {
		display: block;
		white-space: inherit;
		overflow-wrap: inherit;
		word-break: inherit;
	}
</style>
<div class="cbi-map-descr">
	This page helps the router detect a captive portal, remember the latest portal URL, and proxy the portal through LuCI so the browser only needs to reach <code><%=luci.http.getenv("HTTP_HOST") or "this router"%></code>.
</div>

<% if msg and msg ~= "" then %>
<div class="alert-message notice"><%=msg%></div>
<% end %>

<div class="cbi-section">
	<h3>Current State</h3>
	<table class="table cbi-section-table">
		<tr><td width="220">Needs auth</td><td><%=state.last_need_auth == "1" and "yes" or "no"%></td></tr>
		<tr><td>Current portal URL</td><td><div class="ga-url"><code><%=state.current_url ~= "" and state.current_url or "-"%></code></div></td></tr>
		<tr><td>Last detected portal URL</td><td><div class="ga-url"><code><%=state.last_portal_url ~= "" and state.last_portal_url or "-"%></code></div></td></tr>
		<tr><td>Last effective URL</td><td><div class="ga-url"><code><%=state.last_effective_url ~= "" and state.last_effective_url or "-"%></code></div></td></tr>
		<tr><td>Last probe URL</td><td><div class="ga-url"><code><%=state.last_probe_url ~= "" and state.last_probe_url or settings.probe_url or "-"%></code></div></td></tr>
		<tr><td>Last detection mode</td><td><%=state.last_detect_mode ~= "" and state.last_detect_mode or "-"%></td></tr>
		<tr><td>Last probe time</td><td><%=state.last_probe_time ~= "" and state.last_probe_time or "-"%></td></tr>
		<tr><td>Proxy cookie jar</td><td><%=state.cookie_jar_exists == "1" and "present" or "empty"%></td></tr>
	</table>
</div>

<div class="cbi-section">
	<h3>Settings</h3>
	<form method="post" action="<%=dispatcher.build_url('admin', 'services', 'guestauth', 'save')%>">
		<div class="cbi-value">
			<label class="cbi-value-title">Probe URL</label>
			<div class="cbi-value-field">
				<input class="cbi-input-text" style="width: 100%;" type="text" name="probe_url" value="<%=settings.probe_url or 'http://www.baidu.com/'%>" />
				<div class="cbi-value-description">The router probes this URL to decide whether the network is intercepted.</div>
			</div>
		</div>
		<div class="cbi-value">
			<label class="cbi-value-title">Manual portal URL</label>
			<div class="cbi-value-field">
				<input class="cbi-input-text" style="width: 100%;" type="text" name="manual_url" value="<%=settings.manual_url or ''%>" />
				<div class="cbi-value-description">Optional override. If auto detection misses the live portal URL, paste the latest <code>commonauth</code> or <code>guestauth</code> URL here.</div>
			</div>
		</div>
		<div class="right">
			<input class="cbi-button cbi-button-apply" type="submit" value="Save Settings" />
		</div>
	</form>
</div>

<div class="cbi-section">
	<h3>Actions</h3>
	<form method="post" action="<%=dispatcher.build_url('admin', 'services', 'guestauth', 'detect')%>" style="display: inline-block; margin-right: 8px;">
		<input type="hidden" name="probe_url" value="<%=settings.probe_url or 'http://www.baidu.com/'%>" />
		<input class="cbi-button cbi-button-action" type="submit" value="Detect Portal" />
	</form>
	<form method="get" action="<%=dispatcher.build_url('admin', 'services', 'guestauth', 'open')%>" style="display: inline-block; margin-right: 8px;">
		<input class="cbi-button cbi-button-action important" type="submit" value="Open Current Portal" />
	</form>
	<form method="post" action="<%=dispatcher.build_url('admin', 'services', 'guestauth', 'clear')%>" style="display: inline-block;">
		<input class="cbi-button cbi-button-reset" type="submit" value="Clear Proxy Cookies" />
	</form>
</div>

<div class="cbi-section">
	<h3>Recommended Flow</h3>
	<ol>
		<li>Save the default probe URL or paste a manual portal URL if you already captured one.</li>
		<li>Click <code>Detect Portal</code>.</li>
		<li>Click <code>Open Current Portal</code> and complete login inside the proxied page.</li>
	</ol>
</div>

<%+footer%>
EOF_VIEW

chmod 0644 "$CTRL_FILE" "$VIEW_FILE"
rm -rf /tmp/luci-*
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

echo "Installed luci GuestAuth."
echo "Open: LuCI -> Services -> GuestAuth"
