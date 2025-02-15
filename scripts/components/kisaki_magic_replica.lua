local Sanity = Class(function(self, inst)
    self.inst = inst
    self.max = net_float(inst.GUID, "kisaki_magic.max")
    self.current = net_float(inst.GUID, "kisaki_magic.current")
    self.ratescale = net_ushortint(inst.GUID, "kisaki_magic.ratescale")
end)

function Sanity:SetMax(amount) self.max:set(amount) end

function Sanity:SetCurrent(amount) self.current:set(amount) end

function Sanity:SetRateScale(amount) self.ratescale:set(amount) end

function Sanity:GetMax() return math.floor(self.max:value()) end

function Sanity:GetCurrent() return math.floor(self.current:value()) end

function Sanity:GetRateScale() return self.ratescale:value() end

function Sanity:GetPercent()
    return self.current:value() / math.max(1, self.max:value())
end

return Sanity
