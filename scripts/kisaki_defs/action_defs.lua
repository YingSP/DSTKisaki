local function MakeRangeCheckFn(range)
    return function(doer, target)
        if target then
            return doer:IsNear(target, range)
        end
    end
end
local DefaultRangeCheck = MakeRangeCheckFn(4)

-- 自定义动作
local actions = {
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
            priority = 1,       -- 优先级
            instant = true,     -- 是否立即触发
            mount_valid = true, -- 骑牛可触发
        },
    },
}

-- 动作与组件进行绑定
local component_actions = {
    {
        type = "INVENTORY",
        component = "inventoryitem",
        data = {
            {
                action = "OPENORCLOSEAMULETWITHRIGHT", -- 右键开关护符功能
                checkfn = function(inst, doer, actionlist, right)
                    return inst and inst:HasTag("kisaki_amulet") and inst:HasTag("switchable") and
                        inst.replica.equippable ~= nil and inst.replica.equippable:IsEquipped() and
                        not inst:HasTag("usesdepleted")
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
