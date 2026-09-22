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

--[[[分片同步] 容器升级进度
[方向] 发送 kisaki_world_data:OnContainerLevelChanged（全量 box_level）
       接收 本 handler → 取高合并进本地世界数据
[编解码] DataDumper 序列化（"return {...}" 代码段）→ RunInSandboxSafe 还原
         与游戏本体 shardnetworking.lua 做法一致
[注意] 两端必须注册同名 handler；客户端下 SendModRPCToShard 是空函数，只能在服务端调用
[防循环] 没提升就不推事件、不回推
]]
AddShardModRPCHandler("kisaki", "container_level_sync", function(sender, data)
    local worlddata = TheWorld ~= nil and TheWorld.components.kisaki_world_data or nil
    if worlddata == nil or type(data) ~= "string" then
        return
    end
    local ok, levels = RunInSandboxSafe(data)
    if not ok or type(levels) ~= "table" then
        return
    end
    -- [防循环] 逐容器合并；有提升才推事件，没有就不回推
    local changed = false
    for boxname, boxlevels in pairs(levels) do
        if type(boxname) == "string" and type(boxlevels) == "table" then
            if worlddata:MergeContainerLevels(boxname, boxlevels) then
                changed = true
            end
        end
    end
    if changed then
        TheWorld:PushEvent("kisaki_container_level_changed", {})
    end
end)

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

AddModRPCHandler("kisaki", "MagicStaffPlayerTeleport", function(player, userid)
    -- RPC 参数只包含 userid；传送目标和落点由服务端重新解析。
    if TheWorld.ismastersim then
        require("utils/teleportutil").ToPlayer(player, userid)
    end
end)
