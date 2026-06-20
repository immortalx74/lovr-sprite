require( "table.new" )
require( "table.clear" )

local sprite = {}

math.randomseed( os.time() )

local function generate_uuid()
	local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
	return (string.gsub( template, '[xy]', function( c )
		local v = (c == 'x') and math.random( 0, 0xf ) or math.random( 8, 0xb )
		return string.format( '%x', v )
	end ))
end

local vertices =
{
	{ -0.5, 0.5,  0, 1, 1, 1, 1, 0, 0 },
	{ 0.5,  0.5,  0, 1, 1, 1, 1, 1, 0 },
	{ 0.5,  -0.5, 0, 1, 1, 1, 1, 1, 1 },
	{ -0.5, -0.5, 0, 1, 1, 1, 1, 0, 1 }
}

local mesh = lovr.graphics.newMesh( { { "VertexPosition", "vec3" }, { "VertexColor", "vec4" }, { "VertexUV", "vec2" } }, vertices )

mesh:setIndices( { 1, 2, 3, 3, 4, 1 } )

local sprite_shader = lovr.graphics.newShader( [[
	struct InstanceData {
	mat4 transform;
	int texture_index;
	int col_index;
	int row_index;
	int cols;
	int rows;
};

readonly buffer instance_data{ InstanceData ins_data[]; };

flat out vec2 cell_coords;
flat out vec2 colrow_count;
flat out int texture_index;

vec4 lovrmain()
{
	cell_coords = vec2( ins_data[ InstanceIndex ].col_index, ins_data[ InstanceIndex ].row_index );
	colrow_count = vec2( ins_data[ InstanceIndex ].cols, ins_data[ InstanceIndex ].rows );
	texture_index = ins_data[ InstanceIndex ].texture_index;
	return Projection * View * ins_data[ InstanceIndex ].transform * VertexPosition;
}
]], [[
uniform texture2DArray spritesheets;

flat in vec2 cell_coords;
flat in vec2 colrow_count;
flat in int texture_index;

float offset_x = cell_coords.x * ( 1.0 / colrow_count.x );
float offset_y = cell_coords.y * ( 1.0 / colrow_count.y );

vec4 lovrmain()
{
	vec2 sample_uv = vec2( offset_x + ( UV.x / colrow_count.x ), offset_y + ( UV.y / colrow_count.y ) );
	vec4 tex_color = getPixel( spritesheets, sample_uv, texture_index - 1 );

	if ( tex_color.a < 0.1 )
	{
		discard;
	}

	return Color * tex_color;
}
]] )

local texture_filenames = {}
local textures = nil
local instances = {}

local buffer_format = {
	"mat4", "int", "int", "int", "int", "int", layout = 'std140'
}

local buffer = lovr.graphics.newBuffer( buffer_format, 1000 )
local buffer_filler = table.new( 1000, 0 )

-- creation functions
function sprite:new_spritesheet( img, cols, rows )
	local obj = {}
	setmetatable( obj, { __index = self } )

	local texture_index = 1

	if #texture_filenames == 0 then
		texture_filenames[ #texture_filenames + 1 ] = img
		textures = lovr.graphics.newTexture( img, { type = "array" } )
	else
		texture_filenames[ #texture_filenames + 1 ] = img
		textures:release()
		textures = lovr.graphics.newTexture( texture_filenames, { type = "array" } )
		texture_index = textures:getLayerCount()
	end

	obj.cols = cols == nil and 1 or cols
	obj.rows = rows == nil and 1 or rows
	obj.texture_index = texture_index

	obj.animations = { [ "default" ] = { name = "default", spritesheet = obj, start_index = 1, end_index = 1, speed = 1 } }

	return obj
end

function sprite:new_animation( spritesheet, name, start_index, end_index, speed )
	spritesheet.animations[ name ] = { name = name, spritesheet = spritesheet, start_index = start_index, end_index = end_index, speed = speed }
	return spritesheet.animations[ name ]
end

function sprite:new( spritesheet, transform, animation )
	local obj = {}
	setmetatable( obj, { __index = self } )

	local active_animation

	if animation then
		if type( animation ) == "string" then
			assert( spritesheet.animations[ animation ], string.format( "No animation named '%s' found bound to this spritesheet", animation ) )
			active_animation = spritesheet.animations[ animation ]
		elseif type( animation ) == "table" then
			assert( spritesheet == animation.spritesheet, string.format( "No animation named '%s' found bound to this spritesheet", animation.name ) )
			active_animation = animation
		end
	else
		active_animation = spritesheet.animations[ "default" ]
	end

	obj.id = generate_uuid()

	instances[ obj.id ] = {
		spritesheet = spritesheet,
		transform = transform and transform or mat4(),
		active_animation = active_animation,
		texture_index = spritesheet.texture_index,
		cur_animation_frame = active_animation.start_index,
		visible = true,
		paused = false,
		timer = 0
	}

	return obj
end

-- methods
function sprite:delete()
	instances[ self.id ] = nil
	for k in pairs( self ) do self[ k ] = nil end
	return nil
end

function sprite:set_transform( transform )
	instances[ self.id ].transform = transform
end

function sprite:get_transform()
	return instances[ self.id ].transform
end

function sprite:set_visible( visible )
	instances[ self.id ].visible = visible
end

function sprite:get_visible()
	return instances[ self.id ].visible
end

function sprite:set_paused( paused )
	instances[ self.id ].paused = paused
end

function sprite:get_paused()
	return instances[ self.id ].paused
end

function sprite:set_frame( frame )
	instances[ self.id ].cur_animation_frame = frame
	instances[ self.id ].timer = 0
end

function sprite:get_frame()
	return instances[ self.id ].cur_animation_frame
end

function sprite:set_animation( animation )
	if type( animation ) == "string" then
		assert( instances[ self.id ].spritesheet.animations[ animation ], string.format( "No animation named '%s' found bound to this spritesheet", animation ) )
		instances[ self.id ].active_animation = instances[ self.id ].spritesheet.animations[ animation ]
	elseif type( animation ) == "table" then
		assert( instances[ self.id ].spritesheet == animation.spritesheet, string.format( "No animation named '%s' found bound to this spritesheet", animation.name ) )
		instances[ self.id ].active_animation = animation
	end
end

function sprite:get_animation()
	return instances[ self.id ].active_animation, instances[ self.id ].active_animation.name
end

-- misc
function sprite.set_max_instances( count )
	buffer:release()
	buffer = lovr.graphics.newBuffer( buffer_format, count )
	buffer_filler = table.new( count, 0 )
end

-- draw
function sprite.draw_all( pass )
	pass:push( "state" )
	pass:setSampler( "nearest" )
	pass:setShader( sprite_shader )

	local dt = lovr.headset and lovr.headset.getDeltaTime() or lovr.timer.getDelta()

	table.clear( buffer_filler )

	for _, sprite in pairs( instances ) do
		if sprite.visible then
			if not sprite.paused then
				local saa = sprite.active_animation
				local e_idx = saa.end_index
				local s_idx = saa.start_index
				local speed = saa.speed
				sprite.timer = sprite.timer + dt

				local frame_count = (e_idx - s_idx) + 1
				local elapsed_frames = math.floor( sprite.timer * speed )
				sprite.cur_animation_frame = (elapsed_frames % frame_count) + s_idx
			end

			local cell_col = (sprite.cur_animation_frame - 1) % sprite.spritesheet.cols
			local cell_row = (sprite.cur_animation_frame - 1) / sprite.spritesheet.cols

			buffer_filler[ #buffer_filler + 1 ] =
			{
				sprite.transform,
				sprite.texture_index,
				cell_col,
				cell_row,
				sprite.spritesheet.cols,
				sprite.spritesheet.rows
			}
		end
	end

	buffer:setData( buffer_filler )
	pass:send( "instance_data", buffer )
	pass:send( "spritesheets", textures )
	pass:draw( mesh, mat4(), #buffer_filler )

	pass:pop( "state" )
end

setmetatable( sprite, { __call = function( self, ... ) return self:new( ... ) end } )

return sprite
