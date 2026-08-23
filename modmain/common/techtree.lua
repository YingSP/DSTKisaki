local TechTree = require("techtree")

-- 新增科技树
table.insert(TechTree.AVAILABLE_TECH, "KISAKI_BOOKCRAFT") -- 妃的幻想图书馆
table.insert(TechTree.AVAILABLE_TECH, "KISAKI_SCULPTING") -- 特殊的陶轮科技
-- 科技点，在recipe引用
_G.TECH.KISAKI_BOOKCRAFT_ONE = { KISAKI_BOOKCRAFT = 1 }
_G.TECH.KISAKI_SCULPTING_ONE = { KISAKI_SCULPTING = 1 }

-- 科技
TUNING.PROTOTYPER_TREES.KISAKI_BOOKCRAFT_ONE = TechTree.Create({ KISAKI_BOOKCRAFT = 1 }) -- 和STRINGS.UI.CRAFTING.NEEDSKISAKI_BOOKCRAFT_ONE配合
TUNING.PROTOTYPER_TREES.KISAKI_SCULPTING_ONE = TechTree.Create({ KISAKI_SCULPTING = 1 })

-- 老科技树补齐(原版不会炸，但是部分模组没判断会有问题)
local Create_old = TechTree.Create
TechTree.Create = function(t, ...)
    local newt = Create_old(t, ...)
    newt["KISAKI_BOOKCRAFT"] = newt["KISAKI_BOOKCRAFT"] or 0
    newt["KISAKI_SCULPTING"] = newt["KISAKI_SCULPTING"] or 0
    return newt
end
for _, recipe in pairs(AllRecipes) do
    if recipe.level["KISAKI_BOOKCRAFT"] == nil then
        recipe.level["KISAKI_BOOKCRAFT"] = 0
    end
    if recipe.level["KISAKI_SCULPTING"] == nil then
        recipe.level["KISAKI_SCULPTING"] = 0
    end
end
