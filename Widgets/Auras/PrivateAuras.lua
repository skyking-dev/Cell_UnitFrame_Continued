---@class CUF
local CUF = select(2, ...)

---@class CUF.widgets
local W = CUF.widgets

local Cell = CUF.Cell
local I = Cell.iFuncs

local Builder = CUF.Builder
local DB = CUF.DB
local Handler = CUF.Handler
local const = CUF.constants
local menu = CUF.Menu

local PRIVATE_AURAS_MAX = 5

-------------------------------------------------
-- MARK: AddWidget
-------------------------------------------------

menu:AddWidget(const.WIDGET_KIND.PRIVATE_AURAS,
    Builder.MenuOptions.PrivateAuraOptions,
    Builder.MenuOptions.FrameLevel)

---@param button CUFUnitButton
---@param unit Unit
---@param setting OPTION_KIND
function W.UpdatePrivateAurasWidget(button, unit, setting)
    local privateAuras = button.widgets.privateAuras
    local styleTable = DB.GetCurrentWidgetTable(const.WIDGET_KIND.PRIVATE_AURAS, unit) --[[@as PrivateAuraWidgetTable]]

    if not setting or setting == const.AURA_OPTION_KIND.ORIENTATION then
        privateAuras:SetOrientation(styleTable.orientation)
    end
    if not setting or setting == const.AURA_OPTION_KIND.MAX_ICONS then
        privateAuras:SetMaxNum(styleTable.maxIcons)
    end
    if not setting or setting == const.AURA_OPTION_KIND.SHOW_COUNTDOWN_FRAME then
        privateAuras:SetShowCountdownFrame(styleTable.showCountdownFrame)
    end
    if not setting or setting == const.AURA_OPTION_KIND.SHOW_COUNTDOWN_NUMBERS then
        privateAuras:SetShowCountdownNumbers(styleTable.showCountdownNumbers)
    end

    privateAuras.Update(button)
end

Handler:RegisterWidget(W.UpdatePrivateAurasWidget, const.WIDGET_KIND.PRIVATE_AURAS)

-------------------------------------------------
-- MARK: Helpers
-------------------------------------------------

---@param self PrivateAurasWidget
---@return number
local function PrivateAuras_GetMaxAuras(self)
    local maxAuras = tonumber(self.maxAuras) or 1
    maxAuras = math.floor(maxAuras + 0.5)

    if maxAuras < 1 then
        maxAuras = 1
    elseif maxAuras > PRIVATE_AURAS_MAX then
        maxAuras = PRIVATE_AURAS_MAX
    end

    return maxAuras
end

---@param self PrivateAurasWidget
local function PrivateAuras_RemoveAllAnchors(self)
    if not (C_UnitAuras and C_UnitAuras.RemovePrivateAuraAnchor) then return end

    for i = 1, #self do
        local holder = self[i]
        if holder.auraAnchorID then
            C_UnitAuras.RemovePrivateAuraAnchor(holder.auraAnchorID)
            holder.auraAnchorID = nil
        end
    end
end

---@param self PrivateAurasWidget
---@param maxAuras number
local function PrivateAuras_UpdateHolderVisibility(self, maxAuras)
    for i = 1, #self do
        if i <= maxAuras then
            self[i]:Show()
        else
            self[i]:Hide()
        end
    end

    self:UpdateSize(maxAuras)
end

---@param self PrivateAurasWidget
---@param unit UnitToken?
local function PrivateAuras_UpdatePrivateAuraAnchor(self, unit)
    if InCombatLockdown() then
        self._pendingUnit = unit
        if not self._combatDeferred then
            self._combatDeferred = true
            local frame = CreateFrame("Frame")
            frame:RegisterEvent("PLAYER_REGEN_ENABLED")
            frame:SetScript("OnEvent", function()
                frame:UnregisterAllEvents()
                self._combatDeferred = nil
                PrivateAuras_UpdatePrivateAuraAnchor(self, self._pendingUnit)
                self._pendingUnit = nil
            end)
        end
        return
    end

    local maxAuras = PrivateAuras_GetMaxAuras(self)

    PrivateAuras_RemoveAllAnchors(self)
    self.unit = unit

    PrivateAuras_UpdateHolderVisibility(self, maxAuras)

    if not (unit and C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor) then
        return
    end

    local showCountdownFrame = self.showCountdownFrame ~= false
    local showCountdownNumbers = self.showCountdownNumbers == true

    for i = 1, maxAuras do
        local holder = self[i]
        holder.auraAnchorID = C_UnitAuras.AddPrivateAuraAnchor({
            unitToken = unit,
            auraIndex = i,
            parent = holder,
            showCountdownFrame = showCountdownFrame,
            showCountdownNumbers = showCountdownNumbers,
            iconInfo = {
                iconWidth = holder:GetWidth(),
                iconHeight = holder:GetHeight(),
                borderScale = holder:GetWidth() / 16,
                iconAnchor = {
                    point = "CENTER",
                    relativeTo = holder,
                    relativePoint = "CENTER",
                    offsetX = 0,
                    offsetY = 0,
                },
            },
        })

        if holder.cooldown then
            holder.cooldown:SetDrawSwipe(showCountdownFrame)
            holder.cooldown:SetHideCountdownNumbers(not (showCountdownFrame and showCountdownNumbers))
        end
    end
end

-------------------------------------------------
-- MARK: Setters
-------------------------------------------------

---@param self PrivateAurasWidget
---@param maxNum number
local function PrivateAuras_SetMaxNum(self, maxNum)
    self.maxAuras = maxNum
end

---@param self PrivateAurasWidget
---@param show boolean
local function PrivateAuras_SetShowCountdownFrame(self, show)
    self.showCountdownFrame = show
end

---@param self PrivateAurasWidget
---@param show boolean
local function PrivateAuras_SetShowCountdownNumbers(self, show)
    self.showCountdownNumbers = show
end

---@param self PrivateAurasWidget
---@param styleTable PrivateAuraWidgetTable
local function PrivateAuras_SetWidgetSize(self, styleTable)
    self:SetSize(styleTable.size.width, styleTable.size.height)
end

---@param self PrivateAurasWidget
---@param styleTable PrivateAuraWidgetTable
local function PrivateAuras_SetWidgetFrameLevel(self, styleTable)
    self:SetFrameLevel(styleTable.frameLevel)
    for i = 1, #self do
        self[i]:SetFrameLevel(styleTable.frameLevel + 1)
    end
end

-------------------------------------------------
-- MARK: Generics
-------------------------------------------------

---@param buttonOrWidget CUFUnitButton|PrivateAurasWidget
local function Update(buttonOrWidget)
    local button = buttonOrWidget
    if button and not button.widgets and button._owner then
        button = button._owner
    end
    if not button or not button.widgets then return end

    local privateAuras = button.widgets.privateAuras
    if not privateAuras.enabled or not button:IsVisible() then return end

    privateAuras:Show()
    privateAuras:UpdatePrivateAuraAnchor(button.states.displayedUnit)
end

---@param self PrivateAurasWidget
local function Enable(self)
    self:Show()
    self:UpdatePrivateAuraAnchor(self._owner.states.displayedUnit)
    return true
end

---@param self PrivateAurasWidget
local function Disable(self)
    self:UpdatePrivateAuraAnchor(nil)
end

-------------------------------------------------
-- MARK: Create
-------------------------------------------------

---@param button CUFUnitButton
function W:CreatePrivateAuras(button)
    ---@class PrivateAurasWidget: Frame
    local privateAuras = CreateFrame("Frame", button:GetName() .. "_PrivateAuras", button)
    button.widgets.privateAuras = privateAuras

    privateAuras:Hide()
    privateAuras:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 48)
    privateAuras.enabled = false
    privateAuras.id = const.WIDGET_KIND.PRIVATE_AURAS
    privateAuras._isSelected = false
    privateAuras._owner = button
    privateAuras.maxAuras = 1
    privateAuras.showCountdownFrame = true
    privateAuras.showCountdownNumbers = false

    privateAuras.Update = Update
    privateAuras.Enable = Enable
    privateAuras.Disable = Disable

    privateAuras.SetEnabled = W.SetEnabled
    privateAuras._SetIsSelected = W.SetIsSelected
    privateAuras.SetPosition = W.SetRelativePosition
    privateAuras.SetWidgetSize = PrivateAuras_SetWidgetSize
    privateAuras.SetWidgetFrameLevel = PrivateAuras_SetWidgetFrameLevel
    privateAuras.SetOrientation = I.Cooldowns_SetOrientation_WithSpacing
    privateAuras.UpdateSize = I.Cooldowns_UpdateSize_WithSpacing
    privateAuras.SetMaxNum = PrivateAuras_SetMaxNum
    privateAuras.SetShowCountdownFrame = PrivateAuras_SetShowCountdownFrame
    privateAuras.SetShowCountdownNumbers = PrivateAuras_SetShowCountdownNumbers
    privateAuras.UpdatePrivateAuraAnchor = PrivateAuras_UpdatePrivateAuraAnchor

    privateAuras._SetSize = privateAuras.SetSize
    function privateAuras:SetSize(width, height)
        privateAuras.width = width
        privateAuras.height = height
        for i = 1, #privateAuras do
            privateAuras[i]:SetSize(width, height)
        end
        PrivateAuras_UpdateHolderVisibility(privateAuras, PrivateAuras_GetMaxAuras(privateAuras))
        privateAuras:UpdatePrivateAuraAnchor(privateAuras.unit)
    end

    for i = 1, PRIVATE_AURAS_MAX do
        local holder = CreateFrame("Frame", nil, privateAuras)
        privateAuras[i] = holder
    end

    privateAuras:SetOrientation(const.GROWTH_ORIENTATION.LEFT_TO_RIGHT)
    privateAuras:SetSize(25, 25)
end

W:RegisterCreateWidgetFunc(const.WIDGET_KIND.PRIVATE_AURAS, W.CreatePrivateAuras)
