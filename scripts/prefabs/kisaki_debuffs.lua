local kisaki_debuffs_def = {
    {
        prefab = "kisaki_vulnerable_aries",
        name = "身体朽败-白羊", --buff名称
        time = 20, --持续时间（s）
        OnAttached = function(inst, target)
            -- Buff被施加时执行方法
            inst.entity:SetParent(target.entity)
            if target and target.components and target.components.health and target.components.health.kisaki_takedmg_mult then
                target.components.health.kisaki_takedmg_mult:SetModifier(target, 1.2, "kisaki_vulnerable_aries")
            end
        end,
        OnDetached = function(inst, target)
            -- Buff被解除时执行方法
            if target and target.components and target.components.health and target.components.health.kisaki_takedmg_mult then
                target.components.health.kisaki_takedmg_mult:RemoveModifier(target, "kisaki_vulnerable_aries")
            end
        end,
        OnExtended = function(inst, target)
            -- Buff被刷新执行方法
            if target and target.components and target.components.health and target.components.health.kisaki_takedmg_mult then
                target.components.health.kisaki_takedmg_mult:SetModifier(target, 1.2, "kisaki_vulnerable_aries")
            end
            inst.components.timer:StopTimer("buffover")
            inst.components.timer:StartTimer("buffover", 20)
        end,
        OnTimerDone = function(inst, data)
            -- Buff倒计时结束时执行
            if data.name == "buffover" then
                local target = inst.entity:GetParent()
                if target and target.components and target.components.health and target.components.health.kisaki_takedmg_mult then
                    target.components.health.kisaki_takedmg_mult:RemoveModifier(target, "kisaki_vulnerable_aries")
                end
                inst:Remove()
            end
        end,
        OnSave = function(inst, data)
            -- 保存
        end,
        OnLoad = function(inst, data)
            -- 读取
        end,
    },
    {
        prefab = "kisaki_vulnerable_libra",
        name = "身体朽败-天蝎", --buff名称
        time = 5, --持续时间（s）
        OnAttached = function(inst, target)
            -- Buff被施加时执行方法
            inst.entity:SetParent(target.entity)
            if target and target.components and target.components.health and target.components.health.kisaki_takedmg_mult then
                target.components.health.kisaki_takedmg_mult:SetModifier(target, 1.3, "kisaki_vulnerable_libra")
            end
        end,
        OnDetached = function(inst, target)
            -- Buff被解除时执行方法
            if target and target.components and target.components.health and target.components.health.kisaki_takedmg_mult then
                target.components.health.kisaki_takedmg_mult:RemoveModifier(target, "kisaki_vulnerable_libra")
            end
        end,
        OnExtended = function(inst, target)
            -- Buff被刷新执行方法
            if target and target.components and target.components.health and target.components.health.kisaki_takedmg_mult then
                target.components.health.kisaki_takedmg_mult:SetModifier(target, 1.3, "kisaki_vulnerable_libra")
            end
            inst.components.timer:StopTimer("buffover")
            inst.components.timer:StartTimer("buffover", 5)
        end,
        OnTimerDone = function(inst, data)
            -- Buff倒计时结束时执行
            if data.name == "buffover" then
                local target = inst.entity:GetParent()
                if target and target.components and target.components.health and target.components.health.kisaki_takedmg_mult then
                    target.components.health.kisaki_takedmg_mult:RemoveModifier(target, "kisaki_vulnerable_libra")
                end
                inst:Remove()
            end
        end,
        OnSave = function(inst, data)
            -- 保存
        end,
        OnLoad = function(inst, data)
            -- 读取
        end,
    },
}

local function MakeBuffs(data)
    local function fn()
        local inst = CreateEntity()

        if data.tags then
            for _, v in ipairs(data.tags) do
                inst:AddTag(v)
            end
        end
        if not TheWorld.ismastersim then
            inst:DoTaskInTime(0, inst.Remove)
            return inst
        end
        -----------------------------------

        inst.entity:AddTransform()

        --[[Non-networked entity]]
        inst.entity:Hide()
        inst.persists = false

        inst:AddTag("CLASSIFIED")

        inst:AddComponent("debuff")
        inst.components.debuff:SetAttachedFn(data.OnAttached) -- 设置附加Buff时执行的函数
        inst.components.debuff:SetDetachedFn(data.OnDetached) -- 设置解除buff时执行的函数
        inst.components.debuff:SetExtendedFn(data.OnExtended) -- 设置延长buff时执行的函数
        inst.components.debuff.keepondespawn = true
        inst:AddComponent("timer")
        if inst:HasTag("indefinite") then
            -- 只有有时间组件才能显示，不用buffover这个名字就能显示无限时间（勋章）
            -- 不设立监听事件即时到时间也无事发生
            inst.components.timer:StartTimer("---", data.time)
        else
            inst.components.timer:StartTimer("buffover", data.time)
            inst:ListenForEvent("timerdone", data.OnTimerDone)
        end
        inst.OnSave = data.OnSave
        inst.OnPreLoad = data.OnLoad
        return inst
    end

    return Prefab(data.prefab, fn)
end

local kisaki_debuffs = {}
for _, v in ipairs(kisaki_debuffs_def) do
    if v.name then
        STRINGS.NAMES[string.upper(v.prefab)] = v.name
    end
    table.insert(kisaki_debuffs, MakeBuffs(v))
end
return unpack(kisaki_debuffs)
