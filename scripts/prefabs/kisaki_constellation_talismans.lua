local assets = {
    Asset("ANIM", "anim/kisaki_constellation_talismans.zip"),
    Asset("ATLAS", "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml"),
    Asset("IMAGE", "images/inventoryimages/prefabs/kisaki_constellation_talismans.tex")
}

local function MakeTailsman(def)
    local function commonfn()
        local inst = CreateEntity()

        inst.entity:AddTransform()                                   -- 管理实体的位置、旋转和缩放
        inst.entity:AddAnimState()                                   -- 控制实体的动画
        inst.entity:AddSoundEmitter()                                -- 管理实体的声音
        inst.entity:AddNetwork()                                     -- 网络同步功能

        MakeInventoryPhysics(inst)                                   -- 为实体添加物理特性，使其能够作为物品被玩家拾取和携带。
        MakeInventoryFloatable(inst, "med", nil, 0.75)               -- 为实体添加浮力特性，使其能够在水中漂浮。

        inst.AnimState:SetBank("kisaki_constellation_talismans")     -- 地上动画
        inst.AnimState:SetBuild("kisaki_constellation_talismans")    -- 材质包，就是anim里的zip包
        inst.AnimState:PlayAnimation("kisaki_talisman_" .. def.name) -- 默认播放哪个动画

        inst:AddTag("shadowlevel")                                   -- 暗影等级
        inst:AddTag("kisaki_constellation_talisman")                 -- 护符tag标识
        inst:AddTag("kisaki_amulet")

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
        inst.components.inventoryitem.imagename = "kisaki_talisman_" .. def.name
        inst.components.inventoryitem.atlasname = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml"
        inst:AddComponent("equippable")                                           -- 可装备
        inst.components.equippable.equipslot = EQUIPSLOTS.NECK or EQUIPSLOTS.BODY -- 装备的部位是护符或者身体
        inst.components.equippable:SetOnEquip(def.onequip)                        -- 装备时执行
        inst.components.equippable:SetOnUnequip(def.onunequip)                    -- 取下装备时执行
        inst.components.equippable.walkspeedmult = def.walkspeedmult or 1         -- 装备获得加速
        inst.components.equippable.dapperness = def.dapperness or 0               -- 装备获得回SAN
        if def.shadowlevel then
            inst:AddComponent("shadowlevel")                                      -- 暗影等级
            inst.components.shadowlevel:SetDefaultLevel(def.shadowlevel)
        end
        if def.restrictedtag then
            inst.components.equippable.restrictedtag = def.restrictedtag -- 限制特定tag的角色可装备
        end
        inst:AddTag("amulet")                                            -- 护符位

        MakeHauntableLaunch(inst)                                        -- 可作祟

        -- 额外执行方法
        if def.master_postinit then
            def.master_postinit(inst)
        end

        return inst
    end

    return Prefab("kisaki_talisman_" .. def.name, commonfn, assets)
end

local prefs = {}

for i, v in ipairs(require("kisaki_defs/constellation_talisman_defs")) do
    table.insert(prefs, MakeTailsman(v))
end

return unpack(prefs)
