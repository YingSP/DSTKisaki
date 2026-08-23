local TechTree = require("techtree")
local name = "kisaki_space_chest"

-- 夜莺与黄昏之诗
local assets = {
    Asset("ATLAS", "images/inventoryimages/prefabs/" .. name .. ".xml"),
    Asset("IMAGE", "images/inventoryimages/prefabs/" .. name .. ".tex"),
    Asset("ANIM", "anim/" .. name .. ".zip"),
    Asset("ANIM", "anim/ui_kisaki_container_space.zip"),
}

local function onopen(inst)
    inst.AnimState:PlayAnimation("open")
    inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_open")
end

local function onclose(inst)
    inst.AnimState:PlayAnimation("closed")
    inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_close")
end
local function AttachShadowContainer(inst)
    inst.components.container_proxy:SetMaster(TheWorld:GetPocketDimensionContainer("kisaki_space_chest_child"))
end
local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()     -- 管理实体的位置、旋转和缩放
    inst.entity:AddAnimState()     -- 控制实体的动画
    inst.entity:AddSoundEmitter()  -- 管理实体的声音
    inst.entity:AddLight()         -- 控制物体发光
    inst.entity:AddNetwork()       -- 网络同步功能
    inst.entity:AddMiniMapEntity() -- 地图图标

    inst.MiniMapEntity:SetIcon(name .. ".tex")
    inst.AnimState:SetBank(name)
    inst.AnimState:SetBuild(name)
    inst.AnimState:PlayAnimation("closed", true)
    inst.Light:SetFalloff(0.9)   -- 设置光照衰减
    inst.Light:SetIntensity(0.8) -- 设置光照强度
    inst.Light:SetRadius(16)     -- 设置光照半径
    inst.Light:SetColour(237 / 255, 237 / 255, 209 / 255)

    inst:AddTag("structure")
    inst:AddTag("kisaki_chest")
    inst:AddTag("kisaki_library_box")
    inst:AddTag("nosteal")
    inst:AddTag("prototyper")
    inst:AddTag("giftmachine")
    inst:AddTag("meteor_protection")
    inst:AddTag("NORATCHECK")

    inst:AddComponent("container_proxy")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.components.container_proxy:SetOnOpenFn(onopen)
    inst.components.container_proxy:SetOnCloseFn(onclose)
    inst:AddComponent("inspectable")
    inst:AddComponent("craftingstation")
    inst:AddComponent("prototyper")
    inst.components.prototyper.trees = { SCIENCE = 1, MAGIC = 1, BOOKCRAFT = 5, KISAKI_BOOKCRAFT = 1 }
    inst:AddComponent("lootdropper")
    inst:AddComponent("preserver") -- 保鲜
    inst.components.preserver:SetPerishRateMultiplier(0)
    inst.prefab = "kisaki_space_chest"

    inst.OnLoadPostPass = AttachShadowContainer
    if not POPULATING then
        AttachShadowContainer(inst)
    end
    TheWorld.components.kisaki_ents_manager:RegisterOriginalChest(inst)
    inst:ListenForEvent("onremove", function()
        TheWorld.components.kisaki_ents_manager:UnRegisterOriginalChest(inst)
    end)
    return inst
end

return Prefab("kisaki_space_chest", fn, assets),
    MakePlacer("kisaki_space_chest_placer", "kisaki_space_chest", "kisaki_space_chest", "closed")
