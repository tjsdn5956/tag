fx_version 'cerulean'
game 'gta5'

ui_page "nui/index.html"

client_scripts {
    "@vrp/client/Tunnel.lua",
	"@vrp/client/Proxy.lua",
	"config.lua",
	"Lua/dui_pool.lua",
	"Lua/client.lua"
}

server_scripts {
    "@vrp/lib/utils.lua",
	"@vrp/lib/MySQL.lua",
	"config.lua",
	"Lua/server.lua"
}

files {
	"nui/img/*",
	"nui/*",
	"dui/nametag.html"
}

dependencies {
    'vrp'
}
