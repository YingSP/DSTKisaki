AddStategraphPostInit("wilson", function(sg)
    -- 霸体
    local old_kisaki_attacked = sg.events.attacked.fn
    sg.events.attacked.fn = function(inst, data)
        if inst._kisaki_domination ~= nil and inst._kisaki_domination:Get() then
            return
        end
        old_kisaki_attacked(inst, data)
    end
end)
