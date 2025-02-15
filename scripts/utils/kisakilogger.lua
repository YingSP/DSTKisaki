local modname = "kisaki"
local string_format = "[%s] [%s] %s"

local function debug(str)
    if TUNING.KISAKI_LOGLEVEL <= 1 then
        print(string.format(string_format, "DEBUG", modname, str))
    end
end

local function info(str)
    if TUNING.KISAKI_LOGLEVEL <= 2 then
        print(string.format(string_format, "INFO", modname, str))
    end
end

local function warn(str)
    if TUNING.KISAKI_LOGLEVEL <= 4 then
        print(string.format(string_format, "WARN", modname, str))
    end
end

local function error(str)
    if TUNING.KISAKI_LOGLEVEL <= 5 then
        print(string.format(string_format, "ERROR", modname, str))
    end
end

local function declare(str, userid)
    if TUNING.KISAKI_LOGLEVEL <= 3 then
        if TheNet:GetIsServer() and userid then
            SendModRPCToClient(CLIENT_MOD_RPC["kisaki"]["client_declare"], userid, str)
        else
            Networking_Announcement(str)
        end
    end
end

return {
    debug = debug,
    info = info,
    declare = declare,
    warn = warn,
    error = error,
}
