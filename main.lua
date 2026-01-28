lovr.graphics.setBackgroundColor( 0.3, 0.3, 0.5 )

local sprite = require( "src.sprite" )

-- Call this after requiring the library, to set the maximum number of instances (default is 1000).
-- It's fine if you create less than that, but any created instances beyond the number you set here won't be rendered.
sprite.set_max_instances( 500 )

-- Define a spritesheet by setting the image to be used and the number of columns/rows
-- More spritesheets can be defined but the image sizes must be the same!
local spritesheet1 = sprite:new_spritesheet( "assets/cardsLarge_tilemap_packed.png", 14, 4 )

-- Define an animation on a spritesheet, setting a meaningful name, the start and end frame, and a speed
local animation1 = sprite:new_animation( spritesheet1, "cycle cards", 1, 56, 2 )

-- Create a sprite and assign a previously created animation. The transform is a regular mat4 for drawing it as a quad in 3D
-- For 2D drawing (asuuming you've setup an ortho projection) you can just pass 5 components to the mat4, for x, y, z (set to zero) and width/height
-- like this: "local sprite1 = sprite( spritesheet1, mat4(200, 100, 0, 64, 32), animation1 )"
local sprite1 = sprite( spritesheet1, mat4( 0, 1.8, -2 ), animation1 )

function lovr.update( dt )
	sprite1:set_transform( sprite1:get_transform():rotate( dt * 2, 0, 1, 0 ) )
end

function lovr.draw( pass )
	-- This draws all sprite instances
	sprite.draw_all( pass )
end
