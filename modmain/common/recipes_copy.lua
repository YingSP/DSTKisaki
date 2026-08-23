-- 复制原版配方
-- 奶奶科技
AddRecipe2(
    "kisaki_bookstation",
    { Ingredient("livinglog", 2), Ingredient("papyrus", 4), Ingredient("featherpencil", 1) },
    TECH.KISAKI_BOOKCRAFT_ONE,
    { nounlock = true, station_tag = "kisaki_library_box", placer = "bookstation_placer", product = "bookstation" }
)
STRINGS.NAMES[string.upper("kisaki_bookstation")] = STRINGS.NAMES[string.upper("bookstation")] or ""
-- table.insert(_G.CRAFTING_FILTERS.CRAFTING_STATION.recipes, "kisaki_bookstation") -- nounlock=true会自动将配方加进制作站栏
local wkbtrecipelist = {
    "book_horticulture", "book_horticulture_upgraded", "book_silviculture", "book_research_station",
    "book_birds", "book_fish", "book_bees", "book_sleep", "book_brimstone", "book_fire", "book_tentacles",
    "book_web", "book_moon", "book_light", "book_light", "book_light_upgraded", "book_rain", "book_temperature",
}
for _, recipename in ipairs(wkbtrecipelist) do
    -- 配方
    AddRecipe2(
        "kisaki_" .. recipename,
        AllRecipes[recipename].ingredients,
        TECH.KISAKI_BOOKCRAFT_ONE,
        { nounlock = true, station_tag = "kisaki_library_box", product = recipename }
    )
    -- 配方名
    STRINGS.NAMES[string.upper("kisaki_" .. recipename)] = STRINGS.NAMES[string.upper(recipename)] or ""
    -- 配方加入制作站
    -- table.insert(_G.CRAFTING_FILTERS.CRAFTING_STATION.recipes, "kisaki_" .. recipename)
end

-- 雕像类科技
local builderrecipelist = {
    "chesspiece_hornucopia", "chesspiece_pipe", "chesspiece_anchor", "chesspiece_pawn", "chesspiece_rook",
    "chesspiece_knight", "chesspiece_bishop", "chesspiece_muse", "chesspiece_formal", "chesspiece_deerclops",
    "chesspiece_bearger", "chesspiece_moosegoose", "chesspiece_dragonfly", "chesspiece_minotaur", "chesspiece_toadstool",
    "chesspiece_beequeen", "chesspiece_klaus", "chesspiece_antlion", "chesspiece_stalker", "chesspiece_malbatross",
    "chesspiece_crabking", "chesspiece_butterfly", "chesspiece_moon", "chesspiece_guardianphase3",
    "chesspiece_eyeofterror", "chesspiece_twinsofterror", "chesspiece_clayhound", "chesspiece_claywarg",
    "chesspiece_carrat", "chesspiece_beefalo", "chesspiece_kitcoon", "chesspiece_catcoon", "chesspiece_manrabbit",
    "chesspiece_daywalker", "chesspiece_daywalker2", "chesspiece_deerclops_mutated", "chesspiece_warg_mutated",
    "chesspiece_bearger_mutated", "chesspiece_yotd", "chesspiece_sharkboi", "chesspiece_wormboss", "chesspiece_yots",
    "chesspiece_wagboss_robot", "chesspiece_wagboss_lunar"
}
for _, recipename in ipairs(builderrecipelist) do
    for _, suffix in ipairs({ "_marble", "_stone", "_moonglass" }) do
        -- 配方
        local ingredients =
            (suffix == "_marble" and { Ingredient("marble", 1), Ingredient("rocks", 2) })
            or (suffix == "_stone" and { Ingredient("cutstone", 1), Ingredient("rocks", 2) })
            or (suffix == "_moonglass" and { Ingredient("moonglass", 1), Ingredient("rocks", 2) })
        local config = { nounlock = true, station_tag = "kisaki_library_box", product = recipename .. suffix }
        config.description = recipename .. "_builder"
        if suffix == "_marble" then
            config.image = recipename .. ".tex"
        end
        AddRecipe2("kisaki_" .. recipename .. suffix, ingredients, TECH.KISAKI_SCULPTING_ONE, config)
        -- 配方名
        STRINGS.NAMES[string.upper("kisaki_" .. recipename .. suffix)] = STRINGS.NAMES
            [string.upper(recipename .. "_builder")] or ""
    end
end

-- 刷新制作站列表
-- _G.CRAFTING_FILTERS.CRAFTING_STATION.default_sort_values = table.invert(_G.CRAFTING_FILTERS.CRAFTING_STATION.recipes)
