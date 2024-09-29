# opencomputer-monitor

Yet another web monitor for all kinds of stuff in GT: NH, including machines, AE, and more

## Features

- Monitor GT machines by reading sensor information
- Monitor AE inventory
- Monitor AE crafting status
- Start AE crafting jobs remotely
- Monitor TPS (in `tps.lua`)

## How to use

1. Install `aiohttp aiohttp-cors requests` and run `main.py` on a server. Remember to set the `SECRET` variable in `main.py` to a random string. The server will listen on port 8080.
2. Download `json.lua`, `json2.lua` and `report.lua` on your OpenComputers computer.
3. Edit `report.lua` to set the `url_base` variable to the URL of your server, and the `SECRET` variable to the `SECRET` you set in step 1.
4. Run `report.lua` on your OpenComputers computer.
5. Open `http://<your_server_address>:8080/static/index.html` in a browser.

Optionally, you can dump the item icons with NEI and put them in `/itempanel_icons/`. The icons should be named `<modid>:<itemid>___<meta>.png`. The icons will be used in the item display for AE.

## Configuration

You can change the machines to be reported by editing the `machines` variable in `report.lua`. It is a table, where key is the name of the machine, and value is the address of the machine. The address can be found by running `component.list()` on the OpenComputers computer's Lua prompt.

You have to hook up the computer to a ME interface with an adapter to get the AE data. The computer should be connected to the internet with an internet card.

You can adjust the intervals of the reports by editing the main loop in `report.lua`.
