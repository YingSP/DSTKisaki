local achievement_init_num = require("kisaki_defs/achievement_defs").ACHIEVEMENT_INIT_NUM
local achievement_defs = require("kisaki_defs/achievement_defs").ACHIEVEMENT_DEFS

local log = require("utils/kisakilogger")

local Achievement = Class(function(self, inst)
    self.inst = inst
    -- 初始化
    log.debug("执行了成就组件replica内部初始化的方法")
    for k, v in pairs(achievement_init_num) do
        self[k] = net_float(inst.GUID, "kisaki_achievement." .. k)
    end
end)

function Achievement:sync(achievement, num)
    self[achievement]:set(num)
end

function Achievement:get(achievement)
    return self[achievement]:value()
end

function Achievement:getAll()
    local result = {}
    for k, v in pairs(achievement_init_num) do
        result[k] = self[k]:value() or 0
    end
    return result
end

function Achievement:isDone(achievement)
    if achievement_defs[achievement] then
        local done_number = achievement_defs[achievement].done_number or 1
        if self[achievement] then
            return self:get(achievement) >= done_number
        end
    end
    return false
end

function Achievement:GetDebugString()
    local format = "======================================================================================\r\n"
    format = format .. "当前玩家：%s\r\n"
    format = string.format(format, self.inst.name and self.inst.name or "nil")
    local info = self:getAll()
    for k, v in pairs(info) do
        format = format .. "成就：%s 当前信息如下（是否完成/已完成数量/需要完成数量）：%s/%2.2f/%2.2f\r\n"
        format = string.format(format, k, self:isDone(k) and "是" or "否", v, achievement_defs[k].done_number or 1)
    end
    format = format .. "======================================================================================"
    return format
end

return Achievement
