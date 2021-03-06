local S = minetest.get_translator("mcl_end")

local explosion_strength = 6

local directions = {
	{x = 1}, {x = -1}, {z = 1}, {z = -1}
}

local dimensions = {"x", "y", "z"}

for _, dir in pairs(directions) do
	for _, dim in pairs(dimensions) do
		dir[dim] = dir[dim] or 0
	end
end

local function find_crystal(pos)
	local objects = minetest.get_objects_inside_radius(pos, 0)
	for _, obj in pairs(objects) do
		local luaentity = obj:get_luaentity()
		if luaentity and luaentity.name == "mcl_end:crystal" then
			return luaentity
		end
	end
end

local function crystal_explode(self, puncher)
	if self._exploded then return end
	self._exploded = true
	local strength = puncher and explosion_strength or 1
	mcl_explosions.explode(vector.add(self.object:get_pos(), {x = 0, y = 1.5, z = 0}), strength, {drop_chance = 1}, puncher)
	minetest.after(0, self.object.remove, self.object)
end

local function set_crystal_animation(self)
	self.object:set_animation({x = 0, y = 120}, 25)
end

local function spawn_crystal(pos)
	local crystal = minetest.add_entity(pos, "mcl_end:crystal")
	if not vector.equals(pos, vector.floor(pos)) then return end
	if mcl_worlds.pos_to_dimension(pos) ~= "end" then return end
	local portal_center
	for _, dir in pairs(directions) do
		local node = minetest.get_node(vector.add(pos, dir))
		if node.name == "mcl_portals:portal_end" then
			portal_center = vector.add(pos, vector.multiply(dir, 3))
			break
		end
	end
	if not portal_center then return end
	local crystals = {}
	for i, dir in pairs(directions) do
		local crystal_pos = vector.add(portal_center, vector.multiply(dir, 3))
		crystals[i] = find_crystal(crystal_pos)
		if not crystals[i] then return end
	end
	for _, crystal in pairs(crystals) do
		crystal_explode(crystal)
	end
	local portal_pos = vector.add(portal_center, vector.new(-3, -1, -3))
	mcl_structures.call_struct(portal_pos, "end_exit_portal")
	minetest.add_entity(vector.add(portal_pos, vector.new(3, 11, 3)), "mobs_mc:enderdragon"):get_luaentity()._portal_pos = portal_pos
end

minetest.register_entity("mcl_end:crystal", {
	initial_properties = {
		physical = true,
		visual = "mesh",
		visual_size = {x = 6, y = 6},
		collisionbox = {-1, 0.5, -1, 1, 2.5, 1},
		mesh = "mcl_end_crystal.b3d",
		textures = {"mcl_end_crystal.png"},
		collide_with_objects = false,
	},
	on_punch = crystal_explode,
	on_activate = set_crystal_animation,
	_exploded = false,
	_hittable_by_projectile = true
})

minetest.register_entity("mcl_end:crystal_beam", {
	initial_properties = {
		physical = false,
		visual = "cube",
		visual_size = {x = 1, y = 1, z = 1},
		textures = {
			"mcl_end_crystal_beam.png^[transformR90",
			"mcl_end_crystal_beam.png^[transformR90",
			"mcl_end_crystal_beam.png",
			"mcl_end_crystal_beam.png",
			"blank.png",
			"blank.png",
		},
		static_save = false,
	},
	spin = 0,
	init = function(self, dragon, crystal)
		self.dragon, self.crystal = dragon, crystal
		crystal:get_luaentity().beam = self.object
		dragon:get_luaentity().beam = self.object
	end,
	on_deactivate = function(self)
		if self.crystal and self.crystal:get_luaentity() then
			self.crystal:get_luaentity().beam = nil
		end
		if self.dragon and self.dragon:get_luaentity() then
			self.dragon:get_luaentity().beam = nil
		end
	end,
	on_step = function(self, dtime)
		if self.dragon and self.dragon:get_luaentity() and self.crystal and self.crystal:get_luaentity() then
			self.spin = self.spin + dtime * math.pi * 2 / 4
			local dragon_pos, crystal_pos = self.dragon:get_pos(), self.crystal:get_pos()

			dragon_pos.y = dragon_pos.y + 4
			crystal_pos.y = crystal_pos.y + 2

			self.object:set_pos(vector.divide(vector.add(dragon_pos, crystal_pos), 2))
			local rot = vector.dir_to_rotation(vector.direction(dragon_pos, crystal_pos))
			rot.z = self.spin
			self.object:set_rotation(rot)
			self.object:set_properties({visual_size = {x = 0.5, y = 0.5, z = vector.distance(dragon_pos, crystal_pos)}})
		else
			self.object:remove()
		end
	end,
})

minetest.register_craftitem("mcl_end:crystal", {
	inventory_image = "mcl_end_crystal_item.png",
	description = S("End Crystal"),
	stack_max = 64,
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type == "node" then
			local pos = minetest.get_pointed_thing_position(pointed_thing)
			local node = minetest.get_node(pos)
			local node_name = node.name
			if placer and not placer:get_player_control().sneak then
				if minetest.registered_nodes[node_name] and minetest.registered_nodes[node_name].on_rightclick then
					return minetest.registered_nodes[node_name].on_rightclick(pointed_thing.under, node, placer, itemstack) or itemstack
				end
			end
			if find_crystal(pos) then return itemstack end
			if node_name == "mcl_core:obsidian" or node_name == "mcl_core:bedrock" then
				if not minetest.is_creative_enabled(placer:get_player_name()) then
					itemstack:take_item()
				end
				spawn_crystal(pos)
			end
		end
		return itemstack
	end,
	_tt_help = S("Ignited by a punch or a hit with an arrow").."\n"..S("Explosion radius: @1", tostring(explosion_strength)),
	_doc_items_longdesc = S("End Crystals are explosive devices. They can be placed on Obsidian or Bedrock. Ignite them by a punch or a hit with an arrow. End Crystals can also be used the spawn the Ender Dragon by placing one at each side of the End Exit Portal."),
	_doc_items_usagehelp = S("Place the End Crystal on Obsidian or Bedrock, then punch it or hit it with an arrow to cause an huge and probably deadly explosion. To Spawn the Ender Dragon, place one at each side of the End Exit Portal."),

})

minetest.register_craft({
	output = "mcl_end:crystal",
	recipe = {
		{"mcl_core:glass", "mcl_core:glass", "mcl_core:glass"},
		{"mcl_core:glass", "mcl_end:ender_eye", "mcl_core:glass"},
		{"mcl_core:glass", "mcl_mobitems:ghast_tear", "mcl_core:glass"},
	}
})

minetest.register_alias("mcl_end_crystal:end_crystal", "mcl_end:crystal")
