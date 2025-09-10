--[[
2024 Koentje

modified by v_ramch 2025

added image with rounded corners & circular image
    To draw an image with rounded corners (set radius to 0 for square corners):
    ${lua conky_image "/path/to/image.png" x y width height radius}
    To draw a circular image:
    ${lua conky_image_circle "/path/to/image.png" x y radius}

--]]

function fDrawImage(cr, path, xx, yy, ww, hh, radius, is_circle)
    cairo_save(cr)
    
    -- Load image
    local img = cairo_image_surface_create_from_png(path)
    local w_img, h_img = cairo_image_surface_get_width(img), cairo_image_surface_get_height(img)
    
    -- Apply translation to the center of the image
    cairo_translate(cr, xx, yy)

    if is_circle then
        -- Calculate scaling factors to fit the image within the circle
        local scale_x = ww / w_img
        local scale_y = hh / h_img
        local scale = math.min(scale_x, scale_y) -- Ensure the image fits within the circle

        -- Apply scaling
        cairo_scale(cr, scale, scale)

        -- Move the image so the center is at (0, 0)
        cairo_translate(cr, -w_img / 2, -h_img / 2)

        -- Create a circular clip mask
        cairo_new_path(cr)
        cairo_arc(cr, ww / (2 * scale), hh / (2 * scale), radius / scale, 0, 2 * math.pi)
        cairo_close_path(cr)
        cairo_clip(cr)
    else
        -- Apply scaling for rounded rectangle
        cairo_scale(cr, ww / w_img, hh / h_img)

        -- Create a rounded rectangle clip mask
        cairo_new_path(cr)
        cairo_move_to(cr, radius, 0)
        cairo_arc(cr, w_img - radius, radius, radius, math.pi * 1.5, 0)
        cairo_arc(cr, w_img - radius, h_img - radius, radius, 0, math.pi * 0.5)
        cairo_arc(cr, radius, h_img - radius, radius, math.pi * 0.5, math.pi)
        cairo_arc(cr, radius, radius, radius, math.pi, math.pi * 1.5)
        cairo_close_path(cr)
        cairo_clip(cr)
    end

    -- Draw the image
    cairo_set_source_surface(cr, img, 0, 0)
    cairo_paint(cr)

    -- Cleanup
    cairo_surface_destroy(img)
    collectgarbage()
    cairo_restore(cr)
end

-- Function to draw image with rounded corners
function conky_image(img, xxx, yyy, www, hhh, radius)
    if conky_window == nil then return '' end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Draw image with rounded corners
    fDrawImage(cr, img, xxx, yyy, www, hhh, radius, false)

    cairo_surface_destroy(cs)
    cairo_destroy(cr)
    return ''
end

-- Function to draw a circular image
function conky_image_circle(img, xxx, yyy, radius)
    if conky_window == nil then return '' end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Calculate width and height for a perfect circle
    local diameter = 2 * radius
    local www, hhh = diameter, diameter

    -- Draw image with circular clipping
    fDrawImage(cr, img, xxx, yyy, www, hhh, radius, true)

    cairo_surface_destroy(cs)
    cairo_destroy(cr)
    return ''
end