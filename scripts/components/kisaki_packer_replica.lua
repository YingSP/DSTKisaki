local KisakiPacker = Class(function(self, inst)
    self.inst = inst
    self.prefab = net_string(inst.GUID, "kisaki_packer.prefab", "kisaki_packer_placerdirty")
    self.bank = net_string(inst.GUID, "kisaki_packer.bank", "kisaki_packer_placerdirty")
    self.build = net_string(inst.GUID, "kisaki_packer.build", "kisaki_packer_placerdirty")
    self.anim = net_string(inst.GUID, "kisaki_packer.anim", "kisaki_packer_placerdirty")
    inst:ListenForEvent("kisaki_packer_placerdirty", function()
        self:RefreshPlacer()
    end)
end)

function KisakiPacker:RefreshPlacer()
    local prefab = self.prefab:value()
    local bank = self.bank:value()
    local build = self.build:value()
    local anim = self.anim:value()
    if prefab == "" or bank == "" or build == "" or anim == "" then
        return
    end
    if Prefabs[prefab .. "_placer"] then
        self.inst.overridedeployplacername = prefab .. "_placer"
        return
    end

    local placer_name = string.format("kisaki_packer_placer_%s_%s_%s", bank, build, anim):lower()
    if placer_name:find("fromnum") then
        self.inst.overridedeployplacername = nil
        return
    end
    if not Prefabs[placer_name] then
        local placer = MakePlacer(placer_name, bank, build, anim)
        RegisterPrefabs(placer)
        TheSim:LoadPrefabs({ placer_name })
    end
    self.inst.overridedeployplacername = placer_name
end

return KisakiPacker
