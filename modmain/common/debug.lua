---------------------------------------------------------------------玩家信息获取--------------------------------------------------------------------------------
-- 获取当前玩家的血量组件信息
GLOBAL.k_health_info = function()
    if TheNet:GetIsServer() then
        local player = ConsoleCommandPlayer()
        if player and player.components and player.components.health then
            local health = player.components.health
            local format = "======================================================================================\r\n"
            format = format .. "当前玩家：%s\r\n"
            format = format .. "血量状态（当前值/最大值/锁血/死亡惩罚）：%2.2f/%2.2f/%2.2f/%2.2f%%\r\n"
            format = format .. "伤害计算因素（无敌/火伤倍率/限伤/减伤率）：%s/%2.2f/%2.2f/%2.2f%%\r\n"
            format = format .. "其他（是否可回血/对玩家减伤）：%s/%2.2f%%\r\n"
            format = format .. "======================================================================================"
            local info = string.format(format, player.name, health.currenthealth, health.maxhealth, health.minhealth,
                health.penalty * 100,
                health.invincible and "true" or "false",
                health.fire_damage_scale * health.externalfiredamagemultipliers:Get(),
                (health.maxdamagetakenperhit == nil) and -1 or health.maxdamagetakenperhit,
                (1 - math.clamp(1 - health.absorb, 0, 1) * math.max(1 - health.externalabsorbmodifiers:Get(), 0)) * 100,
                health.canheal and "true" or "false",
                (1 - math.clamp(1 - health.absorb - health.playerabsorb, 0, 1) *
                    math.max(1 - health.externalabsorbmodifiers:Get(), 0)) * 100)
            SendModRPCToClient(CLIENT_MOD_RPC["kisaki"]["client_declare"], player.userid, info)
        end
    end
end

-- 获取当前玩家的精神组件信息
GLOBAL.k_sanity_info = function()
    if TheNet:GetIsServer() then
        local player = ConsoleCommandPlayer()
        if player and player.components and player.components.sanity then
            local sanity = player.components.sanity
            local format = "======================================================================================\r\n"
            format = format .. "当前玩家：%s\r\n"
            format = format .. "精神值状态（当前值/最大值/变化速率/上限减少）：%2.2f/%2.2f/%2.2f/%2.2f%%\r\n"
            format = format .. "精神值计算因素（受所有精神影响因素倍率/角色自带的持续影响光环）：%2.2f%%/%2.2f\r\n"
            format = format .. "精神值黑夜计算因素（是否免疫黑夜影响/黑暗影响倍率）：%s/%2.2f%%\r\n"
            format = format .. "精神值疯狂光环计算因素（是否免疫疯狂光环/疯狂光环影响倍率/疯狂光环吸收率）：%s/%2.2f%%/%2.2f%%\r\n"
            format = format .. "精神值装备计算因素（装备影响的基础数值/受到装备影响的倍率）：%2.2f/%2.2f%%\r\n"
            format = format .. "其他（是否强制0SAN/玩家死亡鬼魂影响系数/是否免疫潮湿影响/是否精神值锁死）：%s/%2.2f%%/%s/%s\r\n"
            format = format .. "======================================================================================"
            local info = string.format(format, player.name, sanity.current, sanity.max, sanity.rate, sanity.penalty * 100,
                sanity.rate_modifier * 100, sanity.externalmodifiers:Get(),
                sanity.light_drain_immune and "true" or "false", sanity.night_drain_mult * 100,
                sanity.neg_aura_immune and "true" or "false",
                sanity.neg_aura_mult * sanity.neg_aura_modifiers:Get() * 100, sanity.neg_aura_absorb * 100,
                sanity.dapperness, sanity.dapperness_mult * 100, sanity.inducedinsanity and "true" or "false",
                sanity.ghost_drain_mult * 100, sanity.no_moisture_penalty and "true" or "false",
                sanity.ignore and "true" or "false")
            SendModRPCToClient(CLIENT_MOD_RPC["kisaki"]["client_declare"], player.userid, info)
        end
    end
end

-- 获取当前玩家的饥饿组件信息
GLOBAL.k_hunger_info = function()
    if TheNet:GetIsServer() then
        local player = ConsoleCommandPlayer()
        if player and player.components and player.components.hunger then
            local hunger = player.components.hunger
            local format = "======================================================================================\r\n"
            format = format .. "当前玩家：%s\r\n"
            format = format .. "饥饿值状态（当前值/最大值）：%2.2f/%2.2f\r\n"
            format = format .. "饥饿值计算因素（是否饥饿锁定/饥饿速率）：%s/%2.2f%% * %2.2f%%\r\n"
            format = format .. "其他（饥饿后掉血速率）：%2.2f%%\r\n"
            format = format .. "PS:血量组件的无敌会影响是否掉饥饿，传送时也不会掉饥饿\r\n"
            format = format .. "======================================================================================"
            local info = string.format(format, player.name, hunger.current, hunger.max,
                hunger.burning and "true" or "false",
                hunger.hungerrate * 100, hunger.burnrate * hunger.burnratemodifiers:Get() * 100, hunger.hurtrate * 100)
            SendModRPCToClient(CLIENT_MOD_RPC["kisaki"]["client_declare"], player.userid, info)
        end
    end
end

-- 获取当前玩家的魔法组件信息
GLOBAL.k_magic_info = function()
    if TheNet:GetIsServer() then
        local player = ConsoleCommandPlayer()
        if player and player.components and player.components.kisaki_magic then
            local info = player.components.kisaki_magic:GetDebugString()
            SendModRPCToClient(CLIENT_MOD_RPC["kisaki"]["client_declare"], player.userid, info)
        end
    end
end

-- 获取当前玩家的等级组件信息
GLOBAL.k_level_info = function()
    if TheNet:GetIsServer() then
        local player = ConsoleCommandPlayer()
        if player and player.components and player.components.kisaki_level then
            local info = player.components.kisaki_level:GetDebugString()
            SendModRPCToClient(CLIENT_MOD_RPC["kisaki"]["client_declare"], player.userid, info)
        end
    end
end

-------------------------------------------------------------------------玩家调试-------------------------------------------------------------------------------
-- 玩家魔力值设置
GLOBAL.k_magic_set = function(val)
    if TheNet:GetIsServer() then
        val = (val and type(val) == "number") and val or 0
        local player = ConsoleCommandPlayer()
        if player and player.components and player.components.kisaki_magic then
            player.components.kisaki_magic:SetCurrent(val)
        end
    end
end

-- 玩家魔力值锁死能力修改
GLOBAL.k_magic_god = function(bool)
    if TheNet:GetIsServer() then
        if not (bool or type(bool) == "boolean") then
            bool = true
        end
        local player = ConsoleCommandPlayer()
        if player and player.components and player.components.kisaki_magic then
            player.components.kisaki_magic:SetIgnore(bool)
        end
    end
end

-- 玩家经验值设置
GLOBAL.k_exp_set = function(val)
    if TheNet:GetIsServer() then
        val = (val and type(val) == "number") and val or 0
        local player = ConsoleCommandPlayer()
        if player and player.components and player.components.kisaki_level then
            local level = player.components.kisaki_level
            level:SetCurrentExpTotal(val)
            level:Refresh()
        end
    end
end

-- 玩家等级增加
GLOBAL.k_exp_add = function(val)
    if TheNet:GetIsServer() then
        val = (val and type(val) == "number") and val or 0
        local player = ConsoleCommandPlayer()
        if player and player.components and player.components.kisaki_level then
            local level = player.components.kisaki_level
            level.current_exp_total = level.current_exp_total + val
            level:Refresh()
        end
    end
end

-- 玩家等级设置
GLOBAL.k_level_set = function(val)
    if TheNet:GetIsServer() then
        val = (val and type(val) == "number") and val or 0
        local player = ConsoleCommandPlayer()
        if player and player.components and player.components.kisaki_level then
            player.components.kisaki_level:SetCurrent(val)
        end
    end
end
