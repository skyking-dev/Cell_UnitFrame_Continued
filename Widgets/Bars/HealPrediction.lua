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

local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitGetIncomingHeals = UnitGetIncomingHeals
local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction

local function ApplyPredictionColor(widget)
    local color
    if CellDB["appearance"]["healPrediction"][2] then
        color = CellDB["appearance"]["healPrediction"][3]
    else
        local r, g, b = widget.parentHealthBar:GetStatusBarColor()
        color = { r, g, b, 0.4 }
    end

    if widget.bar then
        widget.bar:SetStatusBarColor(unpack(color))
        return
    end

    widget.heal.tex:SetVertexColor(unpack(color))
    widget.healReverse.tex:SetVertexColor(unpack(color))
    widget.overHealGlow:SetVertexColor(unpack(color))
    widget.overHealGlowReverse:SetVertexColor(unpack(color))
end

---@param button CUFUnitButton
---@param unit Unit
---@param setting string?
---@param subSetting string?
function W.UpdateHealPredictionWidget(button, unit, setting, subSetting, ...)
    local widget = button.widgets.healPrediction
    if not widget then return end

    widget.enabled = CellDB and CellDB["appearance"] and CellDB["appearance"]["healPrediction"]
        and CellDB["appearance"]["healPrediction"][1] or false
    widget.anchorToHealthBar = true
    widget.currentPoint = "healthBar"
    widget.reverseFill = false
    widget.showOverHeal = false
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
    widget:Hide()
end

Handler:RegisterWidget(W.UpdateHealPredictionWidget, const.WIDGET_KIND.HEAL_PREDICTION)

---@param button CUFUnitButton
local function Update(button)
    if button and button._owner and not button.states then
        button = button._owner
    end

    if not button or not button.states then return end

    local unit = button.states.displayedUnit
    if not unit then return end

    local healPrediction = button.widgets.healPrediction
    if not healPrediction.enabled then
        healPrediction:Hide()
        return
    end

    if healPrediction._isSelected then
        if healPrediction.bar then
            if button.orientation == "horizontal" then
                healPrediction.bar:SetWidth(healPrediction.parentHealthBar:GetWidth())
            else
                healPrediction.bar:SetHeight(healPrediction.parentHealthBar:GetHeight())
            end
            healPrediction.bar:SetMinMaxValues(0, 1)
            healPrediction.bar:SetValue(0.4)
            healPrediction.bar:Show()
        else
            healPrediction:SetValue(0.4, 0.5)
        end
        healPrediction:Show()
        return
    end

    ApplyPredictionColor(healPrediction)

    if Cell.isMidnight and healPrediction.bar and button.widgets.healPredictionCalculator
        and UnitGetDetailedHealPrediction and UnitExists(unit) then
        local calc = button.widgets.healPredictionCalculator
        calc:SetIncomingHealClampMode(0)
        calc:SetIncomingHealOverflowPercent(1.0)
        UnitGetDetailedHealPrediction(unit, "player", calc)

        if button.orientation == "horizontal" then
            healPrediction.bar:SetWidth(healPrediction.parentHealthBar:GetWidth())
        else
            healPrediction.bar:SetHeight(healPrediction.parentHealthBar:GetHeight())
        end

        local maxHealth = calc:GetMaximumHealth()
        if not maxHealth then
            healPrediction:Hide()
            return
        end

        healPrediction.bar:SetMinMaxValues(0, maxHealth)
        healPrediction.bar:SetValue(calc:GetIncomingHeals() or 0)
        healPrediction.bar:Show()
        healPrediction:Show()
        return
    end

    local totalIncomingHeal = UnitGetIncomingHeals(unit) or 0
    local health = UnitHealth(unit)
    local healthMax = UnitHealthMax(unit)

    if Util.HasAnySecretValues(totalIncomingHeal, health, healthMax) then
        healPrediction:Hide()
        return
    end

    if totalIncomingHeal > 0 and healthMax > 0 then
        healPrediction:Show()
        healPrediction:SetValue(totalIncomingHeal / healthMax, health / healthMax)
        return
    end

    healPrediction:Hide()
end

---@param self HealPredictionWidget
local function Enable(self)
    self._owner:AddEventListener("UNIT_HEAL_PREDICTION", Update)
    self._owner:AddEventListener("UNIT_MAXHEALTH", Update)
    self._owner:AddEventListener("UNIT_HEALTH", Update)

    self.Update(self._owner)

    return true
end

---@param self HealPredictionWidget
local function Disable(self)
    self._owner:RemoveEventListener("UNIT_HEAL_PREDICTION", Update)
    self._owner:RemoveEventListener("UNIT_MAXHEALTH", Update)
    self._owner:RemoveEventListener("UNIT_HEALTH", Update)
end

---@param bar HealPredictionWidget
---@param percent number
---@param healthPercent number
local function HealPredict_SetValue_Horizontal(bar, percent, healthPercent)
    percent = math.min(percent, 1)

    local maxWidth = bar.parentHealthBar:GetWidth()
    local barWidth = maxWidth * percent

    if bar.parentHealthBar:GetReverseFill() then
        bar.healReverse:Show()
        bar.heal:Hide()

        local ratio = math.min(percent, healthPercent)
        bar.healReverse:SetWidth(maxWidth * ratio)
        return
    end

    local lostHealthWidth = maxWidth * (1 - healthPercent)
    if lostHealthWidth == 0 then
        bar.heal:Hide()
        return
    end

    if lostHealthWidth > barWidth then
        bar.heal:SetWidth(barWidth)
    else
        bar.heal:SetWidth(lostHealthWidth)
    end

    bar.healReverse:Hide()
    bar.heal:Show()
end

---@param bar HealPredictionWidget
---@param percent number
---@param healthPercent number
local function HealPredict_SetValue_Vertical(bar, percent, healthPercent)
    percent = math.min(percent, 1)

    local maxHeight = bar.parentHealthBar:GetHeight()
    local barHeight = maxHeight * percent

    if bar.parentHealthBar:GetReverseFill() then
        bar.healReverse:Show()
        bar.heal:Hide()

        local ratio = math.min(percent, healthPercent)
        bar.healReverse:SetHeight(maxHeight * ratio)
        return
    end

    local lostHealthHeight = maxHeight * (1 - healthPercent)
    if lostHealthHeight == 0 then
        bar.heal:Hide()
        return
    end

    if lostHealthHeight > barHeight then
        bar.heal:SetHeight(barHeight)
    else
        bar.heal:SetHeight(lostHealthHeight)
    end

    bar.healReverse:Hide()
    bar.heal:Show()
end

---@param self HealPredictionWidget
---@param orientation string?
local function SetOrientation(self, orientation)
    orientation = orientation or "horizontal"

    if self.bar then
        local healthTexture = self.parentHealthBar:GetStatusBarTexture()
        if not healthTexture then return end

        P.ClearPoints(self.bar)
        if orientation == "horizontal" then
            self.bar:SetOrientation("horizontal")
            if self.parentHealthBar:GetReverseFill() then
                self.bar:SetReverseFill(true)
                P.Point(self.bar, "TOPRIGHT", healthTexture, "TOPLEFT")
                P.Point(self.bar, "BOTTOMRIGHT", healthTexture, "BOTTOMLEFT")
            else
                self.bar:SetReverseFill(false)
                P.Point(self.bar, "TOPLEFT", healthTexture, "TOPRIGHT")
                P.Point(self.bar, "BOTTOMLEFT", healthTexture, "BOTTOMRIGHT")
            end
        else
            self.bar:SetOrientation("vertical")
            if self.parentHealthBar:GetReverseFill() then
                self.bar:SetReverseFill(true)
                P.Point(self.bar, "TOPLEFT", healthTexture, "BOTTOMLEFT")
                P.Point(self.bar, "TOPRIGHT", healthTexture, "BOTTOMRIGHT")
            else
                self.bar:SetReverseFill(false)
                P.Point(self.bar, "BOTTOMLEFT", healthTexture, "TOPLEFT")
                P.Point(self.bar, "BOTTOMRIGHT", healthTexture, "TOPRIGHT")
            end
        end

        self.Update(self._owner)
        return
    end

    P.ClearPoints(self.heal)
    P.ClearPoints(self.healReverse)
    P.ClearPoints(self.overHealGlow)
    P.ClearPoints(self.overHealGlowReverse)

    self.heal:Hide()
    self.healReverse:Hide()
    self.overHealGlow:Hide()
    self.overHealGlowReverse:Hide()

    if orientation == "horizontal" then
        self.SetValue = HealPredict_SetValue_Horizontal

        if self.parentHealthBar:GetReverseFill() then
            P.Point(self.healReverse, "TOPRIGHT", self.parentHealthBar:GetStatusBarTexture())
            P.Point(self.healReverse, "BOTTOMRIGHT", self.parentHealthBar:GetStatusBarTexture())
        else
            P.Point(self.heal, "TOPLEFT", self.parentHealthBar:GetStatusBarTexture(), "TOPRIGHT")
            P.Point(self.heal, "BOTTOMLEFT", self.parentHealthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
        end
    else
        self.SetValue = HealPredict_SetValue_Vertical

        if self.parentHealthBar:GetReverseFill() then
            P.Point(self.healReverse, "TOPLEFT", self.parentHealthBar:GetStatusBarTexture())
            P.Point(self.healReverse, "TOPRIGHT", self.parentHealthBar:GetStatusBarTexture())
        else
            P.Point(self.heal, "BOTTOMLEFT", self.parentHealthBar:GetStatusBarTexture(), "TOPLEFT")
            P.Point(self.heal, "BOTTOMRIGHT", self.parentHealthBar:GetStatusBarTexture(), "TOPRIGHT")
        end
    end
end

---@param button CUFUnitButton
function W:CreateHealPrediction(button)
    ---@class HealPredictionWidget: Frame, BaseWidget, BackdropTemplate
    local healPrediction = CreateFrame("Frame", button:GetName() .. "_HealPrediction", button, "BackdropTemplate")
    button.widgets.healPrediction = healPrediction

    healPrediction.id = const.WIDGET_KIND.HEAL_PREDICTION
    healPrediction.enabled = false
    healPrediction._isSelected = false
    healPrediction.parentHealthBar = button.widgets.healthBar
    healPrediction.parentHealthBarLoss = button.widgets.healthBarLoss
    healPrediction._owner = button

    healPrediction:SetFrameLevel(button.widgets.healthBar:GetFrameLevel() + 2)
    healPrediction:Hide()

    if Cell.isMidnight then
        local bar = CreateFrame("StatusBar", healPrediction:GetName() .. "_Bar", healPrediction)
        healPrediction.bar = bar
        bar:SetStatusBarTexture(Cell.vars.texture or F.GetBarTexture())
        bar:SetFrameLevel(button.widgets.healthBar:GetFrameLevel() + 2)
        bar:SetMinMaxValues(0, 1)
        bar.SetTexture = bar.SetStatusBarTexture
        bar.SetVertexColor = bar.SetStatusBarColor
        local tex = bar:GetStatusBarTexture()
        if tex then
            tex:SetDrawLayer("ARTWORK", -6)
        end
        bar:Hide()
    else
        local healReverse = CreateFrame("Frame", healPrediction:GetName() .. "_HealPredictionReverse", healPrediction)
        healPrediction.healReverse = healReverse
        healReverse.tex = healReverse:CreateTexture(nil, "ARTWORK", nil, -6)
        healReverse.tex:SetAllPoints()

        local heal = CreateFrame("Frame", healPrediction:GetName() .. "_HealPrediction", healPrediction)
        healPrediction.heal = heal
        heal.tex = heal:CreateTexture(nil, "ARTWORK", nil, -6)
        heal.tex:SetAllPoints()

        local overHealGlow = healPrediction:CreateTexture(nil, "ARTWORK", nil, -4)
        overHealGlow:SetTexture(CUF.constants.Textures.CELL_OVERSHIELD)
        overHealGlow:Hide()
        healPrediction.overHealGlow = overHealGlow

        local overHealGlowReverse = healReverse:CreateTexture(nil, "ARTWORK", nil, -4)
        overHealGlowReverse:SetTexture(CUF.constants.Textures.CELL_OVERSHIELD)
        overHealGlowReverse:Hide()
        healPrediction.overHealGlowReverse = overHealGlowReverse
    end

    function healPrediction:UpdateStyle()
        if self.bar then
            self.bar:SetStatusBarTexture(Cell.vars.texture or F.GetBarTexture())
            local tex = self.bar:GetStatusBarTexture()
            if tex then
                tex:SetDrawLayer("ARTWORK", -6)
            end
            ApplyPredictionColor(self)
            return
        end

        local tex = Cell.vars.texture or F.GetBarTexture()
        self.heal.tex:SetTexture(tex)
        self.healReverse.tex:SetTexture(tex)
        ApplyPredictionColor(self)
    end

    healPrediction._SetIsSelected = function(bar, val)
        bar._isSelected = val
        bar.Update(bar._owner)
    end

    healPrediction.SetValue = HealPredict_SetValue_Horizontal
    healPrediction.SetEnabled = W.SetEnabled
    healPrediction.SetWidgetFrameLevel = W.SetWidgetFrameLevel
    healPrediction.SetOrientation = SetOrientation

    healPrediction.Update = Update
    healPrediction.Enable = Enable
    healPrediction.Disable = Disable
end

W:RegisterCreateWidgetFunc(CUF.constants.WIDGET_KIND.HEAL_PREDICTION, W.CreateHealPrediction)
