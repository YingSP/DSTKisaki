-- 服务器往某个客户端单独宣告
if TheNet:GetIsClient() then
    AddClientModRPCHandler("kisaki", "client_declare", function(message)
        if ThePlayer and message then
            Networking_Announcement(message)
        end
    end)
end
if TheNet:GetIsServer() then
    AddClientModRPCHandler("kisaki", "client_declare", function(str) end)
end
