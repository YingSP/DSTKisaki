local avatar_name = "kisaki"

-- 修改吃组件，月社妃只吃新鲜食物，不吃带怪物度的食物
-- 使用AddComponentPostInit有点冗余，不如在prefab定义时重写方法(已修改)
-- if TUNING.KISAKI_IS_FOOD_HATE then
--     AddComponentPostInit("eater", function(Eater)
--         local oldPrefersToEat = Eater.PrefersToEat
--         function Eater:PrefersToEat(food, ...)
--             if self.inst:HasTag(avatar_name) then
--                 -- spoiled红色新鲜度食物，stale黄色新鲜度食物，fresh绿色新鲜度食物，monstermeat怪物肉
--                 local KISAKI_CANT_EAT_TAGS = { "stale", "spoiled", "monstermeat" }
--                 -- spoiled_food腐烂食物
--                 local KISAKI_CANT_EAT_FOOD = { "spoiled_food" }
--                 -- 检查食物名字
--                 for i, v in ipairs(KISAKI_CANT_EAT_FOOD) do
--                     if food and food.prefab and string.find(food.prefab, v) then
--                         return false
--                     end
--                 end
--                 -- 检查食物tag
--                 for i, v in ipairs(KISAKI_CANT_EAT_TAGS) do
--                     if food and food:HasTag(v) then
--                         return false
--                     end
--                 end
--                 -- 检查原版逻辑
--                 return oldPrefersToEat(self, food, ...)
--             else
--                 -- 非模组人物走老逻辑
--                 return oldPrefersToEat(self, food, ...)
--             end
--         end
--     end)
-- end

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
    end
end)
