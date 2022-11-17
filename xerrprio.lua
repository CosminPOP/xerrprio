local _G = _G
local tinsert, tablesize, select, strfind, tonumber = tinsert, table.getn, select, strfind, tonumber
local strsub, strlen, sformat, floor, rand = strsub, strlen, string.format, math.floor, math.random
local _, class = UnitClass('player')

-- known issues
-- if target is friendly and turns hostile, the pause doesnt go to false

-- todo
-- sound when dots have x seconds left

xerrprio = LibStub("AceAddon-3.0"):NewAddon("xerrprio", "AceConsole-3.0", "AceEvent-3.0")
local xerrprio = xerrprio

---xprint
---@param a string
local function xprint(a)
    if not a then
        print('|cff37d63e[xp]|r attempt to print a nil value.')
        return
    end
    print('|cff37d63e[xp] |r' .. a)
end

--------------------
--- Inits
--------------------

XerrPrio = CreateFrame("Frame")
XerrPrio.Worker = CreateFrame("Frame")
XerrPrio.OptionsAnim = CreateFrame("Frame")

XerrPrio.init = false
XerrPrio.paused = true
XerrPrio.spellBookSpells = {}
XerrPrio.hp_path = 'Interface\\AddOns\\HaloPro\\HaloPro_Art\\Shadow\\';
XerrPrio.hp_path_icon = 'Interface\\AddOns\\HaloPro\\HaloPro_Art\\Shadow_Icon\\';

XerrPrio.lowestProcTime = 0
XerrPrio.dotStats = {}
XerrPrio.intervalFallback = 3.1415926
XerrPrio.durationFallback = 18.1415926
XerrPrio.vtGUID = 0

XerrPrio.bars = {
    spells = {
        swp = {
            frame = nil,
            ord = 1,
            name = '', id = 589,
            ticks = {}
        },
        vt = {
            frame = nil,
            ord = 2,
            name = '', id = 34914,
            ticks = {},
            castTimeTick = nil
        }
    }
}
XerrPrio.icons = {
    spells = {
        swp = { name = '', id = 589, icon = '', spellBookID = 0 },
        vt = { name = '', id = 34914, icon = '', spellBookID = 0 },
        dp = { name = '', id = 2944, icon = '', spellBookID = 0 },
        mf = { name = '', id = 15407, icon = '', spellBookID = 0 },
        mb = { name = '', id = 8092, icon = '', spellBookID = 0 },
        halo = { name = '', id = 120644, icon = '', spellBookID = 0 },
        shadowfiend = { name = '', id = 34433, icon = '', spellBookID = 0 },
        swd = { name = '', id = 32379, icon = '', lastCastTime = 0, spellBookID = 0 }
    }
}

XerrPrio.buffs = {
    spells = {
        meta = { id = 137590, duration = 0 },
        lightweave = { id = 125487, duration = 0 },
        jade = { id = 104993, duration = 0 },
        volatile = { id = 138703, duration = 0 },
        hydra = { id = 138898, duration = 0 },
        heroism = { id = 32182, duration = 0 },
        bloodlust = { id = 2825, duration = 0 },
        timewarp = { id = 80353, duration = 0 },
        ancienthysteria = { id = 90355, duration = 0 },
        tof = { id = 123254, duration = 0 },
        --uvls = { id = 139, duration = 0, icon = '' },
        uvls = { id = 138963, duration = 0, icon = '' },
    }
}

XerrPrio.nextSpell = {
    [1] = { id = 0, icon = 'Interface\\Icons\\INV_Misc_QuestionMark' },
    [2] = { id = 0, icon = 'Interface\\Icons\\INV_Misc_QuestionMark' }
}

XerrPrio.colors = {
    whiteHex = '|cffffffff',

    hi1 = '|cff01944a',
    hi2 = '|cff04bd60',
    hi3 = '|cff02f542',

    lo1 = '|cff37d63e',
    lo2 = '|cffC8d637',
    lo3 = '|cffD69637',

    white = { r = 1, g = 1, b = 1, a = 1 },
    swpDefault = { r = 255 / 255, g = 65 / 255, b = 9 / 255, a = 1 },
    vtDefault = { r = 60 / 255, g = 52 / 255, b = 175 / 255, a = 1 }
}

--------------------
--- Events
--------------------

XerrPrio:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
XerrPrio:RegisterEvent('UNIT_SPELLCAST_START')
XerrPrio:RegisterEvent('ADDON_LOADED')
XerrPrio:RegisterEvent('PLAYER_ENTERING_WORLD')
XerrPrio:RegisterEvent('PLAYER_TARGET_CHANGED')
XerrPrio:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
XerrPrio:RegisterEvent('PLAYER_TALENT_UPDATE')
XerrPrio:RegisterEvent('PLAYER_REGEN_ENABLED')
XerrPrio:RegisterEvent('VARIABLES_LOADED')
XerrPrio:SetScript("OnEvent", function(self, event, arg1, _, _, _, arg5)
    if event then
        if (event == 'ADDON_LOADED' and arg1 == 'xerrprio') or event == 'PLAYER_ENTERING_WORLD' or event == 'PLAYER_TALENT_UPDATE' then
            self:Init()
            return
        end
        if event == 'VARIABLES_LOADED' then
            self:VarsLoaded()
        end
        if not self.init then
            return false
        end
        if event == 'UNIT_SPELLCAST_START' and arg1 == 'player' and UnitGUID('target') then
            if arg5 == self.icons.spells.vt.id then
                self.vtGUID = UnitGUID('target')
            end
            return
        end
        if event == 'UNIT_SPELLCAST_SUCCEEDED' and arg1 == 'player' and UnitGUID('target') then
            if arg5 == self.icons.spells.swd.id or arg5 == self.icons.spells.swp.id or arg5 == self.icons.spells.vt.id then
                self:SpellCast(arg5, arg5 == self.icons.spells.vt.id and self.vtGUID or UnitGUID('target'))
            end
            return
        end
        if event == 'PLAYER_REGEN_ENABLED' then
            self.Worker.dotScanner.enabled = false
            return
        end
        if event == 'PLAYER_TARGET_CHANGED' then
            if XerrPrioDB.configMode then
                XerrPrioBars:Show()
                XerrPrioIcons:Show()
                self.paused = false
                return
            end
            if not UnitExists('target') then
                self.paused = true
            else
                if UnitReaction('player', 'target') and UnitReaction('player', 'target') >= 5 then
                    self.paused = true
                else
                    self.paused = false
                end
            end
            return
        end
    end
end)

--------------------
---  Init
--------------------

---Init
function XerrPrio:Init()

    self.init = false

    -- limit to priest / shadow
    if class ~= 'PRIEST' or GetSpecialization() ~= 3 then
        XerrPrioBars:Hide()
        XerrPrioIcons:Hide()
        return false
    end

    -- get spellbook ids for all spells
    self:PopulateSpellBookID()

    -- get spell name and icon, and create bars
    for key, spell in next, self.bars.spells do
        if spell.name == '' then
            spell.name, spell.icon = self:GetSpellInfo(spell.id)
            local frameName = 'XerrPrioBar_' .. key

            if not spell.frame then
                spell.frame = CreateFrame('Frame', frameName, XerrPrioBars, 'XerrPrioBarFrameTemplate')
            end

            _G[frameName]:SetPoint("TOPLEFT", XerrPrioBars, "TOPLEFT", 0, -50 + spell.ord * 25)
            _G[frameName .. 'TextsName']:SetText(spell.name)
            _G[frameName .. 'Icon']:SetTexture(spell.icon)
        end
    end

    -- get names and icons for prio spells
    for _, spell in next, self.icons.spells do
        if spell.name == '' then
            spell.name, spell.icon = self:GetSpellInfo(spell.id)
        end
    end

    -- get icons for tof and uvls
    self.buffs.spells.uvls.icon = select(2, self:GetSpellInfo(self.buffs.spells.uvls.id))

    self.icons.spells.swd.lastCastTime = GetTime()

    -- addon settings
    if not XerrPrioDB then
        XerrPrioDB = {
            configMode = false,
            bars = true,
            icons = true,
            swp = {
                enabled = true,
                barColor = self.colors.swpDefault,
                textColor = { r = 1, g = 1, b = 1, a = 1 },
                showIcon = true,
                showTicks = true,
                showOnlyLastTick = true,
                tickWidth = 1,
                tickColor = { r = 0, g = 0, b = 0, a = 1 },
                refreshTextColor = { r = 1, g = 1, b = 1, a = 1 },
                refreshBarColor = { r = 0, g = 1, b = 0, a = 1 }
            },
            vt = {
                enabled = true,
                barColor = self.colors.vtDefault,
                textColor = { r = 1, g = 1, b = 1, a = 1 },
                showIcon = true,
                showTicks = true,
                showOnlyLastTick = true,
                tickWidth = 1,
                tickColor = { r = 0, g = 0, b = 0, a = 1 },
                refreshTextColor = { r = 1, g = 1, b = 1, a = 1 },
                refreshBarColor = { r = 0, g = 1, b = 0, a = 1 }
            },
            barWidth = 280,
            barBackgroundColor = { r = 0, g = 0, b = 0, a = 1 },
            refreshMinDuration = 5,
            minDotDpsIncrease = 1
        }
    end

    self:UpdateConfig()

    self.init = true

    -- start worker
    XerrPrio.Worker:Show()

end

function XerrPrio:VarsLoaded()
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("xerrprio", self:CreateOptions())
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("xerrprio", "xerrprio")
end

--------------------
---  Timers
--------------------

--------------------
--- Worker
--------------------

XerrPrio.Worker:Hide()
XerrPrio.Worker.start = GetTime()
XerrPrio.Worker.dotScanner = {
    spellId = 0,
    enabled = false
}
XerrPrio.Worker.bars = {
    enabled = true,
    show = false
}
XerrPrio.Worker.icons = {
    enabled = true
}

XerrPrio.Worker:SetScript("OnShow", function(self)
    self.start = GetTime()
    self.timeSinceLastUpdate = 0;
end)

XerrPrio.Worker:SetScript("OnUpdate", function(self, elapsed)

    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

    if self.timeSinceLastUpdate >= 0.05 then
        self.timeSinceLastUpdate = 0;

        self.bars.enabled = not XerrPrio.paused and XerrPrioDB.bars and not XerrPrioDB.configMode
        self.icons.enabled = not XerrPrio.paused and XerrPrioDB.icons and not XerrPrioDB.configMode

        local guid = UnitGUID('target')

        if XerrPrioDB.configMode or XerrPrio.paused then
            XerrPrio.nextSpell = {
                [1] = { id = 0, icon = 'Interface\\Icons\\INV_Misc_QuestionMark' },
                [2] = { id = 0, icon = 'Interface\\Icons\\INV_Misc_QuestionMark' }
            }
            XerrPrioIconsIcon:SetTexture(XerrPrio.nextSpell[1].icon)
            XerrPrioIconsIcon2:SetTexture(XerrPrio.nextSpell[2].icon)

            if XerrPrio.paused then
                XerrPrioBars:Hide()
                XerrPrioIcons:Hide()
            end

            return
        end

        -- Dots Scanner
        -- Scans debuffs for dot duration and interval

        if self.dotScanner.enabled then
            for i = 1, 40 do
                local _, _, _, _, _, duration, _, unitCaster, _, _, spellId = UnitDebuff('target', i)
                if spellId == self.dotScanner.spellId and unitCaster == "player" then
                    XerrPrioTooltipFrame:SetOwner(UIParent, "ANCHOR_NONE")
                    XerrPrioTooltipFrame:SetUnitDebuff("target", i)

                    local tooltipDescription = XerrPrioTooltipFrameTextLeft2:GetText()

                    local _, _, interval = strfind(tooltipDescription, "every (%S+) sec")

                    if spellId == XerrPrio.icons.spells.swp.id then
                        XerrPrio.dotStats[self.dotScanner.guid].swp.duration = duration
                        XerrPrio.dotStats[self.dotScanner.guid].swp.interval = tonumber(interval)
                        XerrPrio.dotStats[self.dotScanner.guid].swp.uvlsExpirationTime = GetTime() + duration
                        self.dotScanner.enabled = false
                        break
                    end
                    if spellId == XerrPrio.icons.spells.vt.id then
                        XerrPrio.dotStats[self.dotScanner.guid].vt.duration = duration
                        XerrPrio.dotStats[self.dotScanner.guid].vt.interval = tonumber(interval)
                        XerrPrio.dotStats[self.dotScanner.guid].vt.uvlsExpirationTime = GetTime() + duration
                        self.dotScanner.enabled = false
                        break
                    end

                    break
                end
            end
        end

        local uvls, uvlsDuration = XerrPrio:PlayerHasProc(XerrPrio.buffs.spells.uvls.id)
        local vtCastTime = select(3, XerrPrio:GetSpellInfo(XerrPrio.bars.spells.vt.id))

        -- Bars
        if self.bars.enabled then

            for key, spell in next, XerrPrio.bars.spells do

                local tl, perc, duration = XerrPrio:GetDebuffInfo(spell.id)
                local frame = spell.frame:GetName()

                _G[frame]:Hide()

                if tl > 0 and XerrPrio.dotStats[guid] and XerrPrio.dotStats[guid][key] then

                    local stats = XerrPrio.dotStats[guid][key]

                    if stats.duration == XerrPrio.durationFallback or stats.interval == XerrPrio.intervalFallback then
                        self.dotScanner.spellId = spell.id
                        self.dotScanner.enabled = true
                        self.dotScanner.guid = guid
                        return
                    end

                    self.show = true

                    _G[frame .. 'Bar']:SetWidth(XerrPrioDB.barWidth * perc)
                    _G[frame .. 'TextsTimeLeft']:SetText(floor(tl))
                    _G[frame .. 'RefreshBar']:SetVertexColor(1, 1, 1, 0.2)

                    local currentDps = XerrPrio:GetSpellDamage(spell.id)
                    local color = XerrPrioDB[key].refreshBarColor
                    local refreshPower = floor(100 * currentDps / stats.dps - 100)

                    XerrPrio.lowestProcTime = XerrPrio:GetLowestProcTime(uvls)

                    if stats.uvls then
                        if GetTime() >= stats.uvlsExpirationTime then
                            stats.uvls = false
                        end
                    end

                    XerrPrio:AddLightningBar(frame, stats, perc, spell.id)

                    XerrPrio:AddRefreshBar(frame, refreshPower, color, uvls, duration, perc, tl, stats, spell.id, vtCastTime)

                    XerrPrio:AddArrows(frame, uvls, refreshPower, currentDps, stats)

                    XerrPrio:AddUVLSIcon(frame, stats, uvls, key)

                    XerrPrio:AddDotTicks(frame, spell, key, stats, tl, vtCastTime, duration)

                    _G[frame]:Show()
                end

            end

            if self.show then
                XerrPrioBars:Show()
            else
                XerrPrioBars:Hide()
            end
        end

        -- Icons
        XerrPrio.nextSpell = XerrPrio:GetNextSpell(guid, uvls, uvlsDuration, vtCastTime)
        if self.icons.enabled then
            XerrPrioIconsIcon:SetTexture(XerrPrio.nextSpell[1].icon)
            XerrPrioIconsIcon2:SetTexture(XerrPrio.nextSpell[2].icon)
            XerrPrioIcons:Show()
        end
    end

end)

--------------------
--- Options open animation
--------------------

XerrPrio.OptionsAnim:Hide()
XerrPrio.OptionsAnim.start = GetTime()

XerrPrio.OptionsAnim.duration = 18
XerrPrio.OptionsAnim.tl = XerrPrio.OptionsAnim.duration

XerrPrio.OptionsAnim:SetScript("OnShow", function(self)
    self.start = GetTime()
    self.tl = self.duration
    self.timeSinceLastUpdate = 0;
end)

XerrPrio.OptionsAnim:SetScript("OnUpdate", function(self, elapsed)

    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

    if self.timeSinceLastUpdate >= 0.05 then
        self.timeSinceLastUpdate = 0;

        if XerrPrioDB.configMode then

            self.tl = self.tl - 0.05
            local vtCastTime = select(3, XerrPrio:GetSpellInfo(XerrPrio.bars.spells.vt.id))

            if self.tl <= 0 then
                self.tl = self.duration
            end

            for _, spell in next, XerrPrio.bars.spells do
                local frame = spell.frame:GetName()

                _G[frame .. 'ArrowsUp1']:Hide()
                _G[frame .. 'ArrowsUp2']:Hide()
                _G[frame .. 'ArrowsUp3']:Hide()

                if self.tl <= 18 then
                    _G[frame .. 'ArrowsUp1']:Show()
                end
                if self.tl <= 10 then
                    _G[frame .. 'ArrowsUp2']:Show()
                end
                if self.tl <= 5 then
                    _G[frame .. 'ArrowsUp3']:Show()
                end

                _G[frame .. 'ArrowsDown1']:Hide()
                _G[frame .. 'ArrowsDown2']:Hide()
                _G[frame .. 'ArrowsDown3']:Hide()

                if self.tl <= 18 then
                    _G[frame .. 'ArrowsDown1']:Show()
                end
                if self.tl <= 10 then
                    _G[frame .. 'ArrowsDown2']:Show()
                end
                if self.tl <= 5 then
                    _G[frame .. 'ArrowsDown3']:Show()
                end

                if self.tl == self.duration then
                    _G[frame .. 'RefreshBar']:SetWidth(XerrPrioDB.barWidth * (XerrPrioDB.refreshMinDuration / self.duration))
                end

                _G[frame .. 'Bar']:SetWidth(XerrPrioDB.barWidth * (self.tl / self.duration))
                _G[frame .. 'TextsTimeLeft']:SetText(floor(self.tl))

                if _G[frame .. 'RefreshBar']:GetWidth() > _G[frame .. 'Bar']:GetWidth() then
                    _G[frame .. 'RefreshBar']:SetWidth(_G[frame .. 'Bar']:GetWidth())
                end

                if spell.id == XerrPrio.bars.spells.vt.id then

                    if spell.ticks[2] then
                        spell.castTimeTick:SetPoint("LEFT", spell.ticks[2], "LEFT", 0, 0)
                        _G[spell.castTimeTick:GetName() .. 'Tick']:SetWidth(XerrPrioDB.barWidth * vtCastTime / XerrPrio.OptionsAnim.duration)

                        if self.tl >= 3 and self.tl <= 3 + vtCastTime then
                            _G[spell.castTimeTick:GetName() .. 'Tick']:SetVertexColor(1, 1, 1, 0.5)
                        else
                            _G[spell.castTimeTick:GetName() .. 'Tick']:SetVertexColor(0, 0, 0, 0.5)
                        end

                        spell.castTimeTick:Show()
                    end

                end

            end

        end
    end

end)

--------------------
--- Helpers
--------------------

---SpellCast - get swp/vt dot stats on cast, and save last swd cast time
---@param id number
---@param guid number
function XerrPrio:SpellCast(id, guid)

    if id == self.icons.spells.swd.id then
        self.icons.spells.swd.lastCastTime = GetTime()
        return
    end

    for key, spell in next, self.bars.spells do
        if id == spell.id then

            if not self.dotStats[guid] then
                self.dotStats[guid] = {}
            end

            if not self.dotStats[guid][key] then
                self.dotStats[guid][key] = {
                    uvls = false,
                    uvlsExpirationTime = 0,
                    duration = self.durationFallback,
                    interval = self.intervalFallback,
                    dps = 0
                }
            end

            self.dotStats[guid][key].uvls = self:PlayerHasProc(self.buffs.spells.uvls.id)

            self.dotStats[guid][key].dps, _, self.dotStats[guid][key].duration = self:GetSpellDamage(spell.id)

            self.dotStats[guid][key].uvlsExpirationTime = GetTime() + self.dotStats[guid][key].duration

            XerrPrio.Worker.dotScanner.spellId = id
            XerrPrio.Worker.dotScanner.enabled = true
            XerrPrio.Worker.dotScanner.guid = guid

            return
        end
    end
end

---GetSpellInfo - get spell name, icon, and cast time
---@param id number
---@return table name, icon, castTime (ms)
function XerrPrio:GetSpellInfo(id)
    local name, _, icon, _, _, _, castTime = GetSpellInfo(id)
    return name, icon, castTime / 1000
end

---GetLowestProcTime - get lowest temporary buff/proc duration
---@return number duration
function XerrPrio:GetLowestProcTime(uvls)

    local lowestTime = 100

    for i = 1, 40 do
        local name, _, _, _, _, _, expirationTime, _, _, _, spellId = UnitBuff("player", i)
        if name then
            if uvls then
                if spellId == self.buffs.spells.uvls.id then
                    return expirationTime - GetTime()
                end
            else
                for _, spell in next, self.buffs.spells do
                    if spellId == spell.id then
                        if expirationTime - GetTime() < lowestTime then
                            lowestTime = expirationTime - GetTime()
                        end
                    end
                end
            end
        end
    end

    if lowestTime > 0 and lowestTime ~= 100 then
        return lowestTime
    end
    return 0
end

---GetDebuffInfo - get target debuff timeleft, and duration
---@param id number
---@return table timeLeft, interval, duration
function XerrPrio:GetDebuffInfo(id)
    if not UnitExists('target') then
        return 0, 0, 0
    end
    for i = 1, 40 do
        local _, _, _, _, _, duration, expirationTime, unitCaster, _, _, spellId = UnitDebuff('target', i)
        if spellId == id and unitCaster == "player" then
            local tl = expirationTime - GetTime()
            return tl, tl / duration, duration
        end
    end
    return 0, 0, 0
end

---PlayerHasProc - check if player has a proc/buff
---@param procId number id of proc
---@return table boolean, duration
function XerrPrio:PlayerHasProc(procId)
    for i = 1, 40 do
        local _, _, _, _, _, _, expirationTime, unitCaster, _, _, spellId = UnitBuff("player", i)
        if spellId == procId and unitCaster == "player" then
            return true, expirationTime - GetTime()
        end
    end
    return false, 0
end

---GetWAIconColor - check if spell is next, next2, inRange, and get icon. Helper for wa
---@param spell number id of spell
---@return table r, g, b, a, next, next2, inRange, icon
function XerrPrio:GetWAIconColor(spell)

    if not UnitExists('target') or self.paused then
        return 1, 1, 1, 1, false, false, false, self.hp_path_icon .. 'offcd'
    end

    local inRange = false
    local isNext = self.nextSpell[1].id == spell.id
    local isNext2 = self.nextSpell[2].id == spell.id
    local icon = 'center'

    if spell.id == self.icons.spells.halo.id then
        inRange = false
        if HaloPro_MainFrame and HaloPro_MainFrame.texture:GetTexture() then
            local hpt = HaloPro_MainFrame.texture:GetTexture()
            if hpt == self.hp_path .. 'left' then
                icon = 'left'
            elseif hpt == self.hp_path .. 'mid_left' then
                icon = 'mid_left'
            elseif hpt == self.hp_path .. 'center' then
                inRange = true
                icon = 'center'
            elseif hpt == self.hp_path .. 'mid_right' then
                icon = 'mid_right'
            elseif hpt == self.hp_path .. 'right' then
                icon = 'right'
            end
        end
    else
        inRange = IsSpellInRange(spell.spellBookID, "target") == 1
    end

    icon = self.hp_path_icon .. icon

    if inRange then
        if isNext then
            return 1, 1, 1, 1, isNext, isNext2, inRange, icon
        elseif isNext2 then
            return 1, 1, 1, 1, isNext, isNext2, inRange, icon
        else
            return 0.7, 0.7, 0.7, 1, isNext, isNext2, inRange, icon
        end
    end

    -- out of range
    return 1, 0.2, 0.2, 1, isNext, isNext2, inRange, icon
end

---PopulateSpellBookID - get spellbook ids for all player spells
function XerrPrio:PopulateSpellBookID()
    self.spellBookSpells = {}

    local i = 1
    while true do
        local spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if not spellName then
            do
                break
            end
        end
        self.spellBookSpells[spellName] = i
        i = i + 1
    end

    for _, spell in next, self.icons.spells do
        spell.spellBookID = self.spellBookSpells[spell.name] or false
    end
end

---GetNextSpell - get next spell for priority casting
---@param guid number
---@param uvls boolean
---@param uvlsDuration number
---@param vtCastTime number
---@return table next and next2 spell to cast
function XerrPrio:GetNextSpell(guid, uvls, uvlsDuration, vtCastTime)

    local prio = {}

    -- uvls cases
    if uvls then
        -- swd on 3 orbs - jackpot
        if self:GetShadowOrbs() == 3 then
            -- todo add slot machine sound here
            tinsert(prio, self.icons.spells.dp)
        end
        -- vt and swp if already exists
        if self.dotStats[guid] and self.dotStats[guid].vt and not self.dotStats[guid].vt.uvls then
            tinsert(prio, self.icons.spells.vt)
        elseif self.dotStats[guid] and self.dotStats[guid].swp and not self.dotStats[guid].swp.uvls then
            tinsert(prio, self.icons.spells.swp)
        else
            -- vt and swp if it doesnt exist
            if uvlsDuration >= vtCastTime + 0.2 then
                tinsert(prio, self.icons.spells.vt)
            end
            tinsert(prio, self.icons.spells.swp)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- refresh swp or vt, only if mindblast is on cd and we dont have dp up and next dots will be more powerful
    if self:GetSpellCooldown(self.icons.spells.mb.id) > 1.5 and self:GetDebuffInfo(self.icons.spells.dp.id) == 0 then

        if self.dotStats[guid] then
            if self.dotStats[guid].vt then
                if self:GetSpellDamage(self.icons.spells.vt.id) >= self.dotStats[guid].vt.dps * (1 + XerrPrioDB.minDotDpsIncrease / 100) then
                    if self.lowestProcTime > 0.3 and self.lowestProcTime <= XerrPrioDB.refreshMinDuration then
                        if not self.dotStats[guid].vt.uvls then
                            tinsert(prio, self.icons.spells.vt)
                        end
                    end
                end
            end
            if self.dotStats[guid].swp then
                if self:GetSpellDamage(self.icons.spells.swp.id) >= self.dotStats[guid].swp.dps * (1 + XerrPrioDB.minDotDpsIncrease / 100) then
                    if self.lowestProcTime > 0.3 + vtCastTime and self.lowestProcTime <= XerrPrioDB.refreshMinDuration then
                        if not self.dotStats[guid].swp.uvls then
                            tinsert(prio, self.icons.spells.swp)
                        end
                    end
                end
            end
        end

    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- halo when off cooldown and no dp
    if self.icons.spells.halo.spellBookID and self:GetSpellCooldown(self.icons.spells.halo.id) == 0 then
        if self:GetDebuffInfo(self.icons.spells.dp.id) == 0 then
            tinsert(prio, self.icons.spells.halo)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- devouring plague if 3 orbs
    if self:GetShadowOrbs() == 3 then
        tinsert(prio, self.icons.spells.dp)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- mindblast and dp after if we'll have 3 orbs after mindblast
    if self:GetSpellCooldown(self.icons.spells.mb.id) <= self:GetGCD() then
        tinsert(prio, self.icons.spells.mb)
        if self:GetShadowOrbs() == 2 then
            tinsert(prio, self.icons.spells.dp)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- shadow word: death
    if self:SWDPhase() and self:GetSpellCooldown(self.icons.spells.swd.id) == 0 then
        if self:GetDebuffInfo(self.icons.spells.dp.id) >= 0.2 then
            if GetTime() - self.icons.spells.swd.lastCastTime >= 8 then
                tinsert(prio, self.icons.spells.swd)
            elseif self:GetSpellCooldown(self.icons.spells.mb.id) == 0 then
                tinsert(prio, self.icons.spells.mb)
                if self:GetShadowOrbs() == 2 then
                    tinsert(prio, self.icons.spells.dp)
                end
            else
                tinsert(prio, self.icons.spells.mf)
            end
        else
            tinsert(prio, self.icons.spells.swd)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- insanity
    if self:GetDebuffInfo(self.icons.spells.dp.id) > 0 then
        tinsert(prio, self.icons.spells.mf)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- shadowfiend
    if self:GetSpellCooldown(self.icons.spells.shadowfiend.id) == 0 then
        tinsert(prio, self.icons.spells.shadowfiend)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- vt
    if self:GetDebuffInfo(self.icons.spells.vt.id) >= 0 then
        if self:GetDebuffInfo(self.icons.spells.vt.id) < vtCastTime then
            tinsert(prio, self.icons.spells.vt)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- swp
    if self:GetDebuffInfo(self.icons.spells.swp.id) < 0.8 then
        tinsert(prio, self.icons.spells.swp)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- mind flay if nothing else is available
    tinsert(prio, self.icons.spells.mf)

    if tablesize(prio) == 2 then
        return prio
    end

    -- mind blast 2nd if cd <= 1s
    if prio[1] and prio[1].id ~= self.icons.spells.mb.id and self:GetSpellCooldown(self.icons.spells.mb.id) <= 1 then
        if prio[2] and prio[2].id ~= self.icons.spells.dp.id then
            prio[2] = self.icons.spells.mb
        end
    end

    -- if we dont have a 2nd spell by now add mb if cooldown shorter than halo cd
    -- else add mf
    if tablesize(prio) == 1 then
        if self:GetSpellCooldown(self.icons.spells.mb.id) < self:GetSpellCooldown(self.icons.spells.halo.id) then
            tinsert(prio, self.icons.spells.mb)
        end
        tinsert(prio, self.icons.spells.mf)
    end

    return prio
end

---TimeSinceLastSWD - get time since last swd cast, to track icd
---@return string time, formatted
function XerrPrio:TimeSinceLastSWD()
    local t = GetTime() - self.icons.spells.swd.lastCastTime
    local icd = 8 - t
    if icd > 0 and self:GetSpellCooldown(self.icons.spells.swd.id) == 0 then
        return 'i' .. sformat(icd > 2 and "%d" or "%.1f", icd)
    else
        local cd = self:GetSpellCooldown(self.icons.spells.swd.id)
        if cd == 0 then
            return ''
        end
        return sformat(icd > 2 and "%d" or "%.1f", cd)
    end
end

---GetSpellCooldown - get a spell's cooldown
---@param id number id of spell
---@return number cooldown (s)
function XerrPrio:GetSpellCooldown(id)
    local start, duration, enabled = GetSpellCooldown(id);
    if enabled == 0 then
        return 0 --active, like pom
    elseif start > 0 and duration > 0 then
        if start + duration - GetTime() <= self:GetGCD() + 0.1 then
            return 0
        end
        return start + duration - GetTime()
    end
    return 0
end

---GetGCD - get global cooldown
---@return number global cooldown (s)
function XerrPrio:GetGCD()
    local start, duration = GetSpellCooldown(61304);
    if start > 0 and duration > 0 then
        return start + duration - GetTime()
    end
    return 0
end

---GetShadowOrbs - get number of shadow orbs
---@return number number of shadow orbs
function XerrPrio:GetShadowOrbs()
    return UnitPower("player", SPELL_POWER_SHADOW_ORBS)
end

---SWDPhase - check if target has 20% or less hp
---@return boolean swd phase
function XerrPrio:SWDPhase()
    if not UnitExists('target') then
        return false
    end
    return UnitHealth('target') / UnitHealthMax('target') <= 0.2
end

---replace - simple str replace
---@param text string text to search in
---@param search string text to look for
---@param replace string text to replace with
---@return string text after replace
function XerrPrio:replace(text, search, replace)
    if search == replace then
        return text
    end
    local searchedtext = ""
    local textleft = text
    while (strfind(textleft, search, 1, true)) do
        searchedtext = searchedtext .. strsub(textleft, 1, strfind(textleft, search, 1, true) - 1) .. replace
        textleft = strsub(textleft, strfind(textleft, search, 1, true) + strlen(search))
    end
    if (strlen(textleft) > 0) then
        searchedtext = searchedtext .. textleft
    end
    return searchedtext
end

---GetSpellDamage - get swp/vt dps from tooltip
---@param id number
---@return table dps, damage, duration
function XerrPrio:GetSpellDamage(id)

    XerrPrioTooltipFrame:SetOwner(UIParent, "ANCHOR_NONE")
    XerrPrioTooltipFrame:SetSpellByID(id);
    local tooltipDescription = XerrPrioTooltipFrameTextLeft4:GetText();
    local totalDmg, duration, dps = 0, 0, 0

    if strfind(tooltipDescription, "Cooldown remaining") then
        tooltipDescription = XerrPrioTooltipFrameTextLeft5:GetText()
    end

    tooltipDescription = self:replace(tooltipDescription, ',', '')

    if id == self.icons.spells.swp.id then
        _, _, totalDmg, duration = strfind(tooltipDescription, "(%S+) Shadow damage over (%S+)")
    end
    if id == self.icons.spells.vt.id then
        _, _, totalDmg, duration = strfind(tooltipDescription, "Causes (%S+) Shadow damage over (%S+)")
    end

    dps = tonumber(totalDmg) / tonumber(duration)

    return dps, tonumber(totalDmg), tonumber(duration)

end

function XerrPrio:AddArrows(frame, uvls, refreshPower, currentDps, stats)

    _G[frame .. 'ArrowsUp1']:Hide()
    _G[frame .. 'ArrowsUp2']:Hide()
    _G[frame .. 'ArrowsUp3']:Hide()
    -- down
    _G[frame .. 'ArrowsDown1']:Hide()
    _G[frame .. 'ArrowsDown2']:Hide()
    _G[frame .. 'ArrowsDown3']:Hide()

    if stats.uvls then
        return
    else
        if uvls then
            _G[frame .. 'ArrowsUp1']:Show()
            _G[frame .. 'ArrowsUp2']:Show()
            _G[frame .. 'ArrowsUp3']:Show()
        else
            if refreshPower >= XerrPrioDB.minDotDpsIncrease then
                --up
                _G[frame .. 'ArrowsUp1']:Show()
                if refreshPower >= 10 and refreshPower < 20 then
                    _G[frame .. 'ArrowsUp1']:Show()
                    _G[frame .. 'ArrowsUp2']:Show()
                elseif refreshPower >= 20 then
                    _G[frame .. 'ArrowsUp1']:Show()
                    _G[frame .. 'ArrowsUp2']:Show()
                    _G[frame .. 'ArrowsUp3']:Show()
                end
            else
                -- down
                if currentDps < stats.dps then
                    if refreshPower < 0 and refreshPower > -10 then
                        _G[frame .. 'ArrowsDown1']:Show()
                    elseif refreshPower <= -10 and refreshPower > -20 then
                        _G[frame .. 'ArrowsDown1']:Show()
                        _G[frame .. 'ArrowsDown2']:Show()
                    elseif refreshPower <= -20 then
                        _G[frame .. 'ArrowsDown1']:Show()
                        _G[frame .. 'ArrowsDown2']:Show()
                        _G[frame .. 'ArrowsDown3']:Show()
                    end
                end
            end
        end
    end
end

function XerrPrio:AddLightningBar(frame, stats, perc, spellId)
    _G[frame .. 'BarLightning']:Hide()

    if stats.uvls then
        _G[frame .. 'BarLightning']:SetWidth(XerrPrioDB.barWidth * perc)
        _G[frame .. 'BarLightning']:SetVertexColor(1.3 - rand(), 1.3 - rand(), 1, rand())
        if spellId == self.bars.spells.swp.id then
            _G[frame .. 'BarLightning']:SetTexCoord(0, perc, 0, 1)
        else
            _G[frame .. 'BarLightning']:SetTexCoord(1, 1 - perc, 0, 1)
        end
        _G[frame .. 'BarLightning']:Show()
    end
end

function XerrPrio:AddRefreshBar(frame, refreshPower, color, uvls, duration, perc, tl, stats, spellId, vtCastTime)

    _G[frame .. 'RefreshSpark']:Hide()
    _G[frame .. 'RefreshBar']:Hide()

    if refreshPower >= XerrPrioDB.minDotDpsIncrease or uvls then

        if XerrPrio.lowestProcTime > 0 then

            if uvls then
                color = { r = 1, g = 0.843, b = 0, a = 1 } -- gold
            else
                if stats.uvls or (XerrPrio.lowestProcTime <= 0.3 and spellId == self.bars.spells.swp.id) or
                        (XerrPrio.lowestProcTime <= 0.3 + vtCastTime and spellId == self.bars.spells.vt.id) then
                    -- hide refresh if lowestProcTime <= 0.3 for swp and 0.3+vt cast for vt
                    return
                end
            end

            if XerrPrio.lowestProcTime <= XerrPrioDB.refreshMinDuration or uvls then
                _G[frame .. 'RefreshBar']:SetVertexColor(color.r, color.g, color.b, color.a)
            end

            if XerrPrioDB.barWidth * (XerrPrio.lowestProcTime / duration) > XerrPrioDB.barWidth * perc then
                _G[frame .. 'RefreshBar']:SetWidth(XerrPrioDB.barWidth * perc)
            else
                _G[frame .. 'RefreshBar']:SetWidth(XerrPrioDB.barWidth * (XerrPrio.lowestProcTime / duration))
            end
            _G[frame .. 'RefreshSpark']:Show()
            _G[frame .. 'RefreshBar']:Show()

            if not uvls then
                if (spellId == self.bars.spells.swp.id and tl < 0.3) or
                        (spellId == self.bars.spells.vt.id and tl < vtCastTime + 0.3) then
                    _G[frame .. 'RefreshSpark']:Hide()
                    _G[frame .. 'RefreshBar']:Hide()
                end
            end

        end

    end

    -- refresh before last tick
    if tl <= stats.interval and not stats.uvls then
        _G[frame .. 'RefreshBar']:SetVertexColor(color.r, color.g, color.b, color.a)
        _G[frame .. 'RefreshBar']:SetWidth(XerrPrioDB.barWidth * (tl / duration))
        _G[frame .. 'RefreshSpark']:Show()
        _G[frame .. 'RefreshBar']:Show()
    end
end

function XerrPrio:AddUVLSIcon(frame, stats, uvls, key)
    if uvls then
        _G[frame .. 'Icon']:SetTexture(XerrPrio.buffs.spells.uvls.icon)

        if stats.uvls then
            _G[frame .. 'Icon']:SetDesaturated(false)
        else
            _G[frame .. 'Icon']:SetDesaturated(true)
        end
    else
        if stats.uvls then
            _G[frame .. 'Icon']:SetTexture(XerrPrio.buffs.spells.uvls.icon)
            _G[frame .. 'Icon']:SetDesaturated(false)
        else
            _G[frame .. 'Icon']:SetTexture(XerrPrio.icons.spells[key].icon)
            _G[frame .. 'Icon']:SetDesaturated(false)
        end
    end
end

function XerrPrio:AddDotTicks(frame, spell, key, stats, tl, vtCastTime, duration)
    for i = 1, #spell.ticks do
        spell.ticks[i]:Hide()
    end

    if stats.uvls then
        if spell.id == XerrPrio.bars.spells.vt.id then
            _G[spell.castTimeTick:GetName() .. 'Tick']:Hide()
        end
        return
    end

    if XerrPrioDB[key].showTicks then

        local ticks = floor(stats.duration / stats.interval + 0.5)
        local numTicks = XerrPrioDB[key].showOnlyLastTick and 2 or ticks
        if ticks > 0 then
            for i = 1, numTicks do
                spell.ticks[i]:SetPoint("TOPLEFT", _G[frame], "TOPLEFT", (XerrPrioDB.barWidth / ticks) * (i - 1), 0)
                spell.ticks[i]:Show()
            end
        end

        if spell.id == XerrPrio.bars.spells.vt.id then

            _G[spell.castTimeTick:GetName() .. 'Tick']:SetWidth(XerrPrioDB.barWidth * vtCastTime / duration)

            if tl >= stats.interval and tl <= stats.interval + vtCastTime then
                _G[spell.castTimeTick:GetName() .. 'Tick']:SetVertexColor(1, 1, 1, 0.5)
            else
                _G[spell.castTimeTick:GetName() .. 'Tick']:SetVertexColor(0, 0, 0, 0.5)
            end

        end
    end
end


--------------------
--- Slash Commands
--------------------

SLASH_XERRPRIO1, SLASH_XERRPRIO2 = "/xerrprio", "/xprio";
function SlashCmdList.XERRPRIO()
    InterfaceOptionsFrame_OpenToCategory('xerrprio')
end

--------------------
--- Options
--------------------

---CreateOptions - create options for game's interface options
---@return table options
function XerrPrio:CreateOptions()

    return {
        type = "group",
        name = "XerrPrio Options",
        args = {
            d = {
                type = "description",
                name = "Shadow priest helper",
                order = 0,
            },
            configMode = {
                order = 1,
                name = "Config mode",
                desc = "Enable config mode and make frames visible",
                type = "toggle",
                width = "full",
                set = function(_, val)
                    XerrPrioDB.configMode = val
                    XerrPrio:UpdateConfig()
                end,
                get = function()
                    return XerrPrioDB.configMode
                end
            },
            general = {
                type = "group",
                name = "General",
                order = 2,
                args = {
                    procTime = {
                        order = 1,
                        type = "range",
                        name = "Buff time remaining for refresh",
                        desc = "Shows a bar that helps you refresh a dot N seconds before a buff fades",
                        min = 1,
                        max = 10,
                        step = 0.5,
                        get = function()
                            return XerrPrioDB.refreshMinDuration
                        end,
                        set = function(_, val)
                            XerrPrioDB.refreshMinDuration = val
                            XerrPrio:UpdateConfig()
                        end,

                    },
                    minDotDps = {
                        order = 1,
                        type = "range",
                        name = "Minimum dot dps increase (%)",
                        desc = "How much more powerful should the new dot be in order for the refresh indicator to show",
                        min = 1,
                        max = 100,
                        step = 1,
                        get = function()
                            return XerrPrioDB.minDotDpsIncrease
                        end,
                        set = function(_, val)
                            XerrPrioDB.minDotDpsIncrease = val
                            XerrPrio:UpdateConfig()
                        end,

                    },
                },
            },
            dotBars = {
                type = "group",
                name = "Dot Bars",
                order = 3,
                args = {
                    dotBars = {
                        order = 1,
                        name = "Enable",
                        desc = "Show bars for Shadow Word:Pain and Vampiric Touch spells",
                        type = "toggle",
                        width = "full",
                        set = function(_, val)
                            XerrPrioDB.bars = val
                            XerrPrio:UpdateConfig()
                        end,
                        get = function()
                            return XerrPrioDB.bars
                        end
                    },
                    barsWidth = {
                        order = 2,
                        type = "range",
                        name = "Bar width",
                        desc = "The width of the dot bars",
                        min = 260,
                        max = 360,
                        step = 1,
                        disabled = function()
                            return not XerrPrioDB.bars
                        end,
                        get = function()
                            return XerrPrioDB.barWidth
                        end,
                        set = function(_, val)
                            XerrPrioDB.barWidth = val
                            XerrPrio:UpdateConfig()
                        end,

                    },
                    barBackgroundColor = {
                        order = 3,
                        name = "Bar Background",
                        desc = "The background of the dot bars",
                        type = "color",
                        hasAlpha = true,
                        disabled = function()
                            return not XerrPrioDB.bars
                        end,
                        get = function()
                            local c = XerrPrioDB.barBackgroundColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            XerrPrioDB.barBackgroundColor = { r = r, g = g, b = b, a = a }
                            XerrPrio:UpdateConfig()
                        end,
                    },
                    swp = {
                        order = 4,
                        type = "group",
                        name = "Shadow Word: Pain",
                        inline = true,
                        args = {
                            enable = {
                                order = 1,
                                name = "Enable",
                                desc = "Enable Shadow Word: Pain dot bar",
                                type = "toggle",
                                width = "full",
                                disabled = function()
                                    return not XerrPrioDB.bars
                                end,
                                set = function(_, val)
                                    XerrPrioDB.swp.enabled = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.swp.enabled
                                end
                            },
                            icon = {
                                order = 2,
                                name = "Show icon",
                                desc = "Show Shadow Word: Pain icon",
                                type = "toggle",
                                width = "full",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.bars
                                end,
                                set = function(_, val)
                                    XerrPrioDB.swp.showIcon = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.swp.showIcon
                                end
                            },
                            textColor = {
                                order = 3,
                                name = "Text color",
                                desc = "Color of the Shadow Word: Pain bar text",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.bars
                                end,
                                get = function()
                                    local c = XerrPrioDB.swp.textColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.swp.textColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            barColor = {
                                order = 4,
                                name = "Bar color",
                                desc = "Color of the Shadow Word: Pain bar",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.bars
                                end,
                                get = function()
                                    local c = XerrPrioDB.swp.barColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.swp.barColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetTextColor = {
                                order = 5,
                                name = "Reset text color",
                                desc = "Reset Shadow Word: Pain bar text color to the default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.bars
                                end,
                                func = function()
                                    XerrPrioDB.swp.textColor = XerrPrio.colors.white
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetBarColor = {
                                order = 6,
                                name = "Reset bar color",
                                desc = "Reset Shadow Word: Pain bar color to the default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.bars
                                end,
                                func = function()
                                    XerrPrioDB.swp.barColor = XerrPrio.colors.swpDefault
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            ticks = {
                                order = 7,
                                name = "Show ticks",
                                desc = "Show dot tick indicators",
                                type = "toggle",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.bars
                                end,
                                set = function(_, val)
                                    XerrPrioDB.swp.showTicks = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.swp.showTicks
                                end
                            },
                            ticksOnlyLast = {
                                order = 8,
                                name = "Only last tick",
                                desc = "Show only last dot tick indicator",
                                type = "toggle",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.swp.showTicks or not XerrPrioDB.bars
                                end,
                                set = function(_, val)
                                    XerrPrioDB.swp.showOnlyLastTick = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.swp.showOnlyLastTick
                                end
                            },
                            tickColor = {
                                order = 9,
                                name = "Tick color",
                                desc = "Color of the dot tick indicators",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.swp.showTicks or not XerrPrioDB.bars
                                end,
                                get = function()
                                    local c = XerrPrioDB.swp.tickColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.swp.tickColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            tickWidth = {
                                order = 10,
                                type = "range",
                                name = "Tick width",
                                desc = "The width of the dot tick indicators",
                                min = 1,
                                max = 5,
                                step = 1,
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.swp.showTicks or not XerrPrioDB.bars
                                end,
                                get = function()
                                    return XerrPrioDB.swp.tickWidth
                                end,
                                set = function(_, val)
                                    XerrPrioDB.swp.tickWidth = val
                                    XerrPrio:UpdateConfig()
                                end,

                            },
                            refreshTextColor = {
                                order = 11,
                                name = "Refresh text color",
                                desc = "Color of the Shadow Word: Pain refresh text",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.bars
                                end,
                                get = function()
                                    local c = XerrPrioDB.swp.refreshTextColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.swp.refreshTextColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            refreshBarColor = {
                                order = 12,
                                name = "Refresh bar color",
                                desc = "Color of the Shadow Word: Pain refresh bar",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.bars
                                end,
                                get = function()
                                    local c = XerrPrioDB.swp.refreshBarColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.swp.refreshBarColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetRefreshTextColor = {
                                order = 13,
                                name = "Reset refresh text color",
                                desc = "Reset refresh text color to the default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.bars
                                end,
                                func = function()
                                    XerrPrioDB.swp.refreshTextColor = XerrPrio.colors.white
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetRefreshBarColor = {
                                order = 14,
                                name = "Reset refresh bar color",
                                desc = "Reset refresh bar color to the default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled or not XerrPrioDB.bars
                                end,
                                func = function()
                                    XerrPrioDB.swp.refreshBarColor = XerrPrio.colors.swpDefault
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                        }
                    },
                    vt = {
                        order = 5,
                        type = "group",
                        name = "Vampiric Embrace",
                        inline = true,
                        args = {
                            enable = {
                                order = 1,
                                name = "Enable",
                                desc = "Enable Vampirc Touch dot ar",
                                type = "toggle",
                                width = "full",
                                disabled = function()
                                    return not XerrPrioDB.bars
                                end,
                                set = function(_, val)
                                    XerrPrioDB.vt.enabled = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.vt.enabled
                                end
                            },
                            icon = {
                                order = 2,
                                name = "Show icon",
                                desc = "Show Vampirc Touch Icon",
                                type = "toggle",
                                width = "full",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.bars
                                end,
                                set = function(_, val)
                                    XerrPrioDB.vt.showIcon = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.vt.showIcon
                                end
                            },
                            textColor = {
                                order = 3,
                                name = "Text color",
                                desc = "Color of the Vampirc Touch bar text",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.bars
                                end,
                                get = function()
                                    local c = XerrPrioDB.vt.textColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.vt.textColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            barColor = {
                                order = 4,
                                name = "Bar color",
                                desc = "Color of the Vampirc Touch bar",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.bars
                                end,
                                get = function()
                                    local c = XerrPrioDB.vt.barColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.vt.barColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetTextColor = {
                                order = 5,
                                name = "Reset text color",
                                desc = "Reset Vampirc Touch text color to the default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.bars
                                end,
                                func = function()
                                    XerrPrioDB.vt.textColor = XerrPrio.colors.white
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetBarColor = {
                                order = 6,
                                name = "Reset bar color",
                                desc = "Reset Vampirc Touch bar color to the default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.bars
                                end,
                                func = function()
                                    XerrPrioDB.vt.barColor = XerrPrio.colors.vtDefault
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            ticks = {
                                order = 7,
                                name = "Show ticks",
                                desc = "Show dot tick indicators",
                                type = "toggle",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.bars
                                end,
                                set = function(_, val)
                                    XerrPrioDB.vt.showTicks = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.vt.showTicks
                                end
                            },
                            ticksOnlyLast = {
                                order = 8,
                                name = "Only last tick",
                                desc = "Show only last dot tick indicator",
                                type = "toggle",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.vt.showTicks or not XerrPrioDB.bars
                                end,
                                set = function(_, val)
                                    XerrPrioDB.vt.showOnlyLastTick = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.vt.showOnlyLastTick
                                end
                            },
                            tickColor = {
                                order = 9,
                                name = "Tick color",
                                desc = "Color of the dot tick indicators",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.vt.showTicks or not XerrPrioDB.bars
                                end,
                                get = function()
                                    local c = XerrPrioDB.vt.tickColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.vt.tickColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            tickWidth = {
                                order = 10,
                                type = "range",
                                name = "Tick width",
                                desc = "The width of the dot tick indicators",
                                min = 1,
                                max = 5,
                                step = 1,
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.vt.showTicks or not XerrPrioDB.bars
                                end,
                                get = function()
                                    return XerrPrioDB.vt.tickWidth
                                end,
                                set = function(_, val)
                                    XerrPrioDB.vt.tickWidth = val
                                    XerrPrio:UpdateConfig()
                                end,

                            },
                            refreshTextColor = {
                                order = 11,
                                name = "Refresh text color",
                                desc = "Color of the Vampiric Touch refresh text",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.bars
                                end,
                                get = function()
                                    local c = XerrPrioDB.vt.refreshTextColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.vt.refreshTextColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            refreshBarColor = {
                                order = 12,
                                name = "Refresh bar color",
                                desc = "Color of the Vampiric Touch refresh bar",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.bars
                                end,
                                get = function()
                                    local c = XerrPrioDB.vt.refreshBarColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.vt.refreshBarColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetRefreshTextColor = {
                                order = 13,
                                name = "Reset refresh text color",
                                desc = "Reset refresh text color to the default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.bars
                                end,
                                func = function()
                                    XerrPrioDB.vt.refreshTextColor = XerrPrio.colors.white
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetRefreshBarColor = {
                                order = 14,
                                name = "Reset Refresh Bar Color",
                                desc = "Reset refresh bar color to the default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled or not XerrPrioDB.bars
                                end,
                                func = function()
                                    XerrPrioDB.vt.refreshBarColor = XerrPrio.colors.vtDefault
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                        }
                    }
                },
            },
            prioIcons = {
                type = "group",
                name = "Priority Icons",
                order = 4,
                args = {
                    prioIcons = {
                        order = 1,
                        name = "Enable",
                        desc = "Icons for next spell on priority list",
                        type = "toggle",
                        width = "full",
                        set = function(_, val)
                            XerrPrioDB.icons = val
                            XerrPrio:UpdateConfig()
                        end,
                        get = function()
                            return XerrPrioDB.icons
                        end
                    },
                },
            },
        }
    }

end

---UpdateConfig - update ui based on config vars
function XerrPrio:UpdateConfig()

    self.paused = not XerrPrioDB.configMode

    if XerrPrioDB.bars and XerrPrioDB.configMode then
        XerrPrioBars:Show()
    else
        XerrPrioBars:Hide()
    end

    if XerrPrioDB.icons and XerrPrioDB.configMode then
        XerrPrioIcons:Show()
    else
        XerrPrioIcons:Hide()
    end

    if XerrPrioDB.configMode then
        XerrPrio.OptionsAnim:Show()
    else
        for _, spell in next, self.bars.spells do
            spell.frame:Hide()
        end
        XerrPrio.OptionsAnim:Hide()
    end

    XerrPrioBars:SetWidth(XerrPrioDB.barWidth)
    XerrPrioBars:SetHeight(48)

    local vtCastTime = select(3, self:GetSpellInfo(self.bars.spells.vt.id))

    for key, spell in next, self.bars.spells do
        local frame = spell.frame:GetName()

        spell.frame:SetWidth(XerrPrioDB.barWidth)

        if XerrPrioDB[key].enabled then
            spell.frame:Show()
        else
            spell.frame:Hide()
        end

        if XerrPrioDB[key].showIcon then
            _G[frame .. 'Icon']:Show()
        else
            _G[frame .. 'Icon']:Hide()
        end

        local barColor = XerrPrioDB[key].barColor
        local textColor = XerrPrioDB[key].textColor
        local refreshBarColor = XerrPrioDB[key].refreshBarColor

        _G[frame .. 'RefreshBar']:SetWidth(XerrPrioDB.barWidth * (XerrPrioDB.refreshMinDuration / XerrPrio.OptionsAnim.duration))
        _G[frame .. 'RefreshBar']:SetVertexColor(refreshBarColor.r, refreshBarColor.g, refreshBarColor.b, refreshBarColor.a)
        _G[frame .. 'RefreshBar']:Show()
        _G[frame .. 'RefreshSpark']:Show()

        _G[frame .. 'Bar']:SetVertexColor(barColor.r, barColor.g, barColor.b, barColor.a)

        _G[frame .. 'TextsName']:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a)

        _G[frame .. 'TextsTimeLeft']:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a)
        _G[frame .. 'Background']:SetWidth(XerrPrioDB.barWidth)

        local background = XerrPrioDB.barBackgroundColor
        _G[frame .. 'Background']:SetVertexColor(background.r, background.g, background.b, background.a)

        for i = 1, #spell.ticks do
            spell.ticks[i]:Hide()
        end
        if XerrPrioDB[key].showTicks then
            local ticks = 6
            local numTicks = XerrPrioDB[key].showOnlyLastTick and 2 or ticks
            if ticks > 0 then
                for i = 1, numTicks do
                    if not spell.ticks[i] then
                        spell.ticks[i] = CreateFrame("Frame", "XerrPrio_" .. key .. "_BarTicks_" .. i, _G[frame], "XerrPrioBarTickTemplate")
                    end
                    spell.ticks[i]:SetPoint("TOPLEFT", _G[frame], "TOPLEFT", (XerrPrioDB.barWidth / ticks) * (i - 1), 0)
                    local tickColor = XerrPrioDB[key].tickColor
                    _G["XerrPrio_" .. key .. "_BarTicks_" .. i .. "Tick"]:SetVertexColor(tickColor.r, tickColor.g, tickColor.b, tickColor.a)
                    _G["XerrPrio_" .. key .. "_BarTicks_" .. i .. "Tick"]:SetWidth(XerrPrioDB[key].tickWidth)
                    spell.ticks[i]:Show()
                end
            end

            -- vt cast time tick
            if spell.id == XerrPrio.bars.spells.vt.id then
                if not spell.castTimeTick then
                    spell.castTimeTick = CreateFrame("Frame", "XerrPrio_" .. key .. "_BarTicks_CastTime", _G[frame], "XerrPrioBarTickTemplate")
                end
                if spell.ticks[2] then
                    spell.castTimeTick:SetPoint("LEFT", spell.ticks[2], "LEFT", 0, 0)
                    _G[spell.castTimeTick:GetName() .. 'Tick']:SetWidth(XerrPrioDB.barWidth * vtCastTime / XerrPrio.OptionsAnim.duration)
                    _G[spell.castTimeTick:GetName() .. 'Tick']:SetVertexColor(0, 0, 0, 0.5)
                    spell.castTimeTick:Show()
                end
            end

        end

    end

end