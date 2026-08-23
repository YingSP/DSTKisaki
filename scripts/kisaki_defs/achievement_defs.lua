-------------------------------------------------------------------成就列表------------------------------------------------------------------------------------
local log = require("utils/kisakilogger")
local achievement_defs = {}

local achievement_type = {
    KILL_EPIC = "kill_epic"
}

--------------------------------------------击杀BOSS相关成就--------------------------------------------

-- 击杀树精
achievement_defs.kill_leif = {
    name = "堂吉诃德勇气的证明",
    describe = "击败树精守卫",
    type = achievement_type.KILL_EPIC,
    done_number = 1,
    listen_prefab_action = { "kill_leif", "kill_leif_sparse" },
    -- 传参在外部校验，直接处理逻辑
    listen_fn = function(player)
        if not player.components.kisaki_achievement:isDone("kill_leif") then
            player.components.kisaki_achievement:addNum("kill_leif")
        end
    end
}

-- 击杀树精
achievement_defs.kill_spiderqueen = {
    name = "夏洛特的网",
    describe = "击败蜘蛛女王",
    type = achievement_type.KILL_EPIC,
    done_number = 1,
    listen_prefab_action = { "kill_spiderqueen" },
    -- 传参在外部校验，直接处理逻辑
    listen_fn = function(player)
        if not player.components.kisaki_achievement:isDone("kill_spiderqueen") then
            player.components.kisaki_achievement:addNum("kill_spiderqueen")
        end
    end
}

---------------------------------------------------------------------预制物对应的成就----------------------------------------------------------------------------

local prefab_achievement_map = {}
for k, v in pairs(achievement_defs) do
    if v.listen_prefab_action then
        local acts = v.listen_prefab_action
        for i = 1, #acts do
            local act = acts[i]
            if prefab_achievement_map[act] then
                table.insert(prefab_achievement_map[act], k)
            else
                prefab_achievement_map[act] = { k }
            end
        end
    end
end
-- debug
if TUNING.KISAKI_LOGLEVEL <= 1 then
    for k, v in pairs(prefab_achievement_map) do
        if type(v) == "table" then
            local str = "执行操作：" .. k .. "会完成以下成就：{"
            for i = 1, #v do
                str = str .. " " .. v[i] .. " "
            end
            str = str .. "}"
            log.debug(str)
        else
            log.debug("执行操作：" .. k .. "会完成以下成就：" .. v)
        end
    end
end

------------------------------------------------------------------------成就名称集-------------------------------------------------------------------------------

-- TODO，成就系统未完成
local achievement_init_num = {}
for k, v in pairs(achievement_defs) do
    achievement_init_num[k] = 0
end



return {
    ACHIEVEMENT_DEFS = achievement_defs,
    PREFAB_ACHIEVEMENT_MAP = prefab_achievement_map,
    ACHIEVEMENT_INIT_NUM = achievement_init_num,
}
