----------------------------------------------------------------------------CLASS-----------------------------------------------------------------------------

local KillInfo = Class(function(self, inst)
    self.inst = inst  -- 怪物
    self.killer = nil -- 击杀记录
end, nil, {
})

function KillInfo:SetKiller(killer)
    if self.killer == nil then
        self.killer = { [killer] = true }
    else
        self.killer[killer] = true
    end
end

function KillInfo:GetKiller(killer)
    if self.killer == nil then
        return false
    elseif self.killer[killer] then
        return self.killer[killer]
    end
    return false
end

----------------------------------------------------------------------------加载时运行---------------------------------------------------------------------------

function KillInfo:OnSave()
    return
    {
        killer = self.killer,
    }
end

function KillInfo:OnLoad(data)
    if not data then return end
    self.killer = data.killer ~= nil and data.killer or {}
end

return KillInfo
