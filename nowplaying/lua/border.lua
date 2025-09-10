local cairo = require("cairo")

-- Helper function to convert a hex color string to RGBA
local function hex_to_rgba(hex)
    local r, g, b, a = hex:match("^#(%x%x)(%x%x)(%x%x)(%x?%x?)$")
    r = tonumber(r, 16) / 255
    g = tonumber(g, 16) / 255
    b = tonumber(b, 16) / 255
    a = tonumber(a ~= "" and a or "FF", 16) / 255 -- Default alpha to 1.0 if not specified
    return {r, g, b, a}
end

-- Function to draw the border with a shaded fill and a break in the top border
local function draw_rounded_border_with_shade_with_break(x, y, width, height, radius, thickness, border_color, fill_color, break_start, break_length)
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)

    -- Draw shaded rectangle with transparency
    cairo_set_source_rgba(cr, fill_color[1], fill_color[2], fill_color[3], fill_color[4])
    cairo_new_path(cr)
    cairo_move_to(cr, x + radius, y)
    cairo_arc(cr, x + width - radius, y + radius, radius, 3 * math.pi / 2, 0) -- Top-right corner
    cairo_arc(cr, x + width - radius, y + height - radius, radius, 0, math.pi / 2) -- Bottom-right corner
    cairo_arc(cr, x + radius, y + height - radius, radius, math.pi / 2, math.pi) -- Bottom-left corner
    cairo_arc(cr, x + radius, y + radius, radius, math.pi, 3 * math.pi / 2) -- Top-left corner
    cairo_close_path(cr)
    cairo_fill(cr)

    -- Draw the border with a break in the top border
    cairo_set_source_rgba(cr, border_color[1], border_color[2], border_color[3], border_color[4])
    cairo_set_line_width(cr, thickness)

    -- Top border (left of the break)
    cairo_new_path(cr)
    cairo_move_to(cr, x + radius, y)
    cairo_line_to(cr, x + break_start, y)
    cairo_stroke(cr)

    -- Top border (right of the break)
    cairo_new_path(cr)
    cairo_move_to(cr, x + break_start + break_length, y)
    cairo_line_to(cr, x + width - radius, y)
    cairo_arc(cr, x + width - radius, y + radius, radius, 3 * math.pi / 2, 0) -- Top-right corner
    cairo_stroke(cr)

    -- Right border
    cairo_new_path(cr)
    cairo_move_to(cr, x + width, y + radius)
    cairo_line_to(cr, x + width, y + height - radius)
    cairo_arc(cr, x + width - radius, y + height - radius, radius, 0, math.pi / 2) -- Bottom-right corner
    cairo_stroke(cr)

    -- Bottom border
    cairo_new_path(cr)
    cairo_move_to(cr, x + width - radius, y + height)
    cairo_line_to(cr, x + radius, y + height)
    cairo_arc(cr, x + radius, y + height - radius, radius, math.pi / 2, math.pi) -- Bottom-left corner
    cairo_stroke(cr)

    -- Left border
    cairo_new_path(cr)
    cairo_move_to(cr, x, y + height - radius)
    cairo_line_to(cr, x, y + radius)
    cairo_arc(cr, x + radius, y + radius, radius, math.pi, 3 * math.pi / 2) -- Top-left corner
    cairo_stroke(cr)

    -- Cleanup
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- Function to draw a circular border
local function draw_circular_border(x, y, radius, thickness, border_color)
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)

    -- Draw the circular border
    cairo_set_source_rgba(cr, border_color[1], border_color[2], border_color[3], border_color[4])
    cairo_set_line_width(cr, thickness)
    cairo_new_path(cr)
    cairo_arc(cr, x, y, radius, 0, 2 * math.pi)
    cairo_stroke(cr)

    -- Cleanup
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- Conky function to draw the border with a shaded fill and a break
function conky_draw_border_with_shade()
    local x, y = 0, 30
    local width, height = 340, 130
    local radius = 10
    local thickness = 2 -- Border thickness
    local border_color = hex_to_rgba("#B0B0B0FF") -- Border color (blue with full opacity)
    local fill_color = {0.1, 0.1, 0.3, 1} -- Fill color (light blue with transparency)

    -- Break parameters
    local break_start = 20 -- Distance from the left edge to the start of the break
    local break_length = 110 -- Length of the break

    draw_rounded_border_with_shade_with_break(x, y, width, height, radius, thickness, border_color, fill_color, break_start, break_length)
    return ""
end

-- Conky function to draw a circular border
function conky_draw_circular_border()
    local x, y = 58, 95 -- Center coordinates of the circle
    local radius = 46 -- Radius of the circle
    local thickness = 3 -- Border thickness
    local border_color = hex_to_rgba("#e9c885FF") -- Border color + two character transparency code
    local fill_color = hex_to_rgba("#00000033") -- Hex colour + two character transparency code
    draw_circular_border(x, y, radius, thickness, border_color, fill_color)
    return ""
end

function conky_square_image_border()
    local x, y = 12, 45 -- set the start position of the border
    local width, height = 104, 100 -- set the size of the border here
    local radius = 10
    local thickness = 4
    local border_color = hex_to_rgba("#5eb5d1FF") -- Hex colour + two character transparency code
    local fill_color = hex_to_rgba("#00000000") -- Hex colour + two character transparency code

    -- Break parameters
    local break_x = 42 -- Distance from the left edge of the border to the start of the break
    local break_width = 0 -- Width of the break

    draw_rounded_border_with_shade_with_break(x, y, width, height, radius, thickness, border_color, fill_color, break_x, break_width)
    return ""
end
