local achievement_defs = require("kisaki_defs/achievement_defs").ACHIEVEMENT_DEFS
local prefab_achievement_map = require("kisaki_defs/achievement_defs").PREFAB_ACHIEVEMENT_MAP
local achievement_init_num = require("kisaki_defs/achievement_defs").ACHIEVEMENT_INIT_NUM

local log = require("utils/kisakilogger")

-------------------------------------------------------------------------初始化数据----------------------------------------------------------------------------

local function init(self)
    log.debug("执行了成就组件内部初始化的方法")
end

----------------------------------------------------------------------------监听-------------------------------------------------------------------------------

-- 周围有生物死亡时，触发异界巨兽模块成就监听
local function onentitydeath(inst, data)
    log.info("触发角色成就模块内的生物死亡监听")
    if inst:HasTag('playerghost') or not inst.components.kisaki_achievement then return end -- 角色死亡停止
    if data and data.inst and data.afflicter then
        local the_dead = data.inst                                                          -- 被杀死的对象
        local the_afflicter = data.afflicter                                                -- 造成击杀的事物
        -- 对象必须是被玩家击杀且对象不是玩家，对象死亡时需要在玩家6格地皮以内
        if not the_dead:HasTag("player") and the_afflicter:HasTag("player")
            and not (the_dead.components.kisaki_kill_info and the_dead.components.kisaki_kill_info:GetKiller("kisaki_achievement" .. inst.userid))
            and the_dead.prefab and the_dead.IsNear and the_dead:IsNear(inst, 24) then
            -- 判断下击杀是否有对应的成就
            local achievement_list = prefab_achievement_map["kill_" .. the_dead.prefab]
            if achievement_list and type(achievement_list) == "table" then
                for i = 1, #achievement_list do
                    local name = achievement_list[i]
                    if achievement_defs[name] and achievement_defs[name].listen_fn then
                        achievement_defs[name].listen_fn(inst)
                    end
                end
            end
            -- 防止鞭尸
            if not the_dead.components.kisaki_kill_info then
                the_dead:AddComponent("kisaki_kill_info")
            end
            the_dead.components.kisaki_kill_info:SetKiller("kisaki_achievement" .. inst.userid)
            -- log.debug("击杀的怪物是否有定义的信息：" .. (the_dead.components.kisaki_kill_info:GetKiller("kisaki_level" .. inst.userid) and "true" or "false"))
        end
    end
end

----------------------------------------------------------------------------CLASS-----------------------------------------------------------------------------

local Achievement = Class(function(self, inst)
    self.inst = inst                                                                             -- 角色
    self.achievement = achievement_init_num                                                      -- 成就完成情况

    inst.kisakiAchievementListenEnityDeath = function(world, data) onentitydeath(inst, data) end -- 定义角色方法
    inst:ListenForEvent("entity_death", inst.kisakiAchievementListenEnityDeath, TheWorld)        -- 监听周围生物死亡
end, nil, {
    -- 监听数据变化，影响显示的需要同步到客户端
})

----------------------------------------------------------------------------GET/SET----------------------------------------------------------------------------

function Achievement:SetAchievement(achievement) self.achievement = achievement end

function Achievement:GetAchievement() return self.achievement end

function Achievement:GetDebugString()
    local format = "======================================================================================\r\n"
    format = format .. "当前玩家：%s\r\n"
    format = string.format(format, self.inst.name and self.inst.name or "nil")
    for k, v in pairs(self.achievement) do
        format = format .. "成就：%s 当前信息如下（是否完成/已完成数量/需要完成数量）：%s/%2.2f/%2.2f\r\n"
        format = string.format(format, k, self:isDone(k) and "是" or "否", v, achievement_defs[k].done_number or 1)
    end
    format = format .. "======================================================================================"
    return format
end

------------------------------------------------------------------------------常用方法---------------------------------------------------------------------------

function Achievement:isDone(achievement)
    if achievement_defs[achievement] then
        local done_number = achievement_defs[achievement].done_number or 1
        if self.achievement and self.achievement[achievement] then
            return self.achievement[achievement] >= done_number
        end
    end
    return false
end

function Achievement:addNum(achievement, num)
    num = num or 1
    if self.achievement then
        if self.achievement[achievement] and achievement_defs[achievement] then
            local max = achievement_defs[achievement].done_number or 1
            self.achievement[achievement] = math.min(self.achievement[achievement] + num, max)
        else
            self.achievement[achievement] = 1
        end
        self:sync(achievement)
    end
end

function Achievement:sync(achievement)
    if self.inst and self.inst.replica and self.inst.replica.kisaki_achievement then
        self.inst.replica.kisaki_achievement:sync(achievement, self.achievement[achievement])
    end
end

----------------------------------------------------------------------------加载时运行---------------------------------------------------------------------------

function Achievement:OnSave()
    log.debug("执行了成就组件内部存储成就数据的方法")
    return
    {
        achievement = self.achievement,
    }
end

function Achievement:OnLoad(data)
    log.debug("执行了成就组件内部读取成就数据的方法")
    if not data then return end
    if data.achievement ~= nil then
        local achievement_data = data.achievement
        for k, v in pairs(achievement_data) do
            self.achievement[k] = v
            self:sync(k)
        end
    end
end

-- 角色数据保存模块调用
Achievement.OnPlayerSave = Achievement.OnSave
Achievement.OnPlayerLoad = Achievement.OnLoad

return Achievement
