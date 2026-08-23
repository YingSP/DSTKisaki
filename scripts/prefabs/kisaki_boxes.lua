local function onopen(inst)
    inst.AnimState:PlayAnimation("open")
    inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_open")
    if inst.components.inventoryitem then
        local skin_name = inst:GetSkinName() or inst._baseinventoryimagename
        inst.components.inventoryitem:ChangeImageName(skin_name .. "_open")
    end
end

local function onclose(inst)
    inst.AnimState:PlayAnimation("closed")
    inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_close")
    if inst.components.inventoryitem then
        local skin_name = inst:GetSkinName() or inst._baseinventoryimagename
        inst.components.inventoryitem:ChangeImageName(skin_name)
    end
end

local function ondropped(inst)
    if inst.components.container ~= nil then
        inst.components.container:Close()
    end
end
-- 转移容器内物品(原容器,新容器)
local function transferEverything(inst, obj)
    if inst.components.container and not inst.components.container:IsEmpty() then
        if obj.components.container then
            for slot, v in pairs(inst.components.container.slots) do
                local item = inst.components.container:GetItemInSlot(slot)
                if (item) then
                    if item.components.stackable then
                        inst.components.container.ignoreoverstacked = true
                        item = inst.components.container:RemoveItemBySlot(slot)
                        inst.components.container.ignoreoverstacked = false
                    else
                        item = inst.components.container:RemoveItemBySlot(slot)
                    end
                    obj.components.container:GiveItem(item, slot)
                end
            end
        end
    end
    if inst.syncboxpropertyfn then
        inst.syncboxpropertyfn(inst, obj)
    end
end
-- 当放在地上时
local function ondeploy(inst, pt, deployer)
    local chest = SpawnPrefab(inst.prefab .. "_chest")
    if chest ~= nil then
        chest.Transform:SetPosition(pt.x, pt.y, pt.z)
        chest.AnimState:PushAnimation("closed")
        chest.SoundEmitter:PlaySound("dontstarve/common/dragonfly_chest_craft")
        transferEverything(inst, chest)
        inst:Remove()
    end
end
-- 被锤/回收时
local function onhammered(inst, worker)
    local item = SpawnPrefab(inst.prefab:sub(1, -7))
    if item ~= nil then
        -- 特效
        inst.SoundEmitter:PlaySound("dontstarve/common/fireAddFuel")
        local fx = SpawnPrefab("collapse_small")
        local pos = Vector3(inst.Transform:GetWorldPosition())
        fx.Transform:SetScale(0.5, 0.5, 0.5)
        fx.Transform:SetPosition(pos:Get())
        local fx2 = SpawnPrefab("small_puff")
        fx2.entity:SetParent(inst.entity)
        fx2.Transform:SetPosition(0, 3, 0)
        -- 复制属性
        transferEverything(inst, item)
        item.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
    inst:Remove()
end

local function MagicBoxTraderCount(inst, giver, item)
    for i, data in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
        if item.prefab == data.needprefab then
            local action = data.action
            return math.max(inst[action .. "neednum"] - inst[action .. "num"], 0)
        end
    end
    return 1
end
local function MagicBoxAcceptTest(inst, item)
    for i, data in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
        if item.prefab == data.needprefab then
            local action = data.action
            return inst[action .. "neednum"] > inst[action .. "num"], "GENERIC"
        end
    end
    return false, "WRONGTYPE"
end
local function MagicBoxOnGetItemFromPlayer(inst, giver, item)
    local num = 1
    if item.components.stackable then
        num = item.components.stackable.stacksize
    end
    for i, data in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
        if item.prefab == data.needprefab then
            local action = data.action
            -- 更新数据
            inst[action .. "num"] = inst[action .. "num"] + num
            -- 刷新功能
            if action == "preserver" or action == "fresh" then
                inst.addpreserver()
            elseif action == "durability" or action == "autodurability" then
                inst.addrestorationdurability()
            end
            -- 语音提示
            if inst[action .. "neednum"] > inst[action .. "num"] then
                giver.components.talker:Say(string.format("%s:\t%s\t(%d/%d)\n", data.name or "nil",
                    STRINGS.NAMES[string.upper(data.needprefab)] or "nil",
                    inst[action .. "num"] or 0, inst[action .. "neednum"] or 0))
            else
                giver.components.talker:Say(string.format("%s已满，%s功能已解锁",
                    STRINGS.NAMES[string.upper(data.needprefab)] or "nil", data.name or "nil"))
            end
            break
        end
    end
end
local function MagicBoxOnRefuseItem(inst, giver, item)
    if item then
        local upgradesay = "\n\n\n\n\n\n\n\n\n\n\n\n\n容器升级\n"
        for i, data in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
            upgradesay = upgradesay ..
                string.format("%s:\t%s\t(%d/%d)\n", data.name or "nil",
                    STRINGS.NAMES[string.upper(inst[data.action .. "needprefab"])] or "nil",
                    inst[data.action .. "num"] or 0, inst[data.action .. "neednum"] or 0)
        end
        giver.components.talker:Say(upgradesay)
    end
end

local function RestoreBooks(inst)
    for k, v in pairs(inst.components.container.slots) do
        if v:HasTag("book") and v.components.finiteuses then
            local percent = v.components.finiteuses:GetPercent()
            if percent < 1 then
                v.components.finiteuses:SetPercent(math.min(1,
                    percent +
                    (TUNING.BOOKSTATION_RESTORE_AMOUNT * TUNING.BOOKSTATION_WICKER_BONUS * inst.restore_efficiency)))
            end
        end
    end
end
local function LibraryBoxItemGet(inst)
    if inst.RestoreTask == nil then
        if inst.components.container:HasItemWithTag("book", 1) then
            inst.RestoreTask = inst:DoPeriodicTask(TUNING.BOOKSTATION_RESTORE_TIME, RestoreBooks)
        end
    end
end
local function LibraryBoxItemLose(inst)
    if not inst.components.container:HasItemWithTag("book", 1) then
        if inst.RestoreTask ~= nil then
            inst.RestoreTask:Cancel()
            inst.RestoreTask = nil
        end
    end
end
local function LibraryBoxRefresh(inst)
    for i, data in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
        local id = data.id
        if data.neednum <= inst[id .. "num"] then
            if id == "fast" then
                inst.restore_efficiency = 5
            elseif inst.components.prototyper and inst.components.prototyper.trees then
                for levelname, level in pairs(data.levels) do
                    inst.components.prototyper.trees[levelname] = level
                end
                -- 加标签
                if data.tags then
                    for _, tag in ipairs(data.tags) do
                        inst:AddTag(tag)
                    end
                end
                -- 额外制作站
                local craftingstation = inst.components.craftingstation
                if craftingstation and id == "hermitcrabshop" then
                    -- craftingstation:LearnItem("hermitcrab_relocation_kit", "hermitshop_hermitcrab_relocation_kit")
                    craftingstation:LearnItem("supertacklecontainer", "hermitshop_supertacklecontainer")
                    craftingstation:LearnItem("winter_ornament_boss_pearl", "hermitshop_winter_ornament_boss_pearl")
                    craftingstation:LearnItem("winter_ornament_boss_hermithouse",
                        "hermitshop_winter_ornament_boss_hermithouse")
                elseif craftingstation and id == "wanderingtradershop" then
                    craftingstation:LearnItem("gears", "wanderingtradershop_gears")
                    craftingstation:LearnItem("flint", "wanderingtradershop_flint")
                    craftingstation:LearnItem("pigskin", "wanderingtradershop_pigskin")
                    craftingstation:LearnItem("livinglog", "wanderingtradershop_livinglog")
                    craftingstation:LearnItem("redgem", "wanderingtradershop_redgem")
                    craftingstation:LearnItem("bluegem", "wanderingtradershop_bluegem")
                    craftingstation:LearnItem("cutgrass", "wanderingtradershop_cutgrass")
                    craftingstation:LearnItem("twigs", "wanderingtradershop_twigs")
                    craftingstation:LearnItem("cutreeds", "wanderingtradershop_cutreeds")
                    craftingstation:LearnItem("moonglass", "wanderingtradershop_moonglass")
                end
            end
        end
    end
end
local function LibraryBoxTraderCount(inst, giver, item)
    for i, data in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
        if item.prefab == data.needprefab then
            local id = data.id
            return math.max(data.neednum - inst[id .. "num"], 0)
        end
    end
    return 1
end
local function LibraryBoxAcceptTest(inst, item)
    for i, data in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
        if item.prefab == data.needprefab then
            local id = data.id
            return data.neednum > inst[id .. "num"], "GENERIC"
        end
    end
    return false, "WRONGTYPE"
end
local function LibraryBoxOnGetItemFromPlayer(inst, giver, item)
    local num = 1
    if item.components.stackable then
        num = item.components.stackable.stacksize
    end
    for i, data in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
        if item.prefab == data.needprefab then
            local id = data.id
            -- 更新数据
            inst[id .. "num"] = inst[id .. "num"] + num
            -- 刷新功能
            LibraryBoxRefresh(inst)
            -- 语言提示
            if data.neednum > inst[id .. "num"] then
                giver.components.talker:Say(string.format("%s:\t%s\t(%d/%d)\n", data.name or "nil",
                    STRINGS.NAMES[string.upper(data.needprefab)] or "nil",
                    inst[id .. "num"] or 0, data.neednum or 0))
            else
                giver.components.talker:Say(string.format("%s已满，%s功能已解锁",
                    STRINGS.NAMES[string.upper(data.needprefab)] or "nil", data.name or "nil"))
            end
            break
        end
    end
end
local function LibraryBoxOnRefuseItem(inst, giver, item)
    if item then
        local upgradesay = "\n\n\n\n\n\n\n\n\n\n\n\n\n科技解锁\n"
        for i, data in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
            upgradesay = upgradesay ..
                string.format("%s:\t%s\t(%d/%d)\n", data.name or "nil",
                    STRINGS.NAMES[string.upper(data.needprefab)] or "nil",
                    inst[data.id .. "num"] or 0, data.neednum or 0)
        end
        -- for key, value in pairs(inst.components.prototyper.trees) do
        --     upgradesay = upgradesay .. key .. ":" .. value .. "\n"
        -- end
        giver.components.talker:Say(upgradesay)
    end
end

-- 随身盒子统一定义方法
local function MakeBox(name, def)
    -- 导入动画
    local assets = def.assets or {}
    -- 皮肤
    if def.skinname then
        for i, v in ipairs(def.skinname) do
            table.insert(assets, Asset("ANIM", "anim/" .. v .. ".zip"))
        end
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()                         -- 管理实体的位置、旋转和缩放
        inst.entity:AddAnimState()                         -- 控制实体的动画
        inst.entity:AddSoundEmitter()                      -- 管理实体的声音
        inst.entity:AddNetwork()                           -- 网络同步功能
        inst.entity:AddMiniMapEntity()                     -- 地图图标

        MakeInventoryPhysics(inst)                         -- 为实体添加物理特性，使其能够作为物品被玩家拾取和携带。
        MakeInventoryFloatable(inst, "med", nil, 0.75)     -- 为实体添加浮力特性，使其能够在水中漂浮。

        inst.MiniMapEntity:SetIcon(name .. ".tex")         -- 地图图标
        inst.AnimState:SetBank(def.bank or name)           -- 地上动画
        inst.AnimState:SetBuild(def.build or name)         -- 材质包，就是anim里的zip包
        inst.AnimState:PlayAnimation(def.anim or "closed") -- 默认播放哪个动画

        -- 添加标签
        inst:AddTag("kisaki_box")
        if def.tags then
            for _, tag in pairs(def.tags) do
                inst:AddTag(tag)
            end
        end
        -- 额外执行方法
        if def.entity_postinit then
            def.entity_postinit(inst)
        end

        inst.entity:SetPristine() -- 设置为初始状态
        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddTag("meteor_protection")   -- 防止被流星破坏
        inst:AddTag("nosteal")             -- 不可以被猴子偷走
        inst:AddTag("NORATCHECK")          -- mod兼容：永不妥协。该道具不算鼠潮分
        inst:AddTag("kisaki_container")    -- 特殊tag，防毒雾

        inst:AddComponent("inspectable")   -- 可检查
        inst:AddComponent("inventoryitem") -- 可放入背包
        inst.components.inventoryitem.imagename = def.image or name
        inst.components.inventoryitem.atlasname = def.atlas or ("images/inventoryimages/prefabs/" .. name .. ".xml")
        inst.components.inventoryitem:SetOnDroppedFn(ondropped)

        inst:AddComponent("container") -- 这是一个容器
        inst.components.container:WidgetSetup(def.weight)
        inst.components.container.onopenfn = def.onopenfn or onopen
        inst.components.container.onclosefn = def.onclosefn or onclose
        -- 无限堆叠
        inst.components.container:EnableInfiniteStackSize(true)
        inst._chestupgrade_stacksize = true

        inst:AddComponent("deployable") -- 可以放在地上
        inst.components.deployable.ondeploy = ondeploy
        inst.components.deployable:SetDeploySpacing(DEPLOYSPACING.DEFAULT)
        inst.syncboxpropertyfn = def.syncboxpropertyfn

        MakeHauntableLaunch(inst) -- 可作祟

        inst._baseinventoryimagename = name

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

    local function deployfn()
        local inst = CreateEntity()

        inst.entity:AddTransform()                         -- 管理实体的位置、旋转和缩放
        inst.entity:AddAnimState()                         -- 控制实体的动画
        inst.entity:AddSoundEmitter()                      -- 管理实体的声音
        inst.entity:AddNetwork()                           -- 网络同步功能
        inst.entity:AddMiniMapEntity()                     -- 地图图标

        inst.MiniMapEntity:SetIcon(name .. ".tex")         -- 地图图标
        inst.AnimState:SetBank(def.bank or name)           -- 地上动画
        inst.AnimState:SetBuild(def.build or name)         -- 材质包，就是anim里的zip包
        inst.AnimState:PlayAnimation(def.anim or "closed") -- 默认播放哪个动画

        -- 添加标签
        inst:AddTag("kisaki_chest")
        inst:AddTag("chest")
        if def.tags then
            for _, tag in pairs(def.tags) do
                inst:AddTag(tag)
            end
        end
        -- 额外执行方法
        if def.entity_postinit then
            def.entity_postinit(inst)
        end

        inst.entity:SetPristine() -- 设置为初始状态
        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddTag("meteor_protection") -- 防止被流星破坏
        inst:AddTag("nosteal")           -- 不可以被猴子偷走
        inst:AddTag("NORATCHECK")        -- mod兼容：永不妥协。该道具不算鼠潮分
        inst:AddTag("structure")         -- 结构类物品，防毒雾
        inst:AddTag("kisaki_container")  -- 特殊tag，防毒雾

        inst:AddComponent("inspectable") -- 可检查
        inst:AddComponent("container")   -- 这是一个容器
        inst.components.container:WidgetSetup(def.weight .. "_chest")
        inst.components.container.onopenfn = def.onopenfn or onopen
        inst.components.container.onclosefn = def.onclosefn or onclose
        -- 无限堆叠
        inst.components.container:EnableInfiniteStackSize(true)
        inst._chestupgrade_stacksize = true

        -- 可锤
        inst:AddComponent("lootdropper")
        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(1)
        inst.components.workable:SetOnFinishCallback(onhammered)
        inst.syncboxpropertyfn = def.syncboxpropertyfn
        -- 可回收
        inst:AddComponent("portablestructure")
        inst.components.portablestructure:SetOnDismantleFn(onhammered)

        MakeHauntableLaunch(inst) -- 可作祟

        inst._baseinventoryimagename = name

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

    return def.onlychest and nil or Prefab(name, fn, assets),
        MakePlacer(name .. "_placer", def.bank or name, def.build or name, def.anim or "closed"),
        Prefab(name .. "_chest", deployfn, assets)
end

local box_defs = {} -- 盒子列表
-- 妃的杂物袋
box_defs.kisaki_portable_box = {
    assets = {
        Asset("ATLAS", "images/inventoryimages/prefabs/kisaki_portable_box.xml"),
        Asset("IMAGE", "images/inventoryimages/prefabs/kisaki_portable_box.tex"),
        Asset("ANIM", "anim/ui_kisaki_container_16x1.zip"),
    },
    skinname = { "kisaki_portable_box" },
    tags = { "kisaki_box_special_weight", "kisaki_portable_box" },
    weight = "kisaki_portable_box",
    onopenfn = function(inst)
        inst.AnimState:PlayAnimation("open")
        inst.SoundEmitter:PlaySound("terraria1/skins/voidbag")
        if inst.components.inventoryitem then
            local skin_name = inst:GetSkinName() or inst._baseinventoryimagename
            inst.components.inventoryitem:ChangeImageName(skin_name .. "_open")
        end
    end,
    onclosefn = function(inst)
        inst.AnimState:PlayAnimation("closed")
        inst.SoundEmitter:PlaySound("terraria1/skins/voidbag")
        if inst.components.inventoryitem then
            local skin_name = inst:GetSkinName() or inst._baseinventoryimagename
            inst.components.inventoryitem:ChangeImageName(skin_name)
        end
    end,
    entity_postinit = function(inst)
    end,
    master_postinit = function(inst)
        -- 修改shift移动物品，防止嵌套移动回原箱子
        local oldKisakiMoveItemFromAllOfSlot = inst.components.container.MoveItemFromAllOfSlot
        inst.components.container.MoveItemFromAllOfSlot = function(self, slot, container, opener, ...)
            -- 从模组箱子移动到个人物品栏
            if container ~= nil and container:HasTag("player") then
                KisakiMoveItemFromAllOfSlot(self, slot, container, opener, ...)
            elseif oldKisakiMoveItemFromAllOfSlot then
                oldKisakiMoveItemFromAllOfSlot(self, slot, container, opener, ...)
            end
        end
    end,
}

-- 妃的魔法盒
box_defs.kisaki_magic_box = {
    assets = {
        Asset("ATLAS", "images/inventoryimages/prefabs/kisaki_magic_box.xml"),
        Asset("IMAGE", "images/inventoryimages/prefabs/kisaki_magic_box.tex"),
        Asset("ANIM", "anim/ui_kisaki_container_5x5.zip"),
    },
    skinname = { "kisaki_magic_box" },
    tags = { "kisaki_magic_box", "kisakitrader" },
    weight = "kisaki_magic_box",
    entity_postinit = function(inst)
    end,
    master_postinit = function(inst)
        inst.fishlist = {}
        -- 交易组件
        inst:AddComponent("trader")
        inst.cantrader = MagicBoxTraderCount
        inst.components.trader.acceptnontradable = true
        inst.components.trader:SetAcceptTest(MagicBoxAcceptTest)
        inst.components.trader.onaccept = MagicBoxOnGetItemFromPlayer
        inst.components.trader.onrefuse = MagicBoxOnRefuseItem
        -- 消耗升级
        for i, data in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
            local action = data.action
            inst[action .. "num"] = 0
            inst[action .. "needprefab"] = data.needprefab
            inst[action .. "neednum"] = data.neednum
        end
        inst.addpreserver = function()
            if inst.freshnum >= inst.freshneednum and inst.preservernum >= inst.preserverneednum and not inst.components.preserver then
                inst:AddComponent("preserver") --保鲜
                inst.components.preserver:SetPerishRateMultiplier(-1)
            end
        end
        inst.restorationdurability = function()
            -- 回耐久
            for _, v in pairs(inst.components.container.slots) do
                if v.components.armor ~= nil and not v.components.armor.indestructible
                    and v.components.armor:GetPercent() < 10 then -- 护甲类的
                    v.components.armor:SetPercent(v.components.armor:GetPercent() +
                        (0.1 / math.ceil(v.components.armor:GetPercent() + 0.0001)))
                elseif v.components.finiteuses ~= nil and v.components.finiteuses:GetPercent() < 10 then -- 使用次数类的
                    local peruse = v.components.finiteuses.total *
                        (0.1 / math.ceil(v.components.finiteuses:GetPercent() + 0.0001))
                    v.components.finiteuses:Use(-peruse)                                        -- 可以有小数点
                elseif v.components.fueled ~= nil and v.components.fueled:GetPercent() < 1 then -- 燃料，不能超耐久
                    v.components.fueled:SetPercent(v.components.fueled:GetPercent() + 0.1)
                end
            end
        end
        inst.addrestorationdurability = function()
            if inst.durabilitynum >= inst.durabilityneednum and inst.autodurabilitynum >= inst.autodurabilityneednum then
                inst.restor_ationdurability = inst:DoPeriodicTask(60, function() inst.restorationdurability() end, 0.1)
            else
                inst.restor_ationdurability = nil
            end
        end
        -- 修改shift移动物品，防止嵌套移动回原箱子
        local oldKisakiMoveItemFromAllOfSlot = inst.components.container.MoveItemFromAllOfSlot
        inst.components.container.MoveItemFromAllOfSlot = function(self, slot, container, opener, ...)
            -- 从模组箱子移动到个人物品栏
            if container ~= nil and container:HasTag("player") then
                KisakiMoveItemFromAllOfSlot(self, slot, container, opener, ...)
            elseif oldKisakiMoveItemFromAllOfSlot then
                oldKisakiMoveItemFromAllOfSlot(self, slot, container, opener, ...)
            end
        end
    end,
    syncboxpropertyfn = function(inst, obj)
        for i, datas in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
            obj[datas.action .. "num"] = inst[datas.action .. "num"] or 0
        end
        obj.fishlist = inst.fishlist or {}
        obj.addpreserver()
        obj.addrestorationdurability()
    end,
    onsave = function(inst, data)
        for i, datas in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
            data[datas.action .. "num"] = inst[datas.action .. "num"]
        end
        data.fishlist = inst.fishlist or {}
    end,
    onpreload = function(inst, data)
        if data then
            for i, datas in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
                inst[datas.action .. "num"] = data[datas.action .. "num"] or 0
            end
            inst.fishlist = data.fishlist or {}
            inst.addpreserver()
            inst.addrestorationdurability()
        end
    end
}

-- 妃的幻想图书馆
box_defs.kisaki_library_box = {
    assets = {
        Asset("ATLAS", "images/inventoryimages/prefabs/kisaki_library_box.xml"),
        Asset("IMAGE", "images/inventoryimages/prefabs/kisaki_library_box.tex"),
        Asset("ANIM", "anim/ui_bookstation_4x5.zip"),
    },
    skinname = { "kisaki_library_box" },
    tags = { "kisaki_library_box", "kisakitrader", "giftmachine", "prototyper" },
    weight = "kisaki_library_box",
    entity_postinit = function(inst)
    end,
    master_postinit = function(inst)
        -- 书本回耐久
        inst.restore_efficiency = 1
        inst:ListenForEvent("itemget", LibraryBoxItemGet)
        inst:ListenForEvent("itemlose", LibraryBoxItemLose)
        -- 原型科技
        inst:AddComponent("prototyper")
        inst.components.prototyper.trees = { SCIENCE = 1, MAGIC = 1, BOOKCRAFT = 5, KISAKI_BOOKCRAFT = 1 }
        -- inst.components.prototyper.onactivate = OnActivate -- 靠近监听，播放动画声音
        -- inst.components.prototyper.onturnon = onturnon -- 科技打开监听，播放动画声音
        -- inst.components.prototyper.onturnoff = onturnoff -- 科技关闭监听，播放动画声音
        -- 监听领礼物，播放动画声音
        -- inst:ListenForEvent("ms_giftopened", ongiftopened)
        -- 制作站
        inst:AddComponent("craftingstation")
        -- 交易组件
        inst:AddComponent("trader")
        inst.cantrader = LibraryBoxTraderCount
        inst.components.trader.acceptnontradable = true
        inst.components.trader:SetAcceptTest(LibraryBoxAcceptTest)
        inst.components.trader.onaccept = LibraryBoxOnGetItemFromPlayer
        inst.components.trader.onrefuse = LibraryBoxOnRefuseItem
        -- 消耗升级属性
        for i, data in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
            inst[data.id .. "num"] = 0
        end
        -- 修改shift移动物品，防止嵌套移动回原箱子
        local oldKisakiMoveItemFromAllOfSlot = inst.components.container.MoveItemFromAllOfSlot
        inst.components.container.MoveItemFromAllOfSlot = function(self, slot, container, opener, ...)
            -- 从模组箱子移动到个人物品栏
            if container ~= nil and container:HasTag("player") then
                KisakiMoveItemFromAllOfSlot(self, slot, container, opener, ...)
            elseif oldKisakiMoveItemFromAllOfSlot then
                oldKisakiMoveItemFromAllOfSlot(self, slot, container, opener, ...)
            end
        end
    end,
    syncboxpropertyfn = function(inst, obj)
        for i, datas in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
            obj[datas.id .. "num"] = inst[datas.id .. "num"] or 0
        end
        LibraryBoxRefresh(obj)
    end,
    onsave = function(inst, data)
        for i, datas in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
            data[datas.id .. "num"] = inst[datas.id .. "num"]
        end
    end,
    onpreload = function(inst, data)
        if data then
            for i, datas in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
                inst[datas.id .. "num"] = data[datas.id .. "num"] or 0
            end
            LibraryBoxRefresh(inst)
        end
    end
}

local boxs = {}
for k, v in pairs(box_defs) do
    local item, placer, chest = MakeBox(k, v)
    if item then
        table.insert(boxs, item)
    end
    if placer then
        table.insert(boxs, placer)
    end
    if chest then
        table.insert(boxs, chest)
    end
end
return unpack(boxs)
