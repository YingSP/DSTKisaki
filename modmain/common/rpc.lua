-- 服务器往某个客户端单独宣告
if TheNet:GetIsClient() then
    AddClientModRPCHandler("kisaki", "client_declare", function(message)
        if ThePlayer and message then
            Networking_Announcement(message)
        end
    end)
end
if TheNet:GetIsServer() then
    AddClientModRPCHandler("kisaki", "client_declare", function(str) end)
end

-- 旅法杖：客户端在法术书轮盘中选择状态后请求服务端切换。
AddModRPCHandler("kisaki", "MagicStaffMode", function(player, mode)
    if type(mode) ~= "string" or player == nil or player.components.inventory == nil then
        return
    end
    local inventory = player.components.inventory
    -- 优先检查手上装备的旅，其次检查背包内的旅
    local candidates = { inventory:GetEquippedItem(EQUIPSLOTS.HANDS) }
    for _, item in pairs(inventory.itemslots) do
        table.insert(candidates, item)
    end
    for _, staff in ipairs(candidates) do
        if staff ~= nil and staff.SetMode ~= nil
            and (staff.prefab == "kisaki_magic_staff" or staff.prefab == "kisaki_magic_staff_max") then
            staff:SetMode(mode) -- SetMode 内部校验解锁状态并播报台词
            break
        end
    end
end)
