dofile('json.lua')
component = require("component")
os = require("os")
tps = component.tps_card
gpu = component.gpu

inet = component.internet

url_base = 'http://changeme.me/'
SECRET = 'secret'

function sum(tbl)
    if tbl ~= nil then
        local sum = 0
        for k,v in pairs(tbl) do
            sum = sum + v
        end
        return sum
    end
    return 0
end

gpu.setResolution(55, 35)
gpu.fill(1,1,55,35,' ')
while true do
    ticktimes = tps.getAllTickTimes()

    a={}
    cnt=0
    for k,v in pairs(ticktimes) do
        cnt=cnt+1
        a[cnt]={id=k, tt=v}
    end

    table.sort(a, function(i,j)
        return i.tt > j.tt
    end)

    gpu.set(1,35,"Refreshing...       ")
    cnt=0
    local info = {}
    -- print('id','mspt','chunk','entity','te')
    gpu.set(1,1,string.format('%10s%10s%10s%10s%10s', 'id', 'mspt', 'chunk', 'entity', 'te'))
    for k,v in pairs(a) do
        a[k].chunk = tps.getChunksLoadedForDim(v.id) or 0
        a[k].entity = tps.getEntitiesListForDim(v.id)
        a[k].te = tps.getTileEntitiesListForDim(v.id)
        gpu.set(1, cnt+2, string.format("%10d%10.1f%10d%10d%10d",v.id, v.tt, a[k].chunk, sum(a[k].entity),sum(a[k].te)))
        cnt=cnt+1
        if cnt>30 then
            break
        end
    end
    info.overall = {ticktime=tps.getOverallTickTime(), chunk=tps.getOverallChunksLoaded(), entity=tps.getOverallEntitiesLoaded(), te=tps.getOverallTileEntitiesLoaded()}
    gpu.set(1,34,string.format("%10s%10.1f%10d%10d%10d", 'Overall', info.overall.ticktime, info.overall.chunk, info.overall.entity, info.overall.te))
    gpu.set(1,35,"Reporting...   ")
    info.dims = a
    local json = dumpjson(info)
    i,j = inet.request(url_base..'tps','secret='..SECRET..'&data='..json,{},'POST').finishConnect()
    for i=15,1,-1 do
        gpu.set(1,35,string.format("Refreshing in %ds...", i))
        os.sleep(1)
    end
end