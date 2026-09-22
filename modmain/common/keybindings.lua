-- 旅法杖的客户端按键映射：每次按下 V 切换玩家传送轮盘。
local function GetPlayerTeleportWheel()
    local hud = ThePlayer ~= nil and ThePlayer.HUD or nil
    local controls = hud ~= nil and hud.controls or nil
    return controls ~= nil and controls.kisaki_player_teleport_wheel or nil
end

local v_down = false
TheInput:AddKeyDownHandler(KEY_V, function()
    if v_down then
        return
    end
    v_down = true
    local wheel = GetPlayerTeleportWheel()
    if wheel ~= nil and not TheInput:IsPasteKey(KEY_V) then
        wheel:TogglePlayers()
    end
end)

TheInput:AddKeyUpHandler(KEY_V, function()
    v_down = false
end)
