local function MakeItem(name, def)
    -- 导入动画
    local assets = def.assets or {
        Asset("ANIM", "anim/" .. name .. ".zip"),
        Asset("ATLAS", "images/inventoryimages/prefabs/" .. name .. ".xml"),
        Asset("IMAGE", "images/inventoryimages/prefabs/" .. name .. ".tex")
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()                       -- 管理实体的位置、旋转和缩放
        inst.entity:AddAnimState()                       -- 控制实体的动画
        inst.entity:AddSoundEmitter()                    -- 管理实体的声音
        inst.entity:AddNetwork()                         -- 网络同步功能

        MakeInventoryPhysics(inst)                       -- 为实体添加物理特性，使其能够作为物品被玩家拾取和携带。
        MakeInventoryFloatable(inst, "med", nil, 0.75)   -- 为实体添加浮力特性，使其能够在水中漂浮。

        inst.AnimState:SetBank(def.bank or name)         -- 地上动画
        inst.AnimState:SetBuild(def.build or name)       -- 材质包，就是anim里的zip包
        inst.AnimState:PlayAnimation(def.anim or "idle") -- 默认播放哪个动画

        -- 添加标签
        inst:AddTag("kisaki_item")
        if def.tags then
            for _, tag in pairs(def.tags) do
                inst:AddTag(tag)
            end
        end
        -- 额外执行方法
        if def.eneity_postinit then
            def.eneity_postinit(inst)
        end

        inst.entity:SetPristine() -- 设置为初始状态
        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddTag("meteor_protection")   -- 防止被流星破坏
        inst:AddTag("nosteal")             -- 不可以被猴子偷走
        inst:AddTag("NORATCHECK")          -- mod兼容：永不妥协。该道具不算鼠潮分

        inst:AddComponent("inspectable")   -- 可检查
        inst:AddComponent("inventoryitem") -- 可放入背包
        inst.components.inventoryitem.imagename = def.image or name
        inst.components.inventoryitem.atlasname = def.atlas or ("images/inventoryimages/prefabs/" .. name .. ".xml")

        inst:AddComponent("stackable") -- 可堆叠
        inst.components.stackable.maxsize = def.maxsize or TUNING.STACK_SIZE_PELLET

        inst:AddComponent("tradable") -- 可交易

        MakeHauntableLaunch(inst)     -- 可作祟

        -- 额外执行方法
        if def.master_postinit then
            def.master_postinit(inst)
        end

        -- 保存读取
        if def.onsave then
            inst.OnSave = def.onsave
        end
        if def.onload then
            inst.OnLoad = def.onload
        end
        if def.onpreload then
            inst.OnPreLoad = def.onpreload
        end

        return inst
    end

    return Prefab(name, fn, assets)
end

local item_defs = {} -- 物品列表
-- 以太
item_defs.kisaki_ether = {}

local items = {}
for k, v in pairs(item_defs) do
    table.insert(items, MakeItem(k, v))
end
return unpack(items)
