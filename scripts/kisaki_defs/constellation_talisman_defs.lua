local function AriesOnHitOther(inst, data)
    if data and data.target and data.target:IsValid() then
        data.target:AddDebuff("kisaki_vulnerable_aries", "kisaki_vulnerable_aries")
    end
    if inst and inst.components.sanity and inst.components.health and not inst:HasTag('playerghost') then
        inst.components.health:DoDelta(1, nil, "kisaki_talisman_aries")
        inst.components.sanity:DoDelta(1, nil, "kisaki_talisman_aries")
    end
end

local function GeminiOnCharged(inst)
    local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem:GetGrandOwner() or nil
    if owner and owner.kisaki_gemini_cd then
        owner.kisaki_gemini_cd:Cancel()
        owner.kisaki_gemini_cd = nil
    end
end

local function GeminiEquip(inst, owner)
    if owner == nil or owner.components.petleash == nil then
        return
    end
    -- 增加一个上限
    owner.components.petleash:SetMaxPetsForPrefab("kisaki_shadow_protector_gemini",
        owner.components.petleash:GetMaxPetsForPrefab("kisaki_shadow_protector_gemini") + 1)
    -- 存一下暗影守护者会出现的点位偏移量
    if owner.kisaki_shadow_protector_offset == nil then
        owner.kisaki_shadow_protector_offset = {}
        for i = 1, 6, 1 do
            local angle = math.pi / 3 * i -- 每60°一个点
            owner.kisaki_shadow_protector_offset[i] = Vector3(5 * math.sin(angle), 0, 5 * math.cos(angle))
        end
    end
    -- 攻击时会生成守护者保护主人
    owner:ListenForEvent("onhitother", inst.GeminiOnHitOther)
    -- 带上后至少需要1S后才能触发
    if inst.components.rechargeable:IsCharged() then
        inst.components.rechargeable:Discharge(1)
    end
    -- 佩戴后，如果有随从则删掉随从并重置CD（上下线上下洞穴情况）
    inst:DoTaskInTime(1, function(inst)
        local shadows = owner.components.petleash:GetPetsWithPrefab("kisaki_shadow_protector_gemini")
        if shadows and #shadows > 0 then
            for i, shadow in ipairs(shadows) do
                shadow.sg:GoToState("quickdespawn")
            end
            inst.components.rechargeable:SetPercent(1)
        end
    end)
end

local function GeminiUnEquip(inst, owner)
    if owner == nil or owner.components.petleash == nil then
        return
    end
    -- 删除随从
    local shadows = owner.components.petleash:GetPetsWithPrefab("kisaki_shadow_protector_gemini")
    if shadows and #shadows > 0 then
        for i, shadow in ipairs(shadows) do
            shadow.sg:GoToState("quickdespawn")
        end
    end
    -- 减少一个上限
    owner.components.petleash:SetMaxPetsForPrefab("kisaki_shadow_protector_gemini",
        owner.components.petleash:GetMaxPetsForPrefab("kisaki_shadow_protector_gemini") - 1)
    -- 删除监听
    owner:RemoveEventCallback("onhitother", inst.GeminiOnHitOther)
end

local function GeminiMaster(inst)
    inst.isopen = true                -- 开关控制标识符
    inst:AddComponent("rechargeable") -- CD组件
    -- inst.components.rechargeable:SetOnChargedFn(GeminiOnCharged) -- CD结束
    inst.GeminiOnHitOther = function(owner, data)
        if inst.isopen and owner.kisaki_gemini_cd == nil and inst.components.rechargeable:IsCharged() and data and data.target then
            -- 进入cd
            owner.kisaki_gemini_cd = owner:DoTaskInTime(150, function(owner)
                owner.kisaki_gemini_cd:Cancel()
                owner.kisaki_gemini_cd = nil
            end)
            inst.components.rechargeable:Discharge(150)
            -- 生成守护者
            local shadow = owner.components.petleash:SpawnPetAt(0, 0, 0, "kisaki_shadow_protector_gemini")
            if shadow == nil then
                return
            end
            shadow.components.skinner:CopySkinsFromPlayer(owner)
            shadow.isgeminishadow = true
            -- 设置属性继承人物属性
            local health = owner.components.health.maxhealth
            shadow.components.health:SetMaxHealth(health)
            shadow.components.health:SetMaxDamageTakenPerHit(health / 100)
            local weapon = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) -- 拿到手持武器
            local atk = weapon and weapon.components.weapon
                and weapon.components.weapon.damage or 10                               -- 普通伤害
            local spAtk = weapon and weapon.components.planardamage
                and weapon.components.planardamage.basedamage or 0                      -- 位面伤害
            shadow.components.combat:SetDefaultDamage(atk)
            shadow.components.planardamage:SetBaseDamage(spAtk)
            -- 设置位置
            local offset = owner.kisaki_shadow_protector_offset[math.random(1, 6)]
            shadow.Transform:SetPosition((owner:GetPosition() + (offset or { x = 0, y = 0, z = 0 })):Get())
            -- 监听随从消失
            owner:ListenForEvent("onremove", function() inst:GeminiOnPetLost(owner) end, shadow)
        end
    end
    inst.GeminiOnPetLost = function(self, owner)
        -- CD重置
        local oldPercent = inst.components.rechargeable:GetPercent()
        if not inst.components.rechargeable:IsCharged() then
            local percent = math.max(oldPercent, 0.8)
            inst.components.rechargeable:SetPercent(percent) -- 剩余CD高于30S则调整为30S
        end
        if owner.kisaki_gemini_cd and oldPercent < 0.8 then
            owner.kisaki_gemini_cd:Cancel()
            owner.kisaki_gemini_cd = owner:DoTaskInTime(30, function(owner)
                owner.kisaki_gemini_cd:Cancel()
                owner.kisaki_gemini_cd = nil
            end)
        end
    end
end

local function adaptiveGetInsulation(self)
    local owner = self.inst.components.inventoryitem ~= nil and self.inst.components.inventoryitem:GetGrandOwner() or nil
    local temperature = owner and owner.components.temperature
    local playertemp = temperature and temperature:GetCurrent() or TUNING.STARTING_TEMP
    local overheat = playertemp > TUNING.OVERHEAT_TEMP
    local frozen = playertemp < 0
    local worldtem = TheWorld.state.temperature
    if worldtem < TUNING.STARTING_TEMP then
        self:SetWinter()
        self.insulation = overheat and 0 or 120 or 0
    else
        self:SetSummer()
        self.insulation = frozen and 0 or 120 or 0
    end
    return self.insulation, self:GetType()
end

-- 踏水时只保留地面碰撞：可经过障碍物、角色及巨型生物，同时仍保留地面物理判定。
local function SetCancerWaterWalkPhysics(owner)
    if owner and owner.Physics then
        owner.Physics:ClearCollisionMask()
        owner.Physics:CollidesWith(COLLISION.GROUND)
        owner.Physics:Teleport(owner.Transform:GetWorldPosition())
    end
end

-- 卸下护符后恢复人物默认碰撞层。
local function RestoreCancerPhysics(owner)
    if owner and owner.Physics then
        owner.Physics:ClearCollisionMask()
        owner.Physics:CollidesWith(COLLISION.WORLD)
        owner.Physics:CollidesWith(COLLISION.OBSTACLES)
        owner.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
        owner.Physics:CollidesWith(COLLISION.CHARACTERS)
        owner.Physics:CollidesWith(COLLISION.GIANTS)
        owner.Physics:Teleport(owner.Transform:GetWorldPosition())
    end
end

local function CancerEquip(inst, owner)
    if not (owner and owner:IsValid() and not owner:HasTag("playerghost")) or owner.kisaki_cancer_blocksink then
        return
    end

    -- 保存原始状态，避免卸下巨蟹时错误覆盖其他模组的防溺水效果。
    if owner.components.drownable then
        owner.kisaki_cancer_drownable_enabled = owner.components.drownable.enabled
        owner.components.drownable.enabled = false
    end
    SetCancerWaterWalkPhysics(owner)

    owner.kisaki_cancer_blocksink = inst:DoPeriodicTask(0.6, function()
        if not owner:IsValid() or owner:HasTag("playerghost") then
            return
        end
        if owner.components.drownable then
            owner.components.drownable.enabled = false
            -- 部分动作会重设碰撞层，定时重设以确保踏水期间始终可无视实体碰撞。
            SetCancerWaterWalkPhysics(owner)
            if owner.components.drownable:IsOverWater() and owner.sg and
                (owner.sg:HasStateTag("moving") or owner.sg:HasStateTag("running")) then
                SpawnPrefab("weregoose_splash_less" .. tostring(math.random(2))).entity:SetParent(owner.entity)
            end
        end
    end)
end

local function CancerUnEquip(inst, owner)
    if not owner then
        return
    end
    if owner.kisaki_cancer_blocksink then
        owner.kisaki_cancer_blocksink:Cancel()
        owner.kisaki_cancer_blocksink = nil
    end

    if owner.components.drownable and owner.kisaki_cancer_drownable_enabled ~= nil then
        owner.components.drownable.enabled = owner.kisaki_cancer_drownable_enabled
    end
    if not owner:HasTag("playerghost") then
        RestoreCancerPhysics(owner)
    end
    owner.kisaki_cancer_drownable_enabled = nil
end

local function LibraOnHitOther(inst, data)
    if data and data.target and data.target:IsValid() then
        data.target:AddDebuff("kisaki_vulnerable_libra", "kisaki_vulnerable_libra")
    end
end

local function CapricornOnHitOther(inst, data)
    if data and data.target and data.target:IsValid() then
        local target = data.target
        if target.components.health ~= nil and not target.components.health:IsDead() and
            not target:HasTag("likewateroffducksback") then
            -- 生成个水花特效
            SpawnPrefab("waterballoon_splash").Transform:SetPosition(target.Transform:GetWorldPosition())
            -- inst.components.wateryprotection:SpreadProtection(data.target) -- 原版水球灭火/增加潮湿度逻辑
            -- 如果是物品则直接打湿
            if target.components.inventoryitem ~= nil then
                target.components.inventoryitem:AddMoisture(TUNING.OCEAN_WETNESS)
                return
            end
            -- 增加潮湿度（只有龙蝇和玩家有这个组件）
            if target.components.moisture ~= nil then
                local waterproofness = target.components.moisture:GetWaterproofness()
                target.components.moisture:DoDelta(TUNING.WATERBALLOON_ADD_WETNESS * (1 - waterproofness))
                return
            end
            -- 添加潮湿tag
            if not target:HasTag("wet") then
                target:AddTag("wet")
            end
        end
    end
end

local function StarOnHitOther(inst, data)
    AriesOnHitOther(inst, data)
    LibraOnHitOther(inst, data)
    CapricornOnHitOther(inst, data)
end

local TALISMANS = {
    -- 星灵守护-水瓶
    {
        name = "aquarius",
        tags = { "kisaki_aquarius" }, -- TODO，炼药科技
        walkspeedmult = 1.25,
        shadowlevel = 8,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
        end,
        onunequip = function(inst, owner)
        end,
    },
    -- 星灵守护-双鱼
    {
        name = "pisces",
        -- tags = {},
        -- walkspeedmult = 1,
        -- shadowlevel = 4,
        dapperness = 6 / 60,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
            if owner and owner:HasTag("player") and owner.components and owner.components.sanity then
                if not owner.components.sanity.no_moisture_penalty then
                    owner.kisaki_change_no_moisture_penalty = true
                    owner.components.sanity.no_moisture_penalty = true
                else
                    owner.kisaki_change_no_moisture_penalty = false
                end
            end
        end,
        onunequip = function(inst, owner)
            if owner and owner:HasTag("player") and owner.kisaki_change_no_moisture_penalty and owner.components and owner.components.sanity and not owner:HasTag("plantkin") then
                owner.components.sanity.no_moisture_penalty = false
            end
        end,
    },
    -- 星灵守护-白羊
    {
        name = "aries",
        -- tags = {},
        -- walkspeedmult = 1,
        -- shadowlevel = 4,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
            if owner and owner:HasTag("player") then
                owner:ListenForEvent("onhitother", AriesOnHitOther)
            end
        end,
        onunequip = function(inst, owner)
            if owner and owner:HasTag("player") then
                owner:RemoveEventCallback("onhitother", AriesOnHitOther)
            end
        end,
    },
    -- 星灵守护-金牛
    {
        name = "taurus",
        tags = { "heavyarmor" },
        walkspeedmult = 0.8,
        -- shadowlevel = 4,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
            if owner and owner:HasTag("player") and owner.components.health and owner.components.combat and owner._kisaki_domination ~= nil then
                owner.components.health.kisaki_takedmg_mult:SetModifier(inst, 0.85, "kisaki_vulnerable_taurus")
                owner.components.combat.kisaki_damagetype_mult:SetModifier(inst, 1.25, "kisaki_talisman_taurus")
                owner._kisaki_domination:SetModifier(inst, true, "kisaki_talisman_taurus")
            end
        end,
        onunequip = function(inst, owner)
            if owner and owner:HasTag("player") and owner.components.health and owner.components.combat and owner._kisaki_domination ~= nil then
                owner.components.health.kisaki_takedmg_mult:RemoveModifier(inst, "kisaki_vulnerable_taurus")
                owner.components.combat.kisaki_damagetype_mult:RemoveModifier(inst, "kisaki_talisman_taurus")
                owner._kisaki_domination:RemoveModifier(inst, "kisaki_talisman_taurus")
            end
        end,
    },
    -- 星灵守护-双子
    {
        name = "gemini",
        tags = { "switchable" },
        -- walkspeedmult = 1,
        shadowlevel = 8,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
            GeminiEquip(inst, owner)
        end,
        onunequip = function(inst, owner)
            GeminiUnEquip(inst, owner)
        end,
        master_postinit = function(inst)
            GeminiMaster(inst)
        end
    },
    -- 星灵守护-巨蟹
    {
        name = "cancer",
        tags = {},
        walkspeedmult = 1.25,
        -- shadowlevel = 4,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
            CancerEquip(inst, owner)
        end,
        onunequip = function(inst, owner)
            CancerUnEquip(inst, owner)
        end,
    },
    -- 星灵守护-狮子
    {
        name = "leo",
        tags = { "kisaki_stronger" },
        -- walkspeedmult = 1,
        -- shadowlevel = 4,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
            if owner.components.playervision ~= nil and owner._kisaki_nightvision ~= nil then
                owner.components.playervision:SetCustomCCTable({})
                owner.components.playervision:ForceNightVision(true)
                owner._kisaki_nightvision:set(true)
            end
        end,
        onunequip = function(inst, owner)
            if owner.components.playervision ~= nil and owner._kisaki_nightvision ~= nil then
                owner.components.playervision:ForceNightVision(false)
                owner.components.playervision:SetCustomCCTable(nil)
                owner._kisaki_nightvision:set(false)
            end
        end
    },
    -- 星灵守护-处女
    {
        name = "virgo",
        -- tags = {},
        -- walkspeedmult = 1,
        -- shadowlevel = 8,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
        end,
        onunequip = function(inst, owner)
        end,
        master_postinit = function(inst)
            inst:AddComponent("waterproofer")
            inst.components.waterproofer:SetEffectiveness(1) -- 100%防水
            inst.components.equippable.insulated = true      -- 防雷
            inst:AddComponent("insulator")
            inst.components.insulator:SetInsulation(120)
            inst.components.insulator.GetInsulation = adaptiveGetInsulation
        end
    },
    -- 星灵守护-天秤
    {
        name = "libra",
        -- tags = {},
        -- walkspeedmult = 1,
        -- shadowlevel = 8,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
            if owner and owner.components.combat then
                owner.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 1.1, "kisaki_talisman_libra")
                owner:ListenForEvent("onhitother", LibraOnHitOther)
            end
        end,
        onunequip = function(inst, owner)
            if owner and owner.components.combat then
                owner.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "kisaki_talisman_libra")
                owner:RemoveEventCallback("onhitother", LibraOnHitOther)
            end
        end,
    },
    -- 星灵守护-天蝎
    {
        name = "scorpio",
        tags = { "kisaki_scorpio" },
        -- walkspeedmult = 1,
        shadowlevel = 8,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
        end,
        onunequip = function(inst, owner)
        end,
    },
    -- 星灵守护-射手
    {
        name = "sagittarius",
        -- tags = {},
        -- walkspeedmult = 1,
        -- shadowlevel = 8,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
            if owner and owner:HasTag("player") and owner.kisaki_remote_damagetype_mult then
                owner.kisaki_remote_damagetype_mult:SetModifier(inst, 0.25, "kisaki_talisman_sagittarius")
            end
        end,
        onunequip = function(inst, owner)
            if owner and owner:HasTag("player") and owner.kisaki_remote_damagetype_mult then
                owner.kisaki_remote_damagetype_mult:RemoveModifier(inst, "kisaki_talisman_sagittarius")
            end
        end,
    },
    -- 星灵守护-摩羯
    {
        name = "capricorn",
        -- tags = {},
        -- walkspeedmult = 1,
        -- shadowlevel = 8,
        -- dapperness = 0,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
            owner:ListenForEvent("onhitother", CapricornOnHitOther)
        end,
        onunequip = function(inst, owner)
            owner:RemoveEventCallback("onhitother", CapricornOnHitOther)
        end,
    },
    -- 星灵守护-群星
    {
        name = "star",
        tags = { "kisaki_aquarius", "switchable", "kisaki_stronger", "kisaki_scorpio", "heavyarmor" },
        walkspeedmult = 1.5,
        shadowlevel = 24,
        dapperness = 6 / 60,
        -- restrictedtag = "kisaki",

        onequip = function(inst, owner)
            if owner and owner.components and owner:HasTag("player") then
                -- 免疫潮湿SAN值影响
                if owner.components.sanity and not owner.components.sanity.no_moisture_penalty then
                    owner.kisaki_change_no_moisture_penalty = true
                    owner.components.sanity.no_moisture_penalty = true
                else
                    owner.kisaki_change_no_moisture_penalty = false
                end
                -- 减伤
                if owner.components.health and owner.components.health.kisaki_takedmg_mult then
                    owner.components.health.kisaki_takedmg_mult:SetModifier(inst, 0.85, "kisaki_vulnerable_taurus")
                end
                -- 攻击组件
                if owner.components.combat and owner.components.combat.kisaki_damagetype_mult then
                    owner.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 1.1, "kisaki_talisman_libra")
                    owner.components.combat.kisaki_damagetype_mult:SetModifier(inst, 1.25, "kisaki_talisman_taurus")
                end
                -- 远程攻击
                if owner.kisaki_remote_damagetype_mult then
                    owner.kisaki_remote_damagetype_mult:SetModifier(inst, 0.25, "kisaki_talisman_sagittarius")
                end
                -- 霸体
                if owner._kisaki_domination ~= nil then
                    owner._kisaki_domination:RemoveModifier(inst, "kisaki_talisman_taurus")
                end
                -- 水上行走
                CancerEquip(inst, owner)
                -- 双子
                GeminiEquip(inst, owner)
                -- 夜视
                if owner.components.playervision ~= nil and owner._kisaki_nightvision ~= nil then
                    owner.components.playervision:SetCustomCCTable({})
                    owner.components.playervision:ForceNightVision(true)
                    owner._kisaki_nightvision:set(true)
                end
                -- 攻击监听
                owner:ListenForEvent("onhitother", StarOnHitOther)
            end
        end,
        onunequip = function(inst, owner)
            if owner and owner.components and owner:HasTag("player") then
                -- 免疫潮湿SAN值影响
                if owner.kisaki_change_no_moisture_penalty and owner.components.sanity and not owner:HasTag("plantkin") then
                    owner.components.sanity.no_moisture_penalty = false
                end
                -- 减伤
                if owner.components.health and owner.components.health.kisaki_takedmg_mult then
                    owner.components.health.kisaki_takedmg_mult:RemoveModifier(inst, "kisaki_vulnerable_taurus")
                end
                -- 攻击组件
                if owner.components.combat and owner.components.combat.kisaki_damagetype_mult then
                    owner.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "kisaki_talisman_libra")
                    owner.components.combat.kisaki_damagetype_mult:RemoveModifier(inst, "kisaki_talisman_taurus")
                end
                -- 远程攻击
                if owner.kisaki_remote_damagetype_mult then
                    owner.kisaki_remote_damagetype_mult:RemoveModifier(inst, "kisaki_talisman_sagittarius")
                end
                -- 霸体
                if owner._kisaki_domination ~= nil then
                    owner._kisaki_domination:SetModifier(inst, true, "kisaki_talisman_taurus")
                end
                -- 水上行走
                CancerUnEquip(inst, owner)
                -- 双子
                GeminiUnEquip(inst, owner)
                -- 夜视
                if owner.components.playervision ~= nil and owner._kisaki_nightvision ~= nil then
                    owner.components.playervision:ForceNightVision(false)
                    owner.components.playervision:SetCustomCCTable(nil)
                    owner._kisaki_nightvision:set(false)
                end
                -- 攻击监听
                owner:RemoveEventCallback("onhitother", StarOnHitOther)
            end
        end,
        master_postinit = function(inst)
            -- 防水
            inst:AddComponent("waterproofer")
            inst.components.waterproofer:SetEffectiveness(1) -- 100%防水
            inst.components.equippable.insulated = true      -- 防雷
            -- 保暖/隔热
            inst:AddComponent("insulator")
            inst.components.insulator:SetInsulation(120)
            inst.components.insulator.GetInsulation = adaptiveGetInsulation
            -- 双子
            GeminiMaster(inst)
        end
    },
}

return TALISMANS
