-- SwiftFever in-game overlay customization (Ultra-Compact HUD + Midnight Cobalt palette, toast-free chat).
-- Kept isolated from mpfever_ui.script.lua so upstream MPFever updates remain easy to rebase.
-- MPFEVER_SWIFTUI=0 disables all SwiftFever overrides (falls back to vanilla MPFever UI).
-- MPFEVER_CHATTOAST=1 re-enables the floating top-left chat toast window.

local SF = {}

SF.BRAND = "SwiftFever"
SF.SUBTITLE = "Performance-optimized MPFever"
SF.CREDIT = "by Dan1el-19 based on dkdknight"

SF.enabled = function()
	return os.getenv("MPFEVER_SWIFTUI") ~= "0"
end

-- Midnight Cobalt Neo-Minimalist Bento palette (matches launcher/Ui.cs & launcher/ForkBrand.cs)
SF.PALETTE = {
	Ok = { 0.290, 0.871, 0.502, 1 },
	Warning = { 0.984, 0.749, 0.141, 1 },
	Error = { 0.973, 0.443, 0.443, 1 },
	Info = { 0.376, 0.647, 0.980, 1 },
	Positive = { 0.376, 0.647, 0.980, 1 },
	Negative = { 0.973, 0.443, 0.443, 1 },
	Orange = { 0.984, 0.573, 0.235, 1 },

	NeutralMedium = { 0.353, 0.400, 0.490, 1 },
	NeutralLight = { 0.557, 0.608, 0.698, 1 },
	NeutralLightest = { 0.925, 0.941, 0.969, 1 },

	BaseVeryDark = { 0.039, 0.051, 0.078, 1 },
	BaseDark = { 0.051, 0.067, 0.102, 1 },
	BaseDarkMedium = { 0.067, 0.086, 0.133, 1 },
	BaseMedium = { 0.075, 0.098, 0.149, 1 },
	BaseLightMedium = { 0.094, 0.125, 0.188, 1 },
	BaseLight = { 0.106, 0.137, 0.208, 1 },
	BaseVeryLight = { 0.110, 0.137, 0.200, 1 },

	AccentVeryDark = { 0.086, 0.137, 0.231, 1 },
	AccentDark = { 0.118, 0.227, 0.431, 1 },
	AccentMedium = { 0.145, 0.388, 0.922, 1 },
	AccentLight = { 0.231, 0.510, 0.965, 1 },
	AccentVeryLight = { 0.376, 0.647, 0.980, 1 },

	PillBg = { 0.086, 0.114, 0.173, 1 },
	WindowBg = { 0.051, 0.067, 0.102, 0.94 },
}

local CLS_COLOR = {
	success = "Ok",
	warning = "Warning",
	error = "Error",
	info = "Info",
	negative = "Negative",
	positive = "Positive",
}

local function cloneRgba(raw, alpha)
	return { raw[1], raw[2], raw[3], alpha or raw[4] or 1 }
end

local function makeVec4f(raw, alpha)
	if not (api and api.type and api.type.Vec4f and api.type.Vec4f.new) then return nil end
	local ok, v = pcall(api.type.Vec4f.new, raw[1], raw[2], raw[3], alpha or raw[4] or 1)
	return ok and v or nil
end

local function hBox(K, children, w)
	return K.box(children, { size = { math.max(16, math.floor(w)), -1 } }, K.H)
end

local function vDot(K, kindOrColor, size, topPad, isColorName)
	local dot = isColorName and K.disc(kindOrColor, size) or K.dot(kindOrColor, size)
	return K.col { K.gap(1, topPad or 3), dot }
end

local function clsColorName(cls)
	return CLS_COLOR[cls or ""] or "NeutralLightest"
end

function SF.applyKit(U, C)
	if not SF.enabled() or not U or not U.kit or U.kit.__sfApplied then return end
	local K = U.kit
	K.__sfApplied = true
	U.brandName = SF.BRAND

	-- Ultra-Compact Quick View measures (416px HUD; scrolled tabs use 400px inner width)
	K.WIN_W, K.BODY_H, K.INNER_W, K.TEXT_W = 416, 290, 400, 396
	K.CARD_W, K.CARD_TEXT_W = 400, 376

	local origRgba = K.rgba
	local origColor = K.color
	local vecCache = {}

	K.rgba = function(name, alpha)
		local raw = SF.PALETTE[name]
		if raw then return cloneRgba(raw, alpha) end
		return origRgba and origRgba(name, alpha) or nil
	end

	K.color = function(name, alpha)
		local raw = SF.PALETTE[name]
		if raw then
			local key = tostring(name) .. "/" .. tostring(alpha)
			if vecCache[key] ~= nil then return vecCache[key] or nil end
			local v = makeVec4f(raw, alpha)
			vecCache[key] = v or false
			return v
		end
		return origColor and origColor(name, alpha) or nil
	end

	if type(K.PANELS) == "table" then
		K.PANELS.card = { "BaseMedium", nil, "BaseVeryLight" }
		K.PANELS.inner = { "BaseDark", nil, "BaseVeryLight" }
		K.PANELS.mine = { "AccentVeryDark", nil, "AccentLight" }
		K.PANELS.elevated = { "BaseLightMedium", nil, "AccentLight", 0.26 }
		K.PANELS.sunken = { "BaseDark", nil, "BaseVeryLight", 0.70 }
	end

	-- 9-patch card helper usable in both Quick View and Hub
	K.sfCard = function(kind, children, width, pad)
		local st = K.panel(kind or "card", { size = { width or K.CARD_W, -1 }, padding = pad or { 8, 12, 8, 12 } })
		return K.box(children, st, K.V)
	end

	-- Window container padding + translucent Midnight Cobalt backdrop (#0D111A @ 94%)
	K.padded = function(content)
		if os.getenv("MPFEVER_WINPAD") == "0" or content == nil then return content end
		K.sfPadStyle = K.sfPadStyle or K.style { padding = { 8, 10, 10, 10 }, background = SF.PALETTE.WindowBg }
		return K.builtin.Component { meta = { styleSheet = K.sfPadStyle }, layout = K.col { content } }
	end

	-- Bottom HUD bar branding (SwiftFever pill)
	if U.barInfo then
		local origBarInfo = U.barInfo
		U.barInfo = function()
			local state, tip = origBarInfo()
			if type(tip) == "string" then tip = tip:gsub("^MPFever", SF.BRAND) end
			return state, tip
		end
	end

	if U.barNode then
		U.barNode = function()
			if os.getenv("MPFEVER_BARFAIL") == "1" then error("MPFEVER_BARFAIL=1 (test)") end
			local builtin = K.builtin
			local state, tip = U.barInfo()
			local unread = U.chatUnread or 0
			local inner = builtin.BoxLayout { orientation = K.H, children = {
				builtin.BoxLayout { orientation = K.V, children = { K.gap(1, 7), K.disc((U.BAR_COLOR or {})[state] or "NeutralLight", 13) } },
				K.gap(6, 1),
				builtin.TextView { meta = { class = "font-scale-headline" }, text = SF.BRAND .. (unread > 0 and ("  (" .. unread .. ")") or "") },
			} }
			local item
			if os.getenv("MPFEVER_BARBUTTON") == "1" then
				item = builtin.Button {
					meta = { class = "secondary", tooltip = tip, styleSheet = K.style { padding = { 0, 6, 0, 6 } } },
					content = builtin.Component { layout = inner },
					onClick = function() U.barClick = true end,
				}
			else
				K.sfBarPillStyle = K.sfBarPillStyle or K.style { padding = { 0, 6, 0, 6 }, background = SF.PALETTE.PillBg }
				item = builtin.Component { meta = { tooltip = tip, styleSheet = K.sfBarPillStyle }, layout = inner }
			end
			return builtin.BoxLayout { orientation = K.H, children = { item, K.gap(16, 1) } }
		end
	end

	-- Pause menu card background in Midnight Cobalt
	U.pauseBg = function(hover)
		return K.color(hover and "BaseLightMedium" or "BaseMedium", 0.94)
	end
end

local function countActivePlayers(st)
	local n = 0
	for _, pl in ipairs(st and st.players or {}) do
		if pl.state ~= "left" and pl.role ~= "server" then n = n + 1 end
	end
	return n
end

local function hostSummary(st, sfT, Tf)
	if not (st and st.host) then return SF.BRAND end
	local name = (st.server == "1" and st.title and st.title ~= "") and st.title or st.host
	local mode = st.mode == "separate" and sfT("Entreprises", "Companies") or sfT("Coop", "Co-op")
	return Tf("Hôte : %s", "Host: %s", name) .. "  ·  " .. mode
end

local function shortSyncLine(st, T, sfT, sfTf)
	local sync = st and st.sync or "none"
	local parts = (st and st.parts and st.parts ~= "") and (" (" .. st.parts .. ")") or ""
	if sync == "ok" then
		local age = tonumber(st.age) or -1
		return T("Synchrone", "In sync") .. (age >= 0 and (" · " .. sfTf("%s s", "%s s ago", age)) or ""), "success"
	elseif sync == "drift" then
		return sfT("Dérive", "Drift") .. parts, "warning"
	elseif sync == "desync" then
		return T("Désynchro", "Out of sync") .. parts, "error"
	elseif sync == "resync" then
		return sfT("Resynchro…", "Resync…"), "info"
	end
	return sfT("Non vérifiée", "Not checked"), nil
end

local function compactPlayerName(pl, me, T, sfT, sfTf)
	local text = pl.name or "?"
	local tags = {}
	if pl.id == me then tags[#tags + 1] = sfT("vous", "you") end
	if pl.role == "host" then tags[#tags + 1] = T("hôte", "host") end
	if #tags > 0 then text = text .. " (" .. table.concat(tags, " · ") .. ")" end
	local st = pl.state or "ok"
	if st == "loading" or st == "joining" then
		if pl.pct then return text .. " · " .. sfTf("%s%%", "%s%%", pl.pct), "info" end
		return text .. " · " .. sfT("charge…", "loading…"), "info"
	elseif st == "away" then
		return text .. " · " .. sfTf("absent %s s", "away %s s", pl.lag or 0), "warning"
	elseif st == "noresp" then
		return text .. " · " .. sfT("ne répond pas", "no response"), "error"
	elseif st == "left" then
		return text .. " · " .. sfT("a quitté", "left"), "negative"
	end
	return text, nil
end

local function playerPaceText(U, pl)
	if pl.state == "left" then return "—", "NeutralLight" end
	local pColor = "NeutralLight"
	if U.perfSign then
		local c = U.perfSign(pl)
		if type(c) == "string" and c ~= "" then pColor = c end
	end
	if pl.fps and pl.pace then
		return tostring(pl.fps) .. " · " .. tostring(pl.pace) .. "%", pColor
	elseif pl.fps then
		return tostring(pl.fps) .. " FPS", pColor
	elseif pl.pace then
		return tostring(pl.pace) .. "%", pColor
	end
	return "—", "NeutralLight"
end

local function sessionNeedsScroll(st)
	if st and (st.pending or "") ~= "" then return true end
	local n = 0
	for _, pl in ipairs(st and st.players or {}) do
		if pl.role ~= "server" then n = n + 1 end
	end
	return n > 6
end

function SF.applySession(U, C, deps)
	if not SF.enabled() or not U or U.__sfSessionApplied then return end
	U.__sfSessionApplied = true
	SF.applyKit(U, C)

	local T = deps.T
	local Tf = C.Tf
	-- Local wrappers for fork-specific UI strings so test_lang.py stays green without altering upstream lang.json
	local function sfT(fr, en) return T(fr, en) end
	local function sfTf(fr, en, ...) return Tf(fr, en, ...) end
	local log = deps.log or function() end
	local syncLine = deps.syncLine
	local linkLine = deps.linkLine
	local playerCount = deps.playerCount or countActivePlayers
	local requestInvite = deps.requestInvite
	local requestReport = deps.requestReport
	local sendLine = deps.sendLine
	local myChatName = deps.myChatName
	local sendChat = deps.sendChat

	-- Titles (SwiftFever branding)
	U.winTitle = function(compact)
		return compact and SF.BRAND or (SF.BRAND .. " – " .. T("Multijoueur", "Multiplayer"))
	end

	U.hubTitle = function(st)
		if U.oldHub then return SF.BRAND .. " Hub" end
		local ok, label = pcall(function() return U.hubLabel(U.hubValid(U.hubPage, st)) end)
		if not (ok and type(label) == "string" and label ~= "") then return SF.BRAND .. " Hub" end
		return SF.BRAND .. " – " .. label
	end

	-- Disable floating ChatToast window; keep synthetic/system notices in the Chat tab
	if U.onChatNews then
		local origOnChatNews = U.onChatNews
		U.onChatNews = function(news)
			if os.getenv("MPFEVER_CHATTOAST") == "1" then
				return origOnChatNews(news)
			end
			if type(news) ~= "table" or #news == 0 then return end
			local added = 0
			U.chat = U.chat or {}
			for _, m in ipairs(news) do
				-- pollChat sets numeric id; synthetic notices (winProps, buyRefused) have id == nil
				if m and m.id == nil and m.text then
					local author = (m.name == "MPFever") and SF.BRAND or (m.name or SF.BRAND)
					U.chat[#U.chat + 1] = { id = 0, t = os.time(), kind = m.kind or "msg", name = author, text = m.text }
					added = added + 1
				end
			end
			if added > 0 then
				while #U.chat > 100 do table.remove(U.chat, 1) end
				U.chatVersion = (U.chatVersion or 0) + 1
				if not U.chatOpen then U.chatUnread = (U.chatUnread or 0) + added end
				if U.winChanged then pcall(U.winChanged) end
			end
		end
	end

	-- Sleek segmented tab strip for Quick View (replaces chunky native TabWidget)
	local origTabStrip = U.tabStrip
	U.tabStrip = function(K, tabs, cur)
		if K.hub() or U.hubDrawing or os.getenv("MPFEVER_WINTABS") == "native" then
			return origTabStrip(K, tabs, cur)
		end
		local builtin = K.builtin
		local TBG = nil
		pcall(function() TBG = builtin.ToggleButtonGroup end)
		local out = {}
		if TBG and #tabs >= 1 then
			local perRow = 4
			local first = 1
			while first <= #tabs do
				local last = math.min(#tabs, first + perRow - 1)
				local at = first
				local buttons = {}
				local sel = -1
				for j = first, last do
					local id = tabs[j]
					if id == cur then sel = j - first + 1 end
					buttons[#buttons + 1] = { content = K.text(U.tabLabel(id)), meta = {} }
				end
				if #out > 0 then out[#out + 1] = K.gap(1, 4) end
				out[#out + 1] = TBG {
					meta = { localKey = "mpfever-sf-tabs-" .. tostring(#tabs) .. "-" .. at .. "-" .. #buttons },
					buttons = buttons,
					selected = sel,
					deselectAllowed = false,
					onValueChange = function(index)
						index = tonumber(index)
						local picked = index and tabs[at + index - 1] or nil
						if picked and picked ~= U.tab then U.setTab(picked) end
					end,
				}
				first = last + 1
			end
		else
			local r = {}
			for i, id in ipairs(tabs) do
				if i > 1 then r[#r + 1] = K.gap(4, 1) end
				r[#r + 1] = K.btn(U.tabLabel(id), nil, function() U.setTab(id) end, id == cur)
			end
			out[#out + 1] = K.row(r)
		end
		out[#out + 1] = K.gap(1, 5)
		out[#out + 1] = K.rect(K.WIN_W, 1, SF.PALETTE.BaseVeryLight)
		return K.col(out)
	end

	-- Ultra-Compact 240px Card
	U.compactContent = function(K, st)
		local CW = 216
		local sText, sCls = shortSyncLine(st, T, sfT, sfTf)
		local fullTip = select(1, syncLine(st))
		local link, linkCls = linkLine(st)
		local cardRows = {}
		if link then
			cardRows[#cardRows + 1] = K.row { vDot(K, linkCls, 9, 4), K.gap(6, 1), K.colored(link, K.color(clsColorName(linkCls)), CW - 16) }
		end
		cardRows[#cardRows + 1] = K.row { vDot(K, sCls, 10, 3), K.gap(6, 1), K.colored(sText, K.color(clsColorName(sCls)), CW - 18) }
		local spd = tonumber(st and st.speed)
		local spdStr = (st and st.started == "1" and spd ~= nil) and ("  ·  " .. (spd == 0 and "II" or ("x" .. spd))) or ""
		cardRows[#cardRows + 1] = K.muted(T("Joueurs", "Players") .. " (" .. playerCount(st) .. ")" .. spdStr, CW)
		local unread = U.chatUnread or 0
		local chatLabel = T("Chat", "Chat") .. (unread > 0 and (" (" .. unread .. ")") or "")
		local btns = {
			K.btn(chatLabel, T("Discussion", "Chat"), function() U.compact = false; U.setTab("chat") end, unread > 0),
			K.gap(4, 1),
			K.btn(T("Agrandir", "Expand"), nil, function() U.setCompact(false) end),
		}
		if U.HubWindow and U.hubOn() then
			btns[#btns + 1] = K.gap(4, 1)
			btns[#btns + 1] = K.btn("Hub", fullTip, function() U.openHub() end)
		end
		return K.builtin.Component {
			meta = { styleSheet = K.style { size = { 240, -1 } } },
			layout = K.col { K.sfCard("elevated", cardRows, 236, { 7, 10, 7, 10 }), K.gap(1, 6), K.row(btns) },
		}
	end

	-- Ultra-Compact Quick View Header + Body (416px)
	U.windowContent = function(K, st, chat, ctx)
		local builtin = K.builtin
		if U.compact then return U.compactContent(K, st) end
		local tabs = U.winTabs(st)
		local tab = U.validTab(U.tab, st)
		local rows, result = nil, "ok"
		local okB, res = pcall(function()
			if tab == "chat" then return U.chatBody(K, st, chat, ctx) end
			if not U.TABS[tab] and tab:sub(1, 2) == "f_" then return U.featTabRows(K, st, tab) end
			return U.TABS[tab](K, st, ctx)
		end)
		if okB and type(res) == "table" then
			rows = res
		else
			result = tostring(res)
			if U.tabFailed ~= tab .. result then U.tabFailed = tab .. result; log("window: the " .. tab .. " tab failed: " .. result) end
			rows = { K.text(T("Cet onglet n'a pas pu être affiché (voir ui_mod.log).", "This tab could not be drawn (see ui_mod.log)."), nil, "error", K.TEXT_W) }
		end
		if not U.tabReqHub then U.ackTabReq(tab, result, #rows) end

		local body
		if tab == "chat" then
			body = builtin.Component { meta = { localKey = "mpfever-body-chat", styleSheet = K.style { size = { K.WIN_W, K.BODY_H } } }, layout = K.col(rows) }
		elseif tab == "session" and not sessionNeedsScroll(st) then
			body = builtin.Component { meta = { localKey = "mpfever-body-session", styleSheet = K.style { size = { K.WIN_W, -1 } } }, layout = K.col(rows) }
		else
			body = builtin.ScrollArea {
				meta = { localKey = "mpfever-body-" .. tab, styleSheet = K.style { size = { K.WIN_W, K.BODY_H } } },
				content = builtin.Component { meta = { styleSheet = K.style { size = { K.INNER_W, -1 } } }, layout = K.col(rows) },
				horizontalPolicy = builtin.type.ScrollBarPolicy.AlwaysOff,
				verticalPolicy = builtin.type.ScrollBarPolicy.AsNeeded,
			}
		end

		local hasHub = U.HubWindow and U.hubOn()
		local rightBtnsW = hasHub and 116 or 58
		local topChildren = {
			hBox(K, { K.muted(hostSummary(st, sfT, Tf), K.WIN_W - rightBtnsW - 6) }, K.WIN_W - rightBtnsW),
			K.btn(sfT("Mini", "Mini"), sfT("Une petite carte : la synchronisation, les joueurs et la discussion", "Compact card: sync, players and chat"), function() U.setCompact(true) end),
		}
		if hasHub then
			topChildren[#topChildren + 1] = K.gap(4, 1)
			topChildren[#topChildren + 1] = K.btn("Hub", U.hubTip(), function() U.openHub() end, true)
		end

		return builtin.Component {
			meta = { styleSheet = K.style { size = { K.WIN_W, -1 } } },
			layout = K.col { K.row(topChildren), K.gap(1, 6), U.tabStrip(K, tabs, tab), K.gap(1, 7), body },
		}
	end

	-- Ultra-Compact Session Tab (Quick View: 416px auto-height; Hub keeps original carded layout)
	local origSession = U.TABS.session
	U.TABS.session = function(K, st, ctx)
		if K.hub() or U.hubDrawing then return origSession(K, st, ctx) end

		local cardW = sessionNeedsScroll(st) and K.INNER_W or K.WIN_W
		local W = cardW - 24
		local rows = {}
		local link, linkCls = linkLine(st)
		if link then
			local lPanel = (linkCls == "error" or linkCls == "warning" or linkCls == "info") and linkCls or "sunken"
			rows[#rows + 1] = K.sfCard(lPanel, { K.row { vDot(K, linkCls, 10, 4), K.gap(6, 1), K.colored(link, K.color(clsColorName(linkCls)), W - 18) } }, cardW, { 6, 12, 6, 12 })
			rows[#rows + 1] = K.gap(1, 6)
		end

		-- Card 1: Unified Status + Speed (ToggleButtonGroup) in elevated Bento card
		local sShort, sCls = shortSyncLine(st, T, sfT, sfTf)
		local sFull = select(1, syncLine(st))
		local showSpeed = U.installed and st and st.started == "1"
		local speedW = 132
		local leftSyncW = showSpeed and (W - speedW - 4) or W
		local statusRow = {
			hBox(K, {
				vDot(K, sCls, 10, 4),
				K.gap(7, 1),
				K.colored(sShort, K.color(clsColorName(sCls)), leftSyncW - 18),
			}, leftSyncW),
		}
		if showSpeed then
			local cur = tonumber(st.speed)
			local speeds = { 0, 1, 2, 4 }
			local TBG = nil
			pcall(function() TBG = K.builtin.ToggleButtonGroup end)
			if TBG then
				local sel = -1
				local btns = {}
				for i, v in ipairs(speeds) do
					if cur == v then sel = i end
					btns[#btns + 1] = {
						content = K.text(v == 0 and "II" or ("x" .. v)),
						meta = { tooltip = v == 0 and T("Pause", "Pause") or ("x" .. v) },
					}
				end
				statusRow[#statusRow + 1] = K.gap(4, 1)
				statusRow[#statusRow + 1] = TBG {
					meta = { localKey = "mpfever-sf-speed" },
					buttons = btns,
					selected = sel,
					deselectAllowed = false,
					onValueChange = function(index)
						index = tonumber(index)
						local v = index and speeds[index] or nil
						if v ~= nil and v ~= cur then U.setSpeed(v) end
					end,
				}
			else
				for i, v in ipairs(speeds) do
					statusRow[#statusRow + 1] = K.gap(i == 1 and 4 or 3, 1)
					statusRow[#statusRow + 1] = K.btn(v == 0 and "II" or ("x" .. v), v == 0 and T("Pause", "Pause") or ("x" .. v), function() U.setSpeed(v) end, cur == v)
				end
			end
		end
		local syncCardRows = { K.row(statusRow) }
		local desyncs, resyncs = tonumber(st and st.desyncs) or 0, tonumber(st and st.resyncs) or 0
		local syncState = st and st.sync or "none"
		if desyncs > 0 or (resyncs > 0 and syncState ~= "ok") then
			syncCardRows[#syncCardRows + 1] = K.muted(sfTf("%s désynchro(s) · %s resynchro(s)", "%s desync(s) · %s resync(s)", desyncs, resyncs), W)
		end
		rows[#rows + 1] = K.sfCard("elevated", syncCardRows, cardW, { 8, 12, 8, 12 })
		rows[#rows + 1] = K.gap(1, 6)

		-- Card 2: Players Bento card with right-aligned FPS/Pace column & optional header Invite button
		local canInvite = st and st.invite == "1" and U.isHost(st)
		local rightHdrW = canInvite and 72 or 78
		local pHeadRight = canInvite
			and K.btn(sfT("Inviter", "Invite"), T("Inviter des amis Steam", "Invite Steam friends"), requestInvite, false)
			or K.muted(sfT("FPS · Rythme", "FPS · Pace"), rightHdrW)
		local pRows = {
			K.row {
				hBox(K, { K.colored(T("Joueurs", "Players") .. " (" .. playerCount(st) .. ")", K.color("NeutralLight"), W - rightHdrW - 6, "font-scale-headline") }, W - rightHdrW),
				pHeadRight,
			},
			K.gap(1, 2),
		}
		local kick = st and st.pubkick == "1" and U.isHost(st)
		for _, pl in ipairs(st and st.players or {}) do
			if pl.role ~= "server" then
				local pLabel, pCls = compactPlayerName(pl, st.me, T, sfT, sfTf)
				local sc, sTip = "Ok", ""
				if U.syncSign then sc, sTip = U.syncSign(pl, st) end
				local pc, pTip = "NeutralLight", ""
				if U.perfSign then pc, pTip = U.perfSign(pl) end
				local showSigns = pl.state ~= "left" and U.signsOn ~= false
				local dotNodes
				if showSigns then
					dotNodes = K.row {
						K.builtin.Component { meta = { tooltip = sTip }, layout = vDot(K, sc, 10, 4, true) },
						K.gap(4, 1),
						K.builtin.Component { meta = { tooltip = pTip }, layout = vDot(K, pc, 10, 4, true) },
					}
				else
					dotNodes = vDot(K, pl.state == "left" and "NeutralMedium" or "Info", 10, 4, true)
				end
				local dotsW = showSigns and 30 or 16
				if kick and pl.role ~= "host" and pl.state ~= "left" then
					local who = pl.name
					local kickW = 114
					local leftW = W - kickW
					local nameNode = pCls and K.colored(pLabel, K.color(clsColorName(pCls)), leftW - dotsW - 4) or K.text(pLabel, nil, nil, leftW - dotsW - 4)
					pRows[#pRows + 1] = K.row {
						hBox(K, { dotNodes, K.gap(6, 1), nameNode }, leftW),
						K.btn(sfT("Excl.", "Kick"), nil, function() U.menuRequest("kick", who) end),
						K.gap(4, 1),
						K.btn(sfT("Ban.", "Ban"), nil, function() U.menuRequest("ban", who) end),
					}
				else
					local metricW = 78
					local leftW = W - metricW
					local nameNode = pCls and K.colored(pLabel, K.color(clsColorName(pCls)), leftW - dotsW - 4) or K.text(pLabel, nil, nil, leftW - dotsW - 4)
					local paceTxt, paceCol = playerPaceText(U, pl)
					pRows[#pRows + 1] = K.row {
						hBox(K, { dotNodes, K.gap(6, 1), nameNode }, leftW),
						hBox(K, { K.colored(paceTxt, K.color(paceCol), metricW) }, metricW),
					}
				end
			end
		end
		if st and (st.pending or "") ~= "" and U.isHost(st) then
			for who in st.pending:gmatch("[^,]+") do
				local id = who
				pRows[#pRows + 1] = K.gap(1, 4)
				pRows[#pRows + 1] = K.colored(sfTf("%s veut rejoindre", "%s wants to join", (id:gsub("#%d+$", ""))), K.color("Warning"), W)
				pRows[#pRows + 1] = K.row {
					K.btn(T("Accepter", "Accept"), nil, function() U.menuRequest("admit", id .. " 1") end, true),
					K.gap(4, 1),
					K.btn(T("Refuser", "Refuse"), nil, function() U.menuRequest("admit", id .. " 0") end),
				}
			end
		end
		rows[#rows + 1] = K.sfCard("card", pRows, cardW, { 8, 12, 8, 12 })

		-- Card 3: Compact Action Strip (Resync left, Map Pings right)
		local leftBtn = nil
		local canResync = os.getenv("MPFEVER_RESYNCBUTTON") ~= "0" and st and st.started == "1" and U.isHost(st)
		if canResync then
			local left = tonumber(st.resyncin) or 0
			local note, enabled = nil, false
			if st.sync == "resync" then note = sfT("Resynchro…", "Resyncing…")
			elseif U.resyncAskedAt and os.clock() - U.resyncAskedAt < 15 then note = T("Resynchronisation demandée…", "Resynchronisation asked…")
			elseif playerCount(st) < 2 then note = T("Aucun autre joueur à resynchroniser.", "No other player to resynchronise.")
			elseif left > 0 then note = sfTf("Possible dans %s s (une toutes les 2 min).", "Available in %s s (one every 2 min).", math.ceil(left))
			else note, enabled = sfT("Recharger votre partie chez tous les joueurs (~1 min).", "Reload your game on every player's PC (~1 min)."), true end
			leftBtn = K.btn(sfT("Resync", "Resync"), note or sFull, function()
				if U.menuRequest("resync") then
					U.resyncAskedAt = os.clock()
					U.winChanged()
				end
			end, enabled, enabled)
		end

		local pingBtns = {}
		local showPings = st and st.started == "1" and os.getenv("MPFEVER_PINGS") ~= "0"
		if showPings then
			local pings = {
				{ k = "here", label = T("Ici", "Here"), tip = sfT("Signal « Ici » sur la carte (12 s)", "Ping « Here » on map (12 s)") },
				{ k = "warn", label = sfT("Att.", "Warn"), tip = sfT("Signal « Attention » sur la carte (12 s)", "Ping « Watch out » on map (12 s)") },
				{ k = "build", label = sfT("Const.", "Build"), tip = sfT("Signal « Construire ici » sur la carte (12 s)", "Ping « Build here » on map (12 s)") },
			}
			for i, pg in ipairs(pings) do
				if i > 1 then pingBtns[#pingBtns + 1] = K.gap(4, 1) end
				local kind = pg.k
				pingBtns[#pingBtns + 1] = K.btn(pg.label, pg.tip, function()
					sendLine("ping_arm", { k = kind })
					U.pingArmedAt = os.clock()
					U.winChanged()
				end)
			end
			if U.lastPing then
				pingBtns[#pingBtns + 1] = K.gap(4, 1)
				pingBtns[#pingBtns + 1] = K.btn(sfT("Dern.", "Last"), sfT("Voir le dernier signal sur la carte", "Show last ping on map"), function()
					local x = U.lastPing
					pcall(function() api.gui.camera.focusPosition(api.type.Vec3f.new(x.x, x.y, x.z or 0), 400) end)
				end)
			end
		end

		if leftBtn or #pingBtns > 0 then
			rows[#rows + 1] = K.gap(1, 6)
			local pingsW = showPings and (U.lastPing and 210 or 156) or 0
			local stripRow = {}
			if leftBtn then
				stripRow[#stripRow + 1] = hBox(K, { leftBtn }, math.max(90, W - pingsW))
			elseif #pingBtns > 0 then
				stripRow[#stripRow + 1] = hBox(K, { K.muted(sfT("Signaux", "Signals"), W - pingsW - 4) }, math.max(70, W - pingsW))
			end
			for _, pn in ipairs(pingBtns) do stripRow[#stripRow + 1] = pn end
			local stripRows = { K.row(stripRow) }
			if U.pingArmedAt and os.clock() - U.pingArmedAt < 15 then
				stripRows[#stripRows + 1] = K.colored(T("Cliquez sur la carte pour placer le signal (15 s).", "Click on the map to place the signal (15 s)."), K.color("Warning"), W)
			end
			rows[#rows + 1] = K.sfCard("sunken", stripRows, cardW, { 7, 12, 7, 12 })
		end

		return rows
	end

	-- Compact 416px Chat Tab (Hub keeps original Chat layout)
	local origChatBody = U.chatBody
	U.chatBody = function(K, st, chat, ctx)
		if K.hub() or U.hubDrawing then return origChatBody(K, st, chat, ctx) end
		local builtin = K.builtin
		local W = K.WIN_W
		local innerW = W - 20
		local TIME_W, NAME_W = 40, 84
		local MSG_W = math.max(160, innerW - TIME_W - NAME_W - 10)
		local me = myChatName()
		local function height(m)
			if m.kind == "msg" then return math.max(1, math.ceil(U.textWidth(m.text) / 34), math.ceil(U.textWidth(m.name .. ":") / 11)) end
			if m.kind == "unsent" then return math.max(1, math.ceil((U.textWidth(m.text) + 32) / 44)) end
			return 1
		end
		local pick, budget = {}, 9
		for i = #chat, 1, -1 do
			local h = height(chat[i])
			if h > budget and #pick > 0 then break end
			budget = budget - h
			table.insert(pick, 1, chat[i])
		end
		local msgRows = {}
		if #chat == 0 then msgRows[#msgRows + 1] = K.muted(T("Aucun message pour l'instant.", "No messages yet."), innerW) end
		for _, m in ipairs(pick) do
			local time = U.hhmm(m.t)
			if m.kind == "join" then
				msgRows[#msgRows + 1] = K.muted(time .. "  " .. sfTf("%s a rejoint", "%s joined", m.name), innerW)
			elseif m.kind == "left" then
				msgRows[#msgRows + 1] = K.muted(time .. "  " .. sfTf("%s a quitté", "%s left", m.name), innerW)
			elseif m.kind == "away" then
				msgRows[#msgRows + 1] = K.muted(time .. "  " .. sfTf("%s hors ligne (pause)", "%s lost connection", m.name), innerW)
			elseif m.kind == "back" then
				msgRows[#msgRows + 1] = K.muted(time .. "  " .. sfTf("%s de retour", "%s is back", m.name), innerW)
			elseif m.kind == "unsent" then
				msgRows[#msgRows + 1] = K.row { hBox(K, { K.muted(time, TIME_W) }, TIME_W), K.colored(sfT("Non envoyé : ", "Not sent: ") .. m.text, K.color("Error"), innerW - TIME_W) }
			else
				msgRows[#msgRows + 1] = K.row {
					hBox(K, { K.muted(time, TIME_W) }, TIME_W),
					hBox(K, { K.colored(m.name .. ":", K.color(m.name == me and "Ok" or "AccentVeryLight"), NAME_W) }, NAME_W),
					K.gap(6, 1),
					K.text(m.text, nil, nil, MSG_W),
				}
			end
		end
		local function send(v)
			if sendChat(v) then
				ctx.draft:set("")
				ctx.chatGen:set(ctx.chatGen:old() + 1)
			end
		end
		local msgBox = K.box(msgRows, { size = { W, K.BODY_H - 42 }, padding = { 8, 10, 8, 10 }, background = SF.PALETTE.BaseDark }, K.V)
		local inputRow = K.row {
			builtin.TextInputField {
				meta = { class = "font-scale-body", localKey = "mpfever-chat-input-" .. tostring(ctx.chatGen:old()),
					styleSheet = K.style { size = { math.max(220, W - 82), 32 } } },
				value = "",
				placeholderText = T("Écrire un message…", "Write a message…"),
				maxLength = 300,
				acceptOnFocusLoss = false,
				onTyping = function(v) ctx.draft:set(v or "") end,
				onValueChange = function(v) send(v) end,
			},
			K.gap(6, 1),
			K.btn(T("Envoyer", "Send"), nil, function() send(ctx.draft:old()) end, true),
		}
		return { msgBox, K.gap(1, 8), inputRow }
	end

	-- Clean SwiftFever Settings Tab (no upstream Discord button, clean fork credit)
	U.TABS.settings = function(K, st, ctx)
		local builtin = K.builtin
		local W = K.TEXT_W
		local rows = {}
		local p = U.loadPrefs()
		rows[#rows + 1] = K.section(K.ICON_SETTINGS, sfT("Fenêtre SwiftFever", "SwiftFever window"))
		rows[#rows + 1] = K.row { builtin.CheckBox {
			value = p.autoopen == "0" and 0 or 1,
			label = sfT("Ouvrir SwiftFever au début de chaque partie", "Open SwiftFever when a game starts"),
			onValueChange = function(v) U.saveAutoOpen(v == 1); U.winChanged() end,
		} }
		if st and st.mode == "separate" then
			rows[#rows + 1] = K.row { builtin.CheckBox {
				value = p.aichat == "0" and 0 or 1,
				label = T("Annoncer dans le chat ce que font les entreprises de l'ordinateur", "Tell in the chat what the computer companies do"),
				onValueChange = function(v) p.aichat = v == 1 and "1" or "0"; U.saveGlobalPrefs(); U.winChanged() end,
			} }
			rows[#rows + 1] = K.row { builtin.CheckBox {
				value = U.dotsOn() and 1 or 0,
				label = T("Un point de leur couleur sur les véhicules des autres entreprises", "A dot of their colour over the other companies' vehicles"),
				onValueChange = function(v) p.vdots = v == 1 and "1" or "0"; U.saveGlobalPrefs(); U.winChanged() end,
			} }
		end
		rows[#rows + 1] = K.row { builtin.CheckBox {
			value = U.oldMenus() and 1 or 0,
			label = sfT("Utiliser les anciennes pages de la fenêtre (0.7.3)", "Use the window's old pages (0.7.3)"),
			onValueChange = function(v) p.oldmenus = v == 1 and "1" or "0"; U.saveGlobalPrefs(); U.winChanged() end,
		} }
		U.settingsRows(K, rows)
		rows[#rows + 1] = K.gap(1, 12)
		rows[#rows + 1] = K.section(K.ICON_ALERT, sfT("Diagnostics & Info", "Diagnostics & Info"))
		rows[#rows + 1] = K.muted(SF.BRAND .. " · " .. SF.SUBTITLE .. " (" .. SF.CREDIT .. ")", W)
		rows[#rows + 1] = K.gap(1, 4)
		rows[#rows + 1] = K.row { K.btn(U.reportLabel(), sfT("Rassemble les journaux dans un zip pour signaler un problème.", "Gathers the logs into a zip to report an issue."), requestReport) }
		if U.reportMsg and U.reportAsked and os.time() - U.reportAsked <= 120 then rows[#rows + 1] = K.muted(U.reportMsg, W) end
		return rows
	end
end

return SF