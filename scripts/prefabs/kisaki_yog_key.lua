local name = "kisaki_yog_key"

local assets = {
    Asset("ANIM", "anim/" .. name .. ".zip"),
    Asset("ATLAS", "images/inventoryimages/prefabs/" .. name .. ".xml"),
    Asset("IMAGE", "images/inventoryimages/prefabs/" .. name .. ".tex")
}

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()     -- 管理实体的位置、旋转和缩放
    inst.entity:AddAnimState()     -- 控制实体的动画
    inst.entity:AddSoundEmitter()  -- 管理实体的声音
    inst.entity:AddNetwork()       -- 网络同步功能
    inst.entity:AddMiniMapEntity() -- 地图图标

    inst.MiniMapEntity:SetIcon(name .. ".tex")
    inst.AnimState:SetBank(name)
    inst.AnimState:SetBuild(name)
    inst.AnimState:PlayAnimation("idle", true)

    inst:AddTag("meteor_protection") -- 防止被流星破坏
    inst:AddTag("nosteal")           -- 不可以被猴子偷走
    inst:AddTag("NORATCHECK")        -- mod兼容：永不妥协。该道具不算鼠潮分
    inst:AddTag("kisaki_container_linker")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inventoryitem") -- 可放入背包
    inst.components.inventoryitem.imagename = name
    inst.components.inventoryitem.atlasname = "images/inventoryimages/prefabs/" .. name .. ".xml"

    inst.current_opener = nil
    inst.stopUsing = function()
        if inst.container then
            if inst.current_opener then
                inst.container.components.container_proxy:Close(inst.current_opener)
            end
            inst.container:Remove()
            inst.container = nil
        end
    end
    inst:ListenForEvent("ondropped", inst.stopUsing)
    inst:ListenForEvent("onputininventory", inst.stopUsing)
    return inst
end

local function containerfn()
    local inst = CreateEntity()

    inst.entity:AddNetwork()

    inst:AddTag("CLASSIFIED")
    inst:Hide()

    inst:AddComponent("container_proxy")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.components.container_proxy:SetMaster(TheWorld:GetPocketDimensionContainer("kisaki_space_chest_child"))

    inst.persists = false

    return inst
end

return Prefab("kisaki_yog_key", fn, assets),
    Prefab("kisaki_yog_key_container", containerfn, assets)
