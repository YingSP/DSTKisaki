local containers = require "containers"
local log = require("utils/kisakilogger")
local containers_params = containers.params
local POCKETDIMENSIONCONTAINER_DEFS = require("prefabs/pocketdimensioncontainer_defs").POCKETDIMENSIONCONTAINER_DEFS

------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 拷贝一个容器UI
local function copyChestUI(oldname, newname)
    containers_params[newname] = {
        widget = {
            slotpos = {},
            slotbg = {},
            animbank = "ui_bookstation_4x5",
            animbuild = "ui_bookstation_4x5",
            pos = Vector3(0, 240, 0),
            side_align_tip = 160,
        },
        type = "kisaki_box",
    }
    -- 拷贝UI参数
    local widget = containers_params[oldname].widget
    if widget then
        for key, value in pairs(widget) do
            containers_params[newname].widget[key] = value
        end
    end
    -- 拷贝类型
    if containers_params[oldname].type then
        containers_params[newname].type = containers_params[oldname].type
    end
    -- 拷贝放入限制
    if containers_params[oldname].itemtestfn then
        containers_params[newname].itemtestfn = containers_params[oldname].itemtestfn
    end
    -- 拷贝优先进入规则
    if containers_params[oldname].prioritygivefn then
        containers_params[newname].prioritygivefn = containers_params[oldname].prioritygivefn
    end
    if containers_params[oldname].priorityfn then
        containers_params[newname].priorityfn = containers_params[oldname].priorityfn
    end
end

function checkNothing(container, item, slot)
    return false
end

-- 辅助计算
local function getmagicmaxnum(doer, consume)
    return math.floor(math.max(doer.components.kisaki_magic and (doer.components.kisaki_magic.current - 100) or 0, 0) /
        consume)
end
local function gethungermaxnum(doer, consume)
    return math.floor(math.max(doer.components.hunger and (doer.components.hunger.current - 5) or 0, 0) / consume)
end
local function getssanitymaxnum(doer, consume)
    return math.floor(math.max(doer.components.sanity and (doer.components.sanity.current - 5) or 0, 0) / consume)
end
local function gethealthmaxnum(doer, consume)
    return math.floor(math.max(doer.components.health and (doer.components.health.currenthealth - 5) or 0, 0) /
        consume)
end
local function getworkmaxnum(doer, consume, useother)
    useother = (useother == nil) or useother
    return (0 +
        (TUNING.KISAKI_CONSUME_MAGIC_ENABLE and getmagicmaxnum(doer, consume) or 0) +
        ((TUNING.KISAKI_CONSUME_HUNGER_ENABLE and useother) and gethungermaxnum(doer, consume) or 0) +
        ((TUNING.KISAKI_CONSUME_SANITY_ENABLE and useother) and getssanitymaxnum(doer, consume) or 0) +
        ((TUNING.KISAKI_CONSUME_HEALTH_ENABLE and useother) and gethealthmaxnum(doer, consume) or 0))
end
-- 可捕捉的小动物
local function issmallanimals(v)
    return (v.components.workable and v.components.workable:GetWorkAction() == ACTIONS.NET) or v:HasTag("canbetrapped")
end
-- 校验按钮能否按
local function containerDefaultValid(inst)
    return inst.replica.container ~= nil and not inst.replica.container:IsReadOnlyContainer()
end
local function containerIsNotEmpty(inst)
    return inst.replica.container ~= nil and not inst.replica.container:IsEmpty() and
        not inst.replica.container:IsReadOnlyContainer() --容器不为空
end

-- 按钮消耗三维
local function consumeproperty(player, num)
    if num > 0 and player.components.kisaki_magic and TUNING.KISAKI_CONSUME_MAGIC_ENABLE then
        local magic_max = math.max(player.components.kisaki_magic.current - 100, 0)
        player.components.kisaki_magic:DoDelta(-math.min(magic_max, num))
        num = num - magic_max
    end
    if num > 0 and player.components.hunger and TUNING.KISAKI_CONSUME_HUNGER_ENABLE then
        local hunger_max = math.max(player.components.hunger.current - 5, 0)
        player.components.hunger:DoDelta(-math.min(hunger_max, num))
        num = num - hunger_max
    end
    if num > 0 and player.components.sanity and TUNING.KISAKI_CONSUME_SANITY_ENABLE then
        local sanity_max = math.max(player.components.sanity.current - 5, 0)
        player.components.sanity:DoDelta(-math.min(sanity_max, num))
        num = num - sanity_max
    end
    if num > 0 and player.components.health and TUNING.KISAKI_CONSUME_HEALTH_ENABLE then
        local health_max = math.max(player.components.health.currenthealth - 5, 0)
        player.components.health:DoDelta(-math.min(health_max, num))
    end
end
-- 收集按钮相关方法
local function endbuttonloading(inst) inst.kisaki_button_cd = nil end
-- 全都可以拿
local function deaultcollectjudgefn(item, limitlist, box)
    if item == nil or not item:IsValid() or item.components.inventoryitem == nil then
        return false
    end
    local inventoryitem = item.components.inventoryitem
    return inventoryitem.cangoincontainer
        and (inventoryitem.canbepickedup or inventoryitem.canbepickedupalive or inventoryitem.grabbableoverridetag ~= nil)
        and not (item:IsInLimbo() and item.components.projectile ~= nil and item.components.projectile:IsThrown())
        and inventoryitem:IsHeld()
end
local function realcollectfn(doer, inst, judgefn, limitlist, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    if judgefn == nil or type(judgefn) ~= "function" then
        judgefn = deaultcollectjudgefn
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil and not inst.components.container.readonlycontainer and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        local x, y, z = doer.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, TUNING.KISAKI_BOX_COLLECT_SCOPE, { "_inventoryitem" },
            { "INLIMBO", "NOCLICK", "fire", "minesprung", "mineactive" })
        local capture_num = 0
        for i, v in ipairs(ents) do
            if judgefn(v, limitlist, inst) then
                local issmallanimalflag = issmallanimals(v)
                if maxnum == 999 or (not issmallanimalflag or capture_num < maxnum) then
                    SpawnPrefab("sand_puff").Transform:SetPosition(v.Transform:GetWorldPosition())
                    if v.components.trap ~= nil and v.components.trap:IsSprung() then
                        v.components.trap:Harvest(inst)
                    else
                        local v_x, v_y, v_z = v.Transform:GetWorldPosition()
                        container:GiveItem(v, nil, Vector3(v_x, v_y, v_z))
                    end
                end
                if maxnum ~= 999 and issmallanimalflag then
                    capture_num = capture_num + 1
                end
            end
        end
        return capture_num
    end
    return 0
end
-- 收集容器内有的东西
local function sameitemcollectjudgefn(item, limitlist, box)
    if item == nil or limitlist == nil or item.components.inventoryitem == nil or not item:IsValid() or item:IsInLimbo() then
        return false
    end
    return limitlist[item.prefab]
end

-- 快速存物按钮相关
local function moveitemtotocontainer(inst, slot, proxy_container_list, container_list)
    local item = inst.components.container:GetItemInSlot(slot)
    local prefabname = item and item.prefab or nil
    local findproxycontainers = {}
    local findcontainers = {}
    -- 筛选
    for master, container_event in pairs(proxy_container_list) do
        if master.components.container and master.components.container:Has(prefabname, 1) then
            findproxycontainers[master] = container_event
        end
    end
    for _, container_event in ipairs(container_list) do
        if container_event.components.container and container_event.components.container:Has(prefabname, 1) then
            table.insert(findcontainers, container_event)
        end
    end
    -- 存入
    for master, container_event in pairs(findproxycontainers) do
        inst.components.container:KisakiMoveItemAll(slot, master)
        SpawnPrefab("sand_puff").Transform:SetPosition(container_event.Transform:GetWorldPosition())
        if inst.components.container:GetItemInSlot(slot) == nil then
            break
        end
    end
    for _, container_event in ipairs(findcontainers) do
        inst.components.container:KisakiMoveItemAll(slot, container_event)
        SpawnPrefab("sand_puff").Transform:SetPosition(container_event.Transform:GetWorldPosition())
        if inst.components.container:GetItemInSlot(slot) == nil then
            break
        end
    end
end
local function moveitemintocontainer(inst, priority_proxy_container_list, priority_container_list, proxy_container_list,
                                     container_list)
    -- 只会将其他容器内有的东西堆叠到那个容器内（类似于泰拉瑞亚的快速存储）
    -- 优先存到四周地上的模组的容器内
    -- 之后存到其他地上的容器内
    for slot = 1, inst.components.container.numslots do
        moveitemtotocontainer(inst, slot, priority_proxy_container_list, priority_container_list)
        moveitemtotocontainer(inst, slot, proxy_container_list, container_list)
    end
end
local function magicboxstorage(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer or doer == nil or not doer:HasTag("player") then
        return
    end
    -- 找到周围可用容器
    local x, y, z = doer.Transform:GetWorldPosition()
    local player_platform = inst:GetCurrentPlatform()
    local nearcontainers = TheSim:FindEntities(x, y, z, 30, nil,
        { "_health", "_equippable", "stewer", "fire", "portablestorage", "mermonly", "mastercookware", "FX", "NOCLICK",
            "DECOR", "INLIMBO" },
        { "_container", "_container_proxy" })
    local priority_proxy_container_list = {}
    local priority_container_list = {}
    local proxy_container_list = {}
    local container_list = {}
    for i, container_event in pairs(nearcontainers) do
        log.debug("找到了周围的容器：" ..
            (container_event.prefab and STRINGS.NAMES[string.upper(container_event.prefab)] or "nil"))
        -- 判断可使用容器
        if container_event:IsValid() and container_event.components.container_proxy and container_event.components.container_proxy:CanBeOpened()
            and player_platform == container_event:GetCurrentPlatform() and not container_event.components.locomotor then -- 世界联通容器
            local master = container_event.components.container_proxy.master
            if master and master:IsValid() and master.components.container and not master.components.container.readonlycontainer and
                master.components.container.canbeopened and master.components.container.acceptsstacks then
                if container_event:HasTag("kisaki_proxy_box") and not priority_proxy_container_list[master] then
                    priority_proxy_container_list[master] = container_event
                elseif not proxy_container_list[master] then
                    proxy_container_list[master] = container_event
                end
            end
        elseif container_event:IsValid() and container_event.components.container
            and not container_event.components.locomotor and not container_event.components.container.readonlycontainer
            and container_event.components.container.canbeopened and container_event.components.container.acceptsstacks then -- 普通容器
            if container_event:HasTag("kisaki_box") or container_event:HasTag("kisaki_chest") then
                table.insert(priority_container_list, container_event)
            else
                table.insert(container_list, container_event)
            end
        end
    end
    -- 移动物品
    if IsTableEmpty(priority_proxy_container_list) and IsTableEmpty(priority_container_list)
        and IsTableEmpty(proxy_container_list) and IsTableEmpty(container_list) then
        return
    end
    moveitemintocontainer(inst, priority_proxy_container_list, priority_container_list, proxy_container_list,
        container_list)
end

-- 整理按钮相关方法（代码来自勋章）
-- 排序对比方法
local function compare(a, b)
    if a and b then
        -- 有新鲜度的放在更后面
        if a.components.perishable and not b.components.perishable then
            return 1
        end
        if b.components.perishable and not a.components.perishable then
            return -1
        end
        -- 有堆叠组件的放在前面
        if a.components.stackable and not b.components.stackable then
            return -1
        end
        if b.components.stackable and not a.components.stackable then
            return 1
        end
        --尝试按照 prefab 名字排序
        local prefab_a = tostring(a.prefab)
        local prefab_b = tostring(b.prefab)
        if (prefab_a == prefab_b) then
            return 0
        end
        if (prefab_a < prefab_b) then
            return -1
        end
        if (prefab_a > prefab_b) then
            return 1
        end
    end
end
-- 插入法排序函数
local function insert_sort(list, comparefn)
    for i = 2, #list do
        local v = list[i]
        local j = i - 1
        while (j > 0 and (comparefn(list[j], v) > 0)) do
            list[j + 1] = list[j]
            j = j - 1
        end
        list[j + 1] = v
    end
end
-- 整理总方法
local function boxsort(doer, inst, min, max)
    if inst and inst.components.container and not inst.components.container.readonlycontainer then
        --取出容器中的所有物品
        local items = {}
        for slot, v in pairs(inst.components.container.slots) do
            if (min == nil or slot >= min) and (max == nil or slot <= max) then
                local item = inst.components.container:GetItemInSlot(slot)
                if (item) then
                    if item.components.stackable then
                        inst.components.container.ignoreoverstacked = true
                        item = inst.components.container:RemoveItemBySlot(slot)
                        inst.components.container.ignoreoverstacked = false
                    else
                        item = inst.components.container:RemoveItemBySlot(slot)
                    end
                end
                if (item) then
                    log.debug("拿到了物品" ..
                        item.prefab .. "数量为" .. (item.components.stackable and item.components.stackable.stacksize or 1))
                    table.insert(items, item)
                end
            end
        end
        -- 排序
        insert_sort(items, compare)
        -- 放回去
        for i = 1, #items do
            inst.components.container:GiveItem(items[i])
        end
    end
end

-- 捕鱼相关
-- 捕海鱼
local function realcatchfishfn(doer, inst, limitlist, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        local x, y, z = doer.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, TUNING.KISAKI_BOX_COLLECT_FISH_SCOPE, { "oceanfishable" })
        local catchnum = 0
        for i, v in ipairs(ents) do
            if catchnum < maxnum and v and v:IsValid() and v.components.oceanfishable and v.prefab
                and (limitlist == nil or limitlist[v.prefab .. "_inv"] or limitlist[v.prefab .. "_land"]) then
                -- 生成特效
                local fx = SpawnPrefab("crab_king_waterspout")
                fx.Transform:SetPosition(v:GetPosition():Get())
                -- 捕鱼
                local fish = _G.Prefabs[v.prefab .. "_inv"] and SpawnPrefab(v.prefab .. "_inv") or
                    SpawnPrefab(v.prefab .. "_land")
                local v_x, v_y, v_z = v.Transform:GetWorldPosition()
                container:GiveItem(fish, nil, Vector3(v_x, v_y, v_z))
                v:Remove()
                -- 推送捕鱼事件
                doer:PushEvent("medal_fishingcollect", { fish = v })
                if maxnum ~= 999 then
                    catchnum = catchnum + 1
                end
            end
        end
        return catchnum
    end
    return 0
end
-- 摸陆鱼
local function realcatchloadfishfn(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        local x, y, z = doer.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, TUNING.KISAKI_BOX_COLLECT_FISH_SCOPE, { "fishable" })
        local catchnum = 0
        for i, v in ipairs(ents) do
            if catchnum < maxnum and v and v:IsValid() and v.components.fishable and v.components.fishable.fishleft > 0 then
                -- 生成特效
                local fx = SpawnPrefab("crab_king_waterspout")
                fx.Transform:SetPosition(v:GetPosition():Get())
                -- 抓鱼
                local fish = v.components.fishable:HookFish(doer)
                fish = v.components.fishable:RemoveFish(fish)
                local v_x, v_y, v_z = v.Transform:GetWorldPosition()
                container:GiveItem(fish, nil, Vector3(v_x, v_y, v_z))
                if maxnum ~= 999 then
                    catchnum = catchnum + 1
                end
            end
        end
        return catchnum
    end
    return 0
end

-- 转换相关
local item_transform_list = TUNING.KISAKI_ITEM_TRANSFORM_LIST
local function realconversionfn(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        local transformnum = 0
        local giveitems = {}
        for slot, item in pairs(container.slots) do
            if transformnum < maxnum and item and item:IsValid() and item_transform_list[item.prefab] ~= nil then
                -- 取出物品
                container.ignoreoverstacked = true
                item = container:RemoveItemBySlot(slot)
                container.ignoreoverstacked = false
                -- 给几个
                local num = 1
                if item.components.stackable then
                    num = item.components.stackable:StackSize()
                end
                -- 转化成物品
                giveitems[item_transform_list[item.prefab]] = (giveitems[item_transform_list[item.prefab]] or 0) + num
                -- 删掉老物品
                item:Remove()
                if maxnum ~= 999 then
                    transformnum = transformnum + 1
                end
            end
        end
        -- 给交换的东西
        local isgive = false
        local x, y, z = doer.Transform:GetWorldPosition()
        for prefabname, num in pairs(giveitems) do
            local prefab = SpawnPrefab(prefabname)
            if prefab.components.stackable then
                prefab.components.stackable:SetStackSize(num)
            elseif num > 1 then
                for i = 2, num do
                    local other_prefab = SpawnPrefab(prefabname)
                    container:GiveItem(other_prefab, nil, Vector3(x, y, z))
                end
            end
            container:GiveItem(prefab, nil, Vector3(x, y, z))
            isgive = true
        end
        -- 特效
        if isgive then
            SpawnPrefab('fx_book_light').Transform:SetPosition(Vector3(inst.Transform:GetWorldPosition()):Get())
        end
        return transformnum
    end
    return 0
end

-- 工作相关
local work_invalid_items = {}
local work_mine_invalid_items = {
    "wobster_den",
    "moonglass_wobster_den", -- 龙虾窝
    "statueglommer",         -- 格罗姆雕像
}
local work_chop_legal_items = {
    "marsh_tree",        -- 针刺树
    "palmconetree_tall", -- 棕榈松果树
    "deciduoustree",     -- 桦栗树
    "deciduoustree",     -- 毒桦栗树/桦栗树精
    "tree_rock",         -- 巨石枝
    -- 蘑菇树
    "mushtree_medium",
    "mushtree_small",
    "mushtree_tall",
    "mushtree_tall_webbed",
    "mushtree_moon",
    -- 月树
    "moon_tree",
    "moon_tree_short",
    "moon_tree_normal",
    "moon_tree_tall",
    -- 常青树
    "evergreen",
    "evergreen_short",
    "evergreen_normal",
    "evergreen_tall",
    -- 臃肿常青树
    "evergreen_sparse",
    "evergreen_sparse_short",
    "evergreen_sparse_normal",
    "evergreen_sparse_tall",
    -- 活木树
    "livingtree_halloween",
    "livingtree",
    -- 浮木
    "driftwood_small1",
    "driftwood_small2",
    "driftwood_tall",
    -- 蟾蜍树
    "mushroomsprout",
    "mushroomsprout_dark",
}
local work_hammer_legal_items = {
    -- 垃圾栅栏
    "fence_junk",
    -- 损坏的机器
    "monkeyisland_portal_debris",
    -- 被丢弃的垃圾
    "wagstaff_machinery",
    -- 破损桅杆
    "mast_broken",
    -- 沉底宝箱
    "sunkenchest",
    -- 犬骨
    "houndbone",
    -- 海骨
    "dead_sea_bones",
    -- 骷髅
    "skeleton",
    "scorched_skeleton",
    -- 猴子窝
    "monkeyhut",
    "monkeybarrel",
    -- 变质的鱼
    "spoiled_fish_small",
    "spoiled_fish",
    -- 损坏的发条装置
    "chessjunk1",
    "chessjunk2",
    "chessjunk3",
    -- 贝壳钟
    "singingshell_octave3",
    "singingshell_octave4",
    "singingshell_octave5",
    -- 船碎片
    "boatfragment03",
    "boatfragment04",
    "boatfragment05",
}
local work_dig_legal_items = {
    "mound",        -- 坟
    "pirate_stash", -- X
    -- 农田杂物/杂草
    "farm_soil_debris",
    "weed_forgetmelots",
    "weed_tillweed",
    "weed_firenettle",
    "weed_ivy",
}
local function iscanwork(item)
    return item and item:IsValid() and not table.contains(work_invalid_items, item.prefab)
        and item.components.workable and item.components.workable:CanBeWorked()
        and
        ((ACTIONS.CHOP == item.components.workable:GetWorkAction() and table.contains(work_chop_legal_items, item.prefab))             -- 劈砍
            or (ACTIONS.MINE == item.components.workable:GetWorkAction() and not table.contains(work_mine_invalid_items, item.prefab)) -- 挖
            or (ACTIONS.HAMMER == item.components.workable:GetWorkAction()
                and (item:HasTag("oversized_veggie") or table.contains(work_hammer_legal_items, item.prefab)))                         -- 锤
            or (ACTIONS.DIG == item.components.workable:GetWorkAction()) and table.contains(work_dig_legal_items, item.prefab))        -- 铲
end
local function realworkfn2(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if not doer:HasTag("player") or container == nil then
        return 0
    end
    local x, y, z = doer.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.KISAKI_BOX_WORK_SCOPE, nil,
        { "event_trigger", "insect", "INLIMBO", "NOCLICK" },
        { "CHOP_workable", "DIG_workable", "HAMMER_workable", "MINE_workable" })
    local worknum = 0
    for i, item in ipairs(ents) do
        if worknum < maxnum and iscanwork(item) then
            item.components.workable:WorkedBy_Internal(doer, 50)
            if maxnum ~= 999 then
                worknum = worknum + 1
            end
        end
    end
    return worknum
end
local work_legal_items = {
    -- 变质的鱼(勋章兼容)
    spoiled_fish_small = { spoiled_food = 0.5, boneshard = 0.5, medal_fishbones = 0.5 },
    spoiled_fish = { spoiled_food = 1, boneshard = 1, medal_fishbones = 0.75 },
    -- 贝壳钟
    singingshell_octave3 = { slurtle_shellpieces = 1.5 },
    singingshell_octave4 = { slurtle_shellpieces = 1.5 },
    singingshell_octave5 = { slurtle_shellpieces = 1.5 },
    -- 石果
    rock_avocado_fruit = { rock_avocado_fruit_ripe = 0.65, rocks = 0.34, rock_avocado_fruit_sprout = 0.01 },
}
-- 勋章获取宿命(inst,宿命池key)
function GetMedalDestiny(inst, key)
    if inst ~= nil then
        --有宿命组件优先返回组件记录的宿命
        if inst.components.medal_itemdestiny ~= nil then
            return inst.components.medal_itemdestiny:GetDestiny()
            --否则返回记录的宿命(某些特殊道具需要另外保存宿命)
        elseif inst.medal_destiny_num ~= nil then
            return inst.medal_destiny_num
        end
        key = key or inst.prefab
    end
    --以上均不符合则从宿命池里捞宿命
    if TheWorld and TheWorld.components.medal_serverdestiny ~= nil then
        if key ~= nil then
            return TheWorld.components.medal_serverdestiny:GetDestinyByKey(key)
        end
        return TheWorld.components.medal_serverdestiny:GetDestiny()
    end

    return math.random()
end

local function realworkfn(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if not doer:HasTag("player") or container == nil then
        return 0
    end
    local worknum = 0
    local giveitems = {}
    for slot, item in pairs(container.slots) do
        if worknum < maxnum and item and item:IsValid() then
            if work_legal_items[item.prefab] ~= nil then
                -- 取出物品
                container.ignoreoverstacked = true
                item = container:RemoveItemBySlot(slot)
                container.ignoreoverstacked = false
                -- 给几个
                local num = 1
                if item.components.stackable then
                    num = item.components.stackable:StackSize()
                end
                -- 加上东西
                for prefabname, givenum in pairs(work_legal_items[item.prefab]) do
                    giveitems[prefabname] = (giveitems[prefabname] or 0) + (num * givenum)
                end
                worknum = worknum + 1
                -- 删掉老物品
                item:Remove()
            elseif item.components.unwrappable and item.components.unwrappable.canbeunwrapped then
                item.components.unwrappable:Unwrap(doer)
                worknum = worknum + 1
            elseif item.prefab == "medal_gift_fruit" then -- 勋章兼容
                local stacksize = item.components.stackable and item.components.stackable.stacksize or 1
                local times = math.min(maxnum - worknum, stacksize)
                local destiny_num = GetMedalDestiny(nil, "medal_gift_fruit")
                for i = 1, times do
                    local giftname = item.GetGift and item:GetGift(doer, destiny_num) or "goldnugget"
                    destiny_num = destiny_num * 10 % 1
                    giveitems[giftname] = (giveitems[giftname] or 0) + 1
                end
                worknum = worknum + times
                if times < stacksize then
                    item.components.stackable:SetStackSize(stacksize - times)
                else
                    container.ignoreoverstacked = true
                    item = container:RemoveItemBySlot(slot)
                    container.ignoreoverstacked = false
                    item:Remove()
                end
            end
        end
    end
    local x, y, z = doer.Transform:GetWorldPosition()
    for prefabname, num in pairs(giveitems) do
        if _G.Prefabs[prefabname] ~= nil and num > 0 then
            local prefab = SpawnPrefab(prefabname)
            num = math.floor(num) + (math.random() < (num - math.floor(num)) and 1 or 0)
            if prefab.components.stackable then
                prefab.components.stackable:SetStackSize(num)
            elseif num > 1 then
                for i = 2, num do
                    local other_prefab = SpawnPrefab(prefabname)
                    container:GiveItem(other_prefab, nil, Vector3(x, y, z))
                end
            end
            container:GiveItem(prefab, nil, Vector3(x, y, z))
        end
    end
    if worknum > 0 and inst.SoundEmitter then
        inst.SoundEmitter:PlaySound("dontstarve/wilson/equip_item_gold")
    end
    return maxnum ~= 999 and worknum or 0
end

-- 采集相关
local function realcollectionfn(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        local x, y, z = doer.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, TUNING.KISAKI_BOX_COLLECTION_FISH_SCOPE, nil,
            { "INLIMBO", "NOCLICK", "fire", "minesprung", "mineactive" },
            { "pickable", "harvestable", "readyforharvest" })
        local collectionnum = 0
        for i, v in pairs(ents) do
            if collectionnum >= maxnum then
                break
            end
            if v.prefab == "flower" then
            elseif v.components.pickable then -- 采集
                v.components.pickable:KisakiPick(doer, inst)
                collectionnum = collectionnum + 1
            elseif v.components.harvestable then -- 收获（蜂巢之类的）
                v.components.harvestable:kisakiHarvest(doer, inst)
                collectionnum = collectionnum + 1
            elseif v.components.crop then -- 老版农田
                v.components.crop:KisakiHarvest(doer, inst)
                collectionnum = collectionnum + 1
            end
        end
        if maxnum == 999 then
            return 0
        end
        return collectionnum
    end
    return 0
end

-- 回鲜相关
local function realfreshfn(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        local freshnum = 0
        for slot, item in pairs(container.slots) do
            if freshnum < maxnum and item and item:IsValid() and item.components.perishable
                and item.components.perishable.perishremainingtime < item.components.perishable.perishtime then
                inst.components.container.ignoreoverstacked = true
                item = inst.components.container:RemoveItemBySlot(slot)
                inst.components.container.ignoreoverstacked = false
                item.components.perishable.perishremainingtime = item.components.perishable.perishtime
                inst.components.container:GiveItem(item, slot)
                if maxnum ~= 999 then
                    freshnum = freshnum + 1
                end
            end
        end
        return freshnum
    end
    return 0
end

-- 回耐相关
local function realdurabilityfn(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        local fixnum = 0
        for k, v in pairs(container.slots) do
            if fixnum < maxnum and v and v:IsValid() and
                (v.components.armor or v.components.finiteuses or v.components.fueled) then
                local fix = false
                if v.components.armor ~= nil and not v.components.armor.indestructible and v.components.armor:GetPercent() < 1 then -- 护甲类的
                    v.components.armor:SetPercent(1)
                    fix = true
                elseif v.components.finiteuses ~= nil and v.components.finiteuses:GetPercent() < 1 then -- 使用次数类的
                    v.components.finiteuses:SetPercent(1)
                    fix = true
                elseif v.components.fueled ~= nil and v.components.fueled:GetPercent() < 1 then --燃料
                    v.components.fueled:SetPercent(1)
                    fix = true
                end
                if fix then
                    fixnum = fixnum + 1
                end
            end
        end
        if fixnum > 0 and inst.SoundEmitter then
            inst.SoundEmitter:PlaySound("rifts6/vault_portal/repair")
        end
        return maxnum ~= 999 and fixnum or 0
    end
    return 0
end

-- 消耐相关
local function realconsumedurabilityfn(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if not doer:HasTag("player") or container == nil then
        return 0
    end
    local fixnum = 0
    for k, v in pairs(container.slots) do
        if fixnum < maxnum and v and v:IsValid() and
            (v.components.armor or v.components.finiteuses or v.components.fueled) then
            local fix = false
            if v.components.armor ~= nil and not v.components.armor.indestructible and v.components.armor:GetPercent() > 0.05 then -- 护甲类的
                v.components.armor:SetPercent(0.01)
                fix = true
            elseif v.components.finiteuses ~= nil and v.components.finiteuses:GetPercent() > 0.05 then -- 使用次数类的
                v.components.finiteuses:SetPercent(0.01)
                fix = true
            elseif v.components.fueled ~= nil and v.components.fueled:GetPercent() > 0.05 then --燃料
                v.components.fueled:SetPercent(0.01)
                fix = true
            end
            if fix then
                fixnum = fixnum + 1
            end
        end
    end
    if fixnum > 0 and inst.SoundEmitter then
        inst.SoundEmitter:PlaySound("rifts6/vault_portal/repair")
    end
    return maxnum ~= 999 and fixnum or 0
end

-- 魔火相关
local function realfirefn(doer, inst)
    if inst == nil or doer == nil then
        return
    end
    local container = inst.components.inventory or inst.components.container
    if not doer:HasTag("player") or container == nil then
        return
    end
    -- 特效
    inst.SoundEmitter:PlaySound("dontstarve/common/fireAddFuel")
    local fx = SpawnPrefab("collapse_small")
    local pos = Vector3(inst.Transform:GetWorldPosition())
    fx.Transform:SetScale(0.5, 0.5, 0.5)
    fx.Transform:SetPosition(pos:Get())
    local fx2 = SpawnPrefab("small_puff")
    fx2.entity:SetParent(inst.entity)
    fx2.Transform:SetPosition(0, 3, 0)
    -- 烹饪
    for slot, v in pairs(inst.components.container.slots) do
        local item = inst.components.container:GetItemInSlot(slot)
        if (item) then
            local replacement = nil
            if item.components.cookable then
                replacement = item.components.cookable.product
            elseif item.prefab == "log" then
                replacement = "charcoal"
            elseif item.components.burnable then
                replacement = "ash"
            end
            if replacement then
                if type(replacement) == "function" then
                    replacement = replacement(item, inst)
                end
                if type(replacement) == "string" then
                    local stacksize = 1
                    if item.components.stackable then
                        stacksize = item.components.stackable:StackSize()
                    end
                    local newprefab = SpawnPrefab(replacement)
                    if newprefab.components.stackable then
                        newprefab.components.stackable:SetStackSize(stacksize)
                    end
                    container.ignoreoverstacked = true
                    item = container:RemoveItemBySlot(slot)
                    container.ignoreoverstacked = false
                    if (item) then
                        item:Remove()
                    end
                    container:GiveItem(newprefab, slot)
                end
            end
        end
    end
end

-- 腐烂相关
local function realdecayfn(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        local decaynum = 0
        for slot, item in pairs(container.slots) do
            if decaynum < maxnum and item and item:IsValid() and item.components.perishable and item.components.perishable:GetPercent() > 0.02 then
                inst.components.container.ignoreoverstacked = true
                item = inst.components.container:RemoveItemBySlot(slot)
                inst.components.container.ignoreoverstacked = false
                item.components.perishable.perishremainingtime = 1
                inst.components.container:GiveItem(item, slot)
                if maxnum ~= 999 then
                    decaynum = decaynum + 1
                end
            end
        end
        return decaynum
    end
    return 0
end

-- 提取相关
local function realextractfn(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        -- 特效
        inst.SoundEmitter:PlaySound("dontstarve/common/fireAddFuel")
        local fx = SpawnPrefab("collapse_small")
        local pos = Vector3(inst.Transform:GetWorldPosition())
        fx.Transform:SetScale(0.5, 0.5, 0.5)
        fx.Transform:SetPosition(pos:Get())
        local fx2 = SpawnPrefab("small_puff")
        fx2.entity:SetParent(inst.entity)
        fx2.Transform:SetPosition(0, 3, 0)
        -- 提取
        local extractnum = 0
        for slot, item in pairs(container.slots) do
            if item and item:IsValid() and not item:HasTag("irreplaceable")
                and item.prefab ~= "kisaki_ether" and item.prefab ~= "kisaki_ether_bottle" then
                -- 取出物品
                container.ignoreoverstacked = true
                item = container:RemoveItemBySlot(slot)
                container.ignoreoverstacked = false
                -- 给几个
                local num = 10
                if item.components.stackable then
                    num = item.components.stackable:StackSize()
                end
                extractnum = extractnum + num
                -- 删掉老物品
                item:Remove()
            end
        end
        -- 给予物品
        extractnum = math.min(extractnum, maxnum)
        if extractnum > 0 and _G.Prefabs["kisaki_ether"] then
            local x, y, z = doer.Transform:GetWorldPosition()
            local prefab = SpawnPrefab("kisaki_ether")
            prefab.components.stackable:SetStackSize(extractnum)
            container:GiveItem(prefab, nil, Vector3(x, y, z))
        end
        return MAXUINT == maxnum and 0 or extractnum
    end
    return 0
end

-- 拆解相关
local function destroystructure(target, caster)
    local recipe = AllRecipes[target.prefab]
    if recipe == nil or FunctionOrValue(recipe.no_deconstruction, target) then
        --Action filters should prevent us from reaching here normally
        return nil
    end

    -- 拆解出来东西的给于的比率
    local ingredient_percent =
        ((target.components.finiteuses ~= nil and not FunctionOrValue(recipe.decon_ignores_finiteuses, target) and target.components.finiteuses:GetPercent()) or
            (target.components.fueled ~= nil and target.components.inventoryitem ~= nil and target.components.fueled:GetPercent()) or
            (target.components.armor ~= nil and target.components.inventoryitem ~= nil and target.components.armor:GetPercent()) or
            1
        ) / recipe.numtogive
    -- 拆解
    local giveitems = {}
    for i, v in ipairs(recipe.ingredients) do
        -- 拆不出宝石和重要物品
        if string.sub(v.type, -3) ~= "gem" or string.sub(v.type, -11, -4) == "precious" then
            --V2C: always at least one in case ingredient_percent is 0%
            local amt = v.amount == 0 and 0 or math.max(1, math.ceil(v.amount * ingredient_percent))
            giveitems[v.type] = (giveitems[v.type] or 0) + amt
        end
    end

    if target.components.inventory ~= nil then
        target.components.inventory:DropEverything()
    end

    if target.components.container ~= nil then
        target.components.container:DropEverything(nil, true)
    end

    if target.components.spawner ~= nil and target.components.spawner:IsOccupied() then
        target.components.spawner:ReleaseChild()
    end

    if target.components.occupiable ~= nil and target.components.occupiable:IsOccupied() then
        local item = target.components.occupiable:Harvest()
        if item ~= nil then
            item.Transform:SetPosition(target.Transform:GetWorldPosition())
            item.components.inventoryitem:OnDropped()
        end
    end

    if target.components.trap ~= nil then
        target.components.trap:Harvest()
    end

    if target.components.dryer ~= nil then
        target.components.dryer:DropItem()
    end

    if target.components.harvestable ~= nil then
        target.components.harvestable:Harvest()
    end

    if target.components.stewer ~= nil then
        target.components.stewer:Harvest()
    end

    if target.components.constructionsite ~= nil then
        target.components.constructionsite:DropAllMaterials()
    end

    if target.components.inventoryitemholder ~= nil then
        target.components.inventoryitemholder:TakeItem()
    end

    target:PushEvent("ondeconstructstructure", caster)

    -- 删除老物品
    if not target.no_delete_on_deconstruct then
        if target.components.stackable ~= nil then
            local stacknum = target.components.stackable.stacksize
            for prefabname, num in pairs(giveitems) do
                giveitems[prefabname] = num * stacknum
            end
        end
        target:Remove()
    end
    -- 返回可以拆出来的东西
    return giveitems
end
local function realdisassemblyfn(doer, inst, maxnum)
    if inst == nil or doer == nil then
        return 0
    end
    local container = inst.components.inventory or inst.components.container
    if not doer:HasTag("player") or container == nil then
        return 0
    end
    local giveitems = {}
    local disassemblynum = 0
    local x, y, z = doer.Transform:GetWorldPosition()
    for slot, v in pairs(inst.components.container.slots) do
        if disassemblynum >= maxnum then
            break
        end
        -- 取出物品
        container.ignoreoverstacked = true
        local item = container:RemoveItemBySlot(slot)
        container.ignoreoverstacked = false
        if (item) then
            item.Transform:SetPosition(x, y, z)
            local items = destroystructure(item, doer)
            if items ~= nil then
                for prefabname, num in pairs(items) do
                    giveitems[prefabname] = (giveitems[prefabname] or 0) + num
                end
                disassemblynum = disassemblynum + 1
            else
                -- 放回去
                container:GiveItem(item, slot)
            end
        end
    end

    for prefabname, num in pairs(giveitems) do
        if num > 0 then
            local prefab = SpawnPrefab(prefabname)
            if prefab.components.stackable then
                prefab.components.stackable:SetStackSize(num)
            elseif num > 1 then
                for i = 2, num do
                    local other_prefab = SpawnPrefab(prefabname)
                    container:GiveItem(other_prefab, nil, Vector3(x, y, z))
                end
            end
            container:GiveItem(prefab, nil, Vector3(x, y, z))
        end
    end
    -- 特效
    if disassemblynum > 0 then
        SpawnPrefab('fx_book_fire').Transform:SetPosition(Vector3(inst.Transform:GetWorldPosition()):Get())
    end
    return disassemblynum
end

-- 猪王交易相关
local function realpigtradefn(doer, inst)
    if inst == nil or doer == nil then
        return
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        local num = 0
        for slot, v in pairs(inst.components.container.slots) do
            local item = inst.components.container:GetItemInSlot(slot)
            if (item) and item.components.tradable and item.components.tradable.goldvalue > 0 then
                -- 取出物品
                container.ignoreoverstacked = true
                item = container:RemoveItemBySlot(slot)
                container.ignoreoverstacked = false
                -- 金子
                if item.components.stackable then
                    num = num + (item.components.stackable:StackSize() * item.components.tradable.goldvalue)
                else
                    num = num + item.components.tradable.goldvalue
                end
                -- 其他物品
                if item.components.tradable.tradefor ~= nil then
                    local cycletime = item.components.stackable and item.components.stackable:StackSize() or 1
                    for i = 1, cycletime do
                        for _, other in pairs(item.components.tradable.tradefor) do
                            local other_item = SpawnPrefab(other)
                            if other_item ~= nil then
                                container:GiveItem(other_item)
                            end
                        end
                    end
                end
                -- 删掉老物品
                item:Remove()
            end
        end
        if num > 0 then
            local x, y, z = doer.Transform:GetWorldPosition()
            local nug = SpawnPrefab("goldnugget")
            nug.components.stackable:SetStackSize(num)
            container:GiveItem(nug, nil, Vector3(x, y, z))
            -- 特效
            SpawnPrefab('fx_book_fire').Transform:SetPosition(Vector3(inst.Transform:GetWorldPosition()):Get())
        end
    end
end

-- 鸟笼交易相关
local bird_eat_invalid_foods = {
    "bird_egg",
    "bird_egg_cooked",
    "rottenegg",
    "woby_treat",
    "um_monsteregg",
    "um_monsteregg_cooked",
}
local function isbirdcaneat(item)
    local can_accept = item.components.edible
        and (_G.Prefabs[string.lower(item.prefab .. "_seeds")]
            or item.prefab == "seeds"
            or string.match(item.prefab, "_seeds")
            or item.components.edible.foodtype == FOODTYPE.MEAT)

    if table.contains(bird_eat_invalid_foods, item.prefab) then
        can_accept = false
    end

    return can_accept
end
local isuncompromisingbirdchangeopen = TUNING.DSTU ~= nil and TUNING.DSTU.MONSTER_EGGS > 0
local function realbirdtradefn(doer, inst)
    if inst == nil or doer == nil then
        return
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        local giveitems = {}
        for slot, v in pairs(inst.components.container.slots) do
            local item = inst.components.container:GetItemInSlot(slot)
            -- 种子或者肉
            if (item) and isbirdcaneat(item) then
                -- 取出物品
                container.ignoreoverstacked = true
                item = container:RemoveItemBySlot(slot)
                container.ignoreoverstacked = false
                -- 给几个
                local num = 1
                if item.components.stackable then
                    num = item.components.stackable:StackSize()
                end
                -- 永不妥协兼容,怪物蛋
                if isuncompromisingbirdchangeopen and _G.Prefabs["um_monsteregg"]
                    and item.components.edible.secondaryfoodtype ~= nil and item.components.edible.secondaryfoodtype == FOODTYPE.MONSTER
                    and item.components.edible ~= nil and item.components.edible.foodtype == FOODTYPE.MEAT then
                    if giveitems["um_monsteregg"] ~= nil then
                        giveitems["um_monsteregg"] = giveitems["um_monsteregg"] + num
                    else
                        giveitems["um_monsteregg"] = num
                    end
                else
                    if item.components.edible.foodtype == FOODTYPE.MEAT then
                        if giveitems["bird_egg"] ~= nil then
                            giveitems["bird_egg"] = giveitems["bird_egg"] + num
                        else
                            giveitems["bird_egg"] = num
                        end
                    elseif string.match(item.prefab, "_seeds") or item.prefab == "seeds" then
                        if giveitems["guano"] ~= nil then
                            giveitems["guano"] = giveitems["guano"] + math.ceil(num / 3)
                        else
                            giveitems["guano"] = math.ceil(num / 3)
                        end
                    elseif _G.Prefabs[string.lower(item.prefab .. "_seeds")] then
                        if giveitems[item.prefab .. "_seeds"] ~= nil then
                            giveitems[item.prefab .. "_seeds"] = giveitems[item.prefab .. "_seeds"] + num
                        else
                            giveitems[item.prefab .. "_seeds"] = num
                        end
                    end
                end
                -- 删掉老物品
                item:Remove()
            end
        end
        -- 给交换的东西
        local isgive = false
        local x, y, z = doer.Transform:GetWorldPosition()
        for prefabname, num in pairs(giveitems) do
            isgive = true
            local prefab = SpawnPrefab(prefabname)
            if prefab.components.stackable then
                prefab.components.stackable:SetStackSize(num)
            elseif num > 1 then
                for i = 2, num do
                    local other_prefab = SpawnPrefab(prefabname)
                    container:GiveItem(other_prefab, nil, Vector3(x, y, z))
                end
            end
            container:GiveItem(prefab, nil, Vector3(x, y, z))
        end
        -- 特效
        if isgive then
            SpawnPrefab('fx_book_fire').Transform:SetPosition(Vector3(inst.Transform:GetWorldPosition()):Get())
        end
    end
end

-- 鱼人王交易相关
local fish_trade_list = {
    ["kelp"] = 12,         -- 海带
    ["seeds"] = 16.25,     -- 种子
    ["tentaclespots"] = 1, -- 触手皮
    ["cutreeds"] = 1.5     -- 芦苇
}
local fish_trade_trinkets = { "trinket_12", "trinket_25", "trinket_1", "trinket_17", "trinket_8", }
local fish_trade_seeds = { "durian_seeds", "pepper_seeds", "eggplant_seeds", "pumpkin_seeds", "onion_seeds",
    "garlic_seeds" }
local all_fish_trade_list = {
    { prefabs = { "kelp" },          min_count = 0, max_count = 1 },
    { prefabs = { "kelp" },          min_count = 0, max_count = 2 },
    { prefabs = { "seeds" },         min_count = 2, max_count = 4 },
    { prefabs = { "tentaclespots" }, min_count = 1, max_count = 1 },
    { prefabs = { "cutreeds" },      min_count = 1, max_count = 2 },
    { prefabs = fish_trade_trinkets, min_count = 1, max_count = 1 },
    { prefabs = fish_trade_seeds,    min_count = 1, max_count = 2 },
}
local function realfishtradefn(doer, inst)
    if inst == nil or doer == nil then
        return
    end
    local container = inst.components.inventory or inst.components.container
    if doer:HasTag("player") and container ~= nil then
        local giveitems = {}
        local getfishnum = 0
        -- 先统计下所有的鱼
        for slot, v in pairs(inst.components.container.slots) do
            local item = inst.components.container:GetItemInSlot(slot)
            -- 使用鱼交易
            if (item) and item:HasTag("fish") then
                -- 取出物品
                container.ignoreoverstacked = true
                item = container:RemoveItemBySlot(slot)
                container.ignoreoverstacked = false
                -- 有几个
                local num = 1
                if item.components.stackable then
                    num = item.components.stackable:StackSize()
                end
                getfishnum = getfishnum + num
                -- 海鱼额外给金子/元宝
                if item:HasTag("oceanfish") then
                    local goldnum, goldprefab = 2, "goldnugget"
                    if item.prefab:find("oceanfish_medium_") == 1 then
                        goldnum = 3
                        if item.prefab == "oceanfish_medium_6_inv" or item.prefab == "oceanfish_medium_7_inv" then -- YoT events.
                            goldprefab = "lucky_goldnugget"
                        end
                    end
                    giveitems[goldprefab] = (giveitems[goldprefab] or 0) + (goldnum * num)
                end
                -- 删掉交易物品
                item:Remove()
            end
        end
        -- 7条鱼分一组，先给一套
        local setnum = math.floor(getfishnum / 7)
        if setnum > 0 then
            -- 基础物资
            for prefabname, num in pairs(fish_trade_list) do
                giveitems[prefabname] = num * setnum
            end
            -- 玩具
            if math.floor(setnum / 5) > 0 then
                for _, prefabname in ipairs(fish_trade_trinkets) do
                    giveitems[prefabname] = math.floor(math.floor(setnum / 5) * 1.75)
                end
            end
            for i = 1, (setnum % 5) do
                local selected_trinket = fish_trade_trinkets[math.random(#fish_trade_trinkets)]
                giveitems[selected_trinket] = (giveitems[selected_trinket] or 0) + 1
            end
            -- 种子
            if math.floor(setnum / 6) > 0 then
                for _, prefabname in ipairs(fish_trade_seeds) do
                    giveitems[prefabname] = math.floor(math.floor(setnum / 6) * 2.25)
                end
            end
            for i = 1, (setnum % 6) do
                local selected_seed = fish_trade_seeds[math.random(#fish_trade_seeds)]
                giveitems[selected_seed] = (giveitems[selected_seed] or 0) + 2
            end
        end
        -- 剩下小于7条，随机一组，剩下的给的少，尽量批量交易
        for i = 1, (getfishnum % 7) do
            -- 先给额外物品
            local selected_tarde = all_fish_trade_list[math.random(#all_fish_trade_list)]
            local prefabname = selected_tarde.prefabs[math.random(#selected_tarde.prefabs)]
            giveitems[prefabname] = (giveitems[prefabname] or 0) +
                math.random(selected_tarde.min_count, selected_tarde.max_count)
            -- 给种子或海带
            if prefabname == "kelp" or (prefabname ~= "seeds" and math.random(1, 4) > 3) then
                giveitems["kelp"] = (giveitems["kelp"] or 0) + math.random(2, 6)
            else
                giveitems["seeds"] = (giveitems["seeds"] or 0) + math.random(2, 6)
            end
        end
        local isgive = false
        -- 计算完毕，开始给物品
        local x, y, z = doer.Transform:GetWorldPosition()
        for prefabname, num in pairs(giveitems) do
            if num > 0 then
                isgive = true
                local prefab = SpawnPrefab(prefabname)
                if prefab.components.stackable then
                    prefab.components.stackable:SetStackSize(num)
                elseif num > 1 then
                    for i = 2, num do
                        local other_prefab = SpawnPrefab(prefabname)
                        container:GiveItem(other_prefab, nil, Vector3(x, y, z))
                    end
                end
                container:GiveItem(prefab, nil, Vector3(x, y, z))
            end
        end
        -- 特效
        if isgive then
            SpawnPrefab('fx_book_fire').Transform:SetPosition(Vector3(inst.Transform:GetWorldPosition()):Get())
        end
    end
end

-- 蚁狮交易相关
local antlion_trade_blacklist = { "refined_dust", "cutstone", "rocks" }
local function realantliontradefn(doer, inst)
    if inst == nil or doer == nil then
        return
    end
    local container = inst.components.inventory or inst.components.container
    if not doer:HasTag("player") or container == nil then
        return
    end
    local giveitems = {}
    for slot, v in pairs(inst.components.container.slots) do
        local item = inst.components.container:GetItemInSlot(slot)
        if (item) and item.components.tradable and item.components.tradable.rocktribute and item.components.tradable.rocktribute > 0
            and item.components.temperature == nil and not table.contains(antlion_trade_blacklist, item.prefab) then
            -- 取出物品
            container.ignoreoverstacked = true
            item = container:RemoveItemBySlot(slot)
            container.ignoreoverstacked = false
            -- 可兑换物品
            local pendingrewarditem =
                (item.prefab == "antliontrinket" and { "townportal_blueprint", "antlionhat_blueprint" }) or
                (item.prefab == "cotl_trinket" and { "turf_cotl_brick_blueprint", "turf_cotl_gold_blueprint", "cotl_tabernacle_level1_blueprint" }) or
                (item.components.tradable.goldvalue > 0 and "townportaltalisman") or
                nil
            local stacknum = 1
            if item.components.stackable then
                stacknum = item.components.stackable:StackSize()
            end
            if type(pendingrewarditem) == "table" then
                for _, prefabname in ipairs(pendingrewarditem) do
                    giveitems[prefabname] = (giveitems[prefabname] or 0) + stacknum
                end
            elseif pendingrewarditem ~= nil then
                giveitems[pendingrewarditem] = (giveitems[pendingrewarditem] or 0) + stacknum
            end
            -- 删掉老物品
            item:Remove()
        end
    end
    local isgive = false
    local x, y, z = doer.Transform:GetWorldPosition()
    for prefabname, num in pairs(giveitems) do
        isgive = true
        local prefab = SpawnPrefab(prefabname)
        if prefab.components.stackable then
            prefab.components.stackable:SetStackSize(num)
        elseif num > 1 then
            for i = 2, num do
                local other_prefab = SpawnPrefab(prefabname)
                container:GiveItem(other_prefab, nil, Vector3(x, y, z))
            end
        end
        container:GiveItem(prefab, nil, Vector3(x, y, z))
    end
    -- 特效
    if isgive then
        SpawnPrefab('fx_book_fire').Transform:SetPosition(Vector3(inst.Transform:GetWorldPosition()):Get())
    end
end

-- 制图桌擦纸相关
local function realmappingtradefn(doer, inst)
    if inst == nil or doer == nil then
        return
    end
    local container = inst.components.inventory or inst.components.container
    if not doer:HasTag("player") or container == nil then
        return
    end
    local giveitems = {}
    for slot, v in pairs(inst.components.container.slots) do
        local item = inst.components.container:GetItemInSlot(slot)
        if (item) and item.components.erasablepaper then
            -- 取出物品
            container.ignoreoverstacked = true
            item = container:RemoveItemBySlot(slot)
            container.ignoreoverstacked = false
            -- 数量
            local stacknum = item.components.erasablepaper.stacksize
            if item.components.stackable then
                stacknum = item.components.stackable:StackSize() * item.components.erasablepaper.stacksize
            end
            -- 物品
            local prefabname = item.components.erasablepaper.erased_prefab
            giveitems[prefabname] = (giveitems[prefabname] or 0) + stacknum
            -- 删掉相关物品
            item:Remove()
        end
    end
    local isgive = false
    local x, y, z = doer.Transform:GetWorldPosition()
    for prefabname, num in pairs(giveitems) do
        isgive = true
        local prefab = SpawnPrefab(prefabname)
        if prefab.components.stackable then
            prefab.components.stackable:SetStackSize(num)
        elseif num > 1 then
            for i = 2, num do
                local other_prefab = SpawnPrefab(prefabname)
                container:GiveItem(other_prefab, nil, Vector3(x, y, z))
            end
        end
        container:GiveItem(prefab, nil, Vector3(x, y, z))
    end
    -- 特效
    if isgive then
        SpawnPrefab('fx_book_fire').Transform:SetPosition(Vector3(inst.Transform:GetWorldPosition()):Get())
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 妃的杂物袋
containers_params.kisaki_portable_box = {
    widget = {
        slotpos = {},
        slotbg = {},
        animbank = "ui_kisaki_container_16x1",
        animbuild = "ui_kisaki_container_16x1",
        pos = Vector3(-480, 50, 0),
        side_align_tip = 160,
        dragkey = "kisaki_portable_box" -- 容器UI拖拽的标识key
        -- hanchor = 0, --锚点，0中1左2右
        -- vanchor = 2, --锚点，0中1上2下
    },
    type = "kisaki_portable_box",    -- 物品框在人物栏上方
    usespecificslotsforitems = true, -- 左键移动自动找到可放入格子
}
for x = -7, 8 do
    table.insert(containers_params.kisaki_portable_box.widget.slotpos, Vector3(80 * x - 30, 0, 0))
end
local items = {
    "cutgrass", "twigs", "log", "charcoal", "cutreeds", "flint", "rocks", "nitre",
    "goldnugget", "marble", "moonrocknugget", "moonglass", "gears", "wagpunk_bits", "livinglog", "nightmarefuel",
}
local items_flags = {
    ["cutgrass"] = 1,
    ["twigs"] = 2,
    ["log"] = 3,
    ["charcoal"] = 4,
    ["cutreeds"] = 5,
    ["flint"] = 6,
    ["rocks"] = 7,
    ["nitre"] = 8,
    ["goldnugget"] = 9,
    ["marble"] = 10,
    ["moonrocknugget"] = 11,
    ["moonglass"] = 12,
    ["gears"] = 13,
    ["wagpunk_bits"] = 14,
    ["livinglog"] = 15,
    ["nightmarefuel"] = 16,
}
for key, value in pairs(items) do
    containers_params.kisaki_portable_box.widget.slotbg[key] = {
        atlas = 'images/inventoryimages/widget/kisaki_container_ui.xml',
        image = 'container_ui_' .. value .. '.tex'
    }
end
-- 不能放入特定物品
function containers_params.kisaki_portable_box.itemtestfn(container, item, slot)
    if slot then
        return item.prefab == items[slot]
    end
    return items_flags[item.prefab] ~= nil
end

-- 判断是否优先进入该盒子(模组特有方法定义)
function containers_params.kisaki_portable_box.prioritygivefn(container, item)
    return items_flags[item.prefab]
end

-- 优先进入逻辑，只有背包有用
-- containers_params.kisaki_portable_box.priorityfn = containers_params.kisaki_portable_box.itemtestfn
-- 收集按钮
local function portableboxcollect(doer, inst)
    realcollectfn(doer, inst, sameitemcollectjudgefn, items_flags, 999)
end
AddModRPCHandler("kisaki", "portable_chest_collect", portableboxcollect)
local function portableboxcollectbtnfn(inst, doer)
    if inst.components.container ~= nil then
        portableboxcollect(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "portable_chest_collect"), inst)
    end
end
containers_params.kisaki_portable_box.widget.buttoninfo = {
    text = STRINGS.KISAKI_ACTION.COLLECT,
    position = Vector3(630, 70, 0),
    fn = portableboxcollectbtnfn,
    validfn = containerDefaultValid,
}
copyChestUI("kisaki_portable_box", "kisaki_portable_box_chest")



-- 妃的魔法盒
containers_params.kisaki_magic_box = {
    widget = {
        kisaki_button_position_map = {},
        slotpos = {},
        animbank = "ui_kisaki_container_5x5",
        animbuild = "ui_kisaki_container_5x5",
        pos = Vector3(0, 240, 0),
        side_align_tip = 160,
        dragkey = "kisaki_magic_box" -- 容器UI拖拽的标识key
        -- hanchor = 0, --锚点，0中1左2右
        -- vanchor = 2, --锚点，0中1上2下
    },
    type = "kisaki_magic_box", -- 物品框在人物栏上方
}
for y = 2, -2, -1 do
    for x = -2, 2 do
        table.insert(containers_params.kisaki_magic_box.widget.slotpos, Vector3(80 * x, 80 * y + 30, 0))
    end
end
-- 不能放容器
local kisaki_magic_box_whitelist = { "alterguardianhat", "alterguardianhatshard", "oceanfishingrod", "antlionhat" }
function containers_params.kisaki_magic_box.itemtestfn(container, item, slot)
    return not item:HasTag("_container") or table.contains(kisaki_magic_box_whitelist, item.prefab)
end

-- 判断是否优先进入该盒子(模组特有方法定义)
function containers_params.kisaki_magic_box.prioritygivefn(container, item)
    -- 可堆叠且容器里有这个东西
    return item and container:KisakiGetItemSlot(item) ~= nil and (item.components.stackable or not container:IsFull())
end

-- 收集按钮
local function magicboxcollect(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer or not doer:HasTag("player") then
        return
    end
    local prefabs = {}
    if inst.components.container and inst.components.container.slots then
        for k, v in pairs(inst.components.container.slots) do
            if v ~= nil then
                prefabs[v.prefab] = true
            end
        end
    end
    local collectconsume = TUNING.KISAKI_COLLECT_CONSUME
    local maxnum = inst.noconsumenum >= inst.noconsumeneednum and 999 or getworkmaxnum(doer, collectconsume);
    maxnum = maxnum == 999 and 999 or math.min(TUNING.KISAKI_COLLECT_MAX, maxnum)
    log.debug("本次收集可以收集生物数最大值：" .. maxnum)
    local num = realcollectfn(doer, inst, sameitemcollectjudgefn, prefabs, maxnum)
    if inst.noconsumenum < inst.noconsumeneednum then
        consumeproperty(doer, num * collectconsume)
    end
end
AddModRPCHandler("kisaki", "magic_chest_collect", magicboxcollect)
local function magicboxcollectbtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxcollect(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_collect"), inst)
    end
end
-- 快存按钮
AddModRPCHandler("kisaki", "magic_chest_storage", magicboxstorage)
local function magicboxstoragebtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxstorage(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_storage"), inst)
    end
end
-- 整理按钮
AddModRPCHandler("kisaki", "magic_chest_sort", boxsort)
local function magicboxsortbtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        boxsort(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_sort"), inst)
    end
end
-- 更多按钮
local more_button_list = {
    "upgrade",
    "collection",
    "fishing",
    "conversion",
    "work",
    "fresh",
    "durability",
    "consumedurability",
    "fire",
    "decay",
    "extract",
    "disassembly",
    "pigtrade",
    "birdtrade",
    "fishtrade",
    "antliontrade",
    "mappingtrade",
}
local function magicboxmorebtnfn(inst, doer, self)
    if inst.replica.container ~= nil and not inst.kisaki_button_cd and self.kisaki_buttons then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.2, endbuttonloading)
        for _, buttonname in ipairs(more_button_list) do
            local button = self.kisaki_buttons[buttonname]
            if button.shown then
                button:Hide()
            else
                button:Show()
            end
        end
    end
end
-- 升级按钮
local function magicboxupgrade(doer, inst)
    if inst and doer and inst.components.container and not inst.components.container.readonlycontainer and inst.components.container.slots and doer:HasTag("player") then
        for slot, item in pairs(inst.components.container.slots) do
            for i, data in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
                local action = data.action
                if inst[action .. "needprefab"] ~= nil and inst[action .. "neednum"] ~= nil and inst[action .. "num"] ~= nil then
                    if item.prefab == inst[action .. "needprefab"] and inst[action .. "neednum"] > inst[action .. "num"] then
                        local num = 1
                        if item.components.stackable then
                            if item.components.stackable.stacksize > (inst[action .. "neednum"] - inst[action .. "num"]) then
                                num = inst[action .. "neednum"] - inst[action .. "num"]
                                item.components.stackable:SetStackSize(item.components.stackable.stacksize - num)
                            else
                                num = item.components.stackable.stacksize
                                inst.components.container.ignoreoverstacked = true
                                item = inst.components.container:RemoveItemBySlot(slot)
                                inst.components.container.ignoreoverstacked = false
                                item:Remove()
                            end
                        else
                            inst.components.container:RemoveItem(item, true):Remove()
                        end
                        inst[action .. "num"] = inst[action .. "num"] + num
                        if item.prefab == inst.preserverneedprefab or item.prefab == inst.freshneedprefab then
                            inst.addpreserver()
                        end
                        if item.prefab == inst.durabilityprefab or item.prefab == inst.autodurabilityneedprefab then
                            inst.addrestorationdurability()
                        end
                    end
                end
            end
            if item.prefab and not inst.fishlist[item.prefab] and
                ((string.len(item.prefab) > 4 and item.prefab:sub(-4) == "_inv" and _G.Prefabs[item.prefab:sub(1, -5)])
                    or item.prefab == "wobster_sheller_land" or item.prefab == "wobster_moonglass_land") then
                if item.components.stackable and item.components.stackable.stacksize > 1 then
                    item.components.stackable:SetStackSize(item.components.stackable.stacksize - 1)
                else
                    inst.components.container:RemoveItem(item, true):Remove()
                end
                inst.fishlist[item.prefab] = true
            end
        end
        -- 升级语句
        local upgradesay = "\n\n\n\n\n\n\n\n\n\n\n\n\n容器升级\n"
        for i, data in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
            upgradesay = upgradesay ..
                string.format("%s:\t%s\t(%d/%d)\n", data.name or "nil",
                    STRINGS.NAMES[string.upper(inst[data.action .. "needprefab"])] or "nil",
                    inst[data.action .. "num"] or 0, inst[data.action .. "neednum"] or 0)
        end
        doer.components.talker:Say(upgradesay)
    end
end
AddModRPCHandler("kisaki", "magic_chest_upgrade", magicboxupgrade)
local function magicboxupgradebtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxupgrade(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_upgrade"), inst)
    end
end
-- 采集按钮
local function magicboxcollection(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    -- 采集物品
    if inst.collectionneednum <= inst.collectionnum then
        local consume = TUNING.KISAKI_COLLECTION_CONSUME
        local maxnum = inst.noconsumenum >= inst.noconsumeneednum and TUNING.KISAKI_COLLECTION_MAX or
            getworkmaxnum(doer, consume);
        maxnum = math.min(TUNING.KISAKI_COLLECTION_MAX, maxnum)
        log.debug("本次采集可以采集数最大值：" .. maxnum)
        if maxnum < 1 then
            doer.components.talker:Say("三维不足，无法采集!")
            return
        end
        -- 采集植物
        local num = realcollectionfn(doer, inst, maxnum)
        if inst.noconsumenum < inst.noconsumeneednum then
            consumeproperty(doer, num * consume)
        end
    else
        doer.components.talker:Say("物品采集功能未解锁!")
    end
end
AddModRPCHandler("kisaki", "magic_chest_collection", magicboxcollection)
local function magicboxcollectionbtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxcollection(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_collection"), inst)
    end
end
-- 捕鱼按钮
local function magicboxfishing(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    -- 抓鱼
    if inst.fishneednum <= inst.fishnum or inst.catchfishneednum <= inst.catchfishnum then
        local consume = TUNING.KISAKI_FISH_CONSUME
        local maxnum = inst.noconsumenum >= inst.noconsumeneednum and TUNING.KISAKI_FISH_MAX or
            getworkmaxnum(doer, consume);
        maxnum = math.min(TUNING.KISAKI_FISH_MAX, maxnum)
        log.debug("本次捕鱼可以捕鱼数最大值：" .. maxnum)
        if maxnum < 1 then
            doer.components.talker:Say("三维不足，无法捕鱼!")
            return
        end
        -- 先抓海鱼
        local num = inst.fishneednum <= inst.fishnum and realcatchfishfn(doer, inst, inst.fishlist, maxnum) or 0
        maxnum = maxnum - num
        if maxnum > 0 then
            -- 还有次数抓陆地鱼
            num = num + (inst.catchfishneednum <= inst.catchfishnum and realcatchloadfishfn(doer, inst, maxnum) or 0)
        end
        if inst.noconsumenum < inst.noconsumeneednum then
            consumeproperty(doer, num * consume)
        end
    else
        doer.components.talker:Say("捕鱼功能未解锁!")
    end
end
AddModRPCHandler("kisaki", "magic_chest_fishing", magicboxfishing)
local function magicboxfishingbtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxfishing(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_fishing"), inst)
    end
end
-- 转化按钮
local function magicboxconversion(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.conversionnum < inst.conversionneednum then
        doer.components.talker:Say("转化功能未解锁!")
        return
    end
    local consume = TUNING.KISAKI_CONVERSION_CONSUME
    local maxnum = inst.noconsumenum >= inst.noconsumeneednum and 999 or getworkmaxnum(doer, consume, false);
    maxnum = maxnum == 999 and 999 or math.min(TUNING.KISAKI_CONVERSION_MAX, maxnum)
    log.debug("本次转化可以转化数最大值：" .. maxnum)
    if maxnum < 1 then
        doer.components.talker:Say("魔力不足，无法转化!")
        return
    end
    -- 转化
    local num = realconversionfn(doer, inst, maxnum)
    -- 消耗
    if inst.noconsumenum < inst.noconsumeneednum then
        consumeproperty(doer, num * consume)
    end
end
AddModRPCHandler("kisaki", "magic_chest_conversion", magicboxconversion)
local function magicboxconversionbtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxconversion(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_conversion"), inst)
    end
end
-- 工作按钮
local function magicboxwork(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.worknum < inst.workneednum then
        doer.components.talker:Say("工作功能未解锁!")
        return
    end
    local consume = TUNING.KISAKI_WORK_CONSUME
    local maxnum = inst.noconsumenum >= inst.noconsumeneednum and TUNING.KISAKI_WORK_MAX or getworkmaxnum(doer, consume);
    maxnum = math.min(TUNING.KISAKI_WORK_MAX, maxnum)
    log.debug("本次工作可以工作数最大值：" .. maxnum)
    if maxnum < 1 then
        doer.components.talker:Say("三维不足，无法工作!")
        return
    end
    -- 工作
    local num = realworkfn(doer, inst, maxnum)
    -- 消耗
    if inst.noconsumenum < inst.noconsumeneednum then
        consumeproperty(doer, num * consume)
    end
end
AddModRPCHandler("kisaki", "magic_chest_work", magicboxwork)
local function magicboxworkbtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxwork(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_work"), inst)
    end
end
-- 回鲜按钮
local function magicboxfresh(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.freshnum < inst.freshneednum then
        doer.components.talker:Say("回鲜功能未解锁!")
        return
    end
    local consume = TUNING.KISAKI_FRESH_CONSUME
    local maxnum = inst.noconsumenum >= inst.noconsumeneednum and 999 or getworkmaxnum(doer, consume);
    maxnum = maxnum == 999 and 999 or math.min(TUNING.KISAKI_FRESH_MAX, maxnum)
    log.debug("本次回鲜可以回鲜数最大值：" .. maxnum)
    if maxnum < 1 then
        doer.components.talker:Say("三维不足，无法回鲜!")
        return
    end
    -- 回鲜
    local num = realfreshfn(doer, inst, maxnum)
    -- 消耗
    if inst.noconsumenum < inst.noconsumeneednum then
        consumeproperty(doer, num * consume)
    end
end
AddModRPCHandler("kisaki", "magic_chest_fresh", magicboxfresh)
local function magicboxfreshbtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxfresh(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_fresh"), inst)
    end
end
-- 回耐按钮
local function magicboxdurability(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.durabilitynum < inst.durabilityneednum then
        doer.components.talker:Say("回耐功能未解锁!")
        return
    end
    local consume = TUNING.KISAKI_DURABILITY_CONSUME
    local maxnum = inst.noconsumenum >= inst.noconsumeneednum and 999 or getworkmaxnum(doer, consume, false);
    maxnum = maxnum == 999 and 999 or math.min(TUNING.KISAKI_DURABILITY_MAX, maxnum)
    log.debug("本次回耐可以回耐数最大值：" .. maxnum)
    if maxnum < 1 then
        doer.components.talker:Say("魔力不足，无法回耐!")
        return
    end
    -- 回耐久
    local num = realdurabilityfn(doer, inst, maxnum)
    -- 消耗
    if inst.noconsumenum < inst.noconsumeneednum then
        consumeproperty(doer, num * consume)
    end
end
AddModRPCHandler("kisaki", "magic_chest_durability", magicboxdurability)
local function magicboxdurabilitybtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxdurability(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_durability"), inst)
    end
end
-- 消耐按钮
local function magicboxconsumedurability(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.consumedurabilitynum < inst.consumedurabilityneednum then
        doer.components.talker:Say("消耐功能未解锁!")
        return
    end
    local consume = TUNING.KISAKI_CONSUMEDURABILITY_CONSUME
    local maxnum = inst.noconsumenum >= inst.noconsumeneednum and 999 or getworkmaxnum(doer, consume, false);
    maxnum = maxnum == 999 and 999 or math.min(TUNING.KISAKI_CONSUMEDURABILITY_MAX, maxnum)
    log.debug("本次消耐可以消耐数最大值：" .. maxnum)
    if maxnum < 1 then
        doer.components.talker:Say("魔力不足，无法消耐!")
        return
    end
    -- 回耐久
    local num = realconsumedurabilityfn(doer, inst, maxnum)
    -- 消耗
    if inst.noconsumenum < inst.noconsumeneednum then
        consumeproperty(doer, num * consume)
    end
end
AddModRPCHandler("kisaki", "magic_chest_consumedurability", magicboxconsumedurability)
local function magicboxconsumedurabilitybtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxconsumedurability(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_consumedurability"), inst)
    end
end
-- 魔火按钮
local function magicboxfire(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.firenum < inst.fireneednum then
        doer.components.talker:Say("魔火功能未解锁!")
        return
    end
    realfirefn(doer, inst)
end
AddModRPCHandler("kisaki", "magic_chest_fire", magicboxfire)
local function magicboxfirebtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxfire(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_fire"), inst)
    end
end
-- 腐烂按钮
local function magicboxdecay(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.decaynum < inst.decayneednum then
        doer.components.talker:Say("腐烂功能未解锁!")
        return
    end
    local consume = TUNING.KISAKI_DECAY_CONSUME
    local maxnum = inst.noconsumenum >= inst.noconsumeneednum and 999 or getworkmaxnum(doer, consume);
    maxnum = maxnum == 999 and 999 or math.min(TUNING.KISAKI_DECAY_MAX, maxnum)
    log.debug("本次腐烂可以腐烂数最大值：" .. maxnum)
    if maxnum < 1 then
        doer.components.talker:Say("三维不足，无法腐烂!")
        return
    end
    -- 腐烂
    local num = realdecayfn(doer, inst, maxnum)
    -- 消耗
    if inst.noconsumenum < inst.noconsumeneednum then
        consumeproperty(doer, num * consume)
    end
end
AddModRPCHandler("kisaki", "magic_chest_decay", magicboxdecay)
local function magicboxdecaybtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxdecay(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_decay"), inst)
    end
end
-- 提取按钮
local function magicboxextract(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    local consume = TUNING.KISAKI_EXTRACT_CONSUME
    local maxnum = inst.noconsumenum >= inst.noconsumeneednum and MAXUINT
        or (inst.extractnum < inst.extractneednum and 0 or getworkmaxnum(doer, consume, false));
    log.debug("本次提取可以提取数最大值：" .. maxnum)
    if maxnum == 0 then
        doer.components.talker:Say("无魔法值或提取功能未解锁，当前功能为垃圾桶!")
    else
        doer.components.talker:Say("开始提取以太！")
    end
    -- 提取
    local num = realextractfn(doer, inst, maxnum)
    -- 消耗
    if inst.noconsumenum < inst.noconsumeneednum then
        consumeproperty(doer, num * consume)
    end
end
AddModRPCHandler("kisaki", "magic_chest_extract", magicboxextract)
local function magicboxextractbtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxextract(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_extract"), inst)
    end
end
-- 拆解按钮
local function magicboxdisassembly(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.disassemblynum < inst.disassemblyneednum then
        doer.components.talker:Say("批量拆解功能未解锁!")
        return
    end
    local consume = TUNING.KISAKI_DISASSEMBLY_CONSUME
    local maxnum = inst.noconsumenum >= inst.noconsumeneednum and MAXUINT or getworkmaxnum(doer, consume, false);
    maxnum = maxnum == MAXUINT and MAXUINT or math.min(TUNING.KISAKI_DISASSEMBLY_MAX, maxnum)
    log.debug("本次拆解可以拆解数最大值：" .. maxnum)
    if maxnum < 1 then
        doer.components.talker:Say("魔力不足，无法拆解!")
        return
    end
    -- 拆解
    local num = realdisassemblyfn(doer, inst, maxnum)
    -- 消耗
    if inst.noconsumenum < inst.noconsumeneednum then
        consumeproperty(doer, num * consume)
    end
end
AddModRPCHandler("kisaki", "magic_chest_disassembly", magicboxdisassembly)
local function magicboxdisassemblybtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxdisassembly(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_disassembly"), inst)
    end
end
-- 猪王交易按钮
local function magicboxpigtrade(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.pigtradenum < inst.pigtradeneednum then
        doer.components.talker:Say("猪王交易功能未解锁！")
        return
    end
    realpigtradefn(doer, inst)
end
AddModRPCHandler("kisaki", "magic_chest_pigtrade", magicboxpigtrade)
local function magicboxpigtradebtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxpigtrade(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_pigtrade"), inst)
    end
end
-- 鸟笼交易按钮
local function magicboxbirdtrade(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.birdtradenum < inst.birdtradeneednum then
        doer.components.talker:Say("鸟笼交易功能未解锁！")
        return
    end
    realbirdtradefn(doer, inst)
end
AddModRPCHandler("kisaki", "magic_chest_birdtrade", magicboxbirdtrade)
local function magicboxbirdtradebtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxbirdtrade(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_birdtrade"), inst)
    end
end
-- 鱼人王交易按钮
local function magicboxfishtrade(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.fishtradenum < inst.fishtradeneednum then
        doer.components.talker:Say("鱼人王交易功能未解锁！")
        return
    end
    realfishtradefn(doer, inst)
end
AddModRPCHandler("kisaki", "magic_chest_fishtrade", magicboxfishtrade)
local function magicboxfishtradebtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxfishtrade(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_fishtrade"), inst)
    end
end
-- 蚁狮交易按钮
local function magicboxantliontrade(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.antliontradenum < inst.antliontradeneednum then
        doer.components.talker:Say("蚁狮交易功能未解锁！")
        return
    end
    realantliontradefn(doer, inst)
end
AddModRPCHandler("kisaki", "magic_chest_antliontrade", magicboxantliontrade)
local function magicboxantliontradebtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxantliontrade(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_antliontrade"), inst)
    end
end
-- 擦纸按钮
local function magicboxmappingtrade(doer, inst)
    if inst == nil or inst.components.container == nil or inst.components.container.readonlycontainer then
        return
    end
    if inst.mappingtradenum < inst.mappingtradeneednum then
        doer.components.talker:Say("制图桌交易功能未解锁！")
        return
    end
    realmappingtradefn(doer, inst)
end
AddModRPCHandler("kisaki", "magic_chest_mappingtrade", magicboxmappingtrade)
local function magicboxmappingtradebtnfn(inst, doer, self)
    if inst.components.container ~= nil then
        magicboxmappingtrade(doer, inst)
    elseif inst.replica.container ~= nil and not inst.kisaki_button_cd then
        inst.kisaki_button_cd = inst:DoTaskInTime(0.5, endbuttonloading)
        SendModRPCToServer(GetModRPC("kisaki", "magic_chest_mappingtrade"), inst)
    end
end

containers_params.kisaki_magic_box.widget.kisaki_button_position_map = {
    collect = {
        position = Vector3(0, -190, 0),
        text = STRINGS.KISAKI_ACTION.COLLECT,
        fn = magicboxcollectbtnfn,
        validfn = containerDefaultValid,
    },
    storage = {
        position = Vector3(75, -190, 0),
        text = STRINGS.KISAKI_ACTION.STORAGE,
        fn = magicboxstoragebtnfn,
        validfn = containerIsNotEmpty,
    },
    tidy = {
        position = Vector3(-75, -190, 0),
        text = STRINGS.KISAKI_ACTION.TIDY,
        fn = magicboxsortbtnfn,
        validfn = containerIsNotEmpty,
    },
    more = {
        position = Vector3(0, 250, 0),
        text = STRINGS.KISAKI_ACTION.MORE,
        fn = magicboxmorebtnfn,
        validfn = containerDefaultValid,
    },
    upgrade = {
        position = Vector3(0, 300, 0),
        text = STRINGS.KISAKI_ACTION.UPGRADE,
        fn = magicboxupgradebtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    collection = {
        position = Vector3(80, 300, 0),
        text = STRINGS.KISAKI_ACTION.COLLECTION,
        fn = magicboxcollectionbtnfn,
        validfn = containerDefaultValid,
        show = false,
    },
    fishing = {
        position = Vector3(-80, 300, 0),
        text = STRINGS.KISAKI_ACTION.FISHING,
        fn = magicboxfishingbtnfn,
        validfn = containerDefaultValid,
        show = false,
    },
    conversion = {
        position = Vector3(160, 300, 0),
        text = STRINGS.KISAKI_ACTION.CONVERSION,
        fn = magicboxconversionbtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    work = {
        position = Vector3(-160, 300, 0),
        text = STRINGS.KISAKI_ACTION.WORK,
        fn = magicboxworkbtnfn,
        validfn = containerDefaultValid,
        show = false,
    },
    consumedurability = {
        position = Vector3(-280, 300, 0),
        text = STRINGS.KISAKI_ACTION.CONSUMEDURABILITY,
        fn = magicboxconsumedurabilitybtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    fresh = {
        position = Vector3(-280, 190, 0),
        text = STRINGS.KISAKI_ACTION.FRESH,
        fn = magicboxfreshbtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    durability = {
        position = Vector3(-280, 110, 0),
        text = STRINGS.KISAKI_ACTION.DURABILITY,
        fn = magicboxdurabilitybtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    fire = {
        position = Vector3(-280, 30, 0),
        text = STRINGS.KISAKI_ACTION.FIRE,
        fn = magicboxfirebtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    decay = {
        position = Vector3(-280, -50, 0),
        text = STRINGS.KISAKI_ACTION.DECAY,
        fn = magicboxdecaybtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    extract = {
        position = Vector3(-280, -130, 0),
        text = STRINGS.KISAKI_ACTION.EXTRACT,
        fn = magicboxextractbtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    disassembly = {
        position = Vector3(280, 300, 0),
        text = STRINGS.KISAKI_ACTION.DISASSEMBLY,
        fn = magicboxdisassemblybtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    pigtrade = {
        position = Vector3(280, 190, 0),
        text = STRINGS.KISAKI_ACTION.PIGTRADE,
        fn = magicboxpigtradebtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    birdtrade = {
        position = Vector3(280, 110, 0),
        text = STRINGS.KISAKI_ACTION.BIRDTRADE,
        fn = magicboxbirdtradebtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    fishtrade = {
        position = Vector3(280, 30, 0),
        text = STRINGS.KISAKI_ACTION.FISHTRADE,
        fn = magicboxfishtradebtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    antliontrade = {
        position = Vector3(280, -50, 0),
        text = STRINGS.KISAKI_ACTION.ANTLIONTRADE,
        fn = magicboxantliontradebtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
    mappingtrade = {
        position = Vector3(280, -130, 0),
        text = STRINGS.KISAKI_ACTION.MAPPINGTRADE,
        fn = magicboxmappingtradebtnfn,
        validfn = containerIsNotEmpty,
        show = false,
    },
}
copyChestUI("kisaki_magic_box", "kisaki_magic_box_chest")


-- 妃的幻想图书馆
containers_params.kisaki_library_box = {
    widget =
    {
        slotpos = {},
        slotbg = {},
        animbank = "ui_bookstation_4x5",
        animbuild = "ui_bookstation_4x5",
        pos = Vector3(0, 280, 0),
        side_align_tip = 160,
        dragkey = "kisaki_library_box" -- 容器UI拖拽的标识key
    },
    type = "kisaki_library_box",
}
for y = 0, 4 do
    for x = 0, 3 do
        table.insert(containers_params.kisaki_library_box.widget.slotpos,
            Vector3(-120 + 80 * x, (-77 * y) + 37 - (y * 2), 0))
    end
end
for i = 1, 20 do
    containers_params.kisaki_library_box.widget.slotbg[i] = {
        atlas = 'images/inventoryimages/widget/kisaki_container_ui.xml',
        image = 'container_ui_books.tex'
    }
end
-- 不能放入特定物品
function containers_params.kisaki_library_box.itemtestfn(container, item, slot)
    return item:HasTag("bookcabinet_item")
end

-- 判断是否优先进入该盒子(模组特有方法定义)
function containers_params.kisaki_library_box.prioritygivefn(container, item)
    return item:HasTag("bookcabinet_item")
end

copyChestUI("kisaki_library_box", "kisaki_library_box_chest")

------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 重新设置下可接受的最大格子数
for k, v in pairs(containers_params) do
    containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end
