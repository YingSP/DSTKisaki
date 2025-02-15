----------------------------------------------------------------------------CLASS-----------------------------------------------------------------------------

local SaveInfo = Class(function(self, inst)
    self.inst = inst
    self.saveinfo = nil
end)

function SaveInfo:GetSaveInfo(userid)
    if userid then
        if self.saveinfo == nil then
            return nil
        else
            return self.saveinfo[userid]
        end
    end
    return nil
end

function SaveInfo:SetSaveInfo(userid, saveinfo)
    if saveinfo then
        if self.saveinfo == nil then
            self.saveinfo = { [userid] = saveinfo }
        else
            self.saveinfo[userid] = saveinfo
        end
    elseif self.saveinfo ~= nil then
        self.saveinfo[userid] = nil
        if next(self.saveinfo) == nil then
            self.saveinfo = nil
        end
    end
end

----------------------------------------------------------------------------加载时运行---------------------------------------------------------------------------

function SaveInfo:OnSave()
    return
    {
        saveinfo = self.saveinfo,
    }
end

function SaveInfo:OnLoad(data)
    if not data then return end
    self.saveinfo = data.saveinfo ~= nil and data.saveinfo or {}
end

return SaveInfo