GLOBAL.KISAKI_API = env

GLOBAL.KisakiCD = function(ti, real) -- 内置CD
    local t = ti
    local last = -ti
    local get = real and GetTimeRealSeconds or GetTime
    return function()
        local ct = get()
        if (ct - t) > last then
            last = ct
            return true
        end
        return false
    end
end
