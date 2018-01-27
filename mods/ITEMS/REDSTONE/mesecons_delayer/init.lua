-- Function that get the input/output rules of the delayer
local delayer_get_output_rules = function(node)
	local rules = {{x = -1, y = 0, z = 0, spread=true}}
	for i = 0, node.param2 do
		rules = mesecon.rotate_rules_left(rules)
	end
	return rules
end

local delayer_get_input_rules = function(node)
	local rules = {{x = 1, y = 0, z = 0}}
	for i = 0, node.param2 do
		rules = mesecon.rotate_rules_left(rules)
	end
	return rules
end

local delayer_get_all_rules = function(node)
	local orules = delayer_get_output_rules(node)
	local irules = delayer_get_input_rules(node)
	return mesecon.mergetables(orules, irules)
end

local check_lock_repeater = function(pos, node)
	-- Check the repeater at pos and look if there is
	-- a repeater in its facing direction and sideways.
	-- If yes, lock the second repeater.
	local r = delayer_get_output_rules(node)[1]
	local lpos = vector.add(pos, r)
	local lnode = minetest.get_node(lpos)
	local ldef = minetest.registered_nodes[lnode.name]
	local g = minetest.get_item_group(lnode.name, "redstone_repeater")
	if g >= 1 and g <= 4 then
		local lrs = delayer_get_input_rules(lnode)
		local fail = false
		for _, lr in pairs(lrs) do
			if lr.x == r.x or lr.z == r.z then
				fail = true
				break
			end
		end
		if not fail then
			minetest.swap_node(lpos, {name=ldef.delayer_lockstate, param2=lnode.param2})
			return true
		end
	end
	return false
end

local check_unlock_repeater = function(pos, node)
	-- Unlock repeater
	local r = delayer_get_output_rules(node)[1]
	local lpos = vector.add(pos, r)
	local lnode = minetest.get_node(lpos)
	local ldef = minetest.registered_nodes[lnode.name]
	local g = minetest.get_item_group(lnode.name, "redstone_repeater")
	if g == 5 then
		local lrs = delayer_get_input_rules(lnode)
		local fail = false
		for _, lr in pairs(lrs) do
			if lr.x == r.x or lr.z == r.z then
				fail = true
				break
			end
		end
		if not fail then
			if mesecon.is_powered(lpos) then
				minetest.swap_node(lpos, {name="mesecons_delayer:delayer_on_1", param2=lnode.param2})
				mesecon.queue:add_action(lpos, "receptor_on", {delayer_get_output_rules(lnode)}, ldef.delayer_time, nil)
			else
				minetest.swap_node(lpos, {name="mesecons_delayer:delayer_off_1", param2=lnode.param2})
				mesecon.queue:add_action(lpos, "receptor_off", {delayer_get_output_rules(lnode)}, ldef.delayer_time, nil)
			end
			return true
		end
	end
	return false
end

-- Functions that are called after the delay time
local delayer_activate = function(pos, node)
	local def = minetest.registered_nodes[node.name]
	local time = def.delayer_time
	minetest.swap_node(pos, {name=def.delayer_onstate, param2=node.param2})
	mesecon.queue:add_action(pos, "receptor_on", {delayer_get_output_rules(node)}, time, nil)

	check_lock_repeater(pos, node)
end

local delayer_deactivate = function(pos, node)
	local def = minetest.registered_nodes[node.name]
	local time = def.delayer_time
	minetest.swap_node(pos, {name=def.delayer_offstate, param2=node.param2})
	mesecon.queue:add_action(pos, "receptor_off", {delayer_get_output_rules(node)}, time, nil)

	check_unlock_repeater(pos, node)
end

-- Register the 2 (states) x 4 (delay times) delayers

for i = 1, 4 do
local groups = {}
if i == 1 then 
	groups = {dig_immediate=3,dig_by_water=1,destroy_by_lava_flow=1,dig_by_piston=1,attached_node=1,redstone_repeater=i}
else
	groups = {dig_immediate=3,dig_by_water=1,destroy_by_lava_flow=1,dig_by_piston=1,attached_node=1,redstone_repeater=i,not_in_creative_inventory=1}
end

local delaytime
if i == 1 then delaytime = 0.1
elseif	i == 2 then delaytime = 0.2
elseif	i == 3 then delaytime = 0.3
elseif	i == 4 then delaytime = 0.4
end

local boxes
if i == 1 then
boxes = {
	{ -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },		-- the main slab
	{ -1/16, -6/16, 6/16, 1/16, -1/16, 4/16},     -- still torch
	{ -1/16, -6/16, 0/16, 1/16, -1/16, 2/16},     -- moved torch 
}
elseif i == 2 then
boxes = {
	{ -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },		-- the main slab
	{ -1/16, -6/16, 6/16, 1/16, -1/16, 4/16},     -- still torch
	{ -1/16, -6/16, -2/16, 1/16, -1/16, 0/16},     -- moved torch 
}
elseif i == 3 then
boxes = {
	{ -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },		-- the main slab
	{ -1/16, -6/16, 6/16, 1/16, -1/16, 4/16},     -- still torch
	{ -1/16, -6/16, -4/16, 1/16, -1/16, -2/16},     -- moved torch 
}
elseif i == 4 then
boxes = {
	{ -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },		-- the main slab
	{ -1/16, -6/16, 6/16, 1/16, -1/16, 4/16},     -- still torch
	{ -1/16, -6/16, -6/16, 1/16, -1/16, -4/16},     -- moved torch 
}
end

local help, longdesc, usagehelp, icon
if i == 1 then
	help = true
	longdesc = "Redstone repeaters are versatile redstone components which delay redstone signals and only allow redstone signals to travel through one direction. The delay of the signal is indicated by the redstone torches and is between 0.1 and 0.4 seconds long."
	usagehelp = "To power a redstone repeater, send a signal in “arrow” direction. To change the delay, rightclick the redstone repeater. The delay is changed in steps of 0.1 seconds."
	icon = "mesecons_delayer_item.png"
else
	help = false
end

local on_rotate
if minetest.get_modpath("screwdriver") then
	on_rotate = screwdriver.disallow
end

minetest.register_node("mesecons_delayer:delayer_off_"..tostring(i), {
	description = "Redstone Repeater",
	inventory_image = icon,
	wield_image = icon,
	_doc_items_create_entry = help,
	_doc_items_longdesc = longdesc,
	_doc_items_usagehelp = usagehelp,
	drawtype = "nodebox",
	tiles = {
		"mesecons_delayer_off.png",
		"mcl_stairs_stone_slab_top.png",
		"mesecons_delayer_sides_off.png",
		"mesecons_delayer_sides_off.png",
		"mesecons_delayer_ends_off.png",
		"mesecons_delayer_ends_off.png",
		},
	wield_image = "mesecons_delayer_off.png",
	walkable = true,
	selection_box = {
		type = "fixed",
		fixed = { -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },
	},
	collision_box = {
		type = "fixed",
		fixed = { -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },
	},
	node_box = {
		type = "fixed",
		fixed = boxes
	},
	groups = groups,
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = false,
	is_ground_content = false,
	drop = 'mesecons_delayer:delayer_off_1',
	on_rightclick = function (pos, node)
		if node.name=="mesecons_delayer:delayer_off_1" then
			minetest.swap_node(pos, {name="mesecons_delayer:delayer_off_2", param2=node.param2})
		elseif node.name=="mesecons_delayer:delayer_off_2" then
			minetest.swap_node(pos, {name="mesecons_delayer:delayer_off_3", param2=node.param2})
		elseif node.name=="mesecons_delayer:delayer_off_3" then
			minetest.swap_node(pos, {name="mesecons_delayer:delayer_off_4", param2=node.param2})
		elseif node.name=="mesecons_delayer:delayer_off_4" then
			minetest.swap_node(pos, {name="mesecons_delayer:delayer_off_1", param2=node.param2})
		end
	end,
	delayer_time = delaytime,
	delayer_onstate = "mesecons_delayer:delayer_on_"..tostring(i),
	delayer_lockstate = "mesecons_delayer:delayer_off_locked",
	sounds = mcl_sounds.node_sound_stone_defaults(),
	mesecons = {
		receptor =
		{
			state = mesecon.state.off,
			rules = delayer_get_output_rules
		},
		effector =
		{
			rules = delayer_get_input_rules,
			action_on = delayer_activate
		}
	},
	on_rotate = on_rotate,
})


minetest.register_node("mesecons_delayer:delayer_on_"..tostring(i), {
	description = "Redstone Repeater (Powered)",
	_doc_items_create_entry = false,
	drawtype = "nodebox",
	tiles = {
		"mesecons_delayer_on.png",
		"mcl_stairs_stone_slab_top.png",
		"mesecons_delayer_sides_on.png",
		"mesecons_delayer_sides_on.png",
		"mesecons_delayer_ends_on.png",
		"mesecons_delayer_ends_on.png",
		},
	walkable = true,
	selection_box = {
		type = "fixed",
		fixed = { -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },
	},
	collision_box = {
		type = "fixed",
		fixed = { -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },
	},
	node_box = {
		type = "fixed",
		fixed = boxes
	},
	groups = {dig_immediate = 3, dig_by_water=1,destroy_by_lava_flow=1, dig_by_piston=1, attached_node=1, redstone_repeater=i, not_in_creative_inventory = 1},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = false,
	is_ground_content = false,
	drop = 'mesecons_delayer:delayer_off_1',
	on_rightclick = function (pos, node)
		if node.name=="mesecons_delayer:delayer_on_1" then
			minetest.swap_node(pos, {name="mesecons_delayer:delayer_on_2",param2=node.param2})
		elseif node.name=="mesecons_delayer:delayer_on_2" then
			minetest.swap_node(pos, {name="mesecons_delayer:delayer_on_3",param2=node.param2})
		elseif node.name=="mesecons_delayer:delayer_on_3" then
			minetest.swap_node(pos, {name="mesecons_delayer:delayer_on_4",param2=node.param2})
		elseif node.name=="mesecons_delayer:delayer_on_4" then
			minetest.swap_node(pos, {name="mesecons_delayer:delayer_on_1",param2=node.param2})
		end
	end,
	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		check_unlock_repeater(pos, oldnode)
	end,
	delayer_time = delaytime,
	delayer_offstate = "mesecons_delayer:delayer_off_"..tostring(i),
	delayer_lockstate = "mesecons_delayer:delayer_on_locked",
	sounds = mcl_sounds.node_sound_stone_defaults(),
	mesecons = {
		receptor =
		{
			state = mesecon.state.on,
			rules = delayer_get_output_rules
		},
		effector =
		{
			rules = delayer_get_input_rules,
			action_off = delayer_deactivate
		}
	},
	on_rotate = on_rotate,
})

end


-- Locked repeater

minetest.register_node("mesecons_delayer:delayer_off_locked", {
	description = "Redstone Repeater (Locked)",
	inventory_image = icon,
	wield_image = icon,
	_doc_items_create_entry = false,
	drawtype = "nodebox",
	-- FIXME: Textures of torch and the lock bar overlap. Nodeboxes are (sadly) not suitable for this.
	-- So this needs to be turned into a mesh.
	tiles = {
		"mesecons_delayer_locked_off.png",
		"mcl_stairs_stone_slab_top.png",
		"mesecons_delayer_sides_locked_off.png",
		"mesecons_delayer_sides_locked_off.png",
		"mesecons_delayer_front_locked_off.png",
		"mesecons_delayer_end_locked_off.png",
		},
	wield_image = "mesecons_delayer_locked_off.png",
	walkable = true,
	selection_box = {
		type = "fixed",
		fixed = { -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },
	},
	collision_box = {
		type = "fixed",
		fixed = { -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },
	},
	node_box = {
		type = "fixed",
		fixed = {
			{ -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 }, -- the main slab
			{ -1/16, -6/16, 6/16, 1/16, -1/16, 4/16}, -- still torch
			{ -6/16, -6/16, 0/16, 6/16, -4/16, 2/16}, -- lock
		}
	},
	groups = {dig_immediate = 3, dig_by_water=1,destroy_by_lava_flow=1, dig_by_piston=1, attached_node=1, redstone_repeater=5, not_in_creative_inventory = 1},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = false,
	is_ground_content = false,
	drop = 'mesecons_delayer:delayer_off_1',
	delayer_time = 0.1,
	sounds = mcl_sounds.node_sound_stone_defaults(),
	mesecons = {
		receptor =
		{
			state = mesecon.state.off,
			rules = delayer_get_output_rules
		},
		effector =
		{
			rules = delayer_get_input_rules,
		}
	},
	on_rotate = on_rotate,
})

minetest.register_node("mesecons_delayer:delayer_on_locked", {
	description = "Redstone Repeater (Locked, Powered)",
	_doc_items_create_entry = false,
	drawtype = "nodebox",
	tiles = {
		"mesecons_delayer_locked_on.png",
		"mcl_stairs_stone_slab_top.png",
		"mesecons_delayer_sides_locked_on.png",
		"mesecons_delayer_sides_locked_on.png",
		"mesecons_delayer_front_locked_on.png",
		"mesecons_delayer_end_locked_on.png",
		},
	walkable = true,
	selection_box = {
		type = "fixed",
		fixed = { -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },
	},
	collision_box = {
		type = "fixed",
		fixed = { -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 },
	},
	node_box = {
		type = "fixed",
		fixed = {
			{ -8/16, -8/16, -8/16, 8/16, -6/16, 8/16 }, -- the main slab
			{ -1/16, -6/16, 6/16, 1/16, -1/16, 4/16}, -- still torch
			{ -6/16, -6/16, 0/16, 6/16, -4/16, 2/16}, -- lock
		}
	},
	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		check_unlock_repeater(pos, oldnode)
	end,
	groups = {dig_immediate = 3, dig_by_water=1,destroy_by_lava_flow=1, dig_by_piston=1, attached_node=1, redstone_repeater=5, not_in_creative_inventory = 1},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = false,
	is_ground_content = false,
	drop = 'mesecons_delayer:delayer_off_1',
	delayer_time = 0.1,
	sounds = mcl_sounds.node_sound_stone_defaults(),
	mesecons = {
		receptor =
		{
			state = mesecon.state.on,
			rules = delayer_get_output_rules
		},
		effector =
		{
			rules = delayer_get_input_rules,
		}
	},
	on_rotate = on_rotate,
})

minetest.register_craft({
	output = "mesecons_delayer:delayer_off_1",
	recipe = {
		{"mesecons_torch:mesecon_torch_on", "mesecons:redstone", "mesecons_torch:mesecon_torch_on"},
		{"mcl_core:stone","mcl_core:stone", "mcl_core:stone"},
	}
})

-- Add entry aliases for the Help
if minetest.get_modpath("doc") then
	doc.add_entry_alias("nodes", "mesecons_delayer:delayer_off_1", "nodes", "mesecons_delayer:delayer_off_2")
	doc.add_entry_alias("nodes", "mesecons_delayer:delayer_off_1", "nodes", "mesecons_delayer:delayer_off_3")
	doc.add_entry_alias("nodes", "mesecons_delayer:delayer_off_1", "nodes", "mesecons_delayer:delayer_off_4")
	doc.add_entry_alias("nodes", "mesecons_delayer:delayer_off_1", "nodes", "mesecons_delayer:delayer_off_locked")
	doc.add_entry_alias("nodes", "mesecons_delayer:delayer_off_1", "nodes", "mesecons_delayer:delayer_on_1")
	doc.add_entry_alias("nodes", "mesecons_delayer:delayer_off_1", "nodes", "mesecons_delayer:delayer_on_2")
	doc.add_entry_alias("nodes", "mesecons_delayer:delayer_off_1", "nodes", "mesecons_delayer:delayer_on_3")
	doc.add_entry_alias("nodes", "mesecons_delayer:delayer_off_1", "nodes", "mesecons_delayer:delayer_on_4")
	doc.add_entry_alias("nodes", "mesecons_delayer:delayer_off_1", "nodes", "mesecons_delayer:delayer_on_locked")
end
