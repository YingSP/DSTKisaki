local avatar_name = "kisaki"

-- 新增个制作栏
AddRecipeFilter({
    name = "KISAKI_TALISMAN",
    atlas = "images/inventoryimages/widget/kisaki_talisman.xml",
    image = "kisaki_talisman.tex",
})
AddRecipeFilter({
    name = "KISAKI_CHARACTER",
    atlas = "images/inventoryimages/widget/kisaki_character.xml",
    image = "kisaki_character.tex",
})
-- 靠近原型机，打开哪个筛选栏(月亮科技之类的,想要加配方，可以修改CRAFTING_FILTERS.CRAFTING_STATION.recipes)
AddPrototyperDef("kisaki_library_box", {
    icon_atlas = CRAFTING_ICONS_ATLAS,
    icon_image = "filter_none.tex",
    is_crafting_station = true, -- 靠近显示不可解锁配方的原型科技
    filter_text = STRINGS.UI.CRAFTING_FILTERS.CRAFTING_STATION
})
AddPrototyperDef("kisaki_library_box_chest", PROTOTYPER_DEFS.kisaki_library_box)

-- 限制制作栏显示
if not TUNING.KISAKI_RECIPES_SHARE then
    -- 特定tag的人物才能看到的制作栏列表
    local HideFilter = {
        KISAKI_TALISMAN = 1,
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
    kisaki_talisman_aquarius = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_aquarius.tex" },
    kisaki_talisman_pisces = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_pisces.tex" },
    kisaki_talisman_aries = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_aries.tex" },
    kisaki_talisman_taurus = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_taurus.tex" },
    kisaki_talisman_gemini = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_gemini.tex" },
    kisaki_talisman_cancer = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_cancer.tex" },
    kisaki_talisman_leo = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_leo.tex" },
    kisaki_talisman_virgo = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_virgo.tex" },
    kisaki_talisman_libra = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_libra.tex" },
    kisaki_talisman_scorpio = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_scorpio.tex" },
    kisaki_talisman_sagittarius = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_sagittarius.tex" },
    kisaki_talisman_capricorn = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_capricorn.tex" },
    kisaki_talisman_star = { atlas = "images/inventoryimages/prefabs/kisaki_constellation_talismans.xml", image = "kisaki_talisman_star.tex" },
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
    -- 星灵守护-水瓶
    {
        recipe_name = 'kisaki_talisman_aquarius',
        ingredients_data = {
            messagebottleempty = 10,
            townportaltalisman = 25,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-双鱼
    {
        recipe_name = 'kisaki_talisman_pisces',
        ingredients_data = {
            pondfish = 10,
            eel = 50,
            moonglass = 30,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-白羊
    {
        recipe_name = 'kisaki_talisman_aries',
        ingredients_data = {
            goatmilk = 20,
            lightninggoathorn = 5,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-金牛
    {
        recipe_name = 'kisaki_talisman_taurus',
        ingredients_data = {
            horn = 2,
            minotaurhorn = 1,
            armormarble = 1,
            goldnugget = 40,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-双子
    {
        recipe_name = 'kisaki_talisman_gemini',
        ingredients_data = {
            shieldofterror = 1,
            nightmarefuel = 40,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-巨蟹
    {
        recipe_name = 'kisaki_talisman_cancer',
        ingredients_data = {
            boat_bumper_crabking_kit = 8,
            trident = 1,
            cane = 1,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-狮子
    {
        recipe_name = 'kisaki_talisman_leo',
        ingredients_data = {
            meat = 10,
            coontail = 3,
            lantern = 1,
            molehat = 1,
            lightbulb = 40,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-处女
    {
        recipe_name = 'kisaki_talisman_virgo',
        ingredients_data = {
            sewing_kit = 10,
            raincoat = 1,
            rainhat = 1,
            reflectivevest = 1,
            winterhat = 1,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-天秤
    {
        recipe_name = 'kisaki_talisman_libra',
        ingredients_data = {
            bluegem = 1,
            redgem = 1,
            purplegem = 1,
            yellowgem = 1,
            orangegem = 1,
            greengem = 1,
            opalpreciousgem = 1,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-天蝎
    {
        recipe_name = 'kisaki_talisman_scorpio',
        ingredients_data = {
            spider = 10,
            spider_warrior = 5,
            nightmarefuel = 15,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-射手
    {
        recipe_name = 'kisaki_talisman_sagittarius',
        ingredients_data = {
            goose_feather = 3,
            blowdart_pipe = 10,
            blowdart_fire = 10,
            blowdart_sleep = 10,
            blowdart_yellow = 10,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-摩羯
    {
        recipe_name = 'kisaki_talisman_capricorn',
        ingredients_data = {
            oceanfish_small_7_inv = 1,
            oceanfish_small_8_inv = 1,
            oceanfish_small_6_inv = 1,
            oceanfish_medium_8_inv = 1,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 星灵守护-群星
    {
        recipe_name = 'kisaki_talisman_star',
        ingredients_data = {
            kisaki_talisman_aquarius = 1,
            kisaki_talisman_pisces = 1,
            kisaki_talisman_aries = 1,
            kisaki_talisman_taurus = 1,
            kisaki_talisman_gemini = 1,
            kisaki_talisman_cancer = 1,
            kisaki_talisman_leo = 1,
            kisaki_talisman_virgo = 1,
            kisaki_talisman_libra = 1,
            kisaki_talisman_scorpio = 1,
            kisaki_talisman_sagittarius = 1,
            kisaki_talisman_capricorn = 1,
        },
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_TALISMAN' }
    },
    -- 妃的杂物袋
    {
        recipe_name = 'kisaki_portable_box',
        ingredients_data = {
            papyrus = 4,
            silk = 4,
            kisaki_magic = 160,
        },
        builder_tag = avatar_name,
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_CHARACTER' }
    },
    -- 妃的幻想图书馆
    {
        recipe_name = 'kisaki_library_box',
        ingredients_data = {
            livinglog = 4,
            kisaki_magic = 100,
        },
        builder_tag = avatar_name,
        tech = TECH.NONE,
        isOriginalItem = false,
        isShown = true,
        filters = { 'KISAKI_CHARACTER' }
    },
    -- 妃的魔法盒
    {
        recipe_name = 'kisaki_magic_box',
        ingredients_data = {
            boards = 10,
            kisaki_magic = 1000,
        },
        builder_tag = avatar_name,
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
