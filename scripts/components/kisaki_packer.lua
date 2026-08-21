local KisakiPacker = Class(function(self, inst)
    self.inst = inst
    self.item = nil
    self.prefab = net_string(inst.GUID, "kisaki_packer.prefab", "kisaki_packer_placerdirty")
    self.bank = net_string(inst.GUID, "kisaki_packer.bank", "kisaki_packer_placerdirty")
    self.build = net_string(inst.GUID, "kisaki_packer.build", "kisaki_packer_placerdirty")
    self.anim = net_string(inst.GUID, "kisaki_packer.anim", "kisaki_packer_placerdirty")
end)

local CANT_PACK_TAGS = {
    "player",
    "character",
    "companion",
    "teleportato",
    "nonpackable",
    "cantpack",
    "kisaki_cantpack",
    "kisaki_pack",
    "kisaki_gift",
}

local function GetPackedName(target)
    local name = target:GetDisplayName() or (target.components.named and target.components.named.name)
    if not name or name == "MISSING NAME" then
        name = target.prefab
    end

    local adjective = target:GetAdjective()
    if adjective then
        name = adjective .. " " .. name
    end
    if target.components.stackable then
        local stacksize = target.components.stackable:StackSize()
        if stacksize > 1 then
            name = name .. " x" .. tostring(stacksize)
        end
    end
    return "封印的" .. name
end

function KisakiPacker:HasPackage()
    return self.item ~= nil
end

function KisakiPacker:SetPlacer(prefab, bank, build, anim)
    self.prefab:set(prefab or "")
    self.bank:set(bank or "")
    self.build:set(build or "")
    self.anim:set(anim or "")
end

function KisakiPacker:CanPack(target)
    if not self.inst:IsValid() or self:HasPackage() or target == nil or not target:IsValid() then
        return false
    end
    for _, tag in ipairs(CANT_PACK_TAGS) do
        if target:HasTag(tag) then
            return false
        end
    end
    if target.prefab == nil or target.prefab:match("_bell$") then
        return false
    end
    if target.components.container and (target.components.container.opener or target.components.container.openner) then
        return false
    end
    return not target.components.combat or target.components.combat.defaultdamage == 0
end

function KisakiPacker:Pack(target, doer)
    if not self:CanPack(target) then
        if doer and doer.components.talker then
            doer.components.talker:Say("这个不能封印")
        end
        return false
    end
    if target.ownerlist and target.ownerlist.master and doer and target.ownerlist.master ~= doer.userid then
        if doer.components.talker then
            doer.components.talker:Say("不能封印别人的东西")
        end
        return false
    end
    if target.components.container and target.components.container:IsOpen() then
        target.components.container:Close()
    end

    local debugstring = target.entity:GetDebugString()
    local bank, build, anim = debugstring:match("bank: (.+) build: (.+) anim: .+:(.+) Frame")
    if not bank or bank:find("FROMNUM") then
        bank = target.prefab
    end
    if not build or build:find("FROMNUM") then
        build = target.prefab
    end
    if target.skinname and not Prefabs[target.prefab .. "_placer"] then
        local debuginst = SpawnPrefab(target.prefab)
        if debuginst then
            debugstring = debuginst.entity:GetDebugString()
            bank, build, anim = debugstring:match("bank: (.+) build: (.+) anim: .+:(.+) Frame")
            debuginst:Remove()
        end
    end

    self.item = {
        item = target:GetSaveRecord(),
        prefab = target.prefab,
        bank = bank or "",
        build = build or "",
        anim = anim or "",
        name = GetPackedName(target),
    }
    if target.components.teleporter and target.components.teleporter.targetTeleporter then
        self.item.item2 = target.components.teleporter.targetTeleporter:GetSaveRecord()
        target.components.teleporter.targetTeleporter:Remove()
    end

    if not self.inst.components.named then
        self.inst:AddComponent("named")
    end
    self.inst.components.named:SetName(self.item.name)
    self.inst.components.inspectable:SetDescription("这是" .. self.item.name)
    self.inst:AddTag("kisaki_gift_full")
    self:SetPlacer(self.item.prefab, self.item.bank, self.item.build, self.item.anim)
    target:Remove()
    return true
end

function KisakiPacker:Unpack(pos)
    if not self.item or not self.item.item then
        return false
    end

    local previous_ingameplay = inGamePlay
    inGamePlay = false
    local success, item = pcall(SpawnSaveRecord, self.item.item)
    if success and item and item:IsValid() then
        if item.Physics then
            item.Physics:Teleport(pos:Get())
        else
            item.Transform:SetPosition(pos:Get())
        end
        if item.components.inventoryitem then
            item.components.inventoryitem:OnDropped(true, .5)
        end

        if self.item.item2 then
            local success2, item2 = pcall(SpawnSaveRecord, self.item.item2)
            if success2 and item2 and item.components.teleporter and item2.components.teleporter then
                item2.components.teleporter:Target(item)
                item.components.teleporter:Target(item2)
            end
        end
    end
    inGamePlay = previous_ingameplay

    return success and item and item:IsValid()
end

function KisakiPacker:OnSave()
    return self.item and { item = self.item } or nil
end

function KisakiPacker:OnLoad(data)
    if data and data.item then
        self.item = data.item
        if not self.inst.components.named then
            self.inst:AddComponent("named")
        end
        self.inst.components.named:SetName(self.item.name)
        self.inst.components.inspectable:SetDescription("这是" .. self.item.name)
        self.inst:AddTag("kisaki_gift_full")
        self:SetPlacer(self.item.prefab or self.item.item.prefab, self.item.bank or "", self.item.build or "",
            self.item.anim or "")
    end
end

return KisakiPacker
