#!/usr/bin/env python3
from aiohttp import web
import logging
import aiohttp_cors
import json
import time
import uuid
import requests

SECRET = 'secret'

routes = web.RouteTableDef()

ae_items = []
ae_items_time = 0
ae_cpus = []
ae_cpus_time = 0

ae_items_incoming = []

machines_info = []
machines_time = 0

tps_info = ''
tps_time = 0

logs = []
orders = {}

@routes.get('/tps')
async def getTps(request):
    return web.json_response({'tps': tps_info, 'time': tps_time})

@routes.post('/tps')
async def postTps(request):
    global tps_info, tps_time
    data = await request.post()
    if data.get('secret') is None or data['secret'] != SECRET:
        return web.Response(status=403, text="Forbidden")
    if data.get('data') is None:
        return web.Response(status=400, text="Bad request")
    tps_info = json.loads(data['data'])
    tps_time = time.time()
    with open('tps.json', 'a') as f:
        f.write(f'{{"time":{tps_time}, "mspt":{tps_info["overall"]["ticktime"]}, "te":{tps_info["overall"]["te"]}, "entity":{tps_info["overall"]["entity"]}, "chunk":{tps_info["overall"]["chunk"]}, "dims":{json.dumps({dim["id"]: dim["tt"] for dim in tps_info["dims"]})}}}\n')
    return web.Response(text="OK")

@routes.get('/machines')
async def getMachines(request):
    return web.json_response({'machines': machines_info, 'time': machines_time})

@routes.post('/machines')
async def postMachines(request):
    global machines_info, machines_time
    data = await request.post()
    if data.get('secret') is None or data['secret'] != SECRET:
        return web.Response(status=403, text="Forbidden")
    if data.get('data') is None:
        return web.Response(status=400, text="Bad request")
    machines_info = json.loads(data['data'])
    machines_time = time.time()
    return web.Response(text="OK")

@routes.post('/ae/items')
async def postAeItems(request):
    global ae_items, ae_items_incoming, ae_items_time
    data = await request.post()
    if data.get('secret') is None or data['secret'] != SECRET:
        return web.Response(status=403, text="Forbidden")
    if data.get('data') is None and data.get('submit') is None:
        return web.Response(status=400, text="Bad request")
    # ae_items = data['data']
    if data.get('data') is not None:
        ae_items_incoming.extend(json.loads(data['data']))
    if data.get('submit') is not None:
        ae_items = ae_items_incoming
        ae_items_incoming = []
        ae_items_time = time.time()
        with open('ae_items.json', 'w') as f:
            json.dump(ae_items, f)

    return web.Response(text="OK")


@routes.post('/ae/cpus')
async def postAeCPUs(request):
    global ae_cpus, ae_cpus_time
    data = await request.post()
    logging.info(f'Post AE CPUs: {data}')
    if data.get('secret') is None or data['secret'] != SECRET:
        return web.Response(status=403, text="Forbidden")
    if data.get('data') is None:
        return web.Response(status=400, text="Bad request")
    # logging.info(f'Post AE items data: {json.loads(data["data"])}')
    ae_cpus = json.loads(data["data"])
    ae_cpus_time = time.time()
    with open('ae_cpus.json', 'w') as f:
        json.dump(ae_cpus, f)
    return web.Response(text="OK")


@routes.get('/ae/items')
async def getAeItems(request):
    global ae_items
    return web.json_response({'items': ae_items, 'time': ae_items_time})


@routes.get('/ae/cpus')
async def getAeCPUs(request):
    global ae_cpus
    return web.json_response({'cpus': ae_cpus, 'time': ae_cpus_time})


@routes.get('/logs')
async def getLogs(request):
    return web.json_response(logs)


@routes.post('/ae/order')
async def postOrder(request):
    # check request cookie
    if request.cookies.get('secret') is None or request.cookies['secret'] != SECRET:
        return web.Response(status=403, text="Forbidden")
    data = await request.json()
    # data={name, damage, size}
    if data.get('item') is None or data.get('amount') is None:
        return web.Response(status=400, text="Bad request")
    logs.append(
        f'{time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())} - Order received: {data}')
    order_id = str(uuid.uuid4())
    orders[order_id] = {'item': data['item'],
                        'amount': data['amount'],
                        'status': 'pending',
                        'message': '',
                        'created': time.time(),
                        'updated': time.time()}
    return web.json_response({'id': order_id})


@routes.get('/ae/order')
async def getOrders(request):
    params = request.query
    status = params.get('status')
    if status is not None:
        return web.json_response({k: v for k, v in orders.items() if v['status'] == status})
    return web.json_response(orders)

@routes.post('/ae/order/{order_id}')
async def updateOrder(request):
    order_id = request.match_info['order_id']
    data = await request.post()
    if data.get('status') is None:
        return web.Response(status=400, text="Bad request")
    if orders.get(order_id) is None:
        return web.Response(status=404, text="Not found")
    orders[order_id]['status'] = data['status']
    if data.get('message') is not None:
        orders[order_id]['message'] = data['message']
    orders[order_id]['updated'] = time.time()
    logs.append(f'{time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())} - Order {order_id} updated: {orders[order_id]}')
    return web.Response(text="OK")

routes.static('/static', '.')


app = web.Application(client_max_size=100*1024*1024)
app.add_routes(routes)
cors = aiohttp_cors.setup(app, defaults={
    "*": aiohttp_cors.ResourceOptions(
        allow_credentials=True,
        expose_headers="*",
        allow_headers="*"
    )
})
for route in list(app.router.routes()):
    cors.add(route)
logging.basicConfig(level=logging.INFO)

if __name__ == '__main__':
    with open('ae_items.json') as f:
        ae_items = json.load(f)
    with open('ae_cpus.json') as f:
        ae_cpus = json.load(f)
    web.run_app(app, port=8080)
