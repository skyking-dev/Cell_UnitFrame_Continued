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
local UnitHealthPercent = UnitHealthPercent
local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local CurveConstants = CurveConstants

local shieldTexture = const.Textures.CELL_SHIELD
local overshieldTexture = const.Textures.CELL_OVERSHIELD
local reverseOvershieldTexture = "Interface\\AddOns\\Cell\\Media\\overshield_reversed"

local function ResetShieldVisuals(widget)
    widget.shield:Hide()
    widget.shieldReverse:Hide()
    widget.overshieldGlow:Hide()
    widget.overshieldGlowReverse:Hide()
end

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

---@param unit UnitToken
---@return number?
local function GetDisplayHealthPercent(unit)
    if not UnitHealthPercent then return end

    if CurveConstants and CurveConstants.ScaleTo100 then
        return UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    end

    return UnitHealthPercent(unit)
end

---@param button CUFUnitButton
---@param unit Unit
---@param setting string?
---@param subSetting string?
function W.UpdateShieldBarWidget(button, unit, setting, subSetting, ...)
    local widget = button.widgets.shieldBar
    if not widget then return end

    local shieldAppearance = CellDB and CellDB["appearance"] and CellDB["appearance"]["shield"]
    local overshieldAppearance = CellDB and CellDB["appearance"] and CellDB["appearance"]["overshield"]

    widget.enabled = not (Cell.isVanilla or Cell.isTBC) and shieldAppearance and shieldAppearance[1] or false
    widget.reverseFill = CellDB and CellDB["appearance"] and CellDB["appearance"]["overshieldReverseFill"] or false
    widget.showOverShield = overshieldAppearance and overshieldAppearance[1] or false
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
    ResetShieldVisuals(widget)
end

Handler:RegisterWidget(W.UpdateShieldBarWidget, const.WIDGET_KIND.SHIELD_BAR)

---@param button CUFUnitButton
local function Update(button)
    if button and button._owner and not button.states then
        button = button._owner
    end

    if not button or not button.states then return end

    local unit = button.states.displayedUnit
    if not unit then return end

    local shieldBar = button.widgets.shieldBar
    if not shieldBar.enabled then
        shieldBar:Hide()
        ResetShieldVisuals(shieldBar)
        return
    end

    if shieldBar._isSelected then
        ResetShieldVisuals(shieldBar)
        shieldBar:Show()
        if shieldBar.shield.GetStatusBarTexture then
            local preview = shieldBar.reverseFill and shieldBar.shieldReverse or shieldBar.shield
            preview:SetMinMaxValues(0, 1)
            preview:SetValue(0.4)
            preview:Show()
            if shieldBar.reverseFill then
                shieldBar.overshieldGlowReverse:Show()
            else
                shieldBar.overshieldGlow:Show()
            end
        else
            shieldBar:SetValue(0.4, 0.5)
        end
        return
    end

    if Cell.isMidnight and shieldBar.shield.GetStatusBarTexture and button.widgets.healthCalculator then
        local calc = RefreshHealthCalculator(button)
        if not calc then
            shieldBar:Hide()
            ResetShieldVisuals(shieldBar)
            return
        end

        local absorbs = calc.GetTotalDamageAbsorbs and calc:GetTotalDamageAbsorbs() or 0
        local healthMax = calc.GetMaximumHealth and calc:GetMaximumHealth()
        if not healthMax then
            shieldBar:Hide()
            ResetShieldVisuals(shieldBar)
            return
        end
        local predCalc = RefreshPredictionCalculator(button)
        local _, isClamped
        if predCalc and predCalc.GetDamageAbsorbs then
            _, isClamped = predCalc:GetDamageAbsorbs()
        end

        ResetShieldVisuals(shieldBar)
        shieldBar:Show()

        if shieldBar.reverseFill then
            shieldBar.shieldReverse:SetMinMaxValues(0, healthMax)
            shieldBar.shieldReverse:SetValue(absorbs)
            shieldBar.shieldReverse:Show()
            if shieldBar.showOverShield then
                ApplyClampedGlow(shieldBar.overshieldGlowReverse, isClamped)
            end
        else
            shieldBar.shield:SetMinMaxValues(0, healthMax)
            shieldBar.shield:SetValue(absorbs)
            shieldBar.shield:Show()
            if shieldBar.showOverShield then
                ApplyClampedGlow(shieldBar.overshieldGlow, isClamped)
            end
        end

        if not shieldBar.showOverShield then
            shieldBar.overshieldGlow:Hide()
            shieldBar.overshieldGlowReverse:Hide()
        end
        return
    end

    local totalAbsorbs = UnitGetTotalAbsorbs(unit)
    if totalAbsorbs == nil then
        totalAbsorbs = button.states.totalAbsorbs
    end
    if totalAbsorbs == nil then
        totalAbsorbs = 0
    end
    button.states.totalAbsorbs = totalAbsorbs

    if not Util.IsValueNonSecret(totalAbsorbs) or totalAbsorbs <= 0 then
        shieldBar:Hide()
        ResetShieldVisuals(shieldBar)
        return
    end

    local health = button.states.health or UnitHealth(unit)
    local healthMax = button.states.healthMax or UnitHealthMax(unit)
    if not Util.IsValueNonSecret(healthMax) or healthMax <= 0 then
        shieldBar:Hide()
        ResetShieldVisuals(shieldBar)
        return
    end

    local healthPercent
    if not Util.HasAnySecretValues(health, healthMax) then
        healthPercent = health / healthMax
    else
        local displayPercent = GetDisplayHealthPercent(unit)
        if displayPercent == nil then
            healthPercent = button.states.healthPercent
        else
            healthPercent = displayPercent / 100
        end
    end

    if type(healthPercent) ~= "number" then
        shieldBar:Hide()
        ResetShieldVisuals(shieldBar)
        return
    end

    shieldBar:Show()
    shieldBar:SetValue(totalAbsorbs / healthMax, healthPercent)
end

---@param self ShieldBarWidget
local function Enable(self)
    self._owner:AddEventListener("UNIT_ABSORB_AMOUNT_CHANGED", Update)
    self._owner:AddEventListener("UNIT_MAXHEALTH", Update)
    self._owner:AddEventListener("UNIT_HEALTH", Update)

    self.Update(self._owner)

    return true
end

---@param self ShieldBarWidget
local function Disable(self)
    self._owner:RemoveEventListener("UNIT_ABSORB_AMOUNT_CHANGED", Update)
    self._owner:RemoveEventListener("UNIT_MAXHEALTH", Update)
    self._owner:RemoveEventListener("UNIT_HEALTH", Update)
    ResetShieldVisuals(self)
end

---@param widget ShieldBarWidget
---@param percent number
---@param healthPercent number
local function SetValue_Horizontal(widget, percent, healthPercent)
    percent = math.min(percent, 1)
    healthPercent = math.max(math.min(healthPercent or 0, 1), 0)

    local maxWidth = widget.parentHealthBar:GetWidth()
    ResetShieldVisuals(widget)

    if percent <= 0 or maxWidth <= 0 then return end

    if percent + healthPercent > 1 then
        local visiblePercent = 1 - healthPercent
        if visiblePercent > 0 then
            widget.shield:Show()
            widget.shield:SetWidth(maxWidth * visiblePercent)
        end

        if widget.reverseFill then
            local reversePercent = percent + healthPercent - 1
            if reversePercent > healthPercent then
                reversePercent = healthPercent
            end
            if reversePercent > 0 then
                widget.shieldReverse:Show()
                widget.shieldReverse:SetWidth(maxWidth * reversePercent)
            end

            if widget.showOverShield then
                widget.overshieldGlowReverse:Show()
            end
        elseif widget.showOverShield then
            widget.overshieldGlow:Show()
        end

        return
    end

    widget.shield:Show()
    widget.shield:SetWidth(maxWidth * percent)
end

---@param widget ShieldBarWidget
---@param percent number
---@param healthPercent number
local function SetValue_Vertical(widget, percent, healthPercent)
    percent = math.min(percent, 1)
    healthPercent = math.max(math.min(healthPercent or 0, 1), 0)

    local maxHeight = widget.parentHealthBar:GetHeight()
    ResetShieldVisuals(widget)

    if percent <= 0 or maxHeight <= 0 then return end

    if percent + healthPercent > 1 then
        local visiblePercent = 1 - healthPercent
        if visiblePercent > 0 then
            widget.shield:Show()
            widget.shield:SetHeight(maxHeight * visiblePercent)
        end

        if widget.reverseFill then
            local reversePercent = percent + healthPercent - 1
            if reversePercent > healthPercent then
                reversePercent = healthPercent
            end
            if reversePercent > 0 then
                widget.shieldReverse:Show()
                widget.shieldReverse:SetHeight(maxHeight * reversePercent)
            end

            if widget.showOverShield then
                widget.overshieldGlowReverse:Show()
            end
        elseif widget.showOverShield then
            widget.overshieldGlow:Show()
        end

        return
    end

    widget.shield:Show()
    widget.shield:SetHeight(maxHeight * percent)
end

---@param self ShieldBarWidget
---@param orientation string?
local function SetOrientation(self, orientation)
    orientation = orientation or "horizontal"

    P.ClearPoints(self.shield)
    P.ClearPoints(self.shieldReverse)
    P.ClearPoints(self.overshieldGlow)
    P.ClearPoints(self.overshieldGlowReverse)
    ResetShieldVisuals(self)

    if self.shield.GetStatusBarTexture then
        local barOrientation = orientation == "horizontal" and "horizontal" or "vertical"
        self.shield:SetOrientation(barOrientation)
        self.shield:SetReverseFill(false)
        self.shield:SetAllPoints(self.parentHealthBar)

        self.shieldReverse:SetOrientation(barOrientation)
        self.shieldReverse:SetReverseFill(true)
        self.shieldReverse:SetAllPoints(self.parentHealthBar)

        if orientation == "horizontal" then
            P.Point(self.overshieldGlow, "TOPRIGHT", self.parentHealthBar)
            P.Point(self.overshieldGlow, "BOTTOMRIGHT", self.parentHealthBar)
            P.Width(self.overshieldGlow, self.overshieldGlow.size)
            F.RotateTexture(self.overshieldGlow, 0)

            local reverseAnchor = self.shieldReverse:GetStatusBarTexture() or self.shieldReverse
            P.Point(self.overshieldGlowReverse, "TOP", reverseAnchor, "TOPLEFT", 0, 0)
            P.Point(self.overshieldGlowReverse, "BOTTOM", reverseAnchor, "BOTTOMLEFT", 0, 0)
            P.Width(self.overshieldGlowReverse, self.overshieldGlowReverse.size)
            F.RotateTexture(self.overshieldGlowReverse, 0)
        else
            P.Point(self.overshieldGlow, "TOPLEFT", self.parentHealthBar)
            P.Point(self.overshieldGlow, "TOPRIGHT", self.parentHealthBar)
            P.Height(self.overshieldGlow, self.overshieldGlow.size)
            F.RotateTexture(self.overshieldGlow, 90)

            local reverseAnchor = self.shieldReverse:GetStatusBarTexture() or self.shieldReverse
            P.Point(self.overshieldGlowReverse, "LEFT", reverseAnchor, "BOTTOMLEFT", 0, 0)
            P.Point(self.overshieldGlowReverse, "RIGHT", reverseAnchor, "BOTTOMRIGHT", 0, 0)
            P.Height(self.overshieldGlowReverse, self.overshieldGlowReverse.size)
            F.RotateTexture(self.overshieldGlowReverse, 90)
        end

        self.Update(self._owner)
        return
    end

    local healthTexture = self.parentHealthBar:GetStatusBarTexture()
    if not healthTexture then return end

    if orientation == "horizontal" then
        self.SetValue = SetValue_Horizontal

        if self.parentHealthBar:GetReverseFill() then
            P.Point(self.shield, "TOPRIGHT", healthTexture, "TOPLEFT")
            P.Point(self.shield, "BOTTOMRIGHT", healthTexture, "BOTTOMLEFT")

            P.Point(self.shieldReverse, "TOPLEFT", healthTexture, "TOPLEFT")
            P.Point(self.shieldReverse, "BOTTOMLEFT", healthTexture, "BOTTOMLEFT")

            P.Point(self.overshieldGlow, "TOPLEFT", self.parentHealthBar)
            P.Point(self.overshieldGlow, "BOTTOMLEFT", self.parentHealthBar)

            P.Point(self.overshieldGlowReverse, "TOP", self.shieldReverse, "TOPRIGHT")
            P.Point(self.overshieldGlowReverse, "BOTTOM", self.shieldReverse, "BOTTOMRIGHT")
        else
            P.Point(self.shield, "TOPLEFT", healthTexture, "TOPRIGHT")
            P.Point(self.shield, "BOTTOMLEFT", healthTexture, "BOTTOMRIGHT")

            P.Point(self.shieldReverse, "TOPRIGHT", healthTexture, "TOPRIGHT")
            P.Point(self.shieldReverse, "BOTTOMRIGHT", healthTexture, "BOTTOMRIGHT")

            P.Point(self.overshieldGlow, "TOPRIGHT", self.parentHealthBar)
            P.Point(self.overshieldGlow, "BOTTOMRIGHT", self.parentHealthBar)

            P.Point(self.overshieldGlowReverse, "TOP", self.shieldReverse, "TOPLEFT")
            P.Point(self.overshieldGlowReverse, "BOTTOM", self.shieldReverse, "BOTTOMLEFT")
        end

        P.Width(self.overshieldGlow, self.overshieldGlow.size)
        F.RotateTexture(self.overshieldGlow, 0)
        P.Width(self.overshieldGlowReverse, self.overshieldGlowReverse.size)
        F.RotateTexture(self.overshieldGlowReverse, 0)
        return
    end

    self.SetValue = SetValue_Vertical

    if self.parentHealthBar:GetReverseFill() then
        P.Point(self.shield, "TOPLEFT", healthTexture, "BOTTOMLEFT")
        P.Point(self.shield, "TOPRIGHT", healthTexture, "BOTTOMRIGHT")

        P.Point(self.shieldReverse, "BOTTOMLEFT", healthTexture, "BOTTOMLEFT")
        P.Point(self.shieldReverse, "BOTTOMRIGHT", healthTexture, "BOTTOMRIGHT")

        P.Point(self.overshieldGlow, "BOTTOMLEFT", self.parentHealthBar)
        P.Point(self.overshieldGlow, "BOTTOMRIGHT", self.parentHealthBar)

        P.Point(self.overshieldGlowReverse, "LEFT", self.shieldReverse, "BOTTOMLEFT")
        P.Point(self.overshieldGlowReverse, "RIGHT", self.shieldReverse, "BOTTOMRIGHT")
    else
        P.Point(self.shield, "BOTTOMLEFT", healthTexture, "TOPLEFT")
        P.Point(self.shield, "BOTTOMRIGHT", healthTexture, "TOPRIGHT")

        P.Point(self.shieldReverse, "TOPLEFT", healthTexture, "TOPLEFT")
        P.Point(self.shieldReverse, "TOPRIGHT", healthTexture, "TOPRIGHT")

        P.Point(self.overshieldGlow, "TOPLEFT", self.parentHealthBar)
        P.Point(self.overshieldGlow, "TOPRIGHT", self.parentHealthBar)

        P.Point(self.overshieldGlowReverse, "LEFT", self.shieldReverse, "TOPLEFT")
        P.Point(self.overshieldGlowReverse, "RIGHT", self.shieldReverse, "TOPRIGHT")
    end

    P.Height(self.overshieldGlow, self.overshieldGlow.size)
    F.RotateTexture(self.overshieldGlow, 90)
    P.Height(self.overshieldGlowReverse, self.overshieldGlowReverse.size)
    F.RotateTexture(self.overshieldGlowReverse, 90)
end

---@param self ShieldBarWidget
local function UpdateStyle(self)
    local shieldColor = CellDB["appearance"]["shield"][2]
    local overshieldColor = CellDB["appearance"]["overshield"][2]

    self.overshieldGlow:SetTexture(overshieldTexture)
    self.overshieldGlowReverse:SetTexture(reverseOvershieldTexture)
    self.overshieldGlow.size = 4
    self.overshieldGlowReverse.size = 8
    self.overshieldGlow:SetVertexColor(unpack(overshieldColor))
    self.overshieldGlowReverse:SetVertexColor(unpack(overshieldColor))

    if self.shield.GetStatusBarTexture then
        self.shield:SetStatusBarTexture(shieldTexture)
        self.shieldReverse:SetStatusBarTexture(shieldTexture)

        local shieldTex = self.shield:GetStatusBarTexture()
        if shieldTex then
            shieldTex:SetDrawLayer("ARTWORK", -5)
        end
        local reverseTex = self.shieldReverse:GetStatusBarTexture()
        if reverseTex then
            reverseTex:SetDrawLayer("ARTWORK", -5)
        end

        self.shield:SetStatusBarColor(unpack(shieldColor))
        self.shieldReverse:SetStatusBarColor(unpack(shieldColor))
        return
    end

    self.shield.tex:SetTexture(shieldTexture, "REPEAT", "REPEAT")
    self.shield.tex:SetHorizTile(true)
    self.shield.tex:SetVertTile(true)
    self.shieldReverse.tex:SetTexture(shieldTexture, "REPEAT", "REPEAT")
    self.shieldReverse.tex:SetHorizTile(true)
    self.shieldReverse.tex:SetVertTile(true)
    self.shield.tex:SetVertexColor(unpack(shieldColor))
    self.shieldReverse.tex:SetVertexColor(unpack(shieldColor))
end

---@param button CUFUnitButton
function W:CreateShieldBar(button)
    ---@class ShieldBarWidget: Frame, BaseWidget, BackdropTemplate
    local shieldBar = CreateFrame("Frame", button:GetName() .. "_ShieldBar", button, "BackdropTemplate")
    button.widgets.shieldBar = shieldBar

    shieldBar.id = const.WIDGET_KIND.SHIELD_BAR
    shieldBar.enabled = false
    shieldBar._isSelected = false
    shieldBar.parentHealthBar = button.widgets.healthBar
    shieldBar._owner = button

    shieldBar.reverseFill = false
    shieldBar.showOverShield = false
    shieldBar:SetFrameLevel(button.widgets.healthBar:GetFrameLevel() + 1)
    shieldBar:Hide()

    if Cell.isMidnight then
        local shield = CreateFrame("StatusBar", shieldBar:GetName() .. "_Fill", shieldBar)
        shieldBar.shield = shield
        shield:SetStatusBarTexture(shieldTexture)
        shield:SetFrameLevel(button.widgets.healthBar:GetFrameLevel() + 1)
        shield:SetAllPoints(shieldBar.parentHealthBar)
        shield:SetMinMaxValues(0, 1)
        shield.SetTexture = shield.SetStatusBarTexture
        shield.SetVertexColor = shield.SetStatusBarColor
        local shieldTex = shield:GetStatusBarTexture()
        if shieldTex then
            shieldTex:SetDrawLayer("ARTWORK", -5)
        end
        shield:Hide()

        local shieldReverse = CreateFrame("StatusBar", shieldBar:GetName() .. "_Reverse", shieldBar)
        shieldBar.shieldReverse = shieldReverse
        shieldReverse:SetStatusBarTexture(shieldTexture)
        shieldReverse:SetFrameLevel(button.widgets.healthBar:GetFrameLevel() + 1)
        shieldReverse:SetAllPoints(shieldBar.parentHealthBar)
        shieldReverse:SetMinMaxValues(0, 1)
        shieldReverse:SetReverseFill(true)
        shieldReverse.SetTexture = shieldReverse.SetStatusBarTexture
        shieldReverse.SetVertexColor = shieldReverse.SetStatusBarColor
        local reverseTex = shieldReverse:GetStatusBarTexture()
        if reverseTex then
            reverseTex:SetDrawLayer("ARTWORK", -5)
        end
        shieldReverse:Hide()
    else
        local shield = CreateFrame("Frame", shieldBar:GetName() .. "_Fill", shieldBar)
        shieldBar.shield = shield
        shield.tex = shield:CreateTexture(nil, "ARTWORK", nil, -5)
        shield.tex:SetAllPoints()

        local shieldReverse = CreateFrame("Frame", shieldBar:GetName() .. "_Reverse", shieldBar)
        shieldBar.shieldReverse = shieldReverse
        shieldReverse.tex = shieldReverse:CreateTexture(nil, "ARTWORK", nil, -5)
        shieldReverse.tex:SetAllPoints()
    end

    local overshieldGlow = shieldBar:CreateTexture(nil, "ARTWORK", nil, -4)
    overshieldGlow:SetTexture(overshieldTexture)
    overshieldGlow:Hide()
    shieldBar.overshieldGlow = overshieldGlow
    overshieldGlow.size = 4

    local overshieldGlowReverse = shieldBar:CreateTexture(nil, "ARTWORK", nil, -4)
    overshieldGlowReverse:SetTexture(reverseOvershieldTexture)
    overshieldGlowReverse:Hide()
    shieldBar.overshieldGlowReverse = overshieldGlowReverse
    overshieldGlowReverse.size = 8

    shieldBar._SetIsSelected = function(widget, val)
        widget._isSelected = val
        widget.Update(widget._owner)
    end

    shieldBar.SetValue = SetValue_Horizontal
    shieldBar.SetEnabled = W.SetEnabled
    shieldBar.SetWidgetFrameLevel = W.SetWidgetFrameLevel
    shieldBar.SetOrientation = SetOrientation
    shieldBar.UpdateStyle = UpdateStyle

    shieldBar.Update = Update
    shieldBar.Enable = Enable
    shieldBar.Disable = Disable
end

W:RegisterCreateWidgetFunc(CUF.constants.WIDGET_KIND.SHIELD_BAR, W.CreateShieldBar)
