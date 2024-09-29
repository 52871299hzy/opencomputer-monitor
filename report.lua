dofile('json.lua')
local js = require('json2')
local cp = require("component")
local os = require("os")
local me = cp.me_interface
local inet = cp.internet
-- local inet = require("internet")

local url_base = 'http://changeme.me/'
local SECRET = 'secret'

local machine_addresses = {power_bank="cacf0cd7-fbb9-40a3-b8ec-d39fe9bdcb56"}

local tasks = {}
-- tasks is table uuid->{item, amount, status, r(returned from AE request(), can be nil)}

function report_items()
  -- Report items

  -- local items=me.getItemsInNetwork()
  -- This is too laggy.

  -- local iter = me.allItems()
  -- This is inconsistent.

  local iter = me.getItemsInNetwork()
  local items = {}
  local cnt = 0
  for _, item in ipairs(iter) do
    cnt = cnt + 1
    items[cnt] = item
    if cnt >= 100 then
      local json=dumpjson(items)
      i,j = inet.request(url_base..'ae/items','secret='..SECRET..'&data='..json,{},'POST').finishConnect()
      if not i then
        print('Error reporting items ')
      end
      cnt = 0
      items = {}
    end
  end
  if cnt == 0 then
    return
  end
  local json=dumpjson(items)
  i,j = inet.request(url_base..'ae/items','secret='..SECRET..'&data='..json,{},'POST').finishConnect()
  if not i then
    print('Error reporting items ')
  end
  inet.request(url_base..'ae/items','secret='..SECRET..'&submit=1',{},'POST').finishConnect()
end

function report_cpus()
  local cpus=me.getCpus()
  local cpu_data={}
  for i,v in ipairs(cpus) do
    cpu_data[i]={}
    cpu_data[i].busy=v.busy
    cpu_data[i].coprocessors=v.coprocessors
    cpu_data[i].storage=v.storage
    cpu_data[i].name=v.name
    -- These don't exist in 1.12! WHY???
    cpu_data[i].active=v.cpu.isActive()
    cpu_data[i].activeItems=v.cpu.activeItems()
    cpu_data[i].finalOutput=v.cpu.finalOutput()
    cpu_data[i].pendingItems=v.cpu.pendingItems()
    cpu_data[i].storedItems=v.cpu.storedItems()
  end
  local json=dumpjson(cpu_data)
  i,j = inet.request(url_base..'ae/cpus','secret='..SECRET..'&data='..json,{},'POST').finishConnect()
  if not i then
    print('Error reporting cpus ')
  end
end

function report_machines()
  local machine_data={}
  for i,v in pairs(machine_addresses) do
    local machine=cp.proxy(v)
    machine_data[i]=machine.getSensorInformation()
  end
  local json=dumpjson(machine_data)
  i,j = inet.request(url_base..'machines','secret='..SECRET..'&data='..json,{},'POST').finishConnect()
  if not i then
    print('Error reporting machines ')
  end		
end

function process_orders()
  local r = inet.request(url_base..'ae/order?status=pending')
  local i,j = r.finishConnect()
  if not i then
    print('Error fetching orders ')
    return
  end
  local orders=js.decode(r.read())
  -- orders is a table uuid->{item,amount}
  for uuid,order in pairs(orders) do
    -- Check if the order is already being processed
    if tasks[uuid] then
      -- Maybe last update failed, retry
      inet.request(url_base..'ae/order/'..uuid,'secret='..SECRET..'&status='..tasks[uuid].status,{},'POST').finishConnect()
      if tasks[uuid].message then
        os.sleep(1)
        inet.request(url_base..'ae/order/'..uuid,'secret='..SECRET..'&message='..tasks[uuid].message,{},'POST').finishConnect()
      end
      goto continue
    end
    -- Find craftables that matches item
    local craftables=me.getCraftables({name=order.item.name, damage=order.item.damage, label=order.item.label})
    if #craftables ~= 1 then
      inet.request(url_base..'ae/order/'..uuid,'secret='..SECRET..'&status=error&message=item_is_ambiguous',{},'POST').finishConnect()
      tasks[uuid]={item=order.item, amount=order.amount, status='error', r=nil, message='item_is_ambiguous'}
      goto continue
    end
    local craftable=craftables[1]
    -- Request crafting
    print('Requesting '..order.amount..' of '..order.item.name..'/'..order.item.damage..'...')
    local r,m=craftable.request(order.amount)
    if not r then
      inet.request(url_base..'ae/order/'..uuid,'secret='..SECRET..'&status=error&message='..m,{},'POST').finishConnect()
      tasks[uuid]={item=order.item, amount=order.amount, status='error', r=nil, message=m}
      goto continue
    end
    tasks[uuid]={item=order.item, amount=order.amount, status='processing', r=r}
    inet.request(url_base..'ae/order/'..uuid,'secret='..SECRET..'&status=processing',{},'POST').finishConnect()
    ::continue::
  end

  r = inet.request(url_base..'ae/order?status=processing')
  if not r then
    print('Error fetching orders ')
    return
  end
  i,j = r.finishConnect()
  if not i then
    print('Error fetching orders ')
    return
  end
  orders=js.decode(r.read())
  for uuid,order in pairs(orders) do
    if not tasks[uuid] then
      -- dangling order
      inet.request(url_base..'ae/order/'..uuid,'secret='..SECRET..'&status=error&message=order_not_found',{},'POST').finishConnect()
      goto continue2
    end
    local task=tasks[uuid]
    if task.r.hasFailed() then
      _,j = task.r.isDone()
      if j then
        inet.request(url_base..'ae/order/'..uuid,'secret='..SECRET..'&status=error&message='..j,{},'POST').finishConnect()
        tasks[uuid]={item=order.item, amount=order.amount, status='error', r=nil, message=j}
      end
      goto continue2
    end
    if task.r.isDone() then
      inet.request(url_base..'ae/order/'..uuid,'secret='..SECRET..'&status=done',{},'POST').finishConnect()
      tasks[uuid]={item=order.item, amount=order.amount, status='done', r=nil}
      goto continue2
    end
    if task.r.isCanceled() then
      inet.request(url_base..'ae/order/'..uuid,'secret='..SECRET..'&status=error&message=cancelled',{},'POST').finishConnect()
      tasks[uuid]={item=order.item, amount=order.amount, status='error', r=nil, message='cancelled'}
      goto continue2
    end
    ::continue2::
  end
end

t=0
while true do
  -- report_items()
  if t%4==0 then
    report_cpus()
  end
  os.sleep(10)
  report_machines()
  os.sleep(10)
  process_orders()
  os.sleep(10)
  t=t+1
end