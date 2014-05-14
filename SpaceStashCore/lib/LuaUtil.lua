local MAJOR, MINOR = "LuaUtil", 1

local LuaUtil = {}

function LuaUtil.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[LuaUtil.deepcopy(orig_key)] = LuaUtil.deepcopy(orig_value)
        end
        setmetatable(copy, LuaUtil.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function LuaUtil.shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

Apollo.RegisterPackage(LuaUtil, MAJOR, MINOR, {})
