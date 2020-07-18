local Set = {}

function Set:new(set)
    set = set or {}
    -- Inherit form `Set`
    self.__index = self
    setmetatable(set, self)
    return set
end

function Set:copy()
    local set = Set:new{}
    for k, v in pairs(self) do
        set[k] = v
    end
    return set
end

function Set:is_same(set1)
    local ret = true
    for k in pairs(self) do
        ret = ret and set1[k]
    end
    for k in pairs(set1) do
        ret = ret and self[k]
    end
    return ret
end

function Set:add(key)
    local set = self:copy()
    set[key] = true
    return set
end

function Set:rm(key)
    local set = self:copy()
    set[key] = nil
    return set
end

function Set:union(set1)
    local set = self:copy()
    for k, v in pairs(set1) do
        set[k] = set[k] or v
    end
    return set
end

Set.copy_set_table = function (t)
    local ret = {}
    for k, v in pairs(t) do
        ret[k] = v:copy()
    end
    return ret
end

Set.is_same_set_table = function (t1, t2)
    local ret = true
    for k, v1 in pairs(t1) do
        local v2 = t2[k]
        ret = ret and v1:is_same(v2)
    end
    return ret
end

return Set