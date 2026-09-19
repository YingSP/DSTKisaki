-- 旅：可成长的多形态法杖（武器 + 法术书轮盘切换状态 + 喂食解锁）。
-- 基础形态 kisaki_magic_staff：远程武器（15 点普通伤害 + 10 点位面伤害，攻击距离 10，25% 移速加成），
--   右键物品栏中的法杖打开法术书轮盘切换状态，初始只有"普通"状态可用；
--   拿着对应材料右键法杖给予（trader 组件）可以解锁新状态并强化武器；
--   全部升级满足后自动转换为渡海之诗 kisaki_magic_staff_max
local log = require("utils/kisakilogger")
local staff_spells = require("kisaki_defs/spell_defs")
local name = "kisaki_magic_staff"
local name_max = "kisaki_magic_staff_max"
-- 各状态的施法函数：法术本体在 spell_defs，这里只声明“哪个状态用哪一个”
local SpellIgnite = staff_spells.SpellIgnite
local SpellFreeze = staff_spells.SpellFreeze
local SpellTeleport = staff_spells.SpellTeleport
local SpellDeconstruct = staff_spells.SpellDeconstruct
local SpellBlink = staff_spells.SpellBlink
local SpellStarCall = staff_spells.SpellStarCall
local SpellMoonCall = staff_spells.SpellMoonCall
local SpellMoonFall = staff_spells.SpellMoonFall
local SpellShadowFall = staff_spells.SpellShadowFall

local assets = {
    Asset("ANIM", "anim/" .. name .. ".zip"),
    Asset("ATLAS", "images/inventoryimages/prefabs/" .. name .. ".xml"),
    Asset("IMAGE", "images/inventoryimages/prefabs/" .. name .. ".tex"),
    Asset("ATLAS", "images/inventoryimages/widget/kisaki_magic_staff_icons.xml"),
    Asset("IMAGE", "images/inventoryimages/widget/kisaki_magic_staff_icons.tex"),
}

local prefabs = {
    name,                                 -- 渡海之诗依赖基础形态动画
    "kisaki_magic_staff_light",           -- 装备时的跟随光源
    "cane_candy_fx",                      -- 装备时的雪花粒子（原版懒人魔杖"拐杖糖"皮肤的持有特效）
    "kisaki_brilliance_projectile",       -- 普通攻击弹（我们的辉光弹变种，弹射次数由弹体自身按法杖升级状态决定）
    "cutgrass",                           -- 点燃状态给营火补充的燃料
    "stafflight",                         -- 唤星
    "staffcoldlight",                     -- 唤月
    "sand_puff_large_front",              -- 瞬移特效
    "sand_puff_large_back",
    "brilliance_projectile_blast_fx",     -- 普通攻击弹命中特效
    "slingshotammo_horrorfuel_debuff_fx", -- 影默升级的恐惧效果（原版纯粹恐惧弹阴影之手）
    "winona_catapult_projectile",         -- 月陨/影默召唤的元素袭击
    "fx_book_light",                      -- 进化为渡海之诗的特效
    "reticule",                           -- 施法瞄准圈（普通指针）
    "reticuleaoe",                        -- AOE 落点圈的美术来源
}

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 状态与各项数值定义
-------------------------------------------------------------------------------------------------------------------------------------------------

-- 各状态的配置。写成数组：数组顺序本身就是状态顺序（轮盘条目、状态标签、
-- 数值累加都按此顺序），表项的 key 字段供按名查找，无需再单独维护一份顺序表。
--   施法相关：spell=该状态右键施放的法术（本体见 kisaki_defs/spell_defs.lua），
--     target=可右键目标施放，point=可右键地面施放，recipes=仅限有配方的目标，
--     locomotorspvp=仅限可移动单位（含自己），range=施法距离，
--     sanity=成功后消耗的 SAN，water=允许施放在海面
--   解锁相关：unlock_item/count 解锁所需材料与数量（喂食法杖解锁）
--   武器数值：damage/planardamage —— normal 写基础值，其余状态写"解锁后追加的增量"；
--     align = { tag, bonus } 为阵营克制（被克制的阵营 tag 与伤害倍率）。
--   移速：walkspeedmult 同样由 normal 写基础值，其余状态写增量（累加后作为装备倍率）。
--     刷新时按本表顺序遍历，已解锁的状态把自己的增量累加上去（见 RefreshWeaponStats）。
local MODES = {
    -- 普通：武器基础数值（15 普通伤害 + 10 位面伤害）与基础移速加成（10%）
    {
        key = "normal",
        damage = 15,
        planardamage = 10,
        walkspeedmult = 0.1,
    },
    -- 点燃
    {
        key = "ignite",
        spell = SpellIgnite,
        unlock_item = "redgem",
        count = 3,
        target = true,
    },
    -- 冰冻
    {
        key = "freeze",
        spell = SpellFreeze,
        unlock_item = "bluegem",
        count = 3,
        target = true,
    },
    -- 传送
    {
        key = "teleport",
        spell = SpellTeleport,
        unlock_item = "purplegem",
        count = 3,
        target = true,
        locomotorspvp = true,
        sanity = TUNING.SANITY_HUGE,
    },
    -- 拆解
    {
        key = "deconstruct",
        spell = SpellDeconstruct,
        unlock_item = "greengem",
        count = 3,
        target = true,
        recipes = true,
        range = 10,
        sanity = TUNING.SANITY_MEDLARGE,
    },
    -- 瞬移：橙宝石，移速从基础 10% 提到 25%
    {
        key = "blink",
        spell = SpellBlink,
        unlock_item = "orangegem",
        count = 3,
        point = true,
        water = true,
        walkspeedmult = 0.15,
    },
    -- 唤星
    {
        key = "starcall",
        spell = SpellStarCall,
        unlock_item = "yellowgem",
        count = 3,
        point = true,
        water = true,
        sanity = TUNING.SANITY_MEDLARGE,
    },
    -- 唤月：彩虹宝石，+20 普通伤害 / +5 位面伤害
    {
        key = "mooncall",
        spell = SpellMoonCall,
        unlock_item = "opalpreciousgem",
        count = 3,
        point = true,
        water = true,
        sanity = TUNING.SANITY_MEDLARGE,
        damage = 20,
        planardamage = 5,
    },
    -- 月陨：纯粹辉煌，+10 位面伤害，并克制暗影阵营
    {
        key = "moonfall",
        spell = SpellMoonFall,
        unlock_item = "purebrilliance",
        count = 25,
        point = true,
        target = true,
        planardamage = 10,
        align = { tag = "shadow_aligned", bonus = 1.25 },
    },
    -- 影默：纯粹恐惧，+10 位面伤害，并克制月亮阵营
    {
        key = "shadowfall",
        spell = SpellShadowFall,
        unlock_item = "horrorfuel",
        count = 25,
        point = true,
        target = true,
        planardamage = 10,
        align = { tag = "lunar_aligned", bonus = 1.25 },
    },
}

-- 按名查找表与升级清单：都在模块加载时从 MODES 派生一次，运行时只做查表/遍历，无额外开销。
local MODE_BY_KEY = {}
local UPGRADES = {}
local UPGRADE_BY_ITEM = {}
for _, def in ipairs(MODES) do
    MODE_BY_KEY[def.key] = def
    if def.unlock_item ~= nil then
        local upgrade = {
            key = def.key,
            item = def.unlock_item,
            count = def.count,
        }
        table.insert(UPGRADES, upgrade)
        UPGRADE_BY_ITEM[upgrade.item] = upgrade
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 武器的一些基础小功能
-------------------------------------------------------------------------------------------------------------------------------------------------

-- 读取文本表
local function Text(key)
    return STRINGS.KISAKI_MAGIC_STAFF ~= nil and STRINGS.KISAKI_MAGIC_STAFF[key] or nil
end

-- 状态是否已解锁（解锁状态用 tag 表示，服务端设置后自动同步客户端）
local function IsModeUnlocked(inst, mode)
    return mode == "normal" or inst.is_max or inst:HasTag("kisaki_staff_unlock_" .. mode)
end

-- 让持有者说话
local function StaffSay(inst, msg)
    local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem:GetGrandOwner() or nil
    if owner ~= nil and owner.components.talker ~= nil then
        owner.components.talker:Say(msg)
    end
end

-- 右键动作文本跟随当前状态（"点燃"/"扑灭"/...）：
local old_castspell_strfn = ACTIONS.CASTSPELL.strfn
ACTIONS.CASTSPELL.strfn = function(act)
    if act ~= nil and act.invobject ~= nil and act.invobject:HasTag("kisaki_magic_staff") then
        for _, def in ipairs(MODES) do
            if act.invobject:HasTag("kisaki_staff_mode_" .. def.key) then
                return "KISAKI_" .. string.upper(def.key)
            end
        end
        return nil
    end
    return old_castspell_strfn ~= nil and old_castspell_strfn(act) or nil
end

-- 施法统一入口
local function SpellDispatch(inst, target, pos, doer, spell, def)
    if def == nil or spell == nil or doer == nil then
        return false
    end

    -- 施法距离校验（目标或落点与施法者的距离）
    if def.range ~= nil then
        local cast_pos = target ~= nil and target:GetPosition() or pos
        if cast_pos ~= nil and doer:GetDistanceSqToPoint(cast_pos) > def.range * def.range then
            if doer.components.talker ~= nil then
                doer.components.talker:Say(Text("TOO_FAR"))
            end
            return false
        end
    end

    local succ = spell(inst, target, pos, doer)
    -- 传送/拆解/唤星/唤月继承原版法杖的 SAN 消耗，点燃/冻结/瞬移/袭击不消耗
    if succ and def.sanity ~= nil and doer.components.sanity ~= nil then
        doer.components.sanity:DoDelta(-def.sanity)
    end
    return succ
end
-- 切换法杖状态；quiet 为 true 时不说话（读档、进化继承时使用）
local function SetMode(inst, mode, quiet)
    local def = MODE_BY_KEY[mode]
    if def == nil then
        return false
    end

    -- 未解锁的状态切换失败
    if not IsModeUnlocked(inst, mode) then
        if not quiet then
            StaffSay(inst, Text("MODE_LOCKED"):format(STRINGS.KISAKI_MAGIC_STAFF.MODES[mode]))
        end
        return false
    end

    inst.staff_mode = mode

    -- 状态标签：供 CASTSPELL 的 strfn 在客户端读取，生成"点燃/扑灭/..."右键动作文本
    for _, m in ipairs(MODES) do
        if m.key == mode then
            inst:AddTag("kisaki_staff_mode_" .. m.key)
        else
            inst:RemoveTag("kisaki_staff_mode_" .. m.key)
        end
    end

    -- 清除旧状态的施法配置，再按新模式重建（"普通"状态没有任何施法行为）
    local spellcaster = inst.components.spellcaster
    spellcaster.canuseontargets = false
    spellcaster.canuseonpoint = false
    spellcaster.canonlyuseonrecipes = false
    spellcaster.canonlyuseonlocomotorspvp = false
    spellcaster.canusefrominventory = false
    spellcaster.canuseonpoint_water = false
    if mode ~= "normal" then
        local spell = def.spell
        spellcaster:SetSpellFn(function(spell_inst, target, pos, doer)
            return SpellDispatch(spell_inst, target, pos, doer, spell, def)
        end)
        spellcaster.canuseontargets = def.target == true
        spellcaster.canuseonpoint = def.point == true
        spellcaster.canonlyuseonrecipes = def.recipes == true
        spellcaster.canonlyuseonlocomotorspvp = def.locomotorspvp == true
        spellcaster.canuseonpoint_water = def.water == true
    else
        spellcaster:SetSpellFn(nil)
    end

    -- 瞄准圈：月陨/影默用 AOE 落点圈(2)，唤星/唤月用普通指针圈(1)，
    -- 其余状态（含瞬移）都是 0 —— 不显示鼠标指针处的圆圈
    local reticle_type = 0
    if mode == "moonfall" or mode == "shadowfall" then
        reticle_type = 2
    elseif mode == "starcall" or mode == "mooncall" then
        reticle_type = 1
    end
    inst.reticle_type:set(reticle_type)
    log.debug(string.format("杖圈调试: SetMode %s reticle_type=%d ismaster=%s", tostring(mode), reticle_type,
        tostring(TheWorld.ismastersim)))

    -- 物品名跟随当前状态，例如"旅·点燃"
    local modelabel = STRINGS.KISAKI_MAGIC_STAFF.MODES[mode]
    inst.components.named:SetName(inst._baselabel .. (mode ~= "normal" and ("·" .. modelabel) or ""))

    if not quiet then
        StaffSay(inst, Text("SWITCH_TO"):format(modelabel))
    end
    return true
end

-- 根据解锁进度刷新武器数值。
local function RefreshWeaponStats(inst)
    local weapon = inst.components.weapon
    local planardamage = inst.components.planardamage
    local damagetypebonus = inst.components.damagetypebonus
    local equippable = inst.components.equippable
    if weapon == nil or planardamage == nil then
        return
    end

    local damage = 0
    local planar = 0
    local speedbonus = 0
    -- 当前生效与当前应移除的阵营克制：mode -> def.align
    local align_active = {}
    local align_inactive = {}

    -- 按 MODES 顺序遍历：normal 恒为已解锁，所以基础值一定计入。
    for _, def in ipairs(MODES) do
        if IsModeUnlocked(inst, def.key) then
            damage = damage + (def.damage or 0)
            planar = planar + (def.planardamage or 0)
            speedbonus = speedbonus + (def.walkspeedmult or 0)
            if def.align ~= nil then
                align_active[def.key] = def.align
            end
        elseif def.align ~= nil then
            -- 未解锁（含被回退的情况）时确保摘掉旧倍率
            align_inactive[def.key] = def.align
        end
    end

    weapon:SetDamage(damage)
    planardamage:SetBaseDamage(planar)

    if equippable ~= nil then
        equippable.walkspeedmult = math.floor((1 + speedbonus) * 100 + 0.5) / 100
    end

    -- 阵营克制：已解锁的登记倍率，未解锁的摘除，反复刷新不会叠加也不会残留
    if damagetypebonus ~= nil then
        for mode, align in pairs(align_active) do
            damagetypebonus:AddBonus(align.tag, inst, align.bonus, "kisaki_staff_align" .. "_" .. mode)
        end
        for mode, align in pairs(align_inactive) do
            damagetypebonus:RemoveBonus(align.tag, inst, "kisaki_staff_align" .. "_" .. mode)
        end
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 右键点地施法的瞄准圈
-------------------------------------------------------------------------------------------------------------------------------------------------

-- 按瞄准圈类型换贴图
local function ApplyReticlePrefab(inst)
    local reticule = inst.components.reticule
    if reticule == nil then
        return
    end
    local prefab = inst.reticle_type:value() == 2 and "reticuleaoekisaki_2d5" or "reticule"
    log.debug(string.format("杖圈调试: ApplyReticlePrefab type=%d 新prefab=%s 当前=%s", inst.reticle_type:value(), prefab,
        tostring(reticule.reticuleprefab)))
    if reticule.reticuleprefab == prefab then
        return
    end
    reticule.reticuleprefab = prefab
    local playercontroller = ThePlayer ~= nil and ThePlayer.components.playercontroller or nil
    if playercontroller ~= nil and playercontroller.reticule == reticule then
        playercontroller:RefreshReticule(inst)
        log.debug("杖圈调试: ApplyReticlePrefab 已重建圈")
    end
end

-- 右键瞄准圈落点：从角色朝向由远及近找第一个合法地面点（上限为 CASTSPELL 施法距离）
local function ReticuleTargetFn(inst)
    local player = ThePlayer
    if player == nil then
        return Vector3(0, 0, 0)
    end
    local ground = TheWorld.Map
    local pos = Vector3()
    for r = ACTIONS.CASTSPELL.distance, 0.25, -0.25 do
        pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
        if ground:IsPassableAtPoint(pos.x, 0, pos.z, true) and not ground:IsGroundTargetBlocked(pos) then
            return pos
        end
    end
    return pos
end

-- 右键点地施法的瞄准圈：月陨/影默显示原版投石机齐射的 AOE 落点圈（含攻击范围环），唤星/唤月显示普通指针圈；其余状态隐藏。
local function SetupReticle(inst)
    inst:AddComponent("reticule")
    inst.components.reticule.mouseenabled = true -- 鼠标模式跟随指针
    inst.components.reticule.ease = true
    inst.components.reticule.targetfn = ReticuleTargetFn
    inst.components.reticule.shouldhidefn = function(staff)
        -- 手柄瞄准仍然需要圈，所以只在鼠标操作时按状态隐藏
        return not TheInput:ControllerAttached() and staff.reticle_type:value() == 0
    end
    inst.reticle_type = net_tinybyte(inst.GUID, "kisaki_magic_staff.reticle", "reticletypedirty")
    inst:ListenForEvent("reticletypedirty", function(instance)
        ApplyReticlePrefab(instance)
    end)
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 法术书轮盘：图标参数与条目构建
-------------------------------------------------------------------------------------------------------------------------------------------------

local ICON_ATLAS = "images/inventoryimages/widget/kisaki_magic_staff_icons.xml"
local LOCK_ATLAS = "images/crafting_menu.xml"
local LOCK_TEX = "ingredient_lock.tex"
local scale_factor = 3 / 4                                          -- 缩放轮盘（同时调整半径/判定大小/图标大小）
local WHEEL_RADIUS = (48 + math.max(#MODES, 8) * 12) * scale_factor -- 轮盘半径

-- 按当前解锁状态构建轮盘条目（解锁状态用 tag 同步，客户端重建时也能拿到正确结果）
local function BuildWheelItems(inst)
    local items = {}
    for _, def in ipairs(MODES) do
        local mode = def.key
        local unlocked = IsModeUnlocked(inst, mode)
        local modelabel = STRINGS.KISAKI_MAGIC_STAFF.MODES[mode]
        table.insert(items, {
            mode = mode, -- 供打开轮盘后叠加锁图标时识别状态
            label = unlocked and modelabel or (modelabel .. "（未解锁）"),
            atlas = ICON_ATLAS,
            normal = "kisaki_magic_staff_icons_" .. mode .. ".tex",
            onselect = function()
                if TheWorld.ismastersim then
                    -- 主机直接切换
                    inst.SetMode(inst, mode)
                else
                    -- 客户端通过 RPC 请求服务端切换，服务端会再次校验解锁状态
                    SendModRPCToServer(MOD_RPC["kisaki"]["MagicStaffMode"], mode)
                end
            end,
            execute = function() end,
            widget_scale = 0.82 * scale_factor, -- 图标缩小多少倍
            hit_radius = 60 * scale_factor,     -- 随图标放大同步调大悬停判定半径
        })
    end
    return items
end

-- 给未解锁的轮盘条目调暗并叠加锁图标（打开轮盘时对当前 UI 生效）
local LOCK_SCALE = 0.6 * scale_factor -- 锁大小缩放
local function ApplyLockedItemVisuals(inst, user)
    if user == nil or user.HUD == nil or user.HUD.controls == nil then
        return
    end
    local spellwheel = user.HUD.controls.spellwheel
    if spellwheel == nil then
        return
    end
    for _, item in pairs(spellwheel.items["root"] or {}) do
        if item.mode ~= nil and item.widget ~= nil and not IsModeUnlocked(inst, item.mode) then
            item.widget:SetImageNormalColour(.35, .35, .35, 1)
            item.widget:SetImageFocusColour(.5, .5, .5, 1)
            local lock = item.widget:AddChild(Image(LOCK_ATLAS, LOCK_TEX))
            if lock ~= nil then
                lock:SetScale(LOCK_SCALE, LOCK_SCALE, LOCK_SCALE)
            end
        end
    end
end

-- 法术书轮盘：右键装备栏中的法杖打开。
local function SetupSpellbook(inst)
    inst:AddComponent("spellbook")
    inst.components.spellbook:SetItems(BuildWheelItems(inst))
    inst.components.spellbook:SetRadius(WHEEL_RADIUS)
    inst.components.spellbook:SetFocusRadius(WHEEL_RADIUS + 2)
    inst.components.spellbook.CanBeUsedBy = function(s, doer)
        return doer ~= nil and doer:HasTag("player")
            and s.inst.replica.equippable ~= nil
            and s.inst.replica.equippable:IsEquipped()
    end
    -- 每次打开轮盘前按当前解锁状态重建条目，保证锁定图标显示正确
    local base_OpenSpellBook = inst.components.spellbook.OpenSpellBook
    inst.components.spellbook.OpenSpellBook = function(self, user)
        self:SetItems(BuildWheelItems(inst))
        base_OpenSpellBook(self, user)
        ApplyLockedItemVisuals(inst, user)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 唤星升级：发光逻辑
-------------------------------------------------------------------------------------------------------------------------------------------------

-- 发光参数
local LIGHT_RADIUS, LIGHT_INTENSITY = 6.5, 0.5

-- 黄宝石解锁后：拿在手上（装备）时跟随玩家的光源
local function CreateOwnerLight(inst, owner)
    if owner._kisaki_magic_staff_light ~= nil then
        return
    end
    local light = SpawnPrefab("kisaki_magic_staff_light")
    if light ~= nil then
        owner:AddChild(light)
        light.Transform:SetPosition(0, 0, 0)
        owner._kisaki_magic_staff_light = light
    end
end

-- 移除发光光源
local function RemoveOwnerLight(inst, owner)
    if owner ~= nil and owner._kisaki_magic_staff_light ~= nil then
        owner._kisaki_magic_staff_light:Remove()
        owner._kisaki_magic_staff_light = nil
    end
end

-- 黄宝石解锁后：装备时的跟随光源。
local function UpdateOwnerLight(inst)
    local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem:GetGrandOwner() or nil
    RemoveOwnerLight(inst, owner)
    if owner ~= nil
        and IsModeUnlocked(inst, "starcall")
        and inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() then
        CreateOwnerLight(inst, owner)
    end
end

-- 黄宝石解锁后：放在地上时自身发光。
local function UpdateGroundLight(inst)
    if inst.ground_light_on == nil then
        return
    end
    local held = inst.components.inventoryitem ~= nil and inst.components.inventoryitem:IsHeld()
    inst.ground_light_on:set(not held and IsModeUnlocked(inst, "starcall"))
end

-- 放在地上时的自身光源
local function SetupGroundLight(inst)
    inst.Light:SetIntensity(LIGHT_INTENSITY)
    inst.Light:SetRadius(LIGHT_RADIUS)
    inst.Light:SetFalloff(1)
    inst.Light:SetColour(255 / 255, 200 / 255, 130 / 255)
    inst.Light:Enable(false)
    inst.Light:EnableClientModulation(true)
    inst.ground_light_on = net_bool(inst.GUID, "kisaki_magic_staff.groundlight", "groundlightdirty")
    KisakiStartDayNightLight(inst, function(instance)
        return instance.ground_light_on:value()
    end)
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 影默升级：命中附加原版纯粹恐惧弹（slingshotammo_horrorfuel）的恐惧效果
-------------------------------------------------------------------------------------------------------------------------------------------------

local HORROR_TICKS = TUNING.SLINGSHOT_HORROR_TICKS -- 每层持续秒数（7）
local HORROR_MAX_STACKS = 4                        -- 同一目标最大层数（与原版一致）
local HORROR_VARIATIONS = 6                        -- 阴影之手动画变体数（与原版一致）
local HORROR_PERIOD = 1                            -- 阴影之手出现间隔（与原版一致）

-- 命中闪红（照搬原版 slingshotammo.lua 的同名局部函数）
local function UpdateFlash(target, data, id, r, g, b)
    if data.flashstep < 4 then
        local value = (data.flashstep > 2 and 4 - data.flashstep or data.flashstep) * 0.05
        if target.components.colouradder == nil then
            target:AddComponent("colouradder")
        end
        target.components.colouradder:PushColour(id, value * r, value * g, value * b, 0)
        data.flashstep = data.flashstep + 1
    else
        target.components.colouradder:PopColour(id)
        data.task:Cancel()
    end
end

local function StartFlash(inst, target, r, g, b)
    local data = { flashstep = 1 }
    local id = inst.prefab .. "::" .. tostring(inst.GUID)
    data.task = target:DoPeriodicTask(0, UpdateFlash, nil, data, id, r, g, b)
    UpdateFlash(target, data, id, r, g, b)
end

-- 阴影之手播完动画后回收进池，供后续 tick 复用（原版同款）
local function RecycleHorrorDebuffFX(fx, pool)
    fx:RemoveFromScene()
    table.insert(pool, fx)
end

-- 每次 tick：生成/复用一只阴影之手出手；到期则移除一个 task，全部到期后清空 FX 池
local function OnUpdateHorror(target, attacker, data, endtime, first)
    if not (target.components.health ~= nil and target.components.health:IsDead())
        and target.components.combat ~= nil and target.components.combat:CanBeAttacked() then
        -- 只从"最近没用过"的变体里抽，避免连续两 tick 出现同一只手
        local rnd = math.random(math.clamp(HORROR_VARIATIONS - #data.tasks, 2, HORROR_VARIATIONS / 2))
        local variation = data.variations[rnd]
        for i = rnd, HORROR_VARIATIONS - 1 do
            data.variations[i] = data.variations[i + 1]
        end
        data.variations[HORROR_VARIATIONS] = variation

        local fx
        if #data.pool > 0 then
            fx = table.remove(data.pool)
            fx:ReturnToScene()
        else
            fx = SpawnPrefab("slingshotammo_horrorfuel_debuff_fx")
            fx.pool = data.pool
            fx.onrecyclefn = RecycleHorrorDebuffFX
        end
        fx.entity:SetParent(target.entity)
        fx:Restart(attacker, target, variation, data.pool, first)
    end

    if GetTime() >= endtime then
        table.remove(data.tasks, 1):Cancel()
        if #data.tasks <= 0 then
            for _, v in ipairs(data.pool) do
                v:Remove()
            end
            target._kisaki_staff_horror = nil
        end
    end
end

-- 每次命中叠加一层恐惧（照搬原版 DoHit_HorrorFuel；超出层数上限时踢掉最旧的一层）
local function DoHitHorror(inst, attacker, target)
    if target ~= nil and target:IsValid() then
        StartFlash(inst, target, 1, 0, 0)
        local data = target._kisaki_staff_horror
        if data == nil then
            data = { tasks = {}, variations = {}, pool = {} }
            for i = 1, HORROR_VARIATIONS do
                table.insert(data.variations, math.random(i), i)
            end
            target._kisaki_staff_horror = data
        elseif #data.tasks >= HORROR_MAX_STACKS then
            table.remove(data.tasks, 1):Cancel()
        end

        -- 命中立刻出一只手，之后每 HORROR_PERIOD 秒一只，共 HORROR_TICKS 只
        local endtime = GetTime() + HORROR_PERIOD * (HORROR_TICKS - 1) - 0.001
        table.insert(data.tasks, target:DoPeriodicTask(HORROR_PERIOD, OnUpdateHorror, nil, attacker, data, endtime))
        OnUpdateHorror(target, attacker, data, endtime, true)
    end
end

-- 命中入口
local function ApplyHorror(inst, attacker, target)
    if target and target:IsValid() then
        DoHitHorror(inst, attacker, target)
    end
end

-- 武器命中回调：projectile 武器的 OnAttack 在投射物命中目标时触发
local function OnStaffAttack(inst, attacker, target)
    if inst:HasTag("kisaki_staff_unlock_shadowfall") then
        ApplyHorror(inst, attacker, target)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 升级系统（喂食解锁）
-------------------------------------------------------------------------------------------------------------------------------------------------

-- 判断给予的物品是否可用于升级
local function UpgradeAcceptTest(inst, item)
    local upgrade = item ~= nil and UPGRADE_BY_ITEM[item.prefab] or nil
    return upgrade ~= nil and (inst._upgrade_count[upgrade.key] or 0) < upgrade.count
end

-- 获得升级材料：累计数量、解锁状态、刷新武器数值；喂满全部材料时进化为渡海之诗
local function UpgradeOnAccept(inst, giver, item)
    local upgrade = UPGRADE_BY_ITEM[item.prefab]
    if upgrade == nil or giver == nil then
        return
    end

    local stacksize = item.components.stackable ~= nil and item.components.stackable.stacksize or 1
    local need = math.max(upgrade.count - (inst._upgrade_count[upgrade.key] or 0), 0)
    local applied = math.min(stacksize, need)

    -- 给多了的部分退还给玩家，避免浪费
    if stacksize > applied then
        local excess = SpawnPrefab(item.prefab)
        if excess ~= nil then
            if excess.components.stackable ~= nil then
                excess.components.stackable:SetStackSize(stacksize - applied)
            end
            giver.components.inventory:GiveItem(excess, nil, giver:GetPosition())
        end
    end

    if applied > 0 then
        inst._upgrade_count[upgrade.key] = (inst._upgrade_count[upgrade.key] or 0) + applied
        inst:AddTag("kisaki_staff_unlock_" .. upgrade.key)
        RefreshWeaponStats(inst)
        UpdateGroundLight(inst)
        UpdateOwnerLight(inst)
    end

    local modelabel = STRINGS.KISAKI_MAGIC_STAFF.MODES[upgrade.key]
    if (inst._upgrade_count[upgrade.key] or 0) >= upgrade.count then
        StaffSay(inst, Text("UPGRADE_DONE"):format(modelabel))
    else
        StaffSay(inst, Text("UPGRADE_PROGRESS"):format(modelabel, inst._upgrade_count[upgrade.key], upgrade.count))
    end

    -- 全部升级满足后转换为渡海之诗
    if not inst.is_max then
        local complete = true
        for _, data in ipairs(UPGRADES) do
            if (inst._upgrade_count[data.key] or 0) < data.count then
                complete = false
                break
            end
        end
        if complete then
            local max_staff = SpawnPrefab(name_max)
            if max_staff ~= nil then
                -- 渡海之诗继承全部升级效果与当前状态（继承状态时不播报台词）
                max_staff.SetMode(max_staff, inst.staff_mode or "normal", true)
                giver.components.inventory:GiveItem(max_staff, nil, giver:GetPosition())
                local x, y, z = giver.Transform:GetWorldPosition()
                local fx = SpawnPrefab("fx_book_light")
                if fx ~= nil then
                    fx.Transform:SetPosition(x, y, z)
                end
                giver.SoundEmitter:PlaySound("dontstarve/wilson/fireball_explo")
                StaffSay(inst, Text("UPGRADE_FULL"))
            end
            inst:Remove()
        end
    end
end

-- 拒绝时提示升级进度或缺少的材料（只有基础形态会挂 trader，渡海之诗不会走到这里）
local function UpgradeOnRefuse(inst, giver, item)
    if giver == nil or giver.components.talker == nil then
        return
    end

    local upgrade = item ~= nil and UPGRADE_BY_ITEM[item.prefab] or nil
    if upgrade ~= nil and (inst._upgrade_count[upgrade.key] or 0) >= upgrade.count then
        -- 材料正确但已经喂满
        giver.components.talker:Say(Text("UPGRADE_DONE"):format(STRINGS.KISAKI_MAGIC_STAFF.MODES[upgrade.key]))
        return
    end

    -- 列出全部还差的材料
    local needs = {}
    for _, data in ipairs(UPGRADES) do
        local have = inst._upgrade_count[data.key] or 0
        if have < data.count then
            local item_name = STRINGS.NAMES[string.upper(data.item)] or data.item
            table.insert(needs, string.format("%s：%s（%d/%d）",
                STRINGS.KISAKI_MAGIC_STAFF.MODES[data.key], item_name, have, data.count))
        end
    end
    giver.components.talker:Say(Text("NEED_MORE"):format(table.concat(needs, "\n")))
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 装备与卸下
-------------------------------------------------------------------------------------------------------------------------------------------------

-- 雪花的持有特效：复用原版懒人魔杖"拐杖糖"皮肤（orangestaff_candycane）用的那套雪花粒子
local SNOW_FX_OFFSET = -200
local function CreateHeldSnowFx(inst, owner)
    if inst._snow_fx ~= nil or owner == nil then
        return
    end
    local fx = SpawnPrefab("cane_candy_fx")
    if fx ~= nil then
        fx.entity:AddFollower()
        fx.entity:SetParent(owner.entity)
        fx.Follower:FollowSymbol(owner.GUID, "swap_object", 0, SNOW_FX_OFFSET, 0)
        inst._snow_fx = fx
    end
end
local function RemoveHeldSnowFx(inst)
    if inst._snow_fx ~= nil then
        inst._snow_fx:Remove()
        inst._snow_fx = nil
    end
end

-- 装备监听
local function OnEquip(inst, owner)
    -- 手持贴图：编译产物为单 build，swap_weapon 符号直接在 kisaki_magic_staff build 内
    owner.AnimState:OverrideSymbol("swap_object", name, "swap_weapon")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    -- 黄宝石解锁后装备时挂上跟随光源（昼夜开关由光源自身处理）
    UpdateOwnerLight(inst)
    -- 装备状态下关闭自身光源（改由跟随玩家的光源发光）
    UpdateGroundLight(inst)
    -- 雪花持有特效
    CreateHeldSnowFx(inst, owner)
end

-- 卸下监听
local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    RemoveOwnerLight(inst, owner)
    RemoveHeldSnowFx(inst)
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 存档与读档
-------------------------------------------------------------------------------------------------------------------------------------------------

local function OnSave(inst, data)
    data.staff_mode = inst.staff_mode
    local counts = {}
    for _, upgrade in ipairs(UPGRADES) do
        counts[upgrade.key] = inst._upgrade_count[upgrade.key] or 0
    end
    data.upgrade_counts = counts
end

local function OnPreLoad(inst, data)
    if type(data) ~= "table" then
        return
    end
    -- 还原升级进度并补回解锁 tag
    if type(data.upgrade_counts) == "table" then
        for _, upgrade in ipairs(UPGRADES) do
            local count = data.upgrade_counts[upgrade.key] or 0
            inst._upgrade_count[upgrade.key] = count
            if count >= upgrade.count then
                inst:AddTag("kisaki_staff_unlock_" .. upgrade.key)
            end
        end
    end
    RefreshWeaponStats(inst)
    SetMode(inst, data.staff_mode or "normal", true)
    -- 读档后延迟一帧刷新"该不该有光"，此时才能知道物品是否被持有/装备
    inst:DoTaskInTime(0, function()
        UpdateGroundLight(inst)
        UpdateOwnerLight(inst)
    end)
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 预制物构建
--------------------------------------------------------------------------------------------------------------------------------------------------

local function MakeStaff(is_max)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()                        -- 管理实体的位置、旋转和缩放
        inst.entity:AddAnimState()                        -- 控制实体的动画
        inst.entity:AddLight()                            -- 黄宝石解锁后放在地上时发光
        inst.entity:AddNetwork()                          -- 网络同步功能
        MakeInventoryPhysics(inst)                        -- 作为可拾取的物品参与物理碰撞
        MakeInventoryFloatable(inst, "med", nil, 0.75)    -- 掉入水中时漂浮
        inst.AnimState:SetBank(name)                      -- 渡海之诗复用基础形态的动画
        inst.AnimState:SetBuild(name)
        inst.AnimState:PlayAnimation("idle")              -- 地面待机动画

        SetupGroundLight(inst)                            -- 法杖发光

        inst:AddTag(name)                                 -- 物品标识
        inst:AddTag("kisaki_spellbook")                   -- 法术书标识：容器 UI 与轮盘共存的判定依据
        if not is_max then
            inst:AddTag("kisakitrader")                   -- 没升满可以右键升级
        end
        inst:AddTag("weapon")                             -- 客户端识别为武器
        inst:AddTag("rangedweapon")                       -- 远程武器
        inst:AddTag("_named")                             -- 允许服务端同步动态物品名称
        inst:AddTag("meteor_protection")                  -- 防止被流星破坏
        inst:AddTag("nosteal")                            -- 不可以被猴子偷走
        inst:AddTag("NORATCHECK")                         -- mod兼容：永不妥协。该道具不算鼠潮分

        inst.is_max = is_max                              -- 客户端构建轮盘时也需要读取该字段
        inst.staff_mode = "normal"                        -- 当前状态
        inst._baselabel = is_max and (STRINGS.NAMES.KISAKI_MAGIC_STAFF_MAX or name_max)
            or (STRINGS.NAMES.KISAKI_MAGIC_STAFF or name) -- 法杖名字

        SetupSpellbook(inst)                              -- 右键打开法术书
        SetupReticle(inst)                                -- 鼠标指针处创建跟随的瞄准圈

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        -- 基础
        inst:AddComponent("inspectable")               -- 可检查
        inst:AddComponent("named")                     -- 动态物品名（跟随状态变化）
        inst:AddComponent("inventoryitem")             -- 可放入背包
        inst.components.inventoryitem.imagename = name -- 渡海之诗复用基础形态的物品图标
        inst.components.inventoryitem.atlasname = "images/inventoryimages/prefabs/" .. name .. ".xml"

        -- 手部武器相关
        inst:AddComponent("equippable") -- 可装备到手部
        inst.components.equippable:SetOnEquip(OnEquip)
        inst.components.equippable:SetOnUnequip(OnUnequip)
        inst:AddComponent("weapon")                                          -- 武器组件
        inst.components.weapon:SetRange(10)                                  -- 攻击距离 10
        inst.components.weapon:SetProjectile("kisaki_brilliance_projectile") -- 远程攻击的射弹
        inst.components.weapon:SetOnAttack(OnStaffAttack)                    -- 命中回调（影默附加恐惧效果）
        inst:AddComponent("planardamage")                                    -- 位面伤害
        inst:AddComponent("damagetypebonus")                                 -- 阵营克制

        -- 右键施法相关
        inst:AddComponent("spellcaster")                                 -- 右键法术施放组件，配置随状态切换而变化
        inst.components.spellcaster:SetCanCastFn(function() return true end)
        inst.components.spellcaster.quickcast = true                     -- 全部状态统一使用快速施法动作
        inst.controller_use_attack_distance = ACTIONS.CASTSPELL.distance -- 施法距离

        -- 升级交易组件：只有基础形态需要
        inst._upgrade_count = {}
        if not is_max then
            inst:AddComponent("trader")

            inst.components.trader:SetAcceptStacks() -- 允许整叠喂食
            inst.components.trader:SetAcceptTest(UpgradeAcceptTest)
            inst.components.trader.onaccept = UpgradeOnAccept
            inst.components.trader.onrefuse = UpgradeOnRefuse
        else
            -- 渡海之诗解锁全部状态
            for _, upgrade in ipairs(UPGRADES) do
                inst._upgrade_count[upgrade.key] = upgrade.count
                inst:AddTag("kisaki_staff_unlock_" .. upgrade.key)
            end
        end

        -- 发光：物品进出背包/装备栏时刷新"该不该有光"
        inst:ListenForEvent("onputininventory", UpdateGroundLight)
        inst:ListenForEvent("ondropped", UpdateGroundLight)
        inst:ListenForEvent("onremove", function()
            local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
            RemoveOwnerLight(inst, owner)
            RemoveHeldSnowFx(inst)
        end)

        inst.SetMode = SetMode
        SetMode(inst, "normal", true) -- 刷新武器模式
        RefreshWeaponStats(inst)      -- 刷新武器数值
        MakeHauntableLaunch(inst)     -- 可作祟

        inst.OnSave = OnSave          -- 保存状态与升级进度
        inst.OnPreLoad = OnPreLoad    -- 读取后还原

        return inst
    end

    return Prefab(is_max and name_max or name, fn, assets, prefabs)
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 附属预制体
-------------------------------------------------------------------------------------------------------------------------------------------------

-- 装备时的跟随光源
local function lightfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.Light:SetIntensity(LIGHT_INTENSITY)
    inst.Light:SetRadius(LIGHT_RADIUS)
    inst.Light:SetFalloff(1)
    inst.Light:SetColour(255 / 255, 200 / 255, 130 / 255)
    inst.Light:Enable(false)

    KisakiStartDayNightLight(inst)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    return inst
end

-- 月陨/影默的 AOE 落点圈
local function reticleaofn()
    local inst = CreateEntity()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("reticuleaoe")
    inst.AnimState:SetBuild("reticuleaoe")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetScale(1, 1)

    return inst
end

return MakeStaff(false),
    MakeStaff(true),
    Prefab("kisaki_magic_staff_light", lightfn),
    Prefab("reticuleaoekisaki_2d5", reticleaofn)
