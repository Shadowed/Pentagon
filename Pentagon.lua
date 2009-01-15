Pentagon = {}

local L = PentagonLocals
local ruleStart = 0
local playerMana, frame, LDBObj

function Pentagon:OnInitialize()
	-- Make sure they even need this
	local class = select(2, UnitClass("player"))
	if( class == "ROGUE" or class == "WARRIOR" or class == "DEATHKNIGHT" ) then
		self.disabled = true
		self.evtFrame:UnregisterAllEvents()
		return
	end
	
	-- Setup default DB
	PentagonDB = PentagonDB or {
		visible = true,
		disabled = false,
		ldb = false,
		scale = 1.0,
		backgroundIn = { r = 0.0, g = 0.0, b = 0.0 },
		inTextColor = { r = 1.0, g = 1.0, b = 1.0 },
		backgroundOut = { r = 0.10, g = 0.10, b = 1.0 },
		outTextColor = { r = 1.0, g = 1.0, b = 1.0 },
		backgroundChannel = { r = 0.20, g = 0.20, b = 0.20 },
		channelTextColor = { r = 1.0, g = 1.0, b = 1.0 },
	}
	
	if( PentagonDB.ldb and not LDBObj ) then
		LDBObj = LibStub("LibDataBroker-1.1"):NewDataObject("Pentagon", {type = "data source", icon = "Interface\\Icons\\Spell_Nature_Sleep", text = "-- (----)"})
	end
	
	if( not PentagonDB.disabled ) then
		-- Showing frame if needed
		if( PentagonDB.visible ) then
			self.evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		end

		Pentagon.evtFrame:RegisterEvent("UNIT_MANA")
		Pentagon.evtFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
		Pentagon.evtFrame:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
	end

	-- Set default mana
	playerMana = UnitPower("player", 0)
end

-- Stupid, but we have to delay PEW due to UI scale
function Pentagon:PLAYER_ENTERING_WORLD()
	self:CreateFrame()
	self.evtFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

-- Mana changed, might need to start the rule
function Pentagon:UNIT_MANA(unit)
	if( unit ~= "player" ) then
		return
	end
	
	local mana = UnitPower("player", 0)
	if( mana < playerMana ) then
		-- Experiment, calibration based off lag
		isChannel = UnitChannelInfo("player")
		ruleStart = GetTime() + 5 - (select(3, GetNetStats()) / 1000)
		
		self.evtFrame:Show()
	end

	playerMana = mana
end

-- Channel done, we can resume the FSR (if needed)
function Pentagon:UNIT_SPELLCAST_CHANNEL_STOP(unit, ...)
	if( unit ~= "player" ) then
		return
	end
	
	isChannel = nil
	self:UpdateFrame()
end

-- Update MP5
function Pentagon:PLAYERSTAT_SPELL_COMBAT()
	self:UpdateFrame()
end

-- Update frame display
function Pentagon:UpdateFrame()
	self:UpdateLDB()
	
	if( not frame ) then
		return
	end
		
	-- If we're channeling, and "out" of FSR, then set it to 0/red since we don't actually exit it until the channel is done
	if( ruleStart == 0 and isChannel ) then
		frame:SetBackdropColor(PentagonDB.backgroundChannel.r, PentagonDB.backgroundChannel.g, PentagonDB.backgroundChannel.b, 1.0)

		frame.timeLeft:SetText("0")
		frame.timeLeft:SetTextColor(PentagonDB.channelTextColor.r, PentagonDB.channelTextColor.g, PentagonDB.channelTextColor.b, 1.0)

		frame.currentMP:SetFormattedText("%d", (select(2, GetManaRegen()) * 5))
		frame.currentMP:SetTextColor(PentagonDB.channelTextColor.r, PentagonDB.channelTextColor.g, PentagonDB.channelTextColor.b, 1.0)

	-- Haven't exited FSR yet
	elseif( ruleStart > 0 ) then
		frame:SetBackdropColor(PentagonDB.backgroundIn.r, PentagonDB.backgroundIn.g, PentagonDB.backgroundIn.b, 1.0)

		frame.timeLeft:SetFormattedText("%.1f", ruleStart - GetTime())
		frame.timeLeft:SetTextColor(PentagonDB.inTextColor.r, PentagonDB.inTextColor.g, PentagonDB.inTextColor.b, 1.0)

		frame.currentMP:SetFormattedText("%d", (select(2, GetManaRegen()) * 5))
		frame.currentMP:SetTextColor(PentagonDB.inTextColor.r, PentagonDB.inTextColor.g, PentagonDB.inTextColor.b, 1.0)
	-- Out!
	else
		frame:SetBackdropColor(PentagonDB.backgroundOut.r, PentagonDB.backgroundOut.g, PentagonDB.backgroundOut.b, 1.0)

		frame.timeLeft:SetText("0")
		frame.timeLeft:SetTextColor(PentagonDB.outTextColor.r, PentagonDB.outTextColor.g, PentagonDB.outTextColor.b, 1.0)

		frame.currentMP:SetFormattedText("%d", (GetManaRegen() * 5))
		frame.currentMP:SetTextColor(PentagonDB.outTextColor.r, PentagonDB.outTextColor.g, PentagonDB.outTextColor.b, 1.0)
	end
end

function Pentagon:UpdateLDB()
	if( not LDBObj ) then
		return
	end

	if( ruleStart == 0 and isChannel ) then
		LDBObj.text = string.format("|cffff2020%d|r (%d)", 0, (select(2, GetManaRegen()) * 5))
	elseif( ruleStart > 0 ) then
		LDBObj.text = string.format("%.1f (%d)", ruleStart - GetTime(), (select(2, GetManaRegen()) * 5))
	else
		LDBObj.text = string.format("|cff20ff20%d|r (%d)", 0, (GetManaRegen() * 5))
	end
end

-- FSR monitor
local timeElapsed = 0
local LDBElapsed = 0
local function fsrMonitor(self, elapsed)
	-- Left the FSR
	if( ruleStart < GetTime() ) then
		ruleStart = 0
		self:Hide()

		Pentagon:UpdateFrame()
	
	-- Update frame since we haven't left the FSR yet, but cap it at every 0.10 seconds
	elseif( ruleStart > 0 ) then
		timeElapsed = timeElapsed + elapsed
		
		if( timeElapsed >= 0.10 ) then
			timeElapsed = 0
			
			Pentagon:UpdateFrame()
		end
	end
end

-- Display frame
function Pentagon:CreateFrame()
	-- Create our display frame
	if( not frame ) then
		local backdrop = {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
				tile = false,
				edgeSize = 0.90,
				tileSize = 5,
				insets = {left = 1, right = 1, top = 1, bottom = 1}}
	
		-- Create the tab frame
		frame = CreateFrame("Frame", nil, UIParent)
		frame:SetHeight(18)
		frame:SetWidth(90)
		frame:EnableMouse(true)
		frame:SetMovable(true)
		frame:SetClampedToScreen(true)
		frame:SetBackdrop(backdrop)
		frame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
		frame:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)
		frame:Hide()
		
		frame:SetScript("OnMouseUp", function(self)
			if( self.isMoving ) then
				self.isMoving = nil
				self:StopMovingOrSizing()

				local scale = self:GetEffectiveScale()
				PentagonDB.position = {x = self:GetLeft() * scale, y = self:GetTop() * scale}
			end
		end)
		frame:SetScript("OnMouseDown", function(self, mouse)
			if( IsAltKeyDown() ) then
				self.isMoving = true
				self:StartMoving()
			end
		end)
		frame:SetScript("OnShow", function()
			-- Position
			if( PentagonDB.position ) then
				local scale = frame:GetEffectiveScale()

				frame:ClearAllPoints()
				frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", PentagonDB.position.x / scale, PentagonDB.position.y / scale)
			else
				frame:SetPoint("CENTER", UIParent, "CENTER")
			end
		end)
	
		frame:SetScale(PentagonDB.scale)
	
		-- Time left before exiting
		frame.timeLeft = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		frame.timeLeft:SetFont((GameFontHighlightSmall:GetFont()), 12)
		frame.timeLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -3)
		
		-- Current MP5
		frame.currentMP = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		frame.currentMP:SetFont((GameFontHighlightSmall:GetFont()), 12)
		frame.currentMP:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -3)
		
		self:UpdateFrame()
	end
	
	frame:Show()
end

-- Random junk
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ADDON_LOADED")
evtFrame:Hide()

evtFrame:SetScript("OnUpdate", fsrMonitor)
evtFrame:SetScript("OnEvent", function(self, event, ...)
	if( event == "ADDON_LOADED" and select(1, ...) == "Pentagon" ) then
		Pentagon:OnInitialize()
		self:UnregisterEvent("ADDON_LOADED")
	elseif( Pentagon[event] ) then
		Pentagon[event](Pentagon, ...)
	end
end)

function Pentagon:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Pentagon|r: " .. msg)
end

function Pentagon:Echo(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

Pentagon.evtFrame = evtFrame

local function showColor(type)
	ColorPickerFrame.func = function()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		PentagonDB[type] = {r = r, g = g, b = b}
		Pentagon:UpdateFrame()
	end

	ColorPickerFrame.cancelFunc = function()
		PentagonDB[type].r = PentagonDB.original.r
		PentagonDB[type].g = PentagonDB.original.g
		PentagonDB[type].b = PentagonDB.original.b
		Pentagon:UpdateFrame()
	end

	PentagonDB.original = {r = PentagonDB[type].r, g = PentagonDB[type].g, b = PentagonDB[type].b}
	ColorPickerFrame:SetColorRGB(PentagonDB[type].r, PentagonDB[type].g, PentagonDB[type].b)
	ShowUIPanel(ColorPickerFrame)
end

-- Slash commands
SLASH_PENTAGON1 = "/pentagon"
SLASH_PENTAGON2 = "/fivesecondrule"
SLASH_PENTAGON3 = "/fsr"
SlashCmdList["PENTAGON"] = function(msg)
	msg = string.lower(msg or "")
	
	local self = Pentagon
	if( self.disabled ) then
		SlashCmdList["PENTAGON"] = nil
		return
	end
	
	if( msg == "visible" ) then
		PentagonDB.visible = not PentagonDB.visible

		if( PentagonDB.visible ) then
			self:Print(L["Now showing the FSR block."])
			self:CreateFrame()
		else
			self:Print(L["No longer showing the FSR block."])
			if( frame ) then
				frame:Hide()
			end
		end
	
	elseif( msg == "ldb" ) then
		PentagonDB.ldb = not PentagonDB.ldb
		
		if( PentagonDB.ldb ) then
			if( PentagonDB.ldb and not LDBObj ) then
				LDBObj = LibStub("LibDataBroker-1.1"):NewDataObject("Pentagon", {type = "data source", icon = "Interface\\Icons\\Spell_Nature_Sleep", text = "-- (----)"})
			end
			
			self:UpdateFrame()
			self:Print(L["Now showing the LibDataBroker-1.0 widget."])
		else
			self:Print(L["No longer showing the LibDataBroker-1.0 widget, a game restart is required for this to take affect."])
		end
	
	elseif( msg == "disabled" ) then
		PentagonDB.disabled = not PentagonDB.disabled
		
		if( not PentagonDB.disabled ) then
			self:Print(L["Pentagon will be enabled next time you enter the game."])
		else
			self:Print(L["Pentagon will be disabled next time you enter the game."])
		end
	
	elseif( msg == "incolor" ) then
		self:Print(L["Now setting the background color when inside the five second rule."])
		showColor("backgroundIn")
	
	elseif( msg == "intext" ) then
		self:Print(L["Now setting the text color when inside the five second rule."])
		showColor("inTextColor")
	
	elseif( msg == "outcolor" ) then
		self:Print(L["Now setting background color when outside the five second rule."])
		showColor("backgroundOut")
	
	elseif( msg == "outtext" ) then
		self:Print(L["Now setting text color when outside the five second rule."])
		showColor("outTextColor")
		
	elseif( msg == "chancolor" ) then
		self:Print(L["Now setting background color when outside the five second rule, but still channeling."])	
		showColor("backgroundChannel")
	
	elseif( msg == "chantext" ) then
		self:Print(L["Now setting text color when outside the five second rule, but still channeling."])
		showColor("channelTextColor")
	
	elseif( string.match(msg, "^scale") ) then
		local scale = select(2, string.split(" ", msg))
		scale = tonumber(scale)
		
		if( not scale or scale >= 3 ) then
			self:Print(L["Invalid scale entered, must be a number."])
			return
		end
		
		if( frame ) then
			frame:SetScale(scale)

			-- Reposition to the new scale as well
			local scale = frame:GetEffectiveScale()

			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", PentagonDB.position.x / scale, PentagonDB.position.y / scale)
		end
		
		self:Print(string.format(L["Set scale to %.2f"], scale))
		PentagonDB.scale = scale
	else
		self:Print(L["Slash commands"])
		self:Echo(L["/pentagon visible - Toggles showing the five second rule block."])
		self:Echo(L["/pentagon incolor - Sets the background color when inside the five second rule."])
		self:Echo(L["/pentagon intext - Sets the text color when inside the five second rule."])
		self:Echo(L["/pentagon outcolor - Sets the background color when outside the five second rule."])
		self:Echo(L["/pentagon outtext - Sets the text color when outside the five second rule."])
		self:Echo(L["/pentagon chancolor - Sets the background color when outside the five second rule, but still channeling."])
		self:Echo(L["/pentagon chantext - Sets the text color when outside the five second rule, but still channeling."])
		self:Echo(L["/pentagon ldb - Toggles showing the LibDataBroker-1.0 widget."])
		--self:Echo(L["/pentagon scale <scale> - Sets how big the block should be, 1 = 100%, 0.50 = 50% and so on."])
	end
end