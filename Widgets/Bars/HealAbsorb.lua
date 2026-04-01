---@class CUF
local CUF = select(2, ...)

local Cell = CUF.Cell
local F = Cell.funcs

---@class CUF.widgets
local W = CUF.widgets
local Handler = CUF.Handler
local Util = CUF.Util
local P = CUF.PixelPerfect
local const = CUF.constants

local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitExists = UnitExists
local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction
local UnitGetTotalHealAbsorbs = UnitGetTotalHealAbsorbs

local absorbTexture = const.Textures.CELL_SHIELD
local overabsorbTexture = const.Textures.CELL_OVERABSORB

local function RefreshHealthCalculator(button)
    local unit = button.states.displayedUnit
    local calc = button.widgets.healthCalculator
    if not unit or not calc or not UnitGetDetailedHealPrediction or not UnitExists(unit) then
        return
    end

    UnitGetDetailedHealPrediction(unit, "player", calc)
    return calc
end

local function RefreshPredictionCalculator(button)
    local unit = button.states.displayedUnit
    local calc = button.widgets.healPredictionCalculator
    if not unit or not calc or not UnitGetDetailedHealPrediction or not UnitExists(unit) then
        return
    end

    UnitGetDetailedHealPrediction(unit, nil, calc)
    return calc
end

local function ApplyClampedGlow(glow, isClamped)
    if isClamped == nil then
        glow:Hide()
        return
    end

    if glow.SetAlphaFromBoolean then
        glow:Show()
        glow:SetAlphaFromBoolean(isClamped, 1, 0)
        return
    end

    if _G.SetAlphaFromBoolean then
        glow:Show()
        _G.SetAlphaFromBoolean(glow, isClamped, 1, 0)
        return
    end

    if Util.IsValueNonSecret(isClamped) and isClamped then
        glow:Show()
    else
        glow:Hide()
    end
end

local function ApplyAbsorbColor(widget)
    local color = CellDB["appearance"]["healAbsorb"][2]

    if widget.absorbInvertColor then
        local r, g, b = F.InvertColor(widget.parentHealthBar:GetStatusBarColor())
        if widget.bar then
            widget.bar:SetStatusBarColor(r, g, b, 1)
        else
            widget.tex:SetVertexColor(r, g, b, 1)
        end
        widget.overabsorbGlow:SetVertexColor(r, g, b, 1)
        return
    end

    if widget.bar then
        widget.bar:SetStatusBarColor(unpack(color))
    else
        widget.tex:SetVertexColor(unpack(color))
    end
    widget.overabsorbGlow:SetVertexColor(unpack(color))
end

---@param button CUFUnitButton
---@param unit Unit
---@param setting string?
---@param subSetting string?
function W.UpdateHealAbsorbWidget(button, unit, setting, subSetting, ...)
    local widget = button.widgets.healAbsorb
    if not widget then return end

    widget.enabled = CellDB and CellDB["appearance"] and CellDB["appearance"]["healAbsorb"]
        and CellDB["appearance"]["healAbsorb"][1] or false
    widget.absorbInvertColor = CellDB and CellDB["appearance"] and CellDB["appearance"]["healAbsorbInvertColor"] or false
    widget:UpdateStyle()
    widget:SetOrientation(button.orientation or "horizontal")

    if widget.enabled then
        button:EnableWidget(widget)
        if button:IsVisible() then
            widget.Update(button)
        end
        return
    end

    button:DisableWidget(widget)
    widget.overabsorbGlow:Hide()
end

Handler:RegisterWidget(W.UpdateHealAbsorbWidget, const.WIDGET_KIND.HEAL_ABSORB)

---@param button CUFUnitButton
local function Update(button)
    if button and button._owner and not button.states then
        button = button._owner
    end

    if not button or not button.states then return end

    local unit = button.states.displayedUnit
    if not unit then return end

    local healAbsorb = button.widgets.healAbsorb
    if not healAbsorb.enabled then
        healAbsorb:Hide()
        healAbsorb.overabsorbGlow:Hide()
        return
    end

    if healAbsorb._isSelected then
        if healAbsorb.bar then
            healAbsorb.bar:SetMinMaxValues(0, 1)
            healAbsorb.bar:SetValue(0.4)
            healAbsorb.bar:Show()
        else
            healAbsorb:SetValue(0.4, 0.5)
        end
        healAbsorb:Show()
        return
    end

    ApplyAbsorbColor(healAbsorb)

    if Cell.isMidnight and healAbsorb.bar and button.widgets.healthCalculator then
        local calc = RefreshHealthCalculator(button)
        if not calc then
            healAbsorb:Hide()
            healAbsorb.overabsorbGlow:Hide()
            return
        end

        local healAbsorbs = calc.GetHealAbsorbs and calc:GetHealAbsorbs() or 0
        local currentHealth = calc.GetCurrentHealth and calc:GetCurrentHealth()
        if currentHealth then
            healAbsorb.bar:SetMinMaxValues(0, currentHealth)
        end

        healAbsorb.bar:SetValue(healAbsorbs)
        healAbsorb.bar:Show()
        healAbsorb:Show()

        local predCalc = RefreshPredictionCalculator(button)
        local _, isClamped
        if predCalc and predCalc.GetHealAbsorbs then
            _, isClamped = predCalc:GetHealAbsorbs()
        end
        ApplyClampedGlow(healAbsorb.overabsorbGlow, isClamped)
        return
    end

    local totalHealAbsorb = UnitGetTotalHealAbsorbs(unit)
    local health = UnitHealth(unit)
    local healthMax = UnitHealthMax(unit)

    if Util.HasAnySecretValues(totalHealAbsorb, health, healthMax) then
        healAbsorb:Hide()
        healAbsorb.overabsorbGlow:Hide()
        return
    end

    if totalHealAbsorb > 0 and healthMax > 0 then
        healAbsorb:Show()
        healAbsorb:SetValue(totalHealAbsorb / healthMax, health / healthMax)
        return
    end

    healAbsorb:Hide()
    healAbsorb.overabsorbGlow:Hide()
end

---@param self HealAbsorbWidget
local function Enable(self)
    self._owner:AddEventListener("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", Update)
    self._owner:AddEventListener("UNIT_MAXHEALTH", Update)
    self._owner:AddEventListener("UNIT_HEALTH", Update)

    self.Update(self._owner)

    return true
end

---@param self HealAbsorbWidget
local function Disable(self)
    self._owner:RemoveEventListener("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", Update)
    self._owner:RemoveEventListener("UNIT_MAXHEALTH", Update)
    self._owner:RemoveEventListener("UNIT_HEALTH", Update)
    self.overabsorbGlow:Hide()

    if self.bar then
        self.bar:Hide()
    end
end

---@param self HealAbsorbWidget
---@param healAbsorbPercent number
---@param healthPercent number
local function SetValue_Horizontal(self, healAbsorbPercent, healthPercent)
    ApplyAbsorbColor(self)

    local barWidth = self.parentHealthBar:GetWidth()
    if healAbsorbPercent > healthPercent then
        self:SetWidth(healthPercent * barWidth)
        self.overabsorbGlow:Show()
    else
        self:SetWidth(healAbsorbPercent * barWidth)
        self.overabsorbGlow:Hide()
    end
    self:Show()
end

---@param self HealAbsorbWidget
---@param healAbsorbPercent number
---@param healthPercent number
local function SetValue_Vertical(self, healAbsorbPercent, healthPercent)
    ApplyAbsorbColor(self)

    local barHeight = self.parentHealthBar:GetHeight()
    if healAbsorbPercent > healthPercent then
        self:SetHeight(healthPercent * barHeight)
        self.overabsorbGlow:Show()
    else
        self:SetHeight(healAbsorbPercent * barHeight)
        self.overabsorbGlow:Hide()
    end
    self:Show()
end

---@param self HealAbsorbWidget
---@param orientation string?
local function SetOrientation(self, orientation)
    orientation = orientation or "horizontal"

    P.ClearPoints(self)
    P.ClearPoints(self.overabsorbGlow)

    if self.bar then
        local barOrientation = orientation == "horizontal" and "horizontal" or "vertical"
        self.bar:SetOrientation(barOrientation)
        self.bar:SetReverseFill(true)
        self.bar:SetAllPoints(self.parentHealthBar)

        if orientation == "horizontal" then
            if self.parentHealthBar:GetReverseFill() then
                P.Point(self.overabsorbGlow, "TOP", self.parentHealthBar, "TOPRIGHT")
                P.Point(self.overabsorbGlow, "BOTTOM", self.parentHealthBar, "BOTTOMRIGHT")
            else
                P.Point(self.overabsorbGlow, "TOP", self.parentHealthBar, "TOPLEFT")
                P.Point(self.overabsorbGlow, "BOTTOM", self.parentHealthBar, "BOTTOMLEFT")
            end
            P.Width(self.overabsorbGlow, self.overabsorbGlow.size)
            F.RotateTexture(self.overabsorbGlow, 0)
        else
            if self.parentHealthBar:GetReverseFill() then
                P.Point(self.overabsorbGlow, "LEFT", self.parentHealthBar, "TOPLEFT")
                P.Point(self.overabsorbGlow, "RIGHT", self.parentHealthBar, "TOPRIGHT")
            else
                P.Point(self.overabsorbGlow, "LEFT", self.parentHealthBar, "BOTTOMLEFT")
                P.Point(self.overabsorbGlow, "RIGHT", self.parentHealthBar, "BOTTOMRIGHT")
            end
            P.Height(self.overabsorbGlow, self.overabsorbGlow.size)
            F.RotateTexture(self.overabsorbGlow, 90)
        end

        self.Update(self._owner)
        return
    end

    if orientation == "horizontal" then
        if self.parentHealthBar:GetReverseFill() then
            P.Point(self, "TOPLEFT", self.parentHealthBar:GetStatusBarTexture())
            P.Point(self, "BOTTOMLEFT", self.parentHealthBar:GetStatusBarTexture())

            P.Point(self.overabsorbGlow, "TOP", self.parentHealthBar, "TOPRIGHT")
            P.Point(self.overabsorbGlow, "BOTTOM", self.parentHealthBar, "BOTTOMRIGHT")
        else
            P.Point(self, "TOPRIGHT", self.parentHealthBar:GetStatusBarTexture())
            P.Point(self, "BOTTOMRIGHT", self.parentHealthBar:GetStatusBarTexture())

            P.Point(self.overabsorbGlow, "TOP", self.parentHealthBar, "TOPLEFT")
            P.Point(self.overabsorbGlow, "BOTTOM", self.parentHealthBar, "BOTTOMLEFT")
        end
        P.Width(self.overabsorbGlow, self.overabsorbGlow.size)
        F.RotateTexture(self.overabsorbGlow, 0)

        self.SetValue = SetValue_Horizontal
    else
        if self.parentHealthBar:GetReverseFill() then
            P.Point(self, "BOTTOMLEFT", self.parentHealthBar:GetStatusBarTexture())
            P.Point(self, "BOTTOMRIGHT", self.parentHealthBar:GetStatusBarTexture())

            P.Point(self.overabsorbGlow, "LEFT", self.parentHealthBar, "TOPLEFT")
            P.Point(self.overabsorbGlow, "RIGHT", self.parentHealthBar, "TOPRIGHT")
        else
            P.Point(self, "TOPLEFT", self.parentHealthBar:GetStatusBarTexture())
            P.Point(self, "TOPRIGHT", self.parentHealthBar:GetStatusBarTexture())

            P.Point(self.overabsorbGlow, "LEFT", self.parentHealthBar, "BOTTOMLEFT")
            P.Point(self.overabsorbGlow, "RIGHT", self.parentHealthBar, "BOTTOMRIGHT")
        end
        P.Height(self.overabsorbGlow, self.overabsorbGlow.size)
        F.RotateTexture(self.overabsorbGlow, 90)

        self.SetValue = SetValue_Vertical
    end

    self.Update(self._owner)
end

---@param self HealAbsorbWidget
local function UpdateStyle(self)
    self.absorbInvertColor = CellDB["appearance"]["healAbsorbInvertColor"]
    self.overabsorbGlow:SetTexture(overabsorbTexture)
    self.overabsorbGlow.size = 4

    if self.bar then
        self.bar:SetStatusBarTexture(absorbTexture)
        local tex = self.bar:GetStatusBarTexture()
        if tex then
            tex:SetDrawLayer("ARTWORK", 1)
        end
        ApplyAbsorbColor(self)
        return
    end

    self.tex:SetTexture(absorbTexture, "REPEAT", "REPEAT")
    self.tex:SetHorizTile(true)
    self.tex:SetVertTile(true)
    ApplyAbsorbColor(self)
end

---@param button CUFUnitButton
function W:CreateHealAbsorb(button)
    ---@class HealAbsorbWidget: Frame, BaseWidget, BackdropTemplate
    local healAbsorb = CreateFrame("Frame", button:GetName() .. "_HealAbsorb", button, "BackdropTemplate")
    button.widgets.healAbsorb = healAbsorb

    healAbsorb.id = const.WIDGET_KIND.HEAL_ABSORB
    healAbsorb.enabled = false
    healAbsorb._isSelected = false
    healAbsorb.parentHealthBar = button.widgets.healthBar
    healAbsorb._owner = button

    healAbsorb.showOverabsorbGlow = false
    healAbsorb.absorbInvertColor = false

    healAbsorb:Hide()

    if Cell.isMidnight then
        local bar = CreateFrame("StatusBar", healAbsorb:GetName() .. "_Bar", healAbsorb)
        healAbsorb.bar = bar
        bar:SetStatusBarTexture(absorbTexture)
        bar:SetFrameLevel(button.widgets.healthBar:GetFrameLevel() + 2)
        bar:SetAllPoints(healAbsorb.parentHealthBar)
        bar:SetReverseFill(true)
        bar:SetMinMaxValues(0, 1)
        bar:SetStatusBarColor(1, 0.1, 0.1, 1)
        bar.SetVertexColor = bar.SetStatusBarColor
        bar.SetTexture = bar.SetStatusBarTexture
        local tex = bar:GetStatusBarTexture()
        if tex then
            tex:SetDrawLayer("ARTWORK", 1)
        end
        bar:Hide()
    else
        local tex = healAbsorb:CreateTexture(nil, "ARTWORK", nil, -7)
        tex:SetAllPoints()
        healAbsorb.tex = tex
    end

    local overabsorbGlow = healAbsorb:CreateTexture(nil, "ARTWORK", nil, -2)
    overabsorbGlow:SetTexture(overabsorbTexture)
    overabsorbGlow:Hide()
    healAbsorb.overabsorbGlow = overabsorbGlow
    overabsorbGlow.size = 4

    healAbsorb._SetIsSelected = function(bar, val)
        bar._isSelected = val
        bar.Update(bar._owner)
    end

    healAbsorb.SetValue = SetValue_Horizontal
    healAbsorb.SetEnabled = W.SetEnabled
    healAbsorb.SetWidgetFrameLevel = W.SetWidgetFrameLevel
    healAbsorb.SetOrientation = SetOrientation
    healAbsorb.UpdateStyle = UpdateStyle

    healAbsorb.Update = Update
    healAbsorb.Enable = Enable
    healAbsorb.Disable = Disable
end

W:RegisterCreateWidgetFunc(CUF.constants.WIDGET_KIND.HEAL_ABSORB, W.CreateHealAbsorb)
