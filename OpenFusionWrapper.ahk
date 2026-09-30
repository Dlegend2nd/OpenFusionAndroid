#SingleInstance Force
SetWorkingDir A_ScriptDir

; ============================================================
; CONSTANTS
; ============================================================
WSA_VERSION := 0x0202
LOG_BUFFER_THRESHOLD := 65536
FULLSCREEN_RETRY_ATTEMPTS := 15
FULLSCREEN_RETRY_DELAY := 200
WSA_STARTUP_SUCCESS := 0
WSA_BUFFER_SIZE := 512
DEFAULT_SERVER_PORT := "23000"
HTTP_TIMEOUT := 30000

; ============================================================
; LOGGER CLASS
; ============================================================
class Logger {
    __logBuffer := ""
    debugLog := A_ScriptDir "\debug_log.txt"

    Log(msg, level := "INFO", flush := false) {
        this.__logBuffer .= FormatTime(, "yyyy-MM-dd HH:mm:ss") " [" level "] " msg "`n"
        if flush || StrLen(this.__logBuffer) > LOG_BUFFER_THRESHOLD
            this.Flush()
    }

    Flush() {
        if (this.__logBuffer != "") {
            FileAppend(this.__logBuffer, this.debugLog, "UTF-8")
            this.__logBuffer := ""
        }
    }

    Clear() {
        if FileExist(this.debugLog)
            FileDelete(this.debugLog)
    }
}

; ============================================================
; CONFIG MANAGER CLASS
; ============================================================
class ConfigManager {
    c := Map()
    logger := Logger()

    ResolvePath(p) {
        return (p != "" && !InStr(p, ":"))
            ? A_ScriptDir "\" p
            : p
    }

    ; Simple JSON loader adapted from cocobelgica's Jxon_Load (AHK v2)
    TryParseJson(text) {
        try {
            return this.Jxon_Load(&text)
        }
        catch as e {
            this.logger.Log("JSON parse failed: " e.Message, "WARN")
            return ""
        }
    }
	
	Fail(msg) {
		MsgBox msg
		ExitApp
	}
	
    ; Insert Jxon_Load implementation (adapted) to parse JSON without PowerShell
    Jxon_Load(&src, args*) {
        key := "", is_key := false
        stack := [ tree := [] ]
        next := '"{[01234567890-tfn'
        pos := 0

        while ( (ch := SubStr(src, ++pos, 1)) != "" ) {
            if InStr(" `t`n`r", ch)
                continue
            if !InStr(next, ch, true) {
                throw Error("Invalid JSON or unexpected character")
            }

            obj := stack[1]
            is_array := (obj is Array)

            if i := InStr("{[", ch) {
                val := (i = 1) ? Map() : Array()
                is_array ? obj.Push(val) : obj[key] := val
                stack.InsertAt(1,val)
                next := '"' ((is_key := (ch == "{")) ? "}" : "{[]0123456789-tfn")
				
            } else if InStr("}]", ch) {
                stack.RemoveAt(1)
                next := (stack[1]==tree) ? "" : (stack[1] is Array) ? ",]" : ",}"
				
            } else if InStr(",:", ch) {
                is_key := (!is_array && ch == ",")
                next := is_key ? '"' : '"{[0123456789-tfn'
				
            } else {
                if (ch == '"') {
                    start := pos + 1
                    i := pos

                    while i := InStr(src, '"',, i+1) {
                        bsCount := 0
                        j := i - 1
                        while (j >= 1 && SubStr(src, j, 1) = "\") {
                            bsCount++
                            j--
                        }

                        if (Mod(bsCount, 2) = 0)
                            break
                    }

                    if !i {
                        pos--, next := "'"
                        continue
                    }

                    ; ✅ Extract the actual string value FIRST
                    val := SubStr(src, start, i - start)

                    pos := i

                    ; ✅ Now replacements will apply to the correct string
                    ; ✅ FIX: handle escaped backslashes FIRST
                    val := StrReplace(val, "\\", "\")
                    val := StrReplace(val, "\/", "/")
                    val := StrReplace(val, '\\"', '"')
                    val := StrReplace(val, "\\b", "`b")
                    val := StrReplace(val, "\\f", "`f")
                    val := StrReplace(val, "\\n", "`n")
                    val := StrReplace(val, "\\r", "`r")
                    val := StrReplace(val, "\\t", "`t")

                    if is_key {
                        key := val
                        next := ":"
                        continue
                    }
                } else {
                    val := SubStr(src, pos, i := RegExMatch(src, "[\]\},\s]|$",, pos)-pos)
                    if IsInteger(val)
                        val += 0
                    else if IsFloat(val)
                        val += 0
                    else if (val == "true" || val == "false")
                        val := (val == "true")
                    else if (val == "null")
                        val := ""
                    else if is_key {
                        pos--, next := "#"
                        continue
                    }

                    pos += i-1
                }

                is_array ? obj.Push(val) : obj[key] := val
                next := obj == tree ? "" : is_array ? ",]" : ",}"
            }
        }

        return tree[1]
    }
	
    LoadConfig() {
        ; Prefer config.json (used by the C# UI). Fall back to legacy config.ini.
        jsonPath := A_ScriptDir "\config.json"
        if FileExist(jsonPath) {
            ; Read JSON file directly and parse with embedded JSON loader
            jsonText := FileRead(jsonPath)
            cfg := this.TryParseJson(jsonText)
            if !IsObject(cfg) {
                MsgBox "Failed to parse config.json"
                ExitApp
            }

            configs := cfg.Has("configs") ? cfg["configs"] : []
            if (configs is Array) {
                sel := -1
                for idx, item in configs {
                    if item.Has("default") && item["default"] {
                        sel := idx
                        break
                    }
                }
                if sel = -1
                    sel := 1

                try {
                    conf := configs[sel]

                    if !IsObject(conf) {
                        throw Error("Selected config is not an object")
                    }

                    keys := ["id","name","mode","server","cache_dir","address","endpoint","username","password","log_file","verbose","enable_fps_limit","fps_limit","image","default","client","stall_threshold"]

                    for _, k in keys {
                        if conf.Has(k) {
                            val := conf[k]

                            ; ✅ Proper null/empty check
                            if (val = "") {
                                continue
                            }

                            if (k = "server" || k = "cache_dir" || k = "log_file" || k = "client") {
                                this.c[k] := this.ResolvePath(val)
                            } else {
                                this.c[k] := val
                            }
                        }
                    }

                    ; ✅ Safe access helpers
                    serverPath := this.c.Has("server") ? this.c["server"] : ""
                    launcherPath := this.c.Has("client") ? this.c["client"] : ""

                    if (serverPath != "") {
                        SplitPath(serverPath, , &serverDir)
                        this.c["server_dir"] := serverDir
                    }

                    if (launcherPath != "") {
                        SplitPath(launcherPath, , &launcherDir)
                        this.c["client_dir"] := launcherDir
                    }

                    return

                } catch as e {
					this.Fail("Failed to load JSON config")
                }
            }
        }
		else{
			this.Fail("JSON config file not found")
		}
       
    }
}

; ============================================================
; GAME RUNTIME CLASS
; ============================================================
class GameRuntime {
    serverPid := 0
    clientPid := 0
    logger := Logger()
    config := ConfigManager()
    secureApisEnabled := true
    ws2Started := false
    clientLogLineCount := 0
    clientLogLastLine := ""
    clientLogStallStart := 0
    clientLogMonitoringActive := true
	
    Quote(x) => '"' x '"'

    AddArg(&args, flag, val) {
        if val
            args .= " " flag " " this.Quote(val)
    }

	CreateHttpRequest() {
		try {
			return ComObject("WinHttp.WinHttpRequest.5.1")
		} catch as e {
			this.config.Fail("Failed to create HTTP request object: " e.Message)
		}
	}
	
	Ok(res, code := "") {
		return res.success && (code = "" ? (res.status >= 200 && res.status < 300) : res.status = code)
	}
	
	RequestJson(method, url, body := "", token := "") {
		res := this.SendRequest(method, url, body, token)
		if !this.Ok(res) {
			this.logger.Log("RequestJson failed for " method " " url " (status: " res.status ")", "WARN")
			return ""
		}

		return this.config.TryParseJson(res.body)
	}
	
	RequireJson(data, msg) {
		if !IsObject(data)
			this.config.Fail(msg " (received: " (data ? data : "null") ")")
		return data
	}

	IsEmpty(val) {
		return val = "" || val = ""
	}
	
	BuildEnvironment() {
        c := this.config.c
        
        ; Only set UNITY_FF_FPS_CAP when enable_fps_limit is true and fps_limit is a non-zero integer (match GameLauncher.cs)
        if (c.Has("enable_fps_limit") && (c["enable_fps_limit"] = "true" || c["enable_fps_limit"] = 1)) {
            fps := c.Has("fps_limit") ? c["fps_limit"] : ""
            
            if !this.IsEmpty(fps) {
                ; Try to parse as integer
                try {
                    parsed := Integer(fps)
                } catch {
                    parsed := 0
                }
                
                if (parsed != 0) {
                    ; Explicitly evaluate as a string
                    EnvSet("UNITY_FF_FPS_CAP", c["fps_limit"])
                }
            }
        }
    }

    NormalizeEndpoint(endpoint) {
        endpoint := Trim(endpoint)
        if (endpoint == "")
            return ""

        if !RegExMatch(endpoint, "i)^(https?://)")
            endpoint := "http://" endpoint

        return RegExReplace(endpoint, "/+$", "")
    }

    BuildApiUrl(endpoint, path) {
        base := RegExReplace(this.NormalizeEndpoint(endpoint), "i)^(https?://)", "")
        base := RegExReplace(base, "/+$", "")
        scheme := (this.secureApisEnabled = false) ? "http" : "https"
        p := RegExReplace(path, "^/+", "")
        return scheme "://" base "/" p
    }

    NormalizeSlash(path, add := false) => RegExReplace(path ?? "", "/+$", "") (add ? "/" : "")

    SendRequest(method, url, body := "", token := "") {
        try {
            req := this.CreateHttpRequest()
            req.Open(method, url, false)
            req.SetRequestHeader("User-Agent", "fffrontend/1.0")
            req.SetRequestHeader("Accept", "application/json")
			
            if !this.IsEmpty(token)
                req.SetRequestHeader("Authorization", "Bearer " token)
			
            if !this.IsEmpty(body)
                req.SetRequestHeader("Content-Type", "application/json")
			
            req.Send(body)
		
            return {success: true, status: req.Status, body: req.ResponseText}
        }
        catch as e {
            this.logger.Log("SendRequest " method " " url ": " e.Message, "ERROR", true)
            return {success: false, status: -1, body: ""}
        }
    }
	
	TryHttpsFirst(baseUrl) {
		httpsUrl := "https://" baseUrl
		httpUrl := "http://" baseUrl
		
		res := this.SendRequest("GET", httpsUrl)
		if this.Ok(res) {
			this.secureApisEnabled := true
			return res
		}
		
		res := this.SendRequest("GET", httpUrl)
		if this.Ok(res) {
			this.secureApisEnabled := false
			return res
		}
		
		return res
	}
	
	FetchEndpointInfo(endpoint) {
        base := this.NormalizeEndpoint(endpoint)
        if this.IsEmpty(base)
            this.config.Fail("Endpoint cannot be empty")

        ; Try HTTPS first, fall back to HTTP (match EndpointClient behavior)
        baseUrl := RegExReplace(base, "i)^https?://", "") "/"
        res := this.TryHttpsFirst(baseUrl)

        ok := res.success
		status := IsObject(res) && res.HasOwnProp("status") ? res.status : -1 
		
		if (!ok || status < 200 || status >= 300)
            this.config.Fail("Failed to fetch endpoint info from " endpoint " (status: " status ")")

        info := this.config.TryParseJson(res.body)

        if !IsObject(info)
            this.config.Fail("Endpoint " endpoint " returned invalid JSON")

        ; Respect server-declared secure_apis_enabled when present
        if (info.Has("secure_apis_enabled"))
            this.secureApisEnabled := info["secure_apis_enabled"]

        return info
    }

    GetSupportedVersions(info) {
        versions := []

        if info.Has("game_versions") {
            gv := info["game_versions"] 

            if IsObject(gv) {
                for _, version in gv
                    if version
                        versions.Push(version)
            }
        }

        if (versions.Length = 0 && info.Has("game_version") && info["game_version"] != "")
            versions.Push(info["game_version"])

        return versions
    }

    FetchVersion(versionUuid, endpoint) {

	    versionData := this.TryFetchVersion(versionUuid, endpoint)
	
	    if !versionData
	        versionData := this.TryFetchVersion(versionUuid ".json", endpoint)
	
	    if !IsObject(versionData)
	        throw Error("Failed to fetch version " versionUuid)
	
	    if (!versionData.Has("uuid"))
	        throw Error("Version response missing uuid.")
	
	    if (StrLower(versionData["uuid"]) != StrLower(versionUuid))
	        throw Error(
	            "Version mismatch: "
	            versionData["uuid"]
	            " != "
	            versionUuid)
	
	    return versionData
	}

    TryFetchVersion(filename, endpoint) {
        url := this.BuildApiUrl(endpoint, "versions/" filename)
        res := this.SendRequest("GET", url)
		
        if this.Ok(res) {
            versionData := this.config.TryParseJson(res.body)
            if IsObject(versionData)
                return versionData
        }

        ; Try with swapped protocol on failure
        this.secureApisEnabled := !this.secureApisEnabled
        url := this.BuildApiUrl(endpoint, "versions/" filename)
        res := this.SendRequest("GET", url)
        
        if this.Ok(res) {
            versionData := this.config.TryParseJson(res.body)
            if IsObject(versionData)
                return versionData
        }
        
        this.logger.Log("Failed to fetch version " filename " from " endpoint, "WARN")
        return ""
    }

    WsaStartup() {
        if (this.ws2Started)
            return true

        wsadata := Buffer(WSA_BUFFER_SIZE)
        ret := DllCall("Ws2_32.dll\WSAStartup", "UShort", WSA_VERSION, "ptr", wsadata)
        if (ret = WSA_STARTUP_SUCCESS) {
            this.ws2Started := true
            return true
        }
        this.logger.Log("WSAStartup failed with code " ret, "ERROR")
        return false
    }

    WsaCleanup() {
        if (this.ws2Started) {
            DllCall("Ws2_32.dll\WSACleanup")
            this.ws2Started := false
        }
    }

    ResolveHostnameToIPv4(host) {
        if !this.WsaStartup()
            return ""

        size := (A_PtrSize = 8) ? 56 : 28
        hints := Buffer(size)
        NumPut(2, hints, 4, "Int") ; AF_INET

        res := 0
        ret := DllCall("Ws2_32.dll\getaddrinfo", "WStr", host, "WStr", "0", "ptr", hints, "ptr*", res)
        if (ret != 0) {
            this.logger.Log("getaddrinfo failed for " host " with code " ret, "WARN")
            this.WsaCleanup()
            return ""
        }

        ip := ""
        ai_addr_offset := (A_PtrSize = 8) ? 24 : 20
        ai_next_offset := (A_PtrSize = 8) ? 40 : 28

        try {
            ptr := res
            while (ptr) {
                family := NumGet(ptr, 4, "Int")
                if (family = 2) {
                    addrPtr := NumGet(ptr, ai_addr_offset, "Ptr")
                    if (addrPtr) {
                        ip := NumGet(addrPtr, 4, "UChar") "." NumGet(addrPtr, 5, "UChar") "." NumGet(addrPtr, 6, "UChar") "." NumGet(addrPtr, 7, "UChar")
                        break
                    }
                }
                ptr := NumGet(ptr, ai_next_offset, "Ptr")
            }
        }
        finally {
            if (res)
                DllCall("Ws2_32.dll\freeaddrinfo", "ptr", res)
            this.WsaCleanup()
        }

        return ip
    }

    ResolveServerAddress(address) {
        address := Trim(address)
        if this.IsEmpty(address)
            return ""

        m := []
        if RegExMatch(address, "i)^(https?://)?([^/:]+)(?::(\d+))?(?:/.*)?$", &m) {
            host := m.2
            port := !this.IsEmpty(m.3) ? m.3 : DEFAULT_SERVER_PORT
            if (this.IsIPv4Address(host))
                return host ":" port

            ip := RegExMatch(host, "^(?:\d{1,3}\.){3}\d{1,3}$")
            return (ip != "" ? ip : host) ":" port
        }

        return address
    }
	
    AuthRefreshToken(username, password, endpoint) {
        url := this.BuildApiUrl(endpoint, "auth")
        body := Format('{"password":"{}", "username":"{}"}', password, username)
        res := this.SendRequest("POST", url, body)
		
        if !this.Ok(res, 200)
            this.config.Fail("Failed to retrieve refresh token from " endpoint " (status: " res.status ")")

        token := Trim(res.body)
		
        if this.IsEmpty(token)
			this.config.Fail("Endpoint " endpoint " returned empty refresh token")
		
        return token
    }

	Authenticate(c, endpoint) {
		try {
			token := this.AuthRefreshToken(c["username"], c["password"], endpoint)

			session := this.RequireJson(
				this.RequestJson("POST", this.BuildApiUrl(endpoint, "auth/session"), "", token),
				"Invalid session JSON from endpoint " endpoint
			)

			cookie := this.RequireJson(
				this.RequestJson("POST", this.BuildApiUrl(endpoint, "cookie"), "", session["session_token"]),
				"Invalid cookie JSON from endpoint " endpoint
			)

			if (!cookie.Has("cookie") || !cookie.Has("username"))
				throw Error("Cookie response missing 'cookie' or 'username' field")

			c["username"] := cookie["username"]
			c["token"] := cookie["cookie"]
		} catch as e {
			this.config.Fail("Authentication failed: " e.Message)
		}
	}

	ValidateConfigKeys(c, keys) {
		for _, key in keys {
			if !c.Has(key)
				this.config.Fail("Missing required config key: " key)
		}
	}
	
	BuildClientArgs() {
        c := this.config.c
        requiredKeys := ["address", "mode", "client"]
        this.ValidateConfigKeys(c, requiredKeys)
        
        endpoint := ""
        info := ""
        cache := ""
        address := c["address"]
        customLoadingScreen := false

        if (c["mode"] == "online" && !this.IsEmpty(c.Has("endpoint") ? c["endpoint"] : "")) {
            endpoint := this.NormalizeEndpoint(c["endpoint"])
            info := this.FetchEndpointInfo(endpoint)
            supportedVersions := this.GetSupportedVersions(info)
            
            if (supportedVersions.Length == 0)
                MsgBox "Endpoint returned no supported versions"

            version := info.Has("game_version") ? info.game_version : ""
            if (!version)
                for _, candidate in supportedVersions {
                    version := candidate
                    break
                }

            if (!version)
                MsgBox "Unable to resolve a game version from endpoint"

            versionInfo := this.FetchVersion(version, endpoint)
            assetBase := versionInfo.Has("url") ? versionInfo["url"] : (versionInfo.Has("asset_url") ? versionInfo["asset_url"] : "")

            if (assetBase != "") {
                if RegExMatch(assetBase, "i)^[a-z][a-z0-9+.-]*://")
                    cache := this.NormalizeSlash(assetBase, true)
                else
                    cache := "file:///" StrReplace(this.NormalizeSlash(assetBase, true), "\\", "/")
            }

            address := this.ResolveServerAddress(info.Has("login_address") ? info["login_address"] : endpoint)
            customLoadingScreen := info.Has("custom_loading_screen") ? info["custom_loading_screen"] : false

            if !this.IsEmpty(c.Has("password") ? c["password"] : "")
				this.Authenticate(c, endpoint)
        }

        if this.IsEmpty(cache) && c.Has("cache_dir") && !this.IsEmpty(c["cache_dir"])
            cache := "file:///" StrReplace(c["cache_dir"], "\", "/") "/"

        if this.IsEmpty(cache)
            this.config.Fail("Could not determine cache directory from config or endpoint")

        args := ""
		normalizedCache := this.NormalizeSlash(cache, true)
		
        args .= ' -m ' this.Quote(normalizedCache "main.unity3d")
        args .= ' --asseturl ' this.Quote(normalizedCache)
        args .= ' -a ' this.Quote(address)

        if (endpoint != "")
            args .= ' -e ' this.Quote(endpoint)

        this.AddArg(&args, "-u", c.Has("username") ? c["username"] : "")
        ; Prefer token if obtained from endpoint auth, otherwise send the configured password
        tokenVal := (c.Has("token") && !this.IsEmpty(c["token"])) ? c["token"] : (c.Has("password") ? c["password"] : "")
        this.AddArg(&args, "-t", tokenVal)
        this.AddArg(&args, "-l", c.Has("log_file") ? c["log_file"] : "")

        if (customLoadingScreen == true)
            args .= " --loader-images"

        ; Always include width/height (matches GameLauncher.cs)
        this.AddArg(&args, "--width", A_ScreenWidth)
        this.AddArg(&args, "--height", A_ScreenHeight)
        
        if (c.Has("verbose") && c["verbose"] == "true")
            args .= " -v"

        return args
    }

    SpawnClient() {
		c := this.config.c
		args := this.BuildClientArgs()
		cPid := 0
		this.clientLogMonitoringActive := true
		this.BuildEnvironment()

		if !FileExist(c["client"])
			this.config.Fail("Client executable not found: " c["client"])

		Run(c["client"] " " args, c["client_dir"], , &cPid)
		
		if (cPid == 0) {
			this.logger.Log("Client spawn failed. Exe: " c["client"], "ERROR", true)
			this.config.Fail("Failed to spawn client: " c["client"]) 
		}
		
		this.clientPid := cPid
	}

    RestartClient() {
        if (this.clientPid && ProcessExist(this.clientPid)) {
            try {
                ProcessClose(this.clientPid)
            } catch as e {
                this.logger.Log("Failed to close stalled client: " e.Message, "WARN")
            }
        }

        this.clientPid := 0
        this.SpawnClient()
        this.ApplyFullscreen()
    }

    CheckClientLogHealth() {
        if (!this.clientPid || !ProcessExist(this.clientPid) || !this.clientLogMonitoringActive)
            return false

        c := this.config.c
        logPath := c.Has("log_file") ? c["log_file"] : ""
        if (this.IsEmpty(logPath))
            logPath := A_ScriptDir "\ffrunner.txt"

        if (!FileExist(logPath))
            return false

        try {
            fileContent := FileRead(logPath, "UTF-8")
        } catch as e {
            this.logger.Log("Unable to read client log file " logPath ": " e.Message, "WARN")
            return false
        }

        lineCount := 0
        lineText := ""
        if (fileContent != "") {
            lines := StrSplit(fileContent, "`n")
            lineCount := lines.Length
            if (lineCount > 0)
                lineText := Trim(lines[lineCount])
        }

        ; Retrieve the delay threshold from config.json (defaults to 2700ms if not specified)
        stallThreshold := c.Has("stall_threshold") ? c["stall_threshold"] : 2700

        if (lineCount >= 111 && lineCount <= 112 && lineCount = this.clientLogLineCount && lineText = this.clientLogLastLine) {
            if (this.clientLogStallStart = 0)
                this.clientLogStallStart := A_TickCount
            else if (A_TickCount - this.clientLogStallStart >= stallThreshold) {
                this.RestartClient()
                this.clientLogLineCount := 0
                this.clientLogLastLine := ""
                this.clientLogStallStart := 0
                return true
            }
        } else {
            this.clientLogLineCount := lineCount
            this.clientLogLastLine := lineText
            this.clientLogStallStart := 0
        }

        return false
    }

    StartServer() {
        c := this.config.c
        sPid := 0
        
		if !c.Has("server")
			this.config.Fail("Server path not configured")
		
		if !FileExist(c["server"])
			this.config.Fail("Server executable not found: " c["server"])
        
		Run(c["server"], c["server_dir"], "Hide", &sPid)

        if (sPid == 0) {
            this.logger.Log("Server spawn failed. Exe: " c["server"], "ERROR", true)
            this.config.Fail("Failed to start server: " c["server"])
        }
            
        this.serverPid := sPid
    }

	ApplyFullscreen() {
        ; Set DPI awareness so dimensions match physical display pixels
        DllCall("SetThreadDpiAwarenessContext", "ptr", -4)

        Loop FULLSCREEN_RETRY_ATTEMPTS {
            hwnd := WinExist("ahk_pid " this.clientPid)
            if hwnd {
                GWL_STYLE   := -16
                GWL_EXSTYLE := -20

                ; Remove caption, resizable frames, minimize/maximize buttons, and borders
                removeMask := 0xC00000 | 0x00040000 | 0x20000000 | 0x01000000 | 0x00080000 | 0x00800000 ; WS_BORDER
                removeExMask := 0x00000200 | 0x00000100 | 0x00000001 ; WS_EX_CLIENTEDGE | WS_EX_WINDOWEDGE | WS_EX_DLGMODALFRAME

                if (A_PtrSize = 8) {
                    style := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", GWL_STYLE, "ptr")
                    newStyle := (style & ~removeMask) | 0x80000000 ; WS_POPUP
                    DllCall("SetWindowLongPtr", "ptr", hwnd, "int", GWL_STYLE, "ptr", newStyle)

                    exStyle := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", GWL_EXSTYLE, "ptr")
                    newExStyle := exStyle & ~removeExMask
                    DllCall("SetWindowLongPtr", "ptr", hwnd, "int", GWL_EXSTYLE, "ptr", newExStyle)
                } else {
                    style := DllCall("GetWindowLong", "ptr", hwnd, "int", GWL_STYLE, "int")
                    newStyle := (style & ~removeMask) | 0x80000000 ; WS_POPUP
                    DllCall("SetWindowLong", "ptr", hwnd, "int", GWL_STYLE, "int", newStyle)

                    exStyle := DllCall("GetWindowLong", "ptr", hwnd, "int", GWL_EXSTYLE, "int")
                    newExStyle := exStyle & ~removeExMask
                    DllCall("SetWindowLong", "ptr", hwnd, "int", GWL_EXSTYLE, "int", newExStyle)
                }

                ; Get primary monitor exact physical pixel bounds
                MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
                width  := right - left
                height := bottom - top

                HWND_TOPMOST     := -1
                SWP_FRAMECHANGED := 0x0020
                SWP_SHOWWINDOW   := 0x0040
                flags := SWP_FRAMECHANGED | SWP_SHOWWINDOW
                DllCall("SetWindowPos", "ptr", hwnd, "ptr", HWND_TOPMOST, "int", left, "int", top, "int", width, "int", height, "uint", flags)

                ; Force Unity engine to resize its internal viewport backbuffer
                WM_SIZE := 0x0005
                lParam := (height << 16) | (width & 0xFFFF)
                PostMessage(WM_SIZE, 0, lParam, hwnd)

                return
            }
            Sleep(FULLSCREEN_RETRY_DELAY)
        }

        this.logger.Log("Failed to apply fullscreen after " FULLSCREEN_RETRY_ATTEMPTS " attempts", "WARN")
    }

    WaitClient() {
        while (this.clientPid && ProcessExist(this.clientPid)) {
            if (this.CheckClientLogHealth())
                continue
            Sleep(1000)
        }
        
        if this.serverPid {
            if ProcessExist(this.serverPid)
                ProcessClose(this.serverPid)
        }
        
        ExitApp
    }

    Run() {
        this.logger.Clear()
        this.config.LoadConfig()
        
        if (this.config.c["mode"] == "offline")
            this.StartServer()
            
        this.SpawnClient()

        this.ApplyFullscreen()
            
        this.WaitClient()
    }
}

; ============================================================
; ENTRYPOINT
; ============================================================
GameRuntime().Run()
