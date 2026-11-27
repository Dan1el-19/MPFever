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
	Ok = { 0.133, 0.773, 0.369, 1 },
	Warning = { 0.961, 0.620, 0.043, 1 },
	Error = { 0.937, 0.267, 0.267, 1 },
	Info = { 0.231, 0.510, 0.965, 1 },
	Positive = { 0.376, 0.647, 0.980, 1 },
	Negative = { 0.973, 0.443, 0.443, 1 },
	Orange = { 0.976, 0.451, 0.086, 1 },

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
}

local function cloneRgba(raw, alpha)
	return { raw[1], raw[2], raw[3], alpha or raw[4] or 1 }
end

local function makeVec4f(raw, alpha)
	if not (api and api.type and api.type.Vec4f and api.type.Vec4f.new) then return nil end
	local ok, v = pcall(api.type.Vec4f.new, raw[1], raw[2], raw[3], alpha or raw[4] or 1)
	return ok and v or nil
end

function SF.applyKit(U, C)
	if not SF.enabled() or not U or not U.kit or U.kit.__sfApplied then return end
	local K = U.kit
	K.__sfApplied = true
	U.brandName = SF.BRAND

	-- Ultra-Compact Quick View measures (420px HUD)
	K.WIN_W, K.BODY_H, K.INNER_W, K.TEXT_W = 420, 340, 404, 392
	K.CARD_W, K.CARD_TEXT_W = 392, 372

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
		K.PANELS.elevated = { "BaseLightMedium", nil, "AccentLight", 0.45 }
		K.PANELS.sunken = { "BaseDark", nil, "BaseVeryLight", 0.75 }
	end

	-- 9-patch card helper usable in both Quick View and Hub
	K.sfCard = function(kind, children, width, pad)
		local st = K.panel(kind or "card", { size = { width or K.CARD_W, -1 }, padding = pad or { 8, 10, 8, 10 } })
		return K.box(children, st, K.V)
	end

	-- Window container padding + Midnight Cobalt backdrop (#0A0D14)
	K.padded = function(content)
		if os.getenv("MPFEVER_WINPAD") == "0" or content == nil then return content end
		K.sfPadStyle = K.sfPadStyle or K.style { padding = { 8, 10, 10, 10 }, background = SF.PALETTE.BaseVeryDark }
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

local function hostSummary(st, T, Tf)
	if not (st and st.host) then return SF.BRAND end
	local name = (st.server == "1" and st.title and st.title ~= "") and st.title or st.host
	local mode = st.mode == "separate" and T("Entreprises", "Companies") or T("Coop", "Co-op")
	return Tf("Hôte : %s", "Host: %s", name) .. "  ·  " .. mode
end

local function shortSyncLine(st, T, Tf)
	local sync = st and st.sync or "none"
	local parts = (st and st.parts and st.parts ~= "") and (" (" .. st.parts .. ")") or ""
	if sync == "ok" then
		local age = tonumber(st.age) or -1
		return T("Synchrone", "In sync") .. (age >= 0 and (" · " .. Tf("%s s", "%s s ago", age)) or ""), "success"
	elseif sync == "drift" then
		return T("Dérive", "Drift") .. parts, "warning"
	elseif sync == "desync" then
		return T("Désynchro", "Out of sync") .. parts, "error"
	elseif sync == "resync" then
		return T("Resynchro…", "Resync…"), "info"
	end
	return T("Non vérifiée", "Not checked"), nil
end

function SF.applySession(U, C, deps)
	if not SF.enabled() or not U or U.__sfSessionApplied then return end
	U.__sfSessionApplied = true
	SF.applyKit(U, C)

	local T = deps.T
	local log = deps.log or function() end
	local syncLine = deps.syncLine
	local linkLine = deps.linkLine
	local playerCount = deps.playerCount or countActivePlayers
	local playerLine = deps.playerLine
	local requestInvite = deps.requestInvite
	local requestReport = deps.requestReport
	local sendLine = deps.sendLine
	local myChatName = deps.myChatName
	local sendChat = deps.sendChat
	local Tf = C.Tf

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

	-- Ultra-Compact 240px Card
	U.compactContent = function(K, st)
		local CW = 216
		local sText, sCls = shortSyncLine(st, T, Tf)
		local fullTip = select(1, syncLine(st))
		local link, linkCls = linkLine(st)
		local cardRows = {}
		if link then cardRows[#cardRows + 1] = K.row { K.dot(linkCls, 10), K.gap(5, 1), K.text(link, nil, linkCls, CW - 16) } end
		cardRows[#cardRows + 1] = K.row { K.dot(sCls, 11), K.gap(6, 1), K.text(sText, nil, sCls, CW - 18) }
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

	-- Ultra-Compact Quick View Header + Body (420px)
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
		else
			body = builtin.ScrollArea {
				meta = { localKey = "mpfever-body-" .. tab, styleSheet = K.style { size = { K.WIN_W, K.BODY_H } } },
				content = builtin.Component { meta = { styleSheet = K.style { size = { K.INNER_W, -1 } } }, layout = K.col(rows) },
				horizontalPolicy = builtin.type.ScrollBarPolicy.AlwaysOff,
				verticalPolicy = builtin.type.ScrollBarPolicy.AsNeeded,
			}
		end

		local hasHub = U.HubWindow and U.hubOn()
		local topRow = {
			K.muted(hostSummary(st, T, Tf), K.WIN_W - (hasHub and 138 or 78)),
			K.btn(T("Mini", "Mini"), T("Une petite carte : la synchronisation, les joueurs et la discussion", "Compact card: sync, players and chat"), function() U.setCompact(true) end),
		}
		if hasHub then
			topRow[#topRow + 1] = K.gap(4, 1)
			topRow[#topRow + 1] = K.btn("Hub", U.hubTip(), function() U.openHub() end, true)
		end

		return builtin.Component {
			meta = { styleSheet = K.style { size = { K.WIN_W, -1 } } },
			layout = K.col { K.row(topRow), K.gap(1, 6), U.tabStrip(K, tabs, tab), K.gap(1, 6), body },
		}
	end

	-- Ultra-Compact Session Tab (Quick View: 420px; Hub keeps original carded layout)
	local origSession = U.TABS.session
	U.TABS.session = function(K, st, ctx)
		if K.hub() or U.hubDrawing then return origSession(K, st, ctx) end

		local rows = {}
		local W = K.CARD_TEXT_W
		local link, linkCls = linkLine(st)
		if link then
			local lPanel = (linkCls == "error" or linkCls == "warning" or linkCls == "info") and linkCls or "sunken"
			rows[#rows + 1] = K.sfCard(lPanel, { K.row { K.dot(linkCls, 11), K.gap(6, 1), K.text(link, nil, linkCls, W - 20) } }, K.CARD_W, { 6, 10, 6, 10 })
			rows[#rows + 1] = K.gap(1, 6)
		end

		-- Unified Status + Speed elevated Bento card
		local sShort, sCls = shortSyncLine(st, T, Tf)
		local sFull = select(1, syncLine(st))
		local showSpeed = U.installed and st and st.started == "1"
		local statusRow = {
			K.dot(sCls, 12),
			K.gap(6, 1),
			K.text(sShort, nil, sCls, showSpeed and (W - 190) or (W - 22)),
		}
		if showSpeed then
			local cur = tonumber(st.speed)
			for i, v in ipairs({ 0, 1, 2, 4 }) do
				if i > 1 then statusRow[#statusRow + 1] = K.gap(3, 1) end
				statusRow[#statusRow + 1] = K.btn(v == 0 and "II" or ("x" .. v), v == 0 and T("Pause", "Pause") or ("x" .. v), function() U.setSpeed(v) end, cur == v)
			end
		end
		local syncCardRows = { K.row(statusRow) }
		local desyncs, resyncs = tonumber(st and st.desyncs) or 0, tonumber(st and st.resyncs) or 0
		if desyncs > 0 or resyncs > 0 then
			syncCardRows[#syncCardRows + 1] = K.muted(Tf("%s désynchro(s) · %s resynchro(s)", "%s desync(s) · %s resync(s)", desyncs, resyncs), W)
		end
		rows[#rows + 1] = K.sfCard("elevated", syncCardRows, K.CARD_W, { 8, 10, 8, 10 })
		rows[#rows + 1] = K.gap(1, 6)

		-- Players Bento card
		local pRows = {
			K.row {
				K.text(T("Joueurs", "Players") .. " (" .. playerCount(st) .. ")", "font-scale-title-4", nil, W - 90),
				K.muted(T("Sync · Rythme", "Sync · Pace"), 90),
			},
		}
		local kick = st and st.pubkick == "1" and U.isHost(st)
		for _, pl in ipairs(st and st.players or {}) do
			if pl.role ~= "server" then
				local line, cls = playerLine(pl, st.me)
				local signs = pl.state ~= "left" and U.playerSigns and U.playerSigns(K, pl, st) or nil
				if kick and pl.role ~= "host" and pl.state ~= "left" then
					local who = pl.name
					local r = {}
					if signs then r[#r + 1] = signs; r[#r + 1] = K.gap(6, 1) end
					r[#r + 1] = K.text(line, nil, cls, W - (signs and 180 or 146))
					r[#r + 1] = K.btn(T("Excl.", "Kick"), nil, function() U.menuRequest("kick", who) end)
					r[#r + 1] = K.gap(4, 1)
					r[#r + 1] = K.btn(T("Ban.", "Ban"), nil, function() U.menuRequest("ban", who) end)
					pRows[#pRows + 1] = K.row(r)
				elseif signs then
					pRows[#pRows + 1] = K.row { signs, K.gap(6, 1), K.text(line, nil, cls, W - 36) }
				else
					pRows[#pRows + 1] = K.row { K.icon(K.ICON_PERSON, 18), K.gap(6, 1), K.text(line, nil, cls, W - 26) }
				end
			end
		end
		if st and (st.pending or "") ~= "" and U.isHost(st) then
			for who in st.pending:gmatch("[^,]+") do
				local id = who
				pRows[#pRows + 1] = K.gap(1, 4)
				pRows[#pRows + 1] = K.text(Tf("%s veut rejoindre", "%s wants to join", (id:gsub("#%d+$", ""))), nil, "warning", W)
				pRows[#pRows + 1] = K.row {
					K.btn(T("Accepter", "Accept"), nil, function() U.menuRequest("admit", id .. " 1") end, true),
					K.gap(4, 1),
					K.btn(T("Refuser", "Refuse"), nil, function() U.menuRequest("admit", id .. " 0") end),
				}
			end
		end
		if st and st.invite == "1" and U.isHost(st) then
			pRows[#pRows + 1] = K.gap(1, 4)
			pRows[#pRows + 1] = K.row { K.btn(T("Inviter des amis Steam", "Invite Steam friends"), nil, requestInvite, true) }
		end
		rows[#rows + 1] = K.sfCard("card", pRows, K.CARD_W, { 8, 10, 8, 10 })

		-- Compact Action Strip (Resync + Map Pings)
		local actionBtns = {}
		local canResync = os.getenv("MPFEVER_RESYNCBUTTON") ~= "0" and st and st.started == "1" and U.isHost(st)
		if canResync then
			local left = tonumber(st.resyncin) or 0
			local note, enabled = nil, false
			if st.sync == "resync" then note = T("Resynchro…", "Resyncing…")
			elseif U.resyncAskedAt and os.clock() - U.resyncAskedAt < 15 then note = T("Resynchronisation demandée…", "Resynchronisation asked…")
			elseif playerCount(st) < 2 then note = T("Aucun autre joueur à resynchroniser.", "No other player to resynchronise.")
			elseif left > 0 then note = Tf("Possible dans %s s (une toutes les 2 min).", "Available in %s s (one every 2 min).", math.ceil(left))
			else note, enabled = T("Recharger votre partie chez tous les joueurs (~1 min).", "Reload your game on every player's PC (~1 min)."), true end
			actionBtns[#actionBtns + 1] = K.btn(T("Resync", "Resync"), note or sFull, function()
				if U.menuRequest("resync") then
					U.resyncAskedAt = os.clock()
					U.winChanged()
				end
			end, true, enabled)
		end

		if st and st.started == "1" and os.getenv("MPFEVER_PINGS") ~= "0" then
			if #actionBtns > 0 then actionBtns[#actionBtns + 1] = K.gap(6, 1) end
			local pings = {
				{ k = "here", label = T("Ici", "Here"), tip = T("Signal « Ici » sur la carte (12 s)", "Ping « Here » on map (12 s)") },
				{ k = "warn", label = T("Att.", "Warn"), tip = T("Signal « Attention » sur la carte (12 s)", "Ping « Watch out » on map (12 s)") },
				{ k = "build", label = T("Const.", "Build"), tip = T("Signal « Construire ici » sur la carte (12 s)", "Ping « Build here » on map (12 s)") },
			}
			for i, pg in ipairs(pings) do
				if i > 1 then actionBtns[#actionBtns + 1] = K.gap(4, 1) end
				local kind = pg.k
				actionBtns[#actionBtns + 1] = K.btn(pg.label, pg.tip, function()
					sendLine("ping_arm", { k = kind })
					U.pingArmedAt = os.clock()
					U.winChanged()
				end)
			end
			if U.lastPing then
				actionBtns[#actionBtns + 1] = K.gap(4, 1)
				actionBtns[#actionBtns + 1] = K.btn(T("Dern.", "Last"), T("Voir le dernier signal sur la carte", "Show last ping on map"), function()
					local x = U.lastPing
					pcall(function() api.gui.camera.focusPosition(api.type.Vec3f.new(x.x, x.y, x.z or 0), 400) end)
				end)
			end
		end

		if #actionBtns > 0 then
			rows[#rows + 1] = K.gap(1, 6)
			local stripRows = { K.row(actionBtns) }
			if U.pingArmedAt and os.clock() - U.pingArmedAt < 15 then
				stripRows[#stripRows + 1] = K.text(T("Cliquez sur la carte pour placer le signal (15 s).", "Click on the map to place the signal (15 s)."), nil, "warning", W)
			end
			rows[#rows + 1] = K.sfCard("sunken", stripRows, K.CARD_W, { 7, 8, 7, 8 })
		end

		return rows
	end

	-- Compact 420px Chat Tab (Hub keeps original Chat layout)
	local origChatBody = U.chatBody
	U.chatBody = function(K, st, chat, ctx)
		if K.hub() or U.hubDrawing then return origChatBody(K, st, chat, ctx) end
		local builtin = K.builtin
		local W = K.TEXT_W
		local TIME_W, NAME_W = 42, 86
		local MSG_W = math.max(160, W - TIME_W - NAME_W - 6)
		local me = myChatName()
		local function height(m)
			if m.kind == "msg" then return math.max(1, math.ceil(U.textWidth(m.text) / 34), math.ceil(U.textWidth(m.name .. ":") / 11)) end
			if m.kind == "unsent" then return math.max(1, math.ceil((U.textWidth(m.text) + 32) / 44)) end
			return 1
		end
		local pick, budget = {}, 11
		for i = #chat, 1, -1 do
			local h = height(chat[i])
			if h > budget and #pick > 0 then break end
			budget = budget - h
			table.insert(pick, 1, chat[i])
		end
		local rows = {}
		if #chat == 0 then rows[#rows + 1] = K.muted(T("Aucun message pour l'instant.", "No messages yet."), W) end
		for _, m in ipairs(pick) do
			local time = U.hhmm(m.t)
			if m.kind == "join" then
				rows[#rows + 1] = K.muted(time .. "  " .. Tf("%s a rejoint", "%s joined", m.name), W)
			elseif m.kind == "left" then
				rows[#rows + 1] = K.muted(time .. "  " .. Tf("%s a quitté", "%s left", m.name), W)
			elseif m.kind == "away" then
				rows[#rows + 1] = K.muted(time .. "  " .. Tf("%s hors ligne (pause)", "%s lost connection", m.name), W)
			elseif m.kind == "back" then
				rows[#rows + 1] = K.muted(time .. "  " .. Tf("%s de retour", "%s is back", m.name), W)
			elseif m.kind == "unsent" then
				rows[#rows + 1] = K.row { K.muted(time, TIME_W), K.text(T("Non envoyé : ", "Not sent: ") .. m.text, nil, "error", W - TIME_W) }
			else
				rows[#rows + 1] = K.row {
					K.muted(time, TIME_W),
					K.colored(m.name .. ":", K.color(m.name == me and "Ok" or "AccentVeryLight"), NAME_W),
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
		rows[#rows + 1] = K.gap(1, 8)
		rows[#rows + 1] = K.row {
			builtin.TextInputField {
				meta = { class = "font-scale-body", localKey = "mpfever-chat-input-" .. tostring(ctx.chatGen:old()),
					styleSheet = K.style { size = { math.max(220, W - 84), 32 } } },
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
		return rows
	end

	-- Clean SwiftFever Settings Tab (no upstream Discord button, clean fork credit)
	U.TABS.settings = function(K, st, ctx)
		local builtin = K.builtin
		local W = K.TEXT_W
		local rows = {}
		local p = U.loadPrefs()
		rows[#rows + 1] = K.section(K.ICON_SETTINGS, T("Fenêtre SwiftFever", "SwiftFever window"))
		rows[#rows + 1] = K.row { builtin.CheckBox {
			value = p.autoopen == "0" and 0 or 1,
			label = T("Ouvrir SwiftFever au début de chaque partie", "Open SwiftFever when a game starts"),
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
			label = T("Utiliser les anciennes pages de la fenêtre (0.7.3)", "Use the window's old pages (0.7.3)"),
			onValueChange = function(v) p.oldmenus = v == 1 and "1" or "0"; U.saveGlobalPrefs(); U.winChanged() end,
		} }
		U.settingsRows(K, rows)
		rows[#rows + 1] = K.gap(1, 12)
		rows[#rows + 1] = K.section(K.ICON_ALERT, T("Diagnostics & Info", "Diagnostics & Info"))
		rows[#rows + 1] = K.muted(SF.BRAND .. " · " .. SF.SUBTITLE .. " (" .. SF.CREDIT .. ")", W)
		rows[#rows + 1] = K.gap(1, 4)
		rows[#rows + 1] = K.row { K.btn(U.reportLabel(), T("Rassemble les journaux dans un zip pour signaler un problème.", "Gathers the logs into a zip to report an issue."), requestReport) }
		if U.reportMsg and U.reportAsked and os.time() - U.reportAsked <= 120 then rows[#rows + 1] = K.muted(U.reportMsg, W) end
		return rows
	end
end

return SF
