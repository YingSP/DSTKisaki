local Level = Class(function(self, inst)
    self.inst = inst
    self.current = net_ushortint(inst.GUID, "kisaki_level.current")
    self.current_exp = net_float(inst.GUID, "kisaki_level.current_exp")
    self.levelup_need_exp = net_float(inst.GUID, "kisaki_level.levelup_need_exp")

    -- self.current_exp_total = net_float(inst.GUID, "kisaki_level.current_exp_total")
    -- self.current_today_exp = net_float(inst.GUID, "kisaki_level.current_today_exp")
    -- self.exp_pre_day_max = net_float(inst.GUID, "kisaki_level.exp_pre_day_max")
    -- self.is_today_kill_boss = net_bool(inst.GUID, "kisaki_level.is_today_kill_boss")
    -- self.is_death_punishment = net_bool(inst.GUID, "kisaki_level.is_death_punishment")
end)

function Level:SetCurrent(amount) self.current:set(amount) end

function Level:SetCurrentExp(amount) self.current_exp:set(amount) end

function Level:SetLevelUpNeedExp(amount) self.levelup_need_exp:set(amount) end

-- function Level:SetCurrentExpTotal(amount) self.current_exp_total:set(amount) end

-- function Level:SetCurrentTodayExp(amount) self.current_today_exp:set(amount) end

-- function Level:SetExpPreDayMax(amount) self.exp_pre_day_max:set(amount) end

-- function Level:SetIsTodayKillBoss(amount) self.is_today_kill_boss:set(amount) end

-- function Level:SetIsDeathPunishment(amount) self.is_death_punishment:set(amount) end

function Level:GetCurrent() return self.current:value() end

function Level:GetCurrentExp() return math.floor(self.current_exp:value()) end

function Level:GetLevelUpNeedExp() return math.floor(self.levelup_need_exp:value()) end

-- function Level:GetCurrentExpTotal() return math.floor(self.current_exp_total:value()) end

-- function Level:GetCurrentTodayExp() return math.floor(self.current_today_exp:value()) end

-- function Level:GetExpPreDayMax() return math.floor(self.exp_pre_day_max:value()) end

-- function Level:GetIsTodayKillBoss() return self.is_today_kill_boss:value() end

-- function Level:GetIsDeathPunishment() return self.is_death_punishment:value() end

function Level:GetPercent()
    return self.current_exp:value() / math.max(1, self.levelup_need_exp:value())
end

return Level
