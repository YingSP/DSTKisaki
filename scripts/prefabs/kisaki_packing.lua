local packname = "kisaki_pack"
local giftname = "kisaki_gift"


local function getassets(name, animname)
    return {
        Asset("ANIM", "anim/" .. animname .. ".zip"),
        Asset("ATLAS", "images/inventoryimages/prefabs/" .. name .. ".xml"),
        Asset("IMAGE", "images/inventoryimages/prefabs/" .. name .. ".tex"),
    }
end

local function OnDeploy(inst, pt)
    if inst.components.kisaki_packer and inst.components.kisaki_packer:Unpack(pt) then
        inst:Remove()
    end
end

local function fn(name, bank, build, anim)
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst, "med", nil, 0.75)
    inst.AnimState:SetBank(bank)
    inst.AnimState:SetBuild(build)
    inst.AnimState:PlayAnimation(anim)
    inst:AddTag("nonpackable")
    if name == packname then
        inst:AddTag("kisaki_pack")
    else
        inst:AddTag("kisaki_gift")
        inst:AddTag("_named")
    end
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/prefabs/" .. name .. ".xml"
    inst.components.inventoryitem.imagename = name
    if name == packname then
        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
        inst:AddComponent("tradable")
    else
        inst:AddComponent("kisaki_packer")
        inst:AddComponent("deployable")
        inst.components.deployable.ondeploy = OnDeploy
        inst.components.deployable:SetDeploySpacing(DEPLOYSPACING.DEFAULT)
    end

    MakeHauntableLaunch(inst)
    return inst
end

return Prefab("kisaki_pack", function()
        return fn(packname, packname, packname, "idle")
    end, getassets(packname, packname)),
    Prefab("kisaki_gift", function()
        return fn(giftname, giftname, giftname, "idle")
    end, getassets(giftname, giftname)),
    MakePlacer("kisaki_gift_placer", giftname, giftname, "idle")
