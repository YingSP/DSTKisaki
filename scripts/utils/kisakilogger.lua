local modname = "kisaki"
local string_format = "[%s] [%s] %s"
local loglevel = TUNING.KISAKI_LOGLEVEL

local function debug(str)
    if loglevel <= 1 then
        print(string.format(string_format, "DEBUG", modname, str))
    end
end

local function info(str)
    if loglevel <= 2 then
        print(string.format(string_format, "INFO", modname, str))
    end
end

local function warn(str)
    if loglevel <= 4 then
        print(string.format(string_format, "WARN", modname, str))
    end
end

local function error(str)
    if loglevel <= 5 then
        print(string.format(string_format, "ERROR", modname, str))
    end
end

local function declare(str, userid)
    if loglevel <= 3 then
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
