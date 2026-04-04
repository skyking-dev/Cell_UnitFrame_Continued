---@class CUF
local CUF = select(2, ...)

---@class CUF.Locales
local L = CUF.L

----------------------------------
-- !!DO NOT ADD TO CURSEFORGE!! --
----------------------------------

-- Forwards from Cell
L.invertColor = L["Invert Color"]
L.dispels = L["Dispels"]
L.barColor = L["Health Bar Color"]
L.lossColor = L["Health Loss Color"]
L.useFullColor = L["Enable Full Health Color"]
L.useDeathColor = L["Enable Death Color"]
L.barAlpha = L["Health Bar Alpha"]
L.lossAlpha = L["Health Loss Alpha"]
L.backgroundAlpha = L["Background Alpha"]
L.none = L["None"]
L.pixel = L["Pixel"]
L.shine = L["Shine"]
L.proc = L["Proc"]
L.healPrediction = L["Heal Prediction"]
L.shieldTexture = L["Shield Texture"]
L.overshieldTexture = L["Overshield Texture"]
L.privateAuras = L["Private Auras"] or "Private Auras"
L["Show countdown swipe"] = L["Show countdown swipe"] or "Show countdown swipe"
L["Show countdown number"] = L["Show countdown number"] or "Show countdown number"
L["Max Displayed"] = L["Max Displayed"] or "Max Displayed"
L["Due to restrictions of the private aura system, this indicator can only use Blizzard style."] =
    L["Due to restrictions of the private aura system, this indicator can only use Blizzard style."]
    or "Due to restrictions of the private aura system, this indicator can only use Blizzard style."

-- Aliases
L.unitFrames = L.UnitFrames
L.hover = L.Hover
