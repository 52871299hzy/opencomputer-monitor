--[[
   dumps tables into json.
]]--
do
    function dumpjson(  tbl )
        if type(tbl) == 'table' then
            local ret = ''
            local is_array = 0
            local first = 1
            for k,v in pairs(tbl) do
                if first == 1 then
                    first = 0
                else
                    ret = ret .. ', '
                end
                if type(k) == 'number' then
                    is_array = 1
                    ret = ret .. dumpjson(v)
                else
                    if k ~= 'tag' then
                        ret = ret .. '"' .. k .. '": ' .. dumpjson(v)
                    else -- workaround for NBT
                        ret = ret .. '"' .. k .. '": ' .. dumpjson({string.byte(v,1,-1)})
                    end
                end
            end
            if is_array == 0 then
                return '{' .. ret .. '}'
            else
                return '[' .. ret .. ']'
            end
        elseif type(tbl) == 'string' then
            tbl = tbl:gsub('&', '%%26')
            return string.format("%q", tbl)
        else
            return tostring(tbl)
        end
    end
end