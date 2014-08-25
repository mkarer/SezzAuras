--[[

	s:UI Auras Library

	Contains all buffs and debuffs of a specified unit.
	Callbacks are used to react on buff gain/change/lose.

	Martin Karer / Sezz, 2014
	http://www.sezz.at

--]]

local MAJOR, MINOR = "Sezz:Auras-0.1", 1;
local APkg = Apollo.GetPackage(MAJOR);
if (APkg and (APkg.nVersion or 0) >= MINOR) then return; end

local Auras = APkg and APkg.tPackage or {};
local log;

-- Lua API
local tinsert = table.insert;

-- WildStar API
local Apollo, XmlDoc = Apollo, XmlDoc;

-----------------------------------------------------------------------------

function Auras:Enable()
	if (self.bEnabled) then return; end

	-- Update
	if (self.unit and self.unit:IsValid()) then
--		log:debug("Enable");
		self.bEnabled = true;
		Apollo.RegisterEventHandler("VarChange_FrameCount", "Update", self);
		self:Update();
	else
		self:Disable();
	end
end

function Auras:Disable()
	if (not self.bEnabled) then return; end

--	log:debug("Disable");
	self.bEnabled = false;
	Apollo.RemoveEventHandler("VarChange_FrameCount", self);
	self.unit = nil;
	self:Reset();
end

function Auras:RegisterCallback(strEvent, strFunction, tEventHandler)
	if (not self.tCallbacks[strEvent]) then
		self.tCallbacks[strEvent] = {};
	end

	tinsert(self.tCallbacks[strEvent], { strFunction, tEventHandler });
end

function Auras:SetUnit(unit, bNoAutoEnable)
	local bClearBuffs = (not self.unit or self.unit ~= unit);
	self.unit = unit;

--[[
	if (self.wndBuffContainer) then
		self.wndBuffContainer:SetUnit(self.unit);
	end
--]]

	if (bClearBuffs) then
		self:Reset();
	end

	if (not bNoAutoEnable and not self.bEnabled) then
		self:Enable()
	end

	return self;
end

function Auras:Reset()
--	log:debug("Reset");

	for _, tAura in pairs(self.tDebuffs) do
		self.tDebuffs[tAura.idBuff] = nil;
		self:Call("OnAuraRemoved", tAura);
	end

	for _, tAura in pairs(self.tBuffs) do
		self.tBuffs[tAura.idBuff] = nil;
		self:Call("OnAuraRemoved", tAura);
	end
end

function Auras:Call(strEvent, tAura, ...)
	local bFiltered = (tAura.bIsDebuff and self.tFilter["Debuff"]) or (not tAura.bIsDebuff and self.tFilter["Buff"]) or (self.tFilter[tAura.splEffect:GetId()]);

	if (not bFiltered and self.tCallbacks[strEvent]) then
		for _, tCallback in ipairs(self.tCallbacks[strEvent]) do
			local strFunction = tCallback[1];
			local tEventHandler = tCallback[2];

			tEventHandler[strFunction](tEventHandler, tAura, ...);
		end
	end
end

function Auras:ScanAuras(arAuras, tCache, bIsDebuff)
	-- Mark all auras as expired
	for _, tAura in pairs(tCache) do
		tAura.bExpired = true;
	end

	-- Add/Update Auras
	for i, tAura in ipairs(arAuras) do
		tAura.bIsDebuff = bIsDebuff;

		if (not tCache[tAura.idBuff]) then
			-- New Aura
--			log:debug("Added Aura: %s", tAura.splEffect:GetName());
			tCache[tAura.idBuff] = tAura;
			tAura.unit = self.unit;
			tAura.nIndex = i;

			self:Call("OnAuraAdded", tAura);
		else
			-- Update Existing Aura
			local bAuraUpdated = (tAura.fTimeRemaining > tCache[tAura.idBuff].fTimeRemaining);
			tCache[tAura.idBuff].fTimeRemaining = tAura.fTimeRemaining; -- fTimeRemaining doesn't get updated when a buff is refreshed!
			tCache[tAura.idBuff].nIndex = i;

			if (tCache[tAura.idBuff].nCount ~= tAura.nCount) then
				tCache[tAura.idBuff].nCount = tAura.nCount;
				bAuraUpdated = true;
			end

			if (bAuraUpdated) then
--				log:debug("Updated Aura: %s", tAura.splEffect:GetName());
				self:Call("OnAuraUpdated", tCache[tAura.idBuff]);
			end
		end

		-- Remove IsExpired
		tCache[tAura.idBuff].bExpired = false;
	end

	-- Remove expired
	for _, tAura in pairs(tCache) do
		if (tAura.bExpired) then
			-- Remove Aura
			tCache[tAura.idBuff] = nil;
--			log:debug("Removed Aura: %s", tAura.splEffect:GetName());
			self:Call("OnAuraRemoved", tAura);
		end
	end
end

function Auras:Update()
--	log:debug("Update");

	if (self.unit and self.unit:IsValid()) then
		local tAuras = self.unit:GetBuffs();
		self:ScanAuras(tAuras.arBeneficial, self.tBuffs, false);
		self:ScanAuras(tAuras.arHarmful, self.tDebuffs, true);
	else
		-- Invalid Unit
		log:debug("Unit Invalid!")
		self:Disable();
	end
end

function Auras:SetFilter(tFilter)
	self.tFilter = tFilter;
end

-----------------------------------------------------------------------------
-- Constructor
-----------------------------------------------------------------------------

function Auras:New()
	local self = setmetatable({}, { __index = Auras });

	self.bEnabled = false;
	self.tBuffs = {};
	self.tDebuffs = {};
	self.tCallbacks = {};
	self.tFilter = {};

	return self;
end

-----------------------------------------------------------------------------
-- Apollo Registration
-----------------------------------------------------------------------------

function Auras:OnLoad()
	local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2") and Apollo.GetAddon("GeminiConsole") and Apollo.GetPackage("Gemini:Logging-1.2").tPackage;
	if (GeminiLogging) then
		log = GeminiLogging:GetLogger({
			level = GeminiLogging.DEBUG,
			pattern = "%d %n %c %l - %m",
			appender ="GeminiConsole"
		});
	else
		log = setmetatable({}, { __index = function() return function(self, ...) local args = #{...}; if (args > 1) then Print(string.format(...)); elseif (args == 1) then Print(tostring(...)); end; end; end });
	end
end

function Auras:OnDependencyError(strDep, strError)
	return false;
end

-----------------------------------------------------------------------------

Apollo.RegisterPackage(Auras, MAJOR, MINOR, {});
