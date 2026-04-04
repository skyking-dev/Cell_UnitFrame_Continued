---@class CUF
local CUF = select(2, ...)

local Cell = CUF.Cell
local Debug = CUF.Debug
local F = Cell and Cell.funcs

SLASH_CUF1 = "/cuf"
function SlashCmdList.CUF(msg, editbox)
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    if command == "test" then
        CUF.vars.testMode = not CUF.vars.testMode
        CUF:Print("Test mode: " .. (CUF.vars.testMode and "ON" or "OFF"))
    elseif command == "dev" then
        CUF.SetDebugMode(not CUF.IsInDebugMode())
        Debug:ToggleDebugWindow()
        CUF:Print("Debug: " .. (CUF.IsInDebugMode() and "ON" or "OFF"))
    elseif command == "restore" then
        if rest ~= "automatic" and rest ~= "manual" then
            CUF:Print("Usage: /cuf restore <automatic|manual>")
            return
        end
        CUF.DB.RestoreFromBackup(rest)
    elseif command == "edit" then
        CUF.uFuncs:EditMode()
    elseif command == "tips" or command == "resettips" then
        for tip, _ in pairs(CUF_DB.helpTips) do
            CUF.DB.SetHelpTip(tip, false)
        end
        CUF:Print("All Help Tips have been reset, reload to see them again")
    elseif command == "tags" then
        CUF.widgets:ShowTooltipFrame()
    elseif command == "pixel" then
        CUF:Print(CUF.PixelPerfect.DebugInfo())
    elseif command == "midnight" then
        local auraRestricted = F and F.IsAuraRestricted and F.IsAuraRestricted()
        local cooldownRestricted = F and F.IsCooldownRestricted and F.IsCooldownRestricted()
        local secretContext = F and F.IsSecretContextActive and F.IsSecretContextActive()
        local commRestricted = F and F.IsCommRestricted and F.IsCommRestricted()
        local groupChannel = F and F.GetGroupCommChannel and F.GetGroupCommChannel() or "none"
        local privateAuraAPI = C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor and "available" or "missing"
        CUF:Print(
            "Midnight diagnostics:\n" ..
            "Aura restrictions: " .. tostring(auraRestricted) .. "\n" ..
            "Cooldown restrictions: " .. tostring(cooldownRestricted) .. "\n" ..
            "Comm restrictions: " .. tostring(commRestricted) .. "\n" ..
            "Secret context: " .. tostring(secretContext) .. "\n" ..
            "Group channel: " .. tostring(groupChannel) .. "\n" ..
            "Private aura API: " .. privateAuraAPI
        )
    else
        CUF:Print("Available commands:" .. "\n" ..
            "/cuf test - toggle test mode" .. "\n" ..
            "/cuf dev - toggle debug mode" .. "\n" ..
            "/cuf edit - toggle edit mode" .. "\n" ..
            "/cuf restore <automatic|manual> - restore a backup" .. "\n" ..
            "/cuf tips - reset all help tips" .. "\n" ..
            "/cuf tags - show available tags" .. "\n" ..
            "/cuf pixel - show pixel debug info" .. "\n" ..
            "/cuf midnight - show Midnight diagnostics"
        )
    end
end
