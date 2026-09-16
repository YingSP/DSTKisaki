local amuletutil = require("utils/amuletutil")

local function MakeRangeCheckFn(range)
    return function(doer, target)
        if target then
            return doer:IsNear(target, range)
        end
    end
end
local DefaultRangeCheck = MakeRangeCheckFn(4)

local NOTENTCHECK_CANT_TAGS = { "FX", "INLIMBO" }
local function noentcheckfn(pt)
    return not TheWorld.Map:IsPointNearHole(pt) and
        #TheSim:FindEntities(pt.x, pt.y, pt.z, 1, nil, NOTENTCHECK_CANT_TAGS) == 0
end

-- 判断是否是护符，拒绝带护甲的装备（即使他是护符）
local function IsStorableMultivariateAmulet(item, use_replica)
    return amuletutil.IsStorableAmulet(item, use_replica)
end
-- 获取装备中的融合护符
local function GetMultivariateAmulet(inventory)
    return amuletutil.GetEquippedOuter(inventory)
end

-- 自定义动作
local actions = {
    {
        id = "KISAKIEQUIP", -- 右键将护符收纳进薪火。
        str = STRINGS.KISAKI_ACTION.KISAKIEQUIP,
        fn = function(act)
            local doer = act.doer
            local item = act.invobject
            local inventory = doer ~= nil and doer.components.inventory or nil
            local outer = GetMultivariateAmulet(inventory)
            local container = outer ~= nil and outer.components.container or nil

            if container == nil or inventory == nil
                or not IsStorableMultivariateAmulet(item, false)
            then
                return false
            end

            -- 解析落位格：同名护符所在格 > 最靠前的空格 > 最后一格（挤出来）。
            local target_slot = amuletutil.GetStoreTargetSlot(container, item)
            if target_slot == nil then
                return false
            end

            -- 先取出目标格上原有的护符，让格子空出来。
            local replaced = container:GetItemInSlot(target_slot)
            if replaced ~= nil then
                container:RemoveItemBySlot(target_slot)
                -- 清掉来源信息，否则 Inventory:GiveItem 会把这个被换出的旧物又塞回原来容器
                replaced.prevcontainer = nil
                replaced.prevslot = nil
            end

            -- 必须先 RemoveFromOwner 摘出来，否则玩家背包里仍保留一份，造成复制。
            local moved = item.components.inventoryitem:RemoveFromOwner(true) or item

            if container:GiveItem(moved, target_slot) then
                if replaced ~= nil and not inventory:GiveItem(replaced) then
                    -- 旧护符背包放不下就地丢出，避免凭空消失。
                    inventory:DropItem(replaced, true, true)
                end
                return true
            end

            -- 理论上 itemtest 已保证不会失败；若因外部 Mod 临时拒绝，双方各自回滚。
            if replaced ~= nil then
                container:GiveItem(replaced, target_slot)
            end
            inventory:GiveItem(moved)
            return false
        end,
        state = "doaction",
        actiondata = {
            priority = 1,
            rmb = true, -- 仅右键触发，不用 checkfn 的 right 参数（该参数在部分调用路径下为 nil）
            instant = true,
            mount_valid = true,
            encumbered_valid = true,
            floating_valid = true,
            paused_valid = true,
        },
    },
    {
        id = "KISAKIUNEQUIP", -- 右键把护符从薪火中取出到身上。
        str = STRINGS.KISAKI_ACTION.KISAKIUNEQUIP,
        fn = function(act)
            local doer = act.doer
            local item = act.invobject
            local inventory = doer ~= nil and doer.components.inventory or nil
            if inventory == nil or item == nil then
                return false
            end

            -- 判定走 tag（与 checkfn 同一套规则）。
            if not amuletutil.IsStoredInAmulet(item) then
                return false
            end
            local itemdata = item.components.inventoryitem
            local outer = itemdata ~= nil and itemdata.owner or nil
            if not amuletutil.IsOuterAmulet(outer) or outer.components.container == nil then
                return false
            end

            -- 先拿下来
            local removed = outer.components.container:RemoveItem(item, true) or item

            -- 这里清掉来源信息，强制 GiveItem 走正常的背包/掉落流程。
            removed.prevcontainer = nil
            removed.prevslot = nil

            if removed.components.equippable ~= nil
                and removed.components.equippable:ShouldPreventUnequipping()
            then
                -- 不可卸下的护符放回容器，避免卡在中间状态。
                outer.components.container:GiveItem(removed)
                return false
            end

            if removed.components.inventoryitem ~= nil
                and removed.components.inventoryitem.cangoincontainer
                and not GetGameModeProperty("non_item_equips")
            then
                if not inventory:GiveItem(removed) then
                    -- 背包塞不下时兜底丢在地上，避免物品凭空消失。
                    inventory:DropItem(removed, true, true)
                end
            else
                inventory:DropItem(removed, true, true)
            end
            return true
        end,
        state = "doaction",
        actiondata = {
            priority = 1,
            rmb = true,
            instant = true,
            mount_valid = true,
            encumbered_valid = true,
            floating_valid = true,
            paused_valid = true,
        },
    },
    {
        id = "OPENORCLOSEAMULETWITHRIGHT", -- 右键开关护符功能
        str = STRINGS.KISAKI_ACTION.OPENORCLOSEAMULETWITHRIGHT,
        fn = function(act)
            if act.doer ~= nil and act.invobject ~= nil and act.invobject:HasTag("kisaki_amulet") and not act.invobject:HasTag("usesdepleted") then
                act.invobject.isopen = not act.invobject.isopen
                if act.doer.components.talker then
                    local str = act.invobject.isopen and STRINGS.KISAKI_ACTION.OPENGEMINIAMULET or
                        STRINGS.KISAKI_ACTION.CLOSEGEMINIAMULET
                    act.doer.components.talker:Say(str)
                end
                return true
            end
        end,
        state = "doaction",     -- sg
        actiondata = {
            priority = 3,       -- 优先级
            instant = true,     -- 是否立即触发
            mount_valid = true, -- 骑牛可触发
        },
    },
    {
        id = "OPENLINKCONTAINERPROXY", -- 右键开关世界箱子关联器
        str = STRINGS.KISAKI_ACTION.OPENLINKCONTAINERPROXY,
        fn = function(act)
            if act.doer ~= nil and act.invobject ~= nil and act.invobject:HasTag("kisaki_container_linker") then
                local prefab = act.invobject
                if prefab.container then
                    if prefab.current_opener then
                        prefab.container.components.container_proxy:Close(prefab.current_opener)
                    end
                    prefab.container:Remove()
                    prefab.container = nil
                else
                    prefab.container = SpawnPrefab("kisaki_yog_key_container")
                    prefab.container.link_prefab = prefab
                    prefab.container.components.container_proxy:Open(act.doer)
                    prefab.current_opener = act.doer
                end
                return true
            end
        end,
        state = "doaction",     -- sg
        actiondata = {
            priority = 1,       -- 优先级
            instant = true,     -- 是否立即触发
            mount_valid = true, -- 骑牛可触发
        },
    },
    {
        id = "KISAKITRADER", -- 自己写的交易动作
        str = STRINGS.KISAKI_ACTION.KISAKITRADER,
        fn = function(act)
            if act.doer ~= nil and act.invobject ~= nil and act.target ~= nil and act.target.components.trader then
                local able, reason = act.target.components.trader:AbleToAccept(act.invobject, act.doer, nil)
                if not able then
                    return false, reason
                end
                act.target.components.trader:AcceptGift(act.doer, act.invobject, nil)
                return true
            end
        end,
        state = "give",         -- sg
        actiondata = {
            priority = 4,       -- 优先级
            mount_valid = true, -- 骑牛可触发
            canforce = true,
            rangecheckfn = DefaultRangeCheck
        },
    },
    {
        id = "KISAKIOPENDOOR", -- 门之钥开门
        str = STRINGS.KISAKI_ACTION.KISAKIOPENDOOR,
        fn = function(act)
            if act.doer ~= nil and act.invobject ~= nil and act.target ~= nil then
                local chest_list = TheWorld.components.kisaki_ents_manager.chest_list
                if not chest_list or not next(chest_list) then return end
                -- 找到离玩家最近的
                local pt = act.doer:GetPosition()
                local closest_distance = nil
                local closest_chest = nil
                for chest, value in pairs(chest_list) do
                    print("当前世界列表里的容器" .. tostring(chest))
                    if not closest_distance or chest:GetDistanceSqToPoint(pt) < closest_distance then
                        closest_distance = chest:GetDistanceSqToPoint(pt)
                        closest_chest = chest
                    end
                end
                if not closest_chest then return end
                local closest_chest_pt = closest_chest:GetPosition()

                -- 玩家边上进入的洞
                local offset = FindWalkableOffset(pt, math.random() * TWOPI, 3 + math.random(), 16, false, true,
                        noentcheckfn, true, true)
                    or FindWalkableOffset(pt, math.random() * TWOPI, 5 + math.random(), 16, false, true, noentcheckfn,
                        true, true)
                    or FindWalkableOffset(pt, math.random() * TWOPI, 7 + math.random(), 16, false, true, noentcheckfn,
                        true, true)
                if offset ~= nil then
                    pt = pt + offset
                end
                -- 目标位置边上的洞
                local closest_chest_pt_offset = FindWalkableOffset(closest_chest_pt, math.random() * TWOPI,
                        3 + math.random(), 16, false, true,
                        noentcheckfn, true,
                        true)
                    or FindWalkableOffset(closest_chest_pt, math.random() * TWOPI, 5 + math.random(), 16, false, true,
                        noentcheckfn,
                        true, true)
                    or FindWalkableOffset(closest_chest_pt, math.random() * TWOPI, 7 + math.random(), 16, false, true,
                        noentcheckfn,
                        true, true)
                if closest_chest_pt_offset ~= nil then
                    closest_chest_pt = closest_chest_pt + closest_chest_pt_offset
                end

                -- 生成虫洞
                local portal = SpawnPrefab("pocketwatch_portal_entrance")
                portal.Transform:SetPosition(pt:Get())
                portal:SpawnExit(closest_chest_pt.recall_worldid, closest_chest_pt.x, closest_chest_pt.y,
                    closest_chest_pt.z)
                return true
            end
        end,
        state = "give",         -- sg
        actiondata = {
            priority = 4,       -- 优先级
            mount_valid = true, -- 骑牛可触发
            canforce = true,
            rangecheckfn = DefaultRangeCheck
        },
    },
    {
        id = "KISAKIRECYCLE", -- 自己写的回收动作
        str = STRINGS.KISAKI_ACTION.RECYCLE,
        fn = function(act)
            if act.target ~= nil and
                act.target.components.portablestructure ~= nil and
                (not (act.target.components.burnable and act.target.components.burnable:IsBurning()) or act.target:HasTag("campfire")) then
                if act.target.components.container ~= nil then
                    if not act.target:HasTag("kisaki_chest") then
                        return false, "NOTEMPTY"
                    elseif not act.target.components.container.canbeopened then
                        return false, "COOKING"
                    end
                elseif act.target.components.sleepingbag and act.target.components.sleepingbag:InUse() then
                    return false, "INUSE"
                end

                if act.target.candismantle and not act.target:candismantle() then
                    return false
                end

                act.target.components.portablestructure:Dismantle(act.doer)
                return true
            end
        end,
        state = "dolongaction", -- sg
        actiondata = {
            priority = 4,       -- 优先级
            rmb = true
        },
    },
    {
        id = "KISAKIPACK", -- 打包纸打包
        str = STRINGS.KISAKI_ACTION.KISAKIPACK,
        fn = function(act)
            local target = act.target
            local pack = act.invobject
            if target == nil or pack == nil or pack.prefab ~= "kisaki_pack" then
                return false
            end
            local x, y, z = target.Transform:GetWorldPosition()

            local gift = SpawnPrefab("kisaki_gift")
            if gift == nil then
                return false
            end
            if not gift.components.kisaki_packer:Pack(target, act.doer) then
                gift:Remove()
                return false
            end

            gift.Transform:SetPosition(x, y, z)
            if pack.components.stackable then
                pack.components.stackable:Get(1):Remove()
            else
                pack:Remove()
            end
            if act.doer and act.doer.SoundEmitter then
                act.doer.SoundEmitter:PlaySound("dontstarve/common/staff_dissassemble")
            end
            return true
        end,
        state = "doshortaction",
        actiondata = {
            priority = 2,
            mount_valid = true,
        },
    },
    {
        id = "KISAKIUNPACK", -- 礼物解包
        str = STRINGS.KISAKI_ACTION.KISAKIUNPACK,
        fn = function(act)
            local gift = act.target or act.invobject
            if gift and gift.prefab == "kisaki_gift" and gift.components.kisaki_packer then
                if gift.components.kisaki_packer:Unpack(gift:GetPosition()) then
                    gift:Remove()
                    return true
                end
            end
            return false
        end,
        state = "doshortaction",
        actiondata = {
            priority = 2,
            rmb = true,
            mount_valid = true,
        },
    },
    {
        id = "KISAKIRUMMAGE", -- 自己写的打开容器动作
        str = STRINGS.KISAKI_ACTION.KISAKIRUMMAGE,
        fn = ACTIONS.RUMMAGE.fn,
        state = "doshortaction", -- sg
        actiondata = {
            priority = 4,        -- 优先级
            mount_valid = true
        },
    },
}

-- 动作与组件进行绑定
local component_actions = {
    {
        type = "INVENTORY",
        component = "equippable",
        data = {
            {
                action = "KISAKIEQUIP",
                checkfn = function(inst, doer, actionlist, right)
                    -- 基础检查
                    if inst == nil
                        or inst.prefab == "kisaki_multivariate_amulet"
                        or not IsStorableMultivariateAmulet(inst, true)
                        or doer == nil
                        or doer.replica.inventory == nil
                    then
                        return false
                    end
                    -- 已被收纳的物品显示“卸下”，不再显示“装备”，两者互斥。
                    if amuletutil.IsStoredInAmulet(inst) then
                        return false
                    end
                    -- 装备着融合护符才走这条路。
                    local outer = GetMultivariateAmulet(doer.replica.inventory)
                    return outer ~= nil and outer.replica.container ~= nil
                end,
            },
            {
                action = "KISAKIUNEQUIP",
                checkfn = function(inst, doer, actionlist, right)
                    -- 只要物品被融合护符收纳着就能取出
                    return inst ~= nil
                        and amuletutil.IsStoredInAmulet(inst)
                        and doer ~= nil
                        and doer.replica.inventory ~= nil
                        and GetMultivariateAmulet(doer.replica.inventory) ~= nil
                end,
            },
        },
    },
    {
        type = "INVENTORY",
        component = "inventoryitem",
        data = {
            {
                action = "OPENLINKCONTAINERPROXY", -- 右键开关世界箱子关联器
                checkfn = function(inst, doer, actionlist, right)
                    return inst and inst:HasTag("kisaki_container_linker")
                end,
            },
            {
                action = "OPENORCLOSEAMULETWITHRIGHT", -- 右键开关护符功能
                checkfn = function(inst, doer, actionlist, right)
                    return inst and inst:HasTag("kisaki_amulet") and inst:HasTag("switchable") and
                        inst.replica.equippable ~= nil and
                        (inst.replica.equippable:IsEquipped() or amuletutil.IsStoredInAmulet(inst)) and
                        not inst:HasTag("usesdepleted")
                end,
            },
        },
    },
    {
        type = "SCENE",
        component = "inventoryitem",
        data = {
            {
                action = "KISAKIUNPACK", -- 右键拆包
                checkfn = function(inst, doer, actionlist, right)
                    return right and inst and inst:HasTag("kisaki_gift")
                end,
            },
        },
    },
    {
        type = "SCENE",
        component = "portablestructure",
        data = {
            {
                action = "KISAKIRECYCLE", -- 右键回收功能
                checkfn = function(inst, doer, actionlist, right)
                    if not right then
                        return false
                    end
                    local iscampfire = inst:HasTag("campfire")
                    if inst:HasTag("kisaki_chest") and
                        not (iscampfire and inst:HasTag("portable_campfire") and not doer:HasTag("portable_campfire_user")) and
                        (iscampfire or not inst:HasTag("fire")) and --other structures can't be burning
                        (not inst:HasTag("mastercookware") or doer:HasTag("masterchef")) and
                        (not inst:HasTag("engineering") or doer:HasTag("portableengineer"))
                    then
                        return true
                    else
                        return false
                    end
                end,
            },
        },
    },
    {
        type = "SCENE",
        component = "container",
        data = {
            {
                action = "KISAKIRUMMAGE", -- 打开容器功能
                checkfn = function(inst, doer, actionlist, right)
                    if inst:HasTag("kisaki_chest") and not inst:HasTag("burnt")
                        and inst.replica.container:CanBeOpened()
                        and doer.replica.inventory ~= nil
                        and (not inst:HasTag("oceantrawler") or not inst:HasTag("trawler_lowered"))
                        and not (doer.replica.rider ~= nil and doer.replica.rider:IsRiding()) then
                        return true
                    end
                end,
            },
        },
    },
    {
        type = "SCENE",
        component = "container_proxy",
        data = {
            {
                action = "KISAKIRUMMAGE", -- 打开容器功能
                checkfn = function(inst, doer, actionlist, right)
                    if inst:HasTag("kisaki_chest") and
                        inst.components.container_proxy:CanBeOpened() and
                        not inst:HasTag("burnt") and
                        doer.replica.inventory ~= nil
                        and not (doer.replica.rider ~= nil and doer.replica.rider:IsRiding()) then
                        return true
                    end
                end,
            },
        },
    },
    {
        type = "USEITEM",
        component = "inventoryitem",
        data = {
            {
                action = "KISAKITRADER", -- 交易功能
                -- inst这里是物品A，doer是动作执行者，这里是一般为玩家，target动作执行对象，actionlist可触发的动作列表。right=true，是否是右键动作
                checkfn = function(inst, doer, target, actionlist, right)
                    return inst and target and target:HasTag("trader") and target:HasTag("kisakitrader")
                end,
            },
            {
                action = "KISAKIOPENDOOR", -- 门之钥开门
                -- inst这里是物品A，doer是动作执行者，这里是一般为玩家，target动作执行对象，actionlist可触发的动作列表。right=true，是否是右键动作
                checkfn = function(inst, doer, target, actionlist, right)
                    return inst and target and inst.prefab == "kisaki_yog_key"
                end,
            },
            {
                action = "KISAKIPACK", -- 使用打包纸
                checkfn = function(inst, doer, target, actionlist, right)
                    return inst and target and inst.prefab == "kisaki_pack" and not target:HasTag("player")
                end,
            },
        },
    },
}

-- 修改老动作
local old_murder_fn = ACTIONS.MURDER.fn
local old_actions = {
    --谋杀
    {
        switch = true,
        id = "MURDER",
        actiondata = {
            fn = function(act)
                local murdered = act.invobject or act.target
                local player = act.doer
                -- 佩戴天蝎谋杀双倍掉落
                if murdered ~= nil and (murdered.components.health ~= nil or murdered.components.murderable ~= nil)
                    and player ~= nil and player.components.inventory and player.components.inventory:EquipHasTag("kisaki_scorpio") then
                    -- 适配堆叠
                    local stacksize = murdered.components.stackable ~= nil and murdered.components.stackable:StackSize() or
                        1
                    local x, y, z = player.Transform:GetWorldPosition()

                    if murdered.components.lootdropper ~= nil then
                        murdered.causeofdeath = player
                        local pos = Vector3(x, y, z)
                        for i = 1, stacksize do
                            local loots = murdered.components.lootdropper:GenerateLoot()
                            local lootprefab = loots[#loots > 1 and math.random(#loots) or 1]

                            if lootprefab ~= nil then
                                local loot = SpawnPrefab(lootprefab)
                                if loot ~= nil then
                                    player.components.inventory:GiveItem(loot, nil, pos)
                                end
                            end
                        end
                    end

                    if murdered.components.inventory and murdered:HasTag("drop_inventory_onmurder") then
                        murdered.components.inventory:TransferInventory(player)
                    end
                end
                return old_murder_fn(act)
            end,
        },
        state = {
            testfn = function(inst, action)
                local player_inventory = inst.components.inventory
                -- 佩戴天蝎快速谋杀
                return player_inventory and player_inventory:EquipHasTag("kisaki_scorpio")
            end,
            client_testfn = function(inst, action)
                local player_inventory = inst.replica.inventory
                -- 佩戴天蝎快速谋杀
                return player_inventory and player_inventory:EquipHasTag("kisaki_scorpio")
            end,
            deststate = function(inst, action)
                return "doshortaction"
            end,
        },
    },
    -- 采集
    {
        switch = true, --开关
        id = "PICK",
        state = {
            --动作劫持判断(判断是否需特殊处理执行新动作)
            testfn = function(inst, action)
                local player_inventory = inst.components.inventory
                -- 佩戴天蝎快速采集
                return player_inventory and player_inventory:EquipHasTag("kisaki_scorpio")
            end,
            client_testfn = function(inst, action)
                local player_inventory = inst.replica.inventory
                -- 佩戴天蝎快速采集
                return player_inventory and player_inventory:EquipHasTag("kisaki_scorpio")
            end,
            --根据判断返回具体动作
            deststate = function(inst, action)
                return "doshortaction"
            end,
        },
    },
    -- 制作
    {
        switch = true, --开关
        id = "BUILD",
        state = {
            --动作劫持判断(判断是否需特殊处理执行新动作)
            testfn = function(inst, action)
                local player_inventory = inst.components.inventory
                -- 佩戴天蝎快速制作
                return player_inventory and player_inventory:EquipHasTag("kisaki_scorpio")
            end,
            client_testfn = function(inst, action)
                local player_inventory = inst.replica.inventory
                -- 佩戴天蝎快速制作
                return player_inventory and player_inventory:EquipHasTag("kisaki_scorpio")
            end,
            --根据判断返回具体动作
            deststate = function(inst, action)
                return "doshortaction"
            end,
        },
    },
    -- 回收/拆除
    {
        switch = true, --开关
        id = "DISMANTLE",
        state = {
            --动作劫持判断(判断是否需特殊处理执行新动作)
            testfn = function(inst, action)
                local player_inventory = inst.components.inventory
                -- 佩戴天蝎快速回收
                return player_inventory and player_inventory:EquipHasTag("kisaki_scorpio")
            end,
            client_testfn = function(inst, action)
                local player_inventory = inst.replica.inventory
                -- 佩戴天蝎快速回收
                return player_inventory and player_inventory:EquipHasTag("kisaki_scorpio")
            end,
            --根据判断返回具体动作
            deststate = function(inst, action)
                return "domediumaction"
            end,
        },
    },
    -- 吃东西
    {
        switch = true, --开关
        id = "EAT",
        state = {
            --动作劫持判断(判断是否需特殊处理执行新动作)
            testfn = function(inst, action)
                local player_inventory = inst.components.inventory
                -- 佩戴天蝎快速吃东西
                return player_inventory and player_inventory:EquipHasTag("kisaki_scorpio")
            end,
            client_testfn = function(inst, action)
                local player_inventory = inst.replica.inventory
                -- 佩戴天蝎快速吃东西
                return player_inventory and player_inventory:EquipHasTag("kisaki_scorpio")
            end,
            --根据判断返回具体动作
            deststate = function(inst, action)
                if inst.sg:HasStateTag("busy") then
                    return
                end
                local obj = action.target or action.invobject
                if obj == nil then
                    return
                elseif obj.components.edible ~= nil then
                    if not inst.components.eater:PrefersToEat(obj) then
                        inst:PushEvent("wonteatfood", { food = obj })
                        return
                    end
                elseif obj.components.soul ~= nil then
                    if inst.components.souleater == nil then
                        inst:PushEvent("wonteatfood", { food = obj })
                        return
                    end
                else
                    return
                end
                local state = "quickeat"

                if inst.sg:HasStateTag("floating") then
                    inst.sg.statemem.floating = true
                    --for searching: "float_eat", "float_quickeat"
                    return "float_" .. state
                end
                return state
            end,
        },
    },
}

return {
    actions = actions,
    component_actions = component_actions,
    old_actions = old_actions,
}
