local avatar_name = "kisaki"

-- 新增个制作栏
AddRecipeFilter({
    name = "KISAKI_CHARACTER",
    atlas = "images/inventoryimages/widget/kisaki_character.xml",
    image = "kisaki_character.tex",
})

-- 限制制作栏显示
if not TUNING.KISAKI_RECIPES_SHARE then
    -- 特定tag的人物才能看到的制作栏列表
    local HideFilter = {
        KISAKI_CHARACTER = 1,
    }
    -- 修改UI组件
    local craftingMenuWidget = require "widgets/redux/craftingmenu_widget"
    local oldMakeFilterPanel = craftingMenuWidget.MakeFilterPanel
    craftingMenuWidget.MakeFilterPanel = function(self, width, ...)
        local OLD_CRAFTING_FILTER_DEFS = CRAFTING_FILTER_DEFS -- 保存原有的制作栏列表参数然后copy
        local NEW_CRAFTING_FILTER_DEFS = {}
        _G.CRAFTING_FILTER_DEFS = NEW_CRAFTING_FILTER_DEFS
        for k, v in pairs(OLD_CRAFTING_FILTER_DEFS) do
            if v then
                if HideFilter[v.name] then
                    if self.owner and self.owner:HasTag(avatar_name) then
                        table.insert(NEW_CRAFTING_FILTER_DEFS, v) -- 只有拥有特定tag才能看到
                    end
                else
                    table.insert(NEW_CRAFTING_FILTER_DEFS, v)
                end
            end
        end
        local data = oldMakeFilterPanel(self, width, ...)
        _G.CRAFTING_FILTER_DEFS = OLD_CRAFTING_FILTER_DEFS -- 还原制作栏列表
        return data                                        -- 返回处理过的数据
    end
end

-- 制作提示
AddClassPostConstruct("widgets/redux/craftingmenu_details", function(self)
    local oldUpdateBuildButton = self.UpdateBuildButton
    self.UpdateBuildButton = function(self, ...)
        local meta = self.data and self.data.meta
        if meta ~= nil and (meta.build_state == "hint" or meta.build_state == "hide")
            and self.ingredients ~= nil and self.ingredients.hint_tech_ingredient == nil
            and self.ingredients.recipe ~= nil and self.ingredients.recipe.builder_tag ~= nil
            and not self.owner:HasTag(self.ingredients.recipe.builder_tag)
            and self.ingredients.recipe.builder_tag:sub(1, 6) == "kisaki" then
            self.ingredients.hint_tech_ingredient = string.upper[self.ingredients.recipe.builder_tag] or nil
        end
        if oldUpdateBuildButton then
            oldUpdateBuildButton(self, ...)
        end
    end
end)

local recipe_images = {
    kisaki_magic = { atlas = "images/inventoryimages/widget/kisaki_magic.xml", image = "kisaki_magic.tex" },
    kisaki_ether = { atlas = "images/inventoryimages/prefabs/kisaki_ether.xml", image = "kisaki_ether.tex" },
}

local recipe_all = {
    -- 以太
    {
        recipe_name = 'kisaki_purplegem_to_ether',
        config = {
            product = 'kisaki_ether',
            numtogive = 10,
        },
        ingredients_data = {
            purplegem = 1,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_CHARACTER' }
    },
    -- 以太
    {
        recipe_name = 'kisaki_goldnugget_to_ether',
        config = {
            product = 'kisaki_ether',
            numtogive = 10,
            builder_tag = avatar_name
        },
        ingredients_data = {
            goldnugget = 40,
            kisaki_magic = 40,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_CHARACTER' }
    },
    -- 以太球
    {
        recipe_name = 'kisaki_ether_bottle',
        ingredients_data = {
            kisaki_ether = 100,
            messagebottleempty = 1,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_CHARACTER' }
    },
}

-- 加载动画资源
local function Injectproductimg(product)
    local atlas = 'images/inventoryimages/prefabs/' .. product .. '.xml'
    return atlas
end

-- 将配方加到制作栏
for _k, _r in pairs(recipe_all) do
    if _r.ingredients == nil then
        _r.ingredients = {}
    end
    if _r.ingredients_data ~= nil then
        for k, v in pairs(_r.ingredients_data) do
            if recipe_images[k] == nil then
                table.insert(_r.ingredients, Ingredient(string.lower(k), v))
            else
                table.insert(_r.ingredients,
                    Ingredient(string.lower(k), v, recipe_images[k].atlas, nil, recipe_images[k].images))
            end
        end
    end

    if _r.config == nil then
        _r.config = {}
    end
    if not TUNING.KISAKI_RECIPES_SHARE then
        _r.config.builder_tag = avatar_name
    end
    if _r.builder_tag then
        _r.config.builder_tag = _r.builder_tag
    end
    -- 默认不可拆解
    if _r.no_deconstruction == nil or _r.no_deconstruction then
        _r.config.no_deconstruction = true
    end
    if _r.config.description == nil then
        _r.config.description = _r.recipe_name
    end
    if _r.config.product == nil then
        _r.config.product = string.lower(_r.recipe_name)
    end
    if _r.config.numtogive == nil and _r.config.placer == nil then
        _r.config.numtogive = _r.numtogive or 1
    end
    if _r.isOriginalItem == nil or not _r.isOriginalItem then
        if _r.config.atlas == nil then
            if _r.config.image == nil then
                local name = _r.config.product ~= nil and _r.config.product or _r.recipe_name
                if recipe_images[name] then
                    _r.config.atlas = recipe_images[name].atlas
                    _r.config.image = recipe_images[name].image
                else
                    _r.config.atlas = Injectproductimg(name)
                    _r.config.image = name .. '.tex'
                end
            else
                _r.config.atlas = GetInventoryItemAtlas_Internal(_r.config.image)
            end
        end
    end
    if _r.filters == nil then
        _r.filters = { 'EXAMPLE_TAB' }
    end
    if _r.config == nil then
        _r.config = {}
    end
    if _r.isShown == nil or _r.isShown == true then
        AddRecipe2(_r.recipe_name, _r.ingredients, _r.tech, _r.config, _r.filters)
    end
end
