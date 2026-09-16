-- 薪火：护符收纳判定。
-- 容器 itemtestfn、右键动作、虚拟装备激活共用这一份规则，保证语义一致：
-- 能放进容器，就能生效（不再额外校验 restrictedtag）。
-- 注意：本文件同时被服务端与客户端调用，服务端实体提供 components，
-- 客户端实体通常只有 replica，两者的 equipslot 读取方式不同。

local AmuletUtil = {}

-- 融合护符代码名
local OUTER_PREFAB = "kisaki_multivariate_amulet"
-- 被融合护符收纳中的物品会带上这个 tag
AmuletUtil.STORED_TAG = "kisaki_multivariate_stored"
-- 是否启用了额外装备栏
local HAS_EXTRA_SLOT = EQUIPSLOTS.NECK ~= nil
-- 无限耐久的护甲会带上这个 tag（原版约定，itemtile 用它隐藏耐久百分比）。
local INDESTRUCTIBLE_TAG = "hide_percentage"

----------------------------------------------------------------------辅助方法--------------------------------------------------------------

-- 取物品的 equippable 组件。
local function GetEquippable(item, use_replica)
    if use_replica then
        return item.replica ~= nil and item.replica.equippable or nil, true
    end

    local equippable = item.components ~= nil and item.components.equippable or nil
    if equippable ~= nil then
        return equippable, false
    end

    -- components 里没有就退回 replica：物品实体存在但组件尚未就绪，
    if item.replica ~= nil and item.replica.equippable ~= nil then
        return item.replica.equippable, true
    end
    return nil
end

-- 是否禁止卸下。第三方 replica 可能没有该方法，做存在性检查。
local function ShouldPreventUnequipping(equippable)
    return equippable.ShouldPreventUnequipping ~= nil
        and equippable:ShouldPreventUnequipping()
        or false
end

-- 或取要装备物品的装备槽位名。服务端读字段，客户端走 EquipSlot()。
local function GetEquipSlot(equippable, from_replica)
    if from_replica then
        if equippable.EquipSlot == nil then
            return nil
        end
        return equippable:EquipSlot()
    end
    return equippable.equipslot
end
-- 判断对象装备的目标栏位是不是护符应该去的栏位
local function IsAllowedSlot(equipslot)
    if HAS_EXTRA_SLOT then
        return equipslot == EQUIPSLOTS.NECK
    end
    return equipslot == EQUIPSLOTS.NECK or equipslot == EQUIPSLOTS.BODY
end

-- 容器内同 prefab 护符所在的槽位；没有同名护符则返回 nil。
local function GetStoredSlot(container, prefab)
    if container == nil or prefab == nil then
        return nil
    end
    -- 数值循环：空槽不会截断后续格子的检查。
    for slot = 1, container:GetNumSlots() do
        local existing = container:GetItemInSlot(slot)
        if existing ~= nil and existing.prefab == prefab then
            return slot
        end
    end
    return nil
end

--------------------------------------------------------------------基础方法-----------------------------------------------------------------

-- 是不是融合护符
function AmuletUtil.IsOuterAmulet(item)
    return item ~= nil and item:HasTag(OUTER_PREFAB)
end

-- 物品是不是在融合护符里面
function AmuletUtil.IsStoredInAmulet(item)
    return item ~= nil and item:HasTag(AmuletUtil.STORED_TAG)
end

-- 从背包中找出已装备的外层护符。
function AmuletUtil.GetEquippedOuter(inventory)
    if inventory == nil then
        return nil
    end
    local outer = inventory:GetEquippedItem(EQUIPSLOTS.NECK)
    if outer == nil and not HAS_EXTRA_SLOT then
        outer = inventory:GetEquippedItem(EQUIPSLOTS.BODY)
    end
    return AmuletUtil.IsOuterAmulet(outer) and outer or nil
end

-- 容器内是否有护符携带指定 tag。
function AmuletUtil.EquippedOuterHasTag(inventory, tag)
    local outer = AmuletUtil.GetEquippedOuter(inventory)
    if outer == nil then
        return false
    end
    local container = (outer.components ~= nil and outer.components.container)
        or (outer.replica ~= nil and outer.replica.container)
        or nil
    if container == nil then
        return false
    end
    -- 数值循环：空槽不会截断后续格子的检查。
    for slot = 1, container:GetNumSlots() do
        local item = container:GetItemInSlot(slot)
        if item ~= nil and item:HasTag(tag) then
            return true
        end
    end
    return false
end

------------------------------------------------------------------护符拦截放入相关-----------------------------------------------------------

-- 基础形态检查：非自身、且是护符。
function AmuletUtil.IsAmuletShape(item)
    if item == nil or item.prefab == OUTER_PREFAB then
        return false
    end
    if item:HasTag("amulet") then
        return true
    end
    return string.find(item.prefab, "amulet$") ~= nil -- 原版护符以amulet结尾
end
-- 容器内是否已存在同 prefab 的护符。
function AmuletUtil.ContainerHasPrefab(container, prefab)
    return GetStoredSlot(container, prefab) ~= nil
end

-- 该物品是否“带 armor 组件的装备”。
function AmuletUtil.HasArmorComponent(item)
    if item == nil then
        return false
    end
    if item:HasTag("armor") then
        return true
    end
    -- 兜底：tag 可能尚未就绪（组件刚建好、tag 还没打），退回组件判断。
    return item.components ~= nil and item.components.armor ~= nil
end

-- 该护甲是否无限耐久。
function AmuletUtil.IsIndestructibleArmor(item)
    if not AmuletUtil.HasArmorComponent(item) then
        return false
    end
    if item:HasTag(INDESTRUCTIBLE_TAG) then
        return true
    end
    local armor = item.components ~= nil and item.components.armor or nil
    return armor ~= nil and armor.IsIndestructible ~= nil and armor:IsIndestructible()
end

-- 判断是否是护符，拒绝“有耐久”的护甲（即使它是护符，无限耐久可收纳）。
function AmuletUtil.IsStorableAmulet(item, use_replica)
    if not AmuletUtil.IsAmuletShape(item) then
        return false
    end
    if AmuletUtil.HasArmorComponent(item) and not AmuletUtil.IsIndestructibleArmor(item) then
        return false
    end
    return AmuletUtil.IsEquippableInAmuletSlot(item, use_replica)
end

-- 装备槽位校验：是不是装备在护符栏、且没被禁止卸下。
function AmuletUtil.IsEquippableInAmuletSlot(item, use_replica)
    local equippable, from_replica = GetEquippable(item, use_replica)
    if equippable == nil then
        return false
    end

    return IsAllowedSlot(GetEquipSlot(equippable, from_replica))
        and not ShouldPreventUnequipping(equippable)
end

------------------------------------------------------------------放入护符逻辑相关-----------------------------------------------------------

-- 该槽位能否放入该护符（拖拽落点判定）
function AmuletUtil.CanStoreInSlot(container, item, slot)
    if container == nil or item == nil or slot == nil then
        return false
    end
    if not AmuletUtil.IsStorableAmulet(item) then
        return false
    end

    local same_slot = GetStoredSlot(container, item.prefab)
    if same_slot ~= nil then
        -- 有同名时锁定到那一格，其它格子一概不接受，避免同名并存。
        return slot == same_slot
    end

    local existing = container:GetItemInSlot(slot)
    -- 空格直接可放；占用格则要求里面是“能卸下的护符”才允许替换出来。
    return existing == nil
        or (AmuletUtil.IsAmuletShape(existing)
            and AmuletUtil.IsEquippableInAmuletSlot(existing))
end

-- 解析右键动作应该落到哪个格子，按优先级依次是：
--   1. 同名护符所在的格子（把它替换下来，避免两件同名并存）
--   2. 最靠前的空格
--   3. 最后一格（满容器且无同名，把它挤出来）
function AmuletUtil.GetStoreTargetSlot(container, item)
    if container == nil or item == nil then
        return nil
    end

    local same_slot = GetStoredSlot(container, item.prefab)
    if same_slot ~= nil then
        return same_slot
    end

    local numslots = container:GetNumSlots()
    if numslots <= 0 then
        return nil
    end
    -- 数值循环：空槽不会截断后续格子的检查。
    for slot = 1, numslots do
        if container:GetItemInSlot(slot) == nil then
            return slot
        end
    end

    -- 满容器且无同名：挤掉最后一格。
    return numslots
end

return AmuletUtil
