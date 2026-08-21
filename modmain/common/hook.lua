local avatar_name = "kisaki"
local log = require("utils/kisakilogger")
local SourceModifierList = require("util/sourcemodifierlist")
local SpDamageUtil = require("components/spdamageutil")
local ImageButton = require "widgets/imagebutton"
local collect_all_item_scope = TUNING.KISAKI_COLLECT_ALL_ITEM_SCOPE

----------------------------------------------------------------------------组件通信----------------------------------------------------------------------------

AddReplicableComponent("kisaki_magic")       -- 角色魔法值通信
AddReplicableComponent("kisaki_level")       -- 角色等级经验通信
AddReplicableComponent("kisaki_achievement") -- 角色成就信息通信
AddReplicableComponent("kisaki_packer")      -- 打包礼物放置预览通信

----------------------------------------------------------------------------预制物修改--------------------------------------------------------------------------

-- 角色默认可听懂鱼人语言
AddPrefabPostInit("merm", function(inst)
    local oldresolvechatterfn = inst.components.talker and inst.components.talker.resolvechatterfn
    if oldresolvechatterfn ~= nil then
        inst.components.talker.resolvechatterfn = function(inst, strid, strtbl)
            if ThePlayer and ThePlayer:HasTag(avatar_name) then
                local stringtable = STRINGS[strtbl:value()]
                if stringtable then
                    if stringtable[strid:value()] ~= nil then
                        return stringtable[strid:value()][1]
                    end
                end
            end
            return oldresolvechatterfn(inst, strid, strtbl)
        end
    else
        log.error("原版鱼人解读语言的方法丢失，请排查！")
    end
end)

-- 天体英雄加tag，实现免疫启蒙光环
local lunacy_sanityaura_prefabs = {
    "alterguardian_phase1",
    "alterguardian_phase2",
    "alterguardian_phase3",
}
if TheNet:GetIsServer() and TUNING.KISAKI_IMMUNITY_AURA_ENABLE then
    for i, prefabname in ipairs(lunacy_sanityaura_prefabs) do
        AddPrefabPostInit(prefabname, function(inst)
            inst:AddTag("kisaki_alterguardian_phase")
        end)
    end
end

-- 给物品添加交易物品组件
local tarder_prefabs = {
}
for i, prefabname in ipairs(tarder_prefabs) do
    AddPrefabPostInit(prefabname, function(inst)
        if TheWorld.ismastersim and inst.components.tradable == nil then
            inst:AddComponent("tradable") -- 可交易
        end
    end)
end

AddPrefabPostInit("kisaki_space_chest_child", function(inst)
    if TheWorld.ismastersim then
        inst:AddTag("kisaki_container") -- 特殊tag，防毒雾
        inst.components.container:EnableInfiniteStackSize(true)
        inst._chestupgrade_stacksize = true
        if collect_all_item_scope then
            inst:DoTaskInTime(0, function()
                TheWorld.components.kisaki_ents_manager:RegisterChest(inst)
            end)
        end
        inst:AddComponent("preserver") --保鲜
        -- 消耗升级
        for i, data in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
            local action = data.action
            inst[action .. "num"] = 0
            inst[action .. "neednum"] = data.neednum
        end
        for i, data in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
            inst[data.id .. "num"] = 0
        end
        -- 其他方法
        inst.addpreserver = function()
            if inst.freshnum >= inst.freshneednum and inst.preservernum >= inst.preserverneednum then
                if inst.components.preserver:GetPerishRateMultiplier() ~= -1 then
                    inst.components.preserver:SetPerishRateMultiplier(-1)
                end
            else
                inst.components.preserver:SetPerishRateMultiplier(0)
            end
        end
        inst.restorationdurability = function()
            -- 回耐久
            for i, v in pairs(inst.components.container.slots) do
                if i > 160 then
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
        end
        inst.addrestorationdurability = function()
            if inst.durabilitynum >= inst.durabilityneednum and inst.autodurabilitynum >= inst.autodurabilityneednum then
                if inst.restor_ationdurability == nil then
                    inst.restor_ationdurability = inst:DoPeriodicTask(60, function() inst.restorationdurability() end,
                        0.1)
                end
            else
                inst.restor_ationdurability = nil
            end
        end
        inst.libraryBoxRefresh = function()
            local trees = { SCIENCE = 1, MAGIC = 1 }
            local tags = {}
            local tag_set = {}
            local addhermitcrabshop = false
            local addwanderingtradershop = false
            for i, data in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
                local id = data.id
                if data.neednum <= inst[id .. "num"] then
                    for levelname, level in pairs(data.levels) do
                        trees[levelname] = level
                    end
                    -- 加标签
                    if data.tags then
                        for _, tag in ipairs(data.tags) do
                            table.insert(tags, tag)
                            tag_set[tag] = true
                        end
                    end
                    -- 额外制作站
                    if id == "hermitcrabshop" then
                        addhermitcrabshop = true
                    elseif id == "wanderingtradershop" then
                        addwanderingtradershop = true
                    end
                end
            end
            local removed_trees = {}
            for levelname, level in pairs(inst.kisaki_library_trees or {}) do
                if trees[levelname] == nil then
                    removed_trees[levelname] = level
                end
            end
            local removed_tags = {}
            for tag in pairs(inst.kisaki_library_tags or {}) do
                if not tag_set[tag] then
                    table.insert(removed_tags, tag)
                end
            end
            inst.kisaki_library_trees = trees
            inst.kisaki_library_tags = tag_set
            return trees, tags, addhermitcrabshop, addwanderingtradershop, removed_trees, removed_tags
        end
    end
end)

----------------------------------------------------------------------------HUD修改-----------------------------------------------------------------------------

AddClassPostConstruct("screens/playerhud", function(self)
    local ContainerWidget = require("widgets/containerwidget")
    local function OpenKisakiWidget(self, container, side)
        local containerwidget = ContainerWidget(self.owner)
        -- 通过类型获取UI的父节点
        local parent
        if side then
            parent = self.controls.containerroot_side
        else
            local _container = container.replica.container
            local _type = _container and _container.type or nil
            parent =
                (_type == "kisaki_portable_box" and self.controls.inv.hand_inv) or
                self.controls.containerroot
        end

        parent:AddChild(containerwidget)

        containerwidget:MoveToBack()
        containerwidget:Open(container, self.owner)
        self.controls.containers[container] = containerwidget
    end
    -- 打开容器
    local oldOpenContainer = self.OpenContainer
    self.OpenContainer = function(self, container, side, ...)
        if container == nil then
            return
        end
        -- 模组的特殊容器UI走这边逻辑
        if container:HasTag("kisaki_box_special_weight") then
            OpenKisakiWidget(self, container, side)
            return
        end
        oldOpenContainer(self, container, side, ...)
    end
    -- 关闭容器
    local oldCloseContainer = self.CloseContainer
    self.CloseContainer = function(self, container, side, ...)
        if container == nil then
            return
        end
        -- 模组的特殊容器UI走这边逻辑
        if side and container:HasTag("kisaki_box_special_weight") then
            side = false
        end
        oldCloseContainer(self, container, side, ...)
    end
end)

-- 按钮添加
-- #参数1：打开容器的UI
-- #参数2：容器的本体
-- #参数3：打开的玩家
-- #参数4：按钮名称，用于关闭按钮UI
-- #参数5：按钮属性
-- #参数6：按钮在哪个地方，有这个参数，后面两个就不需要了
-- #参数7：按钮在四侧的哪边(没用上)
-- #参数8：按钮在四侧的第几个(没用上)
local function addbutton(self, container, doer, button_name, button_info)
    if button_name == nil or button_info == nil then
        return
    end
    local widget = container.replica.container:GetWidget()
    local isreadonlycontainer = container.replica.container:IsReadOnlyContainer()
    local position = button_info.position
    local dirpos = button_info.dirpos
    local index = button_info.index
    local button = self:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex",
        "button_small_disabled.tex", nil, nil, { 1, 1 }, { 0, 0 }))
    -- 设置位置
    if position then
        button:SetPosition(position)
    elseif dirpos and index and widget.kisaki_button_position_map then
        if widget.kisaki_button_position_map[dirpos] and widget.kisaki_button_position_map[dirpos][index] then
            button:SetPosition(widget.kisaki_button_position_map[dirpos][index])
        else
            button:Kill()
            return
        end
    end
    -- 按钮的参数
    button.image:SetScale(0.77, 1.07, 1.07)
    button.text:SetPosition(2, -2)
    button:SetFont(BUTTONFONT)
    button:SetDisabledFont(BUTTONFONT)
    button:SetTextSize(33)
    button.text:SetVAlign(ANCHOR_MIDDLE)
    button.text:SetColour(0, 0, 0, 1)
    button:SetText(button_info.text)
    -- 按钮方法
    if button_info.fn ~= nil then
        button:SetOnClick(function()
            if doer ~= nil then
                if doer:HasTag("busy") then
                    --Ignore button click when doer is busy
                    return
                elseif doer.components.playercontroller ~= nil then
                    local iscontrolsenabled, ishudblocking = doer.components.playercontroller:IsEnabled()
                    if not (iscontrolsenabled or ishudblocking) then
                        --Ignore button click when controls are disabled
                        --but not just because of the HUD blocking input
                        return
                    end
                end
            end
            button_info.fn(container, doer, self)
        end)
    end
    -- 按钮校验方法
    if button_info.validfn ~= nil then
        if button_info.validfn(container) then
            button:Enable()
        else
            button:Disable()
        end
    end
    if button_info.show ~= nil and not button_info.show then
        button:Hide()
    end
    -- 绑定
    self.kisaki_buttons[button_name] = button
end
AddClassPostConstruct("widgets/containerwidget", function(self)
    self.kisaki_buttons = {}

    local oldOpen = self.Open
    self.Open = function(self, container, doer, ...)
        local result = oldOpen(self, container, doer, ...)
        -- 加容器按钮
        local widget = container.replica.container and container.replica.container:GetWidget()
        if widget and widget.kisaki_button_position_map ~= nil then
            for button_name, button_info in pairs(widget.kisaki_button_position_map) do
                addbutton(self, container, doer, button_name, button_info)
            end
        end
        -- 设置容器UI拖拽(勋章拖拽不开启的情况下)
        if not (TUNING.MEDAL_CONTAINERDRAG_SETTING ~= nil and TUNING.MEDAL_CONTAINERDRAG_SETTING > 1
                and TUNING.MEDAL_CLIENT_DRAG_SWITCH ~= nil and TUNING.MEDAL_CLIENT_DRAG_SWITCH)
            and widget and widget.dragkey then
            local dragname = widget.dragkey
            -- 设置可拖拽功能
            if not self.kisakicandrag then
                KisakiMakeDragableUI(self, self.bgimage, dragname, { drag_offset = 0.6 })
                KisakiMakeDragableUI(self, self.bganim, dragname, { drag_offset = 0.6 })
            end
            -- 设置容器坐标，没拖拽过的获取不到，而且不需要重新设置位置，
            local newpos = KisakiGetDragPos(dragname)
            if newpos ~= nil then
                -- 背包需要特殊处理
                if self.container:HasTag("_equippable") and not self.container.isopended then
                    self.container:DoTaskInTime(0, function()
                        self:SetPosition(newpos)
                    end)
                    self.container.isopended = true
                else
                    self:SetPosition(newpos)
                end
            end
        end
        return result
    end

    local oldClose = self.Close
    self.Close = function(self, ...)
        if self.isopen then
            for name, button in pairs(self.kisaki_buttons) do
                if self.kisaki_buttons[name] ~= nil then
                    self.kisaki_buttons[name]:Kill()
                    self.kisaki_buttons[name] = nil
                end
            end
        end
        return oldClose(self, ...)
    end

    local function realRefreshKisakiButton(inst, self, name)
        if self.isopen then
            local widget = self.container.replica.container:GetWidget()
            if widget and widget.kisaki_button_position_map and widget.kisaki_button_position_map[name]
                and widget.kisaki_button_position_map[name].validfn then
                if widget.kisaki_button_position_map[name].validfn(self.container) then
                    self.kisaki_buttons[name]:Enable()
                else
                    self.kisaki_buttons[name]:Disable()
                end
            end
        end
    end
    local function refreshKisakiButton(self)
        if self.container ~= nil then
            for name, button in pairs(self.kisaki_buttons) do
                if self.kisaki_buttons[name] ~= nil then
                    realRefreshKisakiButton(self.inst, self, name)
                    self.inst:DoTaskInTime(0, function() realRefreshKisakiButton(self.inst, self, name) end)
                end
            end
        end
    end
    local oldOnItemGet = self.OnItemGet
    self.OnItemGet = function(self, data, ...)
        local result = oldOnItemGet(self, data, ...)
        refreshKisakiButton(self)
        return result
    end

    local oldOnItemLose = self.OnItemLose
    self.OnItemLose = function(self, data, ...)
        local result = oldOnItemLose(self, data, ...)
        refreshKisakiButton(self)
        return result
    end
end)

----------------------------------------------------------------------------组件修改-----------------------------------------------------------------------------

-- 修改烹饪组件,让收获锅推送一个事件，用于记录角色经验，实现多倍采集
AddComponentPostInit("stewer", function(Stewer)
    local oldHarvest = Stewer.Harvest
    function Stewer:Harvest(harvester, ...)
        -- 已经制作完且有角色拿时，往该角色推一个事件
        if self.done and harvester ~= nil and self.product and harvester:HasTag("kisaki") then
            harvester:PushEvent("kisaki_cook", { product = self.product, prefab = self.inst.prefab })
        end
        if oldHarvest then
            return oldHarvest(self, harvester)
        else
            log.error("原版收获烹饪锅的方法丢失，请排查！")
        end
    end
end)

-- 修改移速组件，原版大力士不减速是通过强壮组件实现的，不能直接拿来用
AddComponentPostInit("locomotor", function(self)
    local oldGetSpeedMultiplier = self.GetSpeedMultiplier
    -- 客户端和服务端用的方法不一样，而且是local的，有点抽象
    if TheWorld.ismastersim then
        self.GetSpeedMultiplier = function(self)
            local player_inventory = self.inst.components.inventory
            if player_inventory and player_inventory:EquipHasTag("kisaki_stronger")
                and not (self.inst.components.rider ~= nil and self.inst.components.rider:IsRiding()) then
                local mult = self:ExternalSpeedMultiplier()
                if player_inventory.isopen then
                    for k, v in pairs(self.inst.components.inventory.equipslots) do
                        if v.components.equippable ~= nil then
                            local item_speed_mult = v.components.equippable:GetWalkSpeedMult()
                            mult = mult * math.max(item_speed_mult, 1)
                        end
                    end
                end
                return mult * (self:TempGroundSpeedMultiplier() or self.groundspeedmultiplier) * self.throttle
            elseif oldGetSpeedMultiplier then
                return oldGetSpeedMultiplier(self)
            end
        end
    else
        self.GetSpeedMultiplier = function(self)
            local player_inventory = self.inst.replica.inventory
            if player_inventory and player_inventory:EquipHasTag("kisaki_stronger")
                and not (self.inst.replica.rider and self.inst.replica.rider:IsRiding()) then
                local mult = self:ExternalSpeedMultiplier()
                for k, v in pairs(player_inventory:GetEquips()) do
                    local inventoryitem = v.replica.inventoryitem
                    if inventoryitem ~= nil then
                        local item_speed_mult = inventoryitem:GetWalkSpeedMult()
                        mult = mult * math.max(item_speed_mult, 1)
                    end
                end
                return mult * (self:TempGroundSpeedMultiplier() or self.groundspeedmultiplier) * self.throttle
            elseif oldGetSpeedMultiplier then
                return oldGetSpeedMultiplier(self)
            end
        end
    end
end)

-- 修改血量组件，实现可加成所有伤害的易伤
AddComponentPostInit("health", function(Health)
    Health.kisaki_takedmg_mult = SourceModifierList(Health.inst, 1, SourceModifierList.multiply) -- 易伤乘算

    local oldDoDelta = Health.DoDelta
    function Health:DoDelta(amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
        if amount < 0 then
            amount = amount * self.kisaki_takedmg_mult:Get()
        end

        return oldDoDelta(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
    end
end)

-- 修改攻击组件，实现独立攻击加成
-- AddComponentPostInit("combat", function(Combat)
--     Combat.kisaki_damagetype_mult = SourceModifierList(Combat.inst, 1, SourceModifierList.multiply) -- 加伤乘算

--     local oldCalcDamage = Combat.CalcDamage
--     function Combat:CalcDamage(target, weapon, multiplier, ...)
--         local damage, spdamage = oldCalcDamage(self, target, weapon, multiplier, ...)
--         if damage > 0 then
--             damage = damage * self.kisaki_damagetype_mult:Get()
--         end
--         if spdamage ~= nil then
--             spdamage = SpDamageUtil.ApplyMult(spdamage, self.kisaki_damagetype_mult:Get())
--         end
--         return damage, spdamage
--     end
-- end)

-- 修改交易组件,使得可以整组交易
AddComponentPostInit("trader", function(Trader)
    local oldAcceptGift = Trader.AcceptGift
    function Trader:AcceptGift(giver, item, count, ...)
        if self.inst:HasTag("kisakitrader") and item.components.stackable and count == nil then
            if self.inst.cantrader then
                count = self.inst:cantrader(giver, item)
            else
                count = item.components.stackable.stacksize
            end
            if count < 1 then
                count = 1
            end
        end
        return oldAcceptGift(self, giver, item, count, ...)
    end
end)

-- 修改物品栏组件
local kisaki_boxes = {
    "kisaki_portable_box",
    "kisaki_magic_box",
    "kisaki_library_box",
}
AddComponentPostInit("inventory", function(self)
    -- 物品优先进入容器逻辑
    local oldGiveItem = self.GiveItem
    self.GiveItem = function(self, inst, slot, src_pos, ...)
        -- 防止重复入盒标签
        local pre_kisaki_container_name = inst.pre_kisaki_container_name
        inst.pre_kisaki_container_name = nil
        -- 不是可携带实体、或实体已销毁，直接拒绝
        if inst.components.inventoryitem == nil or not inst:IsValid() then
            return
        end
        -- 如果正在装备，先卸下来
        local eslot = self:IsItemEquipped(inst)
        if eslot then
            self:Unequip(eslot)
        end
        -- 新物品标记位
        -- local new_item = inst ~= self.activeitem -- 鼠标指针拿着的物品
        -- if new_item then
        --     for k, v in pairs(self.equipslots) do
        --         if v == inst then
        --             new_item = false
        --             break
        --         end
        --     end
        -- end
        -- 清除物品的旧主人
        if inst.components.inventoryitem.owner and inst.components.inventoryitem.owner ~= self.inst then
            inst.components.inventoryitem:RemoveFromOwner(true)
        end
        -- 调用物品的onpickup监听
        local objectDestroyed = inst.components.inventoryitem:OnPickup(self.inst, src_pos)
        if objectDestroyed then
            return
        end
        -- 上面都是抄的原版校验，下面开始逻辑处理
        -- 原版：可堆叠优先堆叠，新物品则先进入装备栏（equipslots），再进入物品栏，再进入背包（overflow）
        local kisaki_box = nil
        -- 不是鼠标指定放入的物品执行优先进入特定容器逻辑
        if not slot then
            -- 找到优先进入的容器
            for i, boxname in ipairs(kisaki_boxes) do
                if pre_kisaki_container_name ~= boxname then
                    kisaki_box = self:FindItem(function(item)
                        return item.prefab == boxname and item.components.container:IsOpen() and
                            item.components.container.prioritygivefn and item.components.container:prioritygivefn(inst)
                    end)
                    if kisaki_box then
                        break
                    end
                end
            end
        end
        -- 进入盒子
        if kisaki_box and kisaki_box.components.container:GiveItem(inst, nil, src_pos) then
            return true
        end
        local returnvalue = oldGiveItem and oldGiveItem(self, inst, slot, src_pos, ...)
        -- 身上放不下了，尝试放入魔法盒
        if not returnvalue then
            kisaki_box = self:FindItem(function(item)
                return item.prefab == "kisaki_magic_box" and item.components.container:IsOpen() and
                    not item.components.container:IsFull() ~= nil
            end)
            return kisaki_box and kisaki_box.components.container:GiveItem(inst, nil, src_pos)
        end
        return returnvalue
    end
end)

-- 修改容器组件
AddComponentPostInit("container", function(Container)
    -- 放入可堆叠的物品
    local function giveStackableItem(self, slot, item, src_pos)
        local other_item = self.slots[slot]
        if other_item ~= nil and other_item.prefab == item.prefab and other_item.skinname == item.skinname and not other_item.components.stackable:IsFull() then
            -- 堆叠的情况
            if self.inst.components.inventoryitem ~= nil and self.inst.components.inventoryitem.owner ~= nil then
                self.inst.components.inventoryitem.owner:PushEvent("gotnewitem", { item = item, slot = slot })
            end
            item = other_item.components.stackable:Put(item, src_pos)
            return item == nil
        elseif other_item == nil then
            -- 空位放入的情况
            -- 有些容器内不可堆叠，比如钓鱼杆和锅
            -- 当前格子放不下了也会返回
            if (not self.acceptsstacks and item.components.stackable and item.components.stackable:StackSize() > 1)
                or (not self.infinitestacksize and item.components.stackable:IsOverStacked()) then
                other_item = item.components.stackable:Get(self.acceptsstacks and item.kisaki_originalmaxsize or 1)
                other_item.components.stackable:SetIgnoreMaxSize(false)
                other_item.components.stackable.maxsize = item.kisaki_originalmaxsize
                self.slots[slot] = other_item
                other_item.components.inventoryitem:OnPutInInventory(self.inst)
                self.inst:PushEvent("itemget", { slot = slot, item = other_item, src_pos = src_pos, })
                return false -- item不为空
            end
            -- 看看能不能整个放进去
            if self.infinitestacksize or not item.components.stackable:IsOverStacked() then
                if not self.infinitestacksize then
                    item.components.stackable:SetIgnoreMaxSize(false)
                    item.components.stackable.maxsize = item.kisaki_originalmaxsize
                else
                    item.components.stackable:SetIgnoreMaxSize(true)
                end
                self.slots[slot] = item
                item.components.inventoryitem:OnPutInInventory(self.inst)
                self.inst:PushEvent("itemget", { slot = slot, item = item, src_pos = src_pos, })
                return true
            end
        end
        return false
    end

    function Container:KisakiGetItemSlot(item)
        for k, v in pairs(self.slots) do
            if v and item.prefab == v.prefab then
                return k
            end
        end
        return nil
    end

    function Container:KisakiGiveItem(item, slot, src_pos, drop_on_fail)
        if item == nil then
            return false
        elseif item.components.inventoryitem ~= nil and self:CanTakeItemInSlot(item, slot) then
            -- 即使指定位置，也要先放进特殊格子
            slot = self:GetSpecificSlotForItem(item) or slot
            -- 可堆叠物品
            if item.components.stackable ~= nil and self.acceptsstacks then
                -- 指定了点位或者物品会放在固定格子
                if slot ~= nil and slot <= self.numslots then
                    return giveStackableItem(self, slot, item, src_pos)
                end
                -- 正常情况下
                if slot == nil then
                    -- 先堆叠下
                    slot = self:KisakiGetItemSlot(item)
                    if slot and giveStackableItem(self, slot, item, src_pos) then
                        return true
                    end
                    -- 遍历
                    for k = 1, self.numslots do
                        if k ~= slot and giveStackableItem(self, k, item, src_pos) then
                            return true -- 全都放进去了那就退出
                        end
                    end
                    -- 容器内已经放不下了
                    return false
                end
            end
            -- 不可堆叠物
            if item.components.stackable == nil then
                if slot ~= nil and slot <= self.numslots then
                    if self.slots[slot] ~= nil then
                        return false
                    end
                    self.slots[slot] = item
                    item.components.inventoryitem:OnPutInInventory(self.inst)
                    self.inst:PushEvent("itemget", { slot = slot, item = item, src_pos = src_pos, })
                    return true
                end
                if slot == nil then
                    for k = 1, self.numslots do
                        if self.slots[k] == nil then
                            self.slots[k] = item
                            item.components.inventoryitem:OnPutInInventory(self.inst)
                            self.inst:PushEvent("itemget", { slot = k, item = item, src_pos = src_pos, })
                            return true
                        end
                    end
                    return false
                end
            end
        end
        --default to true if nil
        if drop_on_fail ~= false then
            --@V2C NOTE: not supported when using container_proxy
            self:DropOverstackedExcess(item)
            item.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
            if item.components.inventoryitem ~= nil then
                item.components.inventoryitem:OnDropped(true)
            end
        end
        return false
    end

    function Container:KisakiMoveItemAll(slot, container)
        if self.readonlycontainer then
            return
        end
        local item = self:GetItemInSlot(slot)
        if item ~= nil and container ~= nil then
            container = container.components.container or container.components.inventory
            if container ~= nil then
                if container:CanTakeItemInSlot(item) then
                    item.kisaki_originalmaxsize = item.components.stackable
                        and item.components.stackable.originalmaxsize or 1 -- 在取出后这项就为nil了
                    -- 取出物品
                    if item.components.stackable then
                        self.ignoreoverstacked = true
                        item = self:RemoveItemBySlot(slot)
                        self.ignoreoverstacked = false
                    else
                        item = self:RemoveItemBySlot(slot)
                    end
                    -- 将物品丢进去
                    if item ~= nil then
                        item.prevcontainer = nil
                        item.prevslot = nil
                        --Hacks for altering normal inventory:GiveItem() behaviour
                        if container.ignoreoverflow ~= nil and container:GetOverflowContainer() == self then
                            container.ignoreoverflow = true
                        end
                        if not container:KisakiGiveItem(item, nil, nil, false) then
                            -- 放不下了就放回去
                            self:GiveItem(item, slot, nil, true)
                        end
                        --Hacks for altering normal inventory:GiveItem() behaviour
                        if container.ignoreoverflow then
                            container.ignoreoverflow = false
                        end
                    end
                end
            end
        end
    end

    -- 适配特殊格子和普通格子并存的情况
    local oldGetSpecificSlotForItem = Container.GetSpecificSlotForItem
    function Container:GetSpecificSlotForItem(item, ...)
        if self.inst.prefab == "kisaki_space_chest_child" and not self.readonlycontainer then
            local slot = self:prioritygivefn(item)
            if slot == nil then
                local isstackable = item.components.stackable ~= nil
                local prefabname = item.prefab
                local emptyslot = nil
                for i = 161, 240 do
                    local other_item = self.slots[i]
                    if isstackable and other_item and other_item.prefab then -- 堆叠的情况
                        if other_item.prefab == prefabname then
                            return i
                        end
                    elseif emptyslot == nil and other_item == nil then -- 没法堆叠的要找到第一个空位
                        emptyslot = i
                    end
                end
                return emptyslot
            end
            return slot
        end
        return oldGetSpecificSlotForItem(self, item, ...)
    end
end)
AddClassPostConstruct("components/container_replica", function(Container)
    local oldGetSpecificSlotForItem = Container.GetSpecificSlotForItem
    function Container:GetSpecificSlotForItem(item, ...)
        if self.inst.prefab == "kisaki_space_chest_child" and not self.readonlycontainer then
            local slot = self:prioritygivefn(item)
            if slot == nil then
                local isstackable = item.replica.stackable ~= nil
                local prefabname = item.prefab
                local emptyslot = nil
                for i = 161, 240 do
                    local other_item = self:GetItemInSlot(i)
                    if isstackable and other_item and other_item.prefab then -- 堆叠的情况
                        if other_item.prefab == prefabname then
                            return i
                        end
                    elseif emptyslot == nil and other_item == nil then -- 没法堆叠的要找到第一个空位
                        emptyslot = i
                    end
                end
                return emptyslot
            end
            return slot
        end
        return oldGetSpecificSlotForItem(self, item, ...)
    end
end)

-- 将魔法值加入到制作配方中
CHARACTER_INGREDIENT.KISAKI_MAGIC = "kisaki_magic"
-- 判断是否是角色属性的方法
local oldIsCharacterIngredient = _G.IsCharacterIngredient
if oldIsCharacterIngredient then
    _G.IsCharacterIngredient = function(ingredienttype)
        if ingredienttype == "kisaki_magic" then
            return true
        end
        return oldIsCharacterIngredient(ingredienttype)
    end
end
-- 修改服务器制作组件
AddComponentPostInit("builder", function(self)
    if not self.inst:HasTag("kisaki") then
        return -1
    end
    -- 判断是否存在该角色属性可以作为制作配方
    local oldHasCharacterIngredient = self.HasCharacterIngredient
    self.HasCharacterIngredient = function(s, ingredient, ...)
        if ingredient.type == CHARACTER_INGREDIENT.KISAKI_MAGIC then
            if self.inst.components.kisaki_magic ~= nil then
                return (self.freebuildmode and 0) or
                    math.ceil(self.inst.components.kisaki_magic.current) >= ingredient.amount,
                    self.inst.components.kisaki_magic.current
            end
        end
        return oldHasCharacterIngredient(s, ingredient, ...)
    end
    -- 制作时消耗人物属性
    local oldRemoveIngredients = self.RemoveIngredients
    self.RemoveIngredients = function(s, ingredients, recname)
        local recipe = AllRecipes[recname]
        if recipe then
            for _, v in pairs(recipe.character_ingredients) do
                if v.type == CHARACTER_INGREDIENT.KISAKI_MAGIC then
                    local current = math.ceil(self.inst.components.kisaki_magic.current)
                    if current >= v.amount and not self.freebuildmode then
                        self.inst.components.kisaki_magic:DoDelta(-v.amount)
                    end
                end
            end
        end
        return oldRemoveIngredients(s, ingredients, recname)
    end
end)
-- 同步修改客户端制作组件
AddClassPostConstruct("components/builder_replica", function(self)
    if not self.inst:HasTag("kisaki") then
        return -1
    end
    -- 制作解锁
    local oldHasCharacterIngredient = self.HasCharacterIngredient
    self.HasCharacterIngredient = function(s, ingredient, ...)
        if self.inst.replica.kisaki_magic.current ~= nil then
            local current = math.ceil(self.inst.replica.kisaki_magic.current:value())
            return (self.classified.isfreebuildmode:value() and 0) or current >= ingredient.amount, current
        end
        return oldHasCharacterIngredient(self, ingredient, ...)
    end
end)

-- 防毒雾
AddComponentPostInit("perishable", function(self)
    local old_ReducePercent = self.ReducePercent
    function self:ReducePercent(amount, ...)
        if amount > 0 then
            local item = self.inst
            local owner = item.components.inventoryitem ~= nil
                and item.components.inventoryitem.owner
                or nil
            if owner ~= nil and
                owner.components.container ~= nil and
                -- owner.components.container:IsOpen() and
                owner:HasTag("kisaki_container") then
                -- local x, y, z = owner.Transform:GetWorldPosition()
                -- local clouds = TheSim:FindEntities(
                --     x, y, z,
                --     TUNING.TOADSTOOL_SPORECLOUD_RADIUS,
                --     {"sporecloud"}
                -- )
                -- if #clouds > 0 then
                --     return  -- 直接跳过，不执行任何削减
                -- end
                -- 注释了，节省点性能
                return
            end
        end

        return old_ReducePercent(self, amount, ...)
    end
end)

-- 修改魔术箱组件
AddComponentPostInit("container_proxy", function(ContainerProxy)
    if ContainerProxy.inst and not ContainerProxy.inst:HasTag("_container_proxy") then
        ContainerProxy.inst:AddTag("_container_proxy")
    end
end)

-- 修改采集组件
AddComponentPostInit("pickable", function(Pickable)
    local function OnRegen(inst)
        inst.components.pickable:Regen()
    end

    function Pickable:KisakiSpawnProductLoot(picker, container)
        if not (picker ~= nil and container ~= nil and self.product ~= nil or self.use_lootdropper_for_product) then
            return
        end

        local inventory = container.components.inventory or container.components.container

        local pt = self.inst:GetPosition()
        local loot = nil

        if self.droppicked and self.inst.components.lootdropper ~= nil then
            pt.y = pt.y + (self.dropheight or 0)

            if self.use_lootdropper_for_product then
                self.inst.components.lootdropper:DropLoot(pt)
            else
                local num = self.numtoharvest or 1
                for i = 1, num do
                    self.inst.components.lootdropper:SpawnLootPrefab(self.product, pt)
                end
            end
        else
            if self.use_lootdropper_for_product then
                loot = self.inst.components.lootdropper:GenerateLoot()

                for i, prefab in ipairs(loot) do -- Convert prefabs to entities.
                    loot[i] = self.inst.components.lootdropper:SpawnLootPrefab(prefab)
                end

                if #loot > 0 then
                    if inventory then
                        picker:PushEvent("picksomething", { object = self.inst, loot = loot })
                    end

                    for i, item in ipairs(loot) do
                        if inventory and item.components.inventoryitem then
                            inventory:GiveItem(item, nil, pt)
                        else
                            item.Transform:SetPosition(pt:Get())
                        end
                    end
                end
            else
                loot = SpawnPrefab(self.product)

                if loot ~= nil then
                    if loot.components.inventoryitem ~= nil then
                        loot.components.inventoryitem:InheritWorldWetnessAtTarget(self.inst)
                    end

                    if self.numtoharvest > 1 and loot.components.stackable ~= nil then
                        loot.components.stackable:SetStackSize(self.numtoharvest)
                    end

                    if inventory then
                        picker:PushEvent("picksomething", { object = self.inst, loot = loot })
                    end

                    if inventory and loot.components.inventoryitem then
                        inventory:GiveItem(loot, nil, pt)
                    else
                        loot.Transform:SetPosition(pt:Get())
                    end
                end
            end
        end

        return loot
    end

    function Pickable:KisakiPick(picker, container)
        if self.canbepicked and self.caninteractwith then
            if self.transplanted and self.cycles_left ~= nil then
                self.cycles_left = math.max(0, self.cycles_left - 1)
            end

            if self.protected_cycles ~= nil then
                self.protected_cycles = self.protected_cycles - 1
                if self.protected_cycles <= 0 then
                    self.protected_cycles = nil
                    if self.inst.components.witherable ~= nil then
                        self.inst.components.witherable:Enable(true)
                    end
                end
            end

            local loot = self:KisakiSpawnProductLoot(picker, container)

            if self.onpickedfn ~= nil then
                self.onpickedfn(self.inst, picker, loot)
            end

            self.canbepicked = false

            if self.baseregentime ~= nil and not (self.paused or self:IsBarren() or self.inst:HasTag("withered")) then
                self.regentime = SpringGrowthMod(self.getregentimefn ~= nil and self.getregentimefn(self.inst) or
                    self.baseregentime)

                if not self.useexternaltimer then
                    if self.task ~= nil then
                        self.task:Cancel()
                    end

                    self.task = self.inst:DoTaskInTime(self.regentime, OnRegen)
                    self.targettime = GetTime() + self.regentime
                else
                    self.stopregentimer(self.inst)
                    self.startregentimer(self.inst, self.regentime)
                end
            end

            self.inst:PushEvent("picked", { picker = picker, loot = loot, plant = self.inst })

            if self.remove_when_picked then
                self.inst:Remove()
            end

            return true, EntityScript.is_instance(loot) and { loot } or loot
        end
    end
end)

-- 修改收获组件
AddComponentPostInit("harvestable", function(Harvestable)
    function Harvestable:kisakiHarvest(picker, container)
        if self:CanBeHarvested() then
            if self.can_harvest_fn ~= nil then
                local can_harvest, fail_reason = self.can_harvest_fn(self.inst, picker)
                if not can_harvest then
                    return false, fail_reason
                end
            end

            local produce = self.produce
            self.produce = 0

            local pos = self.inst:GetPosition()

            if self.onharvestfn ~= nil then
                self.onharvestfn(self.inst, picker, produce)
            end

            if self.product ~= nil then
                if picker ~= nil and picker.components.inventory ~= nil then
                    picker:PushEvent("harvestsomething", { object = self.inst })
                end

                for i = 1, produce, 1 do
                    local loot = SpawnPrefab(self.product)
                    if loot ~= nil then
                        if loot.components.inventoryitem ~= nil then
                            loot.components.inventoryitem:InheritWorldWetnessAtTarget(self.inst)
                        end
                        if container ~= nil and container.components.container ~= nil then
                            container.components.container:GiveItem(loot, nil, pos)
                        else
                            LaunchAt(loot, self.inst, nil, 1, 1)
                        end
                    end
                end
            end
            self:StartGrowing()
            return true
        end
    end
end)

-- 修改晾肉架组件
-- AddComponentPostInit("dryer", function(Dryer)
--     function Dryer:KisakiHarvest(harvester, container)
--         if not self:IsDone() or harvester == nil or container == nil or container.components.container == nil then
--             return false
--         end

--         local loot = SpawnPrefab(self.product)
--         if loot ~= nil then
--             if loot.components.perishable ~= nil then
--                 loot.components.perishable:SetPercent(self:GetTimeToSpoil() / TUNING.PERISH_PRESERVED)
--                 loot.components.perishable:StartPerishing()
--             end
--             if loot.components.inventoryitem ~= nil and not self.protectedfromrain then
--                 loot.components.inventoryitem:InheritWorldWetnessAtTarget(self.inst)
--             end
--             container.components.container:GiveItem(loot, nil, self.inst:GetPosition())
--         end

--         self.ingredient = nil
--         self.buildfile = nil
--         self.dried_buildfile = nil
--         self.product = nil
--         self.foodtype = nil
--         self.remainingtime = nil
--         self.tasktotime = nil
--         if self.task ~= nil then
--             self.task:Cancel()
--             self.task = nil
--         end
--         StopWatchingRain(self)

--         if self.onharvest ~= nil then
--             self.onharvest(self.inst)
--         end
--         return true
--     end
-- end)

-- 修改老版农田收获组件
AddComponentPostInit("crop", function(Crop)
    function Crop:KisakiHarvest(harvester, container)
        if self.matured or self.inst:HasTag("withered") then
            local product = nil
            if self.grower ~= nil and
                (self.grower.components.burnable ~= nil and self.grower.components.burnable:IsBurning()) or
                (self.inst.components.burnable ~= nil and self.inst.components.burnable:IsBurning()) then
                local temp = SpawnPrefab(self.product_prefab)
                product = SpawnPrefab(temp.components.cookable ~= nil and temp.components.cookable.product or
                    "seeds_cooked")
                temp:Remove()
            else
                product = SpawnPrefab(self.product_prefab)
            end

            if self.onharvest ~= nil then
                self.onharvest(self.inst, product, harvester)
            end

            if product ~= nil then
                if product.components.inventoryitem ~= nil then
                    product.components.inventoryitem:InheritWorldWetnessAtTarget(self.inst)
                end

                if container ~= nil then
                    container.components.container:GiveItem(product, nil, self.inst:GetPosition())
                else
                    -- just drop the thing (happens if you haunt the fully grown crop)
                    product.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
                end
                ProfileStatsAdd("grown_" .. product.prefab)
            end

            self.matured = false
            self.growthpercent = 0
            self.product_prefab = nil

            if self.grower ~= nil and self.grower:IsValid() and self.grower.components.grower ~= nil then
                self.grower.components.grower:RemoveCrop(self.inst)
                self.grower = nil
            else
                self.inst:Remove()
            end

            return true, product
        end
    end
end)

----------------------------------------------------------------------------玩家修改-----------------------------------------------------------------------------
local function KillPet(pet)
    if pet.components.health:IsInvincible() then
        --reschedule
        pet._killtask = pet:DoTaskInTime(.5, KillPet)
    else
        pet.components.health:Kill()
    end
end
local function OnSpawnPet(inst, pet)
    if pet:HasTag("kisaki_shadow_protector") then
        if (inst.components.health:IsDead() or inst:HasTag("playerghost")) and pet._killtask == nil then
            pet._killtask = pet:DoTaskInTime(math.random(), KillPet)
        end
    elseif inst.kisaki_OnSpawnPet ~= nil then
        inst:kisaki_OnSpawnPet(pet)
    end
end
local function OnDespawnPet(inst, pet)
    if pet:HasTag("kisaki_shadow_protector") then
        if not inst.is_snapshot_user_session and pet.sg ~= nil then
            pet.sg:GoToState("quickdespawn")
        else
            pet:Remove()
        end
    elseif inst.kisaki_OnDespawnPet ~= nil then
        inst:kisaki_OnDespawnPet(pet)
    end
end

local function SetOmmateumVision(inst)
    if inst and inst.components.playervision then
        inst.components.playervision:ForceNightVision(inst._kisaki_nightvision:value())
        inst.components.playervision:SetCustomCCTable(inst._kisaki_nightvision:value() and {} or nil)
    end
end

AddPlayerPostInit(function(inst)
    -- 删除生成暗影守护者时的转圈圈特效
    if inst.components.petleash ~= nil then
        inst.kisaki_OnSpawnPet = inst.components.petleash.onspawnfn
        inst.kisaki_OnDespawnPet = inst.components.petleash.ondespawnfn
    else
        inst:AddComponent("petleash")
    end
    inst.components.petleash:SetOnSpawnFn(OnSpawnPet)
    inst.components.petleash:SetOnDespawnFn(OnDespawnPet)
    -- 添加夜视监听
    inst._kisaki_nightvision = net_bool(inst.GUID, "kisaki_nightvision._enabled", "kisaki_nightvision_enableddirty")
    inst:ListenForEvent("kisaki_nightvision_enableddirty", SetOmmateumVision)
    -------------------------------------------------------------------服务器部分修改--------------------------------------------------------------
    if TheWorld.ismastersim then
        -- 霸体
        inst._kisaki_domination = SourceModifierList(inst, false, SourceModifierList.boolean)
        -- 玩家攻击独立增伤
        local kisaki_player_combat = inst.components.combat
        kisaki_player_combat.kisaki_damagetype_mult =
            SourceModifierList(kisaki_player_combat.inst, 1, SourceModifierList.multiply) -- 加伤乘算
        local kisaki_oldCalcDamage = kisaki_player_combat.CalcDamage
        kisaki_player_combat.CalcDamage = function(self, target, weapon, multiplier, ...)
            local damage, spdamage = kisaki_oldCalcDamage(self, target, weapon, multiplier, ...)
            if damage > 0 then
                damage = damage * self.kisaki_damagetype_mult:Get()
            end
            if spdamage ~= nil then
                spdamage = SpDamageUtil.ApplyMult(spdamage, self.kisaki_damagetype_mult:Get())
            end
            return damage, spdamage
        end
        -- 特殊增伤（只增伤普通伤害）
        inst.kisaki_remote_damagetype_mult = SourceModifierList(inst, 0, SourceModifierList.additive) -- 远程武器独立增伤加算
        inst.kisaki_melee_damagetype_mult = SourceModifierList(inst, 0, SourceModifierList.additive)  -- 近战武器独立增伤加算
        local kisaki_oldCustomdamagemultfn = kisaki_player_combat.customdamagemultfn
        kisaki_player_combat.customdamagemultfn = function(player, target, weapon, multiplier, mount, ...)
            local customdamagemult = kisaki_oldCustomdamagemultfn ~= nil and
                kisaki_oldCustomdamagemultfn(player, target, weapon, multiplier, mount, ...) or 1
            if customdamagemult <= 0 or weapon == nil or weapon.components.weapon == nil then
                return customdamagemult
            end
            if weapon.components.weapon.attackrange == nil or weapon.components.weapon.attackrange < 5 then
                return customdamagemult *
                    (player.kisaki_melee_damagetype_mult ~= nil and math.max(1 + player.kisaki_melee_damagetype_mult:Get(), 0) or 1)
            else
                return customdamagemult *
                    (player.kisaki_remote_damagetype_mult ~= nil and math.max(1 + player.kisaki_remote_damagetype_mult:Get(), 0) or 1)
            end
        end
    end
end)

------------------------------------------------------------------------世界组件修改-------------------------------------------------------------------------

-- 世界预制物添加监听，用于实现角色等级等信息保存
local function Onplayerdespawnanddelete(world, data)
    local player = data.player or data
    if player:HasTag("kisaki") then
        local saveinfo = {}
        for k, v in pairs(player.components) do
            if v.OnPlayerSave then
                saveinfo[k] = v:OnPlayerSave()
            end
        end
        log.info("检测到角色消失，将角色数据存储进世界数据，当前玩家为：" .. player.userid)
        TheWorld.components.kisaki_info_save:SetSaveInfo(player.userid, saveinfo)
    end
end
-- 角色数据读取
AddPrefabPostInit("kisaki", function(inst)
    if TheWorld.ismastersim then
        local oldOnKisakiSpawn = inst.OnNewSpawn
        inst.OnNewSpawn = function(player)
            if TheWorld.components.kisaki_info_save and TUNING.KISAKI_DATA_SAVE then
                log.info("检测到玩家出生，从世界数据中读取之前存储的角色数据，当前玩家为：" .. player.userid)
                local saveinfo = TheWorld.components.kisaki_info_save:GetSaveInfo(player.userid)
                if saveinfo then
                    log.debug("从世界组件中拿到了当前玩家的数据")
                    for k, v in pairs(saveinfo) do
                        if player.components[k] and player.components[k].OnPlayerLoad then
                            player.components[k]:OnPlayerLoad(v)
                        end
                    end
                else
                    log.info("当前玩家为首次进入世界，数据设为默认值")
                end
            end
            if oldOnKisakiSpawn then
                return oldOnKisakiSpawn(player)
            end
        end
    end
end)


AddPrefabPostInit("world", function(inst)
    if not TheWorld.ismastersim then
        return
    end
    -- 给服务器世界添加一个组件用于存储信息
    inst:AddComponent("kisaki_info_save")
    if collect_all_item_scope then
        inst:AddComponent("kisaki_ents_manager")
    end
    -- 角色退出世界时存储信息
    inst:ListenForEvent("ms_playerdespawn", Onplayerdespawnanddelete)
    inst:ListenForEvent("ms_playerdespawnandmigrate", Onplayerdespawnanddelete)
    inst:ListenForEvent("ms_playerdespawnanddelete", Onplayerdespawnanddelete)
end)
