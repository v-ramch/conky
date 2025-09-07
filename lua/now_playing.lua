local cairo = require("cairo")
require "imlib2"
home_path = os.getenv('HOME')
img = home_path .. "/.conky/nowplaying/images/spotify.png"


home_path = os.getenv('HOME')
img_folder = home_path .. "/.conky/nowplaying/images/"
spotify_png = img_folder .. "spotify.png"
spotify_jpg = img_folder .. "spotify.jpg"
lastfm_png = img_folder .. "lastfm.png"
lastfm_jpg = img_folder .. "lastfm.jpg"



-- Define local variables for the song details
local song_title = ""
local song_artist = ""
local song_album = ""
local song_length = 0
local song_position = 0
local scroll_position = 0 -- Keeps track of the scroll position
local player_status = ""  -- Holds the current player status
local album_art_url = "" -- Holds the album art URL
local album_art_path = "~/.conky/nowplaying/images/spotify.png" -- Set this to the folder where the image will be saved
-- track last artist to know when to refresh images
local last_artist = ""

-- seed RNG once for shuffling
math.randomseed(os.time())


-- Function to safely execute a command and return trimmed output
local function safe_popen(command)
    local handle = io.popen(command)
    if handle then
        local result = handle:read("*all")
        handle:close()
        return result and result:gsub("%s*$", "") or ""
    end
    return ""
end

-- Function to check if any player is running
local function is_player_running(player)
    local status = safe_popen("playerctl --player=" .. player .. " status 2>/dev/null")
    return status ~= "" -- Returns true if status is not empty
end


-- Function to convert JPG to PNG
local function convert_jpg_to_png(input_jpg, output_png)
    os.execute(string.format("convert %s %s", input_jpg, output_png))
    os.remove(input_jpg)
 --   print("Converted JPG to PNG: " .. output_png)
end

-- Ensure input file is converted to PNG
-- input_jpg  = source file
-- output_png = target PNG file
function ensure_png_format(input_jpg, output_png)
    local check_type = safe_popen("file -b --mime-type " .. input_jpg)

    if check_type:match("jpeg") then
        os.execute(string.format("convert %s %s", input_jpg, output_png))
        os.remove(input_jpg)
    elseif not check_type:match("png") then
        print("Warning: Unsupported file format - " .. check_type)
    else
        -- already PNG, move/rename if needed
        if input_jpg ~= output_png then
            os.rename(input_jpg, output_png)
        end
    end
end



-- Function to download album art
local function download_album_art(url, path)
    if url ~= "" then
        local jpg_path = path:gsub("%.png$", ".jpg")
        os.execute("rm -f " .. jpg_path) 
        os.execute("wget -q -O " .. jpg_path .. " " .. url) 
        ensure_png_format(jpg_path, spotify_png)
    end
end

-- Function to download the album art image
--local function download_album_art(url, path)
--    if url ~= "" then
--        os.execute("rm -f " .. path) -- Remove the existing image
--        os.execute("wget -q -O " .. path .. " " .. url) -- Download the new image
--    end
--end

local function urlencode(str)
    return str:gsub("([^0-9a-zA-Z ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "+")
end

local function get_album_art_from_lastfm()
    -- Get Last.fm API URL with URL - artist and album names
    local api_key = "232b87d489d65666f6e512357d8746ee"  --CHANGE TO YOUR API KEY
    local artist = urlencode(song_artist)
    local album = urlencode(song_album)
    local lastfm_url = string.format(
        "http://ws.audioscrobbler.com/2.0/?method=album.getinfo&api_key=%s&artist=%s&album=%s&format=json",
        api_key, artist, album
    )

    -- Fetch album art URL using `wget` and JSON parsing
    local temp_file = "/tmp/lastfm_response.json"
    local wget_cmd = string.format("wget -q -O %s '%s'", temp_file, lastfm_url)
    
    os.execute(wget_cmd)

    -- Check if file was downloaded
    if not safe_popen("test -f " .. temp_file) then
        print("Error: Last.fm response file not found!")
        return ""
    end

    local response = safe_popen("cat " .. temp_file)
    local art_url = response:match('"image":%[.*"size":"extralarge","#text":"(.-)"')
    
    os.execute("rm -f " .. temp_file) -- Clean up the temporary file
    return art_url or ""
end

local function download_artist_images_background(artist)
    if artist == "" or artist == last_artist then return end
    
    local escaped_artist = artist:gsub('"', '\\"')
    local cmd = string.format("bash ~/.conky/nowplaying/start_download.sh \"%s\" >/dev/null 2>&1 &", escaped_artist)
    
 --   print("Launching download: " .. cmd)
    os.execute(cmd)
    last_artist = artist
end


-- Modified update_song_details function
local function update_song_details()
    local players = {"spotify", "vlc", "audacious"} -- add players here
    player_status = ""

    for _, player in ipairs(players) do
        if is_player_running(player) then
            player_status = player
            break
        end
    end

    if player_status == "" then
        -- Reset details if no player is running
        song_title, song_artist, song_album = "", "", ""
        song_length, song_position, scroll_position = 0, 0, 0
        album_art_url = ""
        last_artist = "" -- Also reset last_artist when no player is running
        return
    end

    -- Fetch details using playerctl
    song_title = safe_popen("playerctl --player=" .. player_status .. " metadata title")
    song_artist = safe_popen("playerctl --player=" .. player_status .. " metadata artist")
    song_album = safe_popen("playerctl --player=" .. player_status .. " metadata album")

    local length_output = safe_popen("playerctl --player=" .. player_status .. " metadata mpris:length")
    local position_output = safe_popen("playerctl --player=" .. player_status .. " position")
    song_length = tonumber(length_output) and tonumber(length_output) / 1000000 or 0
    song_position = tonumber(position_output) or 0

    -- ALBUM ART HANDLING FIRST (PRIORITY)
    if player_status == "vlc" or player_status == "audacious" then  -- add "or" variable here if another player is added
        local new_album_art_url = get_album_art_from_lastfm()
        if new_album_art_url ~= album_art_url then
            album_art_url = new_album_art_url
            download_album_art(album_art_url, album_art_path)
        end
    else
        -- Use mpris:artUrl for Spotify or other players
        local new_album_art_url = safe_popen("playerctl --player=" .. player_status .. " metadata mpris:artUrl")
        if new_album_art_url ~= album_art_url then
            album_art_url = new_album_art_url
            download_album_art(album_art_url, album_art_path)
        end
    end

    -- ARTIST IMAGES HANDLING SECOND (BACKGROUND PROCESS)
    -- REMOVE THE OLD LINE AND KEEP ONLY THE BACKGROUND CALL
    if song_artist ~= "" and song_artist ~= last_artist then
        download_artist_images_background(song_artist)
    end
end



-- Function to scroll the song title 
local function scroll_text(text, max_length)
    if #text <= max_length then
        return text -- No scrolling needed
    end

    -- Update scroll position
    scroll_position = (scroll_position + 1) % (#text + 1)

    -- Extract the scrolling portion
    local start_index = scroll_position + 1
    local end_index = start_index + max_length - 1

    if end_index > #text then
        -- Wrap around if the end index exceeds the text length
        return text:sub(start_index) .. " " .. text:sub(1, end_index - #text)
    else
        return text:sub(start_index, end_index)
    end
end

-- Function to format time as mm:ss
local function format_time(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end


-- Conky functions to get the song details
function conky_get_song_title()
    update_song_details()
    if song_title == "" then
        return "" -- No display if no song is playing
    end
    return scroll_text(song_title, 35)
end

function conky_get_song_artist()
    update_song_details()
    --return song_artist
    return scroll_text(song_artist, 25)
end

function conky_get_song_album()
    update_song_details()
    return scroll_text(song_album, 39)
end

function conky_get_song_progress()
    update_song_details()
    if player_status == "" or song_length == 0 then
        return "" -- No progress bar if no player is running or no song is playing
    end
    return get_progress_bar()
end

function conky_spotify_display_art()
    update_song_details()
    if album_art_url == "" then
        return "" -- No album art to display
    end
    return album_art_path
end

-- Function to draw the volume bar using Cairo
local function draw_bar(cr, pct, pt)
    local bgc, bga, fgc, fga = pt.bg_color, pt.bg_alpha, pt.fg_color, pt.fg_alpha
    local w = pct * pt.width
    local x = pt.x
    local y = pt.y + 6  -- Offset for alignment

    -- Background
    cairo_rectangle(cr, x, y, pt.width, pt.height)
    cairo_set_source_rgba(cr, bgc[1], bgc[2], bgc[3], bga)
    cairo_fill(cr)

    -- Indicator
    cairo_rectangle(cr, x, y, w, pt.height)
    cairo_set_source_rgba(cr, fgc[1], fgc[2], fgc[3], fga)
    cairo_fill(cr)
    cairo_stroke(cr)

    -- Draw volume percentage text
    local volume_text = string.format("%.0f%%", volume * 100)
    cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, 8)
    cairo_set_source_rgba(cr, 0.678, 0.847, 0.902, 1)
    cairo_move_to(cr, bar_properties.x + bar_properties.width + 5, bar_properties.y + bar_properties.height / 2 + 1)
    cairo_show_text(cr, volume_text)

    -- Draw circle indicator
    local circle_x = x + w
    local circle_y = y + pt.height / 2
    local circle_radius = 4
    cairo_arc(cr, circle_x, circle_y, circle_radius, 0, 2 * math.pi)
    cairo_set_source_rgba(cr, fgc[1], fgc[2], fgc[3], fga)
    cairo_fill(cr)
    cairo_stroke(cr)
end

-- Helper function to convert a hex color string to RGBA
local function hex_to_rgba(hex)
    local r, g, b, a = hex:match("^#(%x%x)(%x%x)(%x%x)(%x?%x?)$")
    r = tonumber(r, 16) / 255
    g = tonumber(g, 16) / 255
    b = tonumber(b, 16) / 255
    a = tonumber(a ~= "" and a or "FF", 16) / 255 -- Default alpha to 1.0 if not specified
    return {r, g, b, a}
end

-- Updated function to draw the border
local function draw_rounded_border_with_shade_with_break(x, y, width, height, radius, thickness, border_color, fill_color, break_x, break_width)
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
    cairo_arc(cr, x + width - radius, y + radius, radius, 3 * math.pi / 2, 0)
    cairo_arc(cr, x + width - radius, y + height - radius, radius, 0, math.pi / 2)
    cairo_arc(cr, x + radius, y + height - radius, radius, math.pi / 2, math.pi)
    cairo_arc(cr, x + radius, y + radius, radius, math.pi, 3 * math.pi / 2)
    cairo_close_path(cr)
    cairo_fill(cr)

    -- Draw the border with a break
    cairo_set_source_rgba(cr, border_color[1], border_color[2], border_color[3], border_color[4])
    cairo_set_line_width(cr, thickness)

    -- Top-left corner arc and top border left of the break
    cairo_new_path(cr)
    cairo_arc(cr, x + radius, y + radius, radius, math.pi, 3 * math.pi / 2)
    cairo_line_to(cr, x + break_x, y)
    cairo_stroke(cr) -- Stroke the left part of the top border

    -- Top border right of the break
    cairo_new_path(cr)
    cairo_move_to(cr, x + break_x + break_width, y)
    cairo_line_to(cr, x + width - radius, y)
    cairo_arc(cr, x + width - radius, y + radius, radius, 3 * math.pi / 2, 0)
    cairo_stroke(cr) -- Stroke the right part of the top border

    -- Draw the remaining borders
    cairo_new_path(cr)

    -- Right border
    cairo_move_to(cr, x + width, y + radius)
    cairo_line_to(cr, x + width, y + height - radius)
    cairo_arc(cr, x + width - radius, y + height - radius, radius, 0, math.pi / 2)

    -- Bottom border
    cairo_line_to(cr, x + radius, y + height)
    cairo_arc(cr, x + radius, y + height - radius, radius, math.pi / 2, math.pi)

    -- Left border
    cairo_line_to(cr, x, y + radius)
    cairo_arc(cr, x + radius, y + radius, radius, math.pi, 3 * math.pi / 2)

    cairo_stroke(cr)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

function conky_draw_border_with_shade_hex()
    local x, y = 0, 25 -- set the start position of the border
    local width, height = 335, 135 -- set the size of the border here
    local radius = 10
    local thickness = 0
    local border_color = hex_to_rgba("#6b84b0FF") -- Hex colour + two character transparency code
    local fill_color = hex_to_rgba("#00000000") -- Hex colour + two character transparency code

    -- Break parameters
    local break_x = 42 -- Distance from the left edge of the border to the start of the break
    local break_width = 0 -- Width of the break

    draw_rounded_border_with_shade_with_break(x, y, width, height, radius, thickness, border_color, fill_color, break_x, break_width)
    return ""
end

function conky_draw_image_border()
    local x, y = 15, 45 -- set the start position of the border
    local width, height = 100, 100 -- set the size of the border here
    local radius = 10
    local thickness = 1
    local border_color = hex_to_rgba("#ffffffFF") -- Hex colour + two character transparency code
    local fill_color = hex_to_rgba("#00000033") -- Hex colour + two character transparency code

    -- Break parameters
    local break_x = 42 -- Distance from the left edge of the border to the start of the break
    local break_width = 0 -- Width of the break

    draw_rounded_border_with_shade_with_break(x, y, width, height, radius, thickness, border_color, fill_color, break_x, break_width)
    return ""
end

function conky_draw_border_with_shade_buttons()
    local x, y = 5, 290 -- set the start position of the border
    local width, height = 205, 45 -- set the size of the border here
    local radius = 22
    local thickness = 2
    local border_color = hex_to_rgba("#6b84b0FF") -- Hex colour + two character transparency code
    local fill_color = hex_to_rgba("#00000033") -- Hex colour + two character transparency code

    -- Break parameters
    local break_x = 42 -- Distance from the left edge of the border to the start of the break
    local break_width = 0 -- Width of the break

    draw_rounded_border_with_shade_with_break(x, y, width, height, radius, thickness, border_color, fill_color, break_x, break_width)
    return ""
end

-- Function to draw the horizontal volume bar
function conky_get_volume_bar()
    if conky_window == nil then return "" end -- Return an empty string if the Conky window is nil

    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)

    local volume_output = safe_popen("playerctl volume")
    local volume = tonumber(volume_output) or 0

    -- Define bar properties
    local bar_properties = {
        x = 20,  -- Adjust horizontal position
        y = 280, -- Adjust vertical position
        width = 175, -- Adjust size
        height = 3,
        bg_color = {0.2, 0.2, 0.2}, -- Background color
        bg_alpha = 0.8,
        fg_color = {0.420, 0.518, 0.690}, -- Foreground color
        fg_alpha = 1.0,
    }

    -- Draw the volume bar
    draw_bar(cr, volume, bar_properties)

    -- Draw volume percentage text
   -- local volume_text = string.format("%.0f%%", volume * 100)
    cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, 8)
    cairo_set_source_rgba(cr, 0.678, 0.847, 0.902, 1)
    cairo_move_to(cr, bar_properties.x + bar_properties.width + 10, bar_properties.y + bar_properties.height / 2 + 9)
    cairo_show_text(cr, volume_text)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)

    return "" -- Return an empty string
end

-- Function to draw the vertical volume bar
function conky_volume_bar_vertical()
    if conky_window == nil then return "" end -- Return an empty string if the Conky window is nil

    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)

    local volume_output = safe_popen("playerctl volume")
    local volume = tonumber(volume_output) or 0

    -- Define bar properties
    local bar_properties = {
        x = 115,  -- Adjust horizontal position
        y = 140, -- Adjust vertical position (bottom of bar)
        width = 2, -- Adjust bar width
        height = 92, -- Full height of the bar
        bg_color = {1, 1, 1}, -- Background color
        bg_alpha = 0.8,
        fg_color = {0.6, 0.5411, 0.5215}, -- Foreground color
        fg_alpha = 1.0,
    }

    -- Draw the background bar
    cairo_set_source_rgba(cr, bar_properties.bg_color[1], bar_properties.bg_color[2], bar_properties.bg_color[3], bar_properties.bg_alpha)
    cairo_rectangle(cr, bar_properties.x, bar_properties.y - bar_properties.height, bar_properties.width, bar_properties.height)
    cairo_fill(cr)

    -- Draw the foreground bar (volume level)
    local volume_height = volume * bar_properties.height -- Scale volume to bar height
    cairo_set_source_rgba(cr, bar_properties.fg_color[1], bar_properties.fg_color[2], bar_properties.fg_color[3], bar_properties.fg_alpha)
    cairo_rectangle(cr, bar_properties.x, bar_properties.y - volume_height, bar_properties.width, volume_height)
    cairo_fill(cr)

    -- Draw filled circle at current volume level
    local circle_radius = 4
    cairo_arc(cr, bar_properties.x + bar_properties.width / 2, bar_properties.y - volume_height, circle_radius, 0, 2 * math.pi)
    cairo_fill(cr)

    -- Draw volume percentage text
    local volume_text = string.format("%.0f%%", volume * 100)
    cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, 8)
    cairo_set_source_rgba(cr, 0.678, 0.847, 0.902, 1)
    cairo_move_to(cr, bar_properties.x + bar_properties.width + 145, 135)
    cairo_show_text(cr, volume_text)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)

    return "" -- Return an empty string
end



-- Function to draw the song progress bar using Cairo
local function draw_song_progress_bar(cr, pct, pt)
    local w = pct * pt.width
    local x = pt.x
    local y = pt.y + 6  -- Offset for alignment
    
    -- Convert colors from hex to RGBA
    local bg_rgba = hex_to_rgba(pt.bg_color)
    local fg_rgba = hex_to_rgba(pt.fg_color)

    -- Background
    cairo_rectangle(cr, x, y, pt.width, pt.height)
    cairo_set_source_rgba(cr, table.unpack(bg_rgba))
    cairo_fill(cr)

    -- Indicator
    cairo_rectangle(cr, x, y, w, pt.height)
    cairo_set_source_rgba(cr, table.unpack(fg_rgba))
    cairo_fill(cr)
    cairo_stroke(cr)

    -- Ensure the circle does not go beyond the bar width
    local circle_x = math.min(x + w, x + pt.width)
    local circle_y = y + pt.height / 2
    local circle_radius = 4
    cairo_arc(cr, circle_x, circle_y, circle_radius, 0, 2 * math.pi)
    cairo_set_source_rgba(cr, table.unpack(fg_rgba))
    cairo_fill(cr)
    cairo_stroke(cr)
end

-- Function to format time as mm:ss
local function format_time(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end

-- Function to draw the song progress bar

function conky_draw_song_progress()
    if conky_window == nil then return "" end -- Return an empty string if the Conky window is nil

    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)

    update_song_details() -- Ensure song details are updated before using them

    local progress = song_length > 0 and (song_position / song_length) or 0

    -- Define bar properties
    local bar_properties = {
        x = 125,  -- Adjust horizontal position
        y = 105, -- Adjust vertical position
        width = 130, -- Adjust size
        height = 2,
        bg_color = "#ffffffCC", -- Background color in hex (with alpha)
        fg_color = "#978889FF", -- Foreground color in hex (with alpha)
    }

    -- Draw the song progress bar
    draw_song_progress_bar(cr, progress, bar_properties)

    -- Draw the text (song length and remaining time)
    local show_slash = true -- Toggle this to true/false to enable or disable the slash
    local song_length_text = format_time(song_length) .. (show_slash and " /" or "")
    local remaining_time_text = "-" .. format_time(math.max(0, song_length - song_position))

    local text_color = hex_to_rgba("#ADD8E6FF")

    -- Draw song length text
    cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, 8)
    cairo_set_source_rgba(cr, table.unpack(text_color))
   cairo_move_to(cr, bar_properties.x + bar_properties.width + 5, bar_properties.y + bar_properties.height / 2 + 10)
    cairo_show_text(cr, song_length_text)

    -- Draw remaining time text
    cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, 8)
    cairo_set_source_rgba(cr, table.unpack(text_color))
    cairo_move_to(cr, bar_properties.x + bar_properties.width + 40, bar_properties.y + bar_properties.height / 2 + 10)
    cairo_show_text(cr, remaining_time_text)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)

    return "" -- Return an empty string
end

function conky_circle_vol_bar()
    if conky_window == nil then return "" end -- Return an empty string if the Conky window is nil

    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)

    -- Get volume level
    local volume_output = safe_popen("playerctl volume")
    local volume = tonumber(volume_output) or 0

    -- Define parameters for the circular volume bar
    local center_x = 60 -- X coordinate of the center of the circle
    local center_y = 95 -- Y coordinate of the center of the circle
    local radius = 47 -- Radius of the circle
    local thickness = 3 -- Thickness of the bar
    local bg_color = hex_to_rgba("#FFFFFF33") -- Background color (hex with alpha)
    local fg_color = hex_to_rgba("#dd5a17FF") -- Foreground color (hex with alpha)
    local fg_alpha = 1.0 -- Foreground alpha
    local bg_alpha = 0.3 -- Background alpha

    -- Draw the background circle
    cairo_set_source_rgba(cr, bg_color[1], bg_color[2], bg_color[3], bg_alpha)
    cairo_set_line_width(cr, thickness)
    cairo_arc(cr, center_x, center_y, radius, 0, 2 * math.pi)
    cairo_stroke(cr)

    -- Draw the foreground circle (volume level)
    cairo_set_source_rgba(cr, fg_color[1], fg_color[2], fg_color[3], fg_alpha)
    cairo_set_line_width(cr, thickness)
    local end_angle = 2 * math.pi * volume -- Calculate the end angle based on volume
    cairo_arc(cr, center_x, center_y, radius, -math.pi / 2, -math.pi / 2 + end_angle)
    cairo_stroke(cr)

    -- Clean up
    cairo_destroy(cr)
    cairo_surface_destroy(cs)

    return "" -- Return an empty string
end

function conky_song_progress_arc()
    if conky_window == nil then return "" end -- Return an empty string if the Conky window is nil

    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)

    -- Update song details
    update_song_details()

    -- Calculate progress
    local progress = song_length > 0 and (song_position / song_length) or 0

    -- Define parameters for the arc progress bar
    local center_x = 60 -- X coordinate of the center of the arc
    local center_y = 95 -- Y coordinate of the center of the arc
    local radius = 49 -- Radius of the arc
    local thickness = 4 -- Thickness of the arc
    local bg_color = hex_to_rgba("#FFFFFF33") -- Background color (hex with alpha)
    local fg_color = hex_to_rgba("#5eb5d1FF") -- Foreground color (hex with alpha)
    local fg_alpha = 1.0 -- Foreground alpha
    local bg_alpha = 0.3 -- Background alpha

    -- Draw the background arc (empty progress)
    cairo_set_source_rgba(cr, bg_color[1], bg_color[2], bg_color[3], bg_alpha)
    cairo_set_line_width(cr, thickness)
    cairo_arc(cr, center_x, center_y, radius, 3 * math.pi / 6, math.pi * 1.5) -- Half-circle from 6 to 12 o'clock
    cairo_stroke(cr)

    -- Draw the foreground arc (progress)
    cairo_set_source_rgba(cr, fg_color[1], fg_color[2], fg_color[3], fg_alpha)
    cairo_set_line_width(cr, thickness)
    local start_angle = 1 * math.pi / 2 -- Start at 6 o'clock
    local end_angle = start_angle + (math.pi * progress) -- Progress clockwise (half-circle)
    cairo_arc(cr, center_x, center_y, radius, start_angle, end_angle)
    cairo_stroke(cr)

    -- Clean up
    cairo_destroy(cr)
    cairo_surface_destroy(cs)

    return "" -- Return an empty string
end


-- Draw a rounded rectangle helper
local function draw_rounded_rect(cr, x, y, w, h, r)
    cairo_new_sub_path(cr)
    cairo_arc(cr, x + w - r, y + r, r, -math.pi/2, 0)
    cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi/2)
    cairo_arc(cr, x + r, y + h - r, r, math.pi/2, math.pi)
    cairo_arc(cr, x + r, y + r, r, math.pi, 1.5*math.pi)
    cairo_close_path(cr)
end

-- Generic curved bar drawer
local function draw_curved_progress_bar(cr, pct, pt)
    local bg = hex_to_rgba(pt.bg_color)
    local fg = hex_to_rgba(pt.fg_color)

    -- Background
    draw_rounded_rect(cr, pt.x, pt.y, pt.width, pt.height, pt.radius or 6)
    cairo_set_source_rgba(cr, bg[1], bg[2], bg[3], pt.bg_alpha or bg[4])
    cairo_fill(cr)

    -- Foreground
    local w = math.max(0, pct * pt.width)
    if w > 0 then
        draw_rounded_rect(cr, pt.x, pt.y, w, pt.height, pt.radius or 6)
        cairo_set_source_rgba(cr, fg[1], fg[2], fg[3], pt.fg_alpha or fg[4])
        cairo_fill(cr)
    end
end

-- SONG PROGRESS BAR (curved, with configurable labels)
function conky_curved_progress_bar()
    if conky_window == nil then return "" end
    local cs = cairo_xlib_surface_create(conky_window.display,
                                         conky_window.drawable,
                                         conky_window.visual,
                                         conky_window.width,
                                         conky_window.height)
    local cr = cairo_create(cs)

    update_song_details()
    local pct = song_length > 0 and (song_position / song_length) or 0

    -- bar properties
    local props = {
        x = 45, y = 155,
        width = 265, height = 10,
        bg_color = "#969696AA",
        fg_color = "#5eb5d1FF",
        radius = 6,
    }

    -- label properties
    local label_props = {
        elapsed = {
            enabled = true,
            x = props.x - 35,
            y = props.y + 8,
            font_size = 9,
            font_color = "#FFFFFFFF",
            prefix = "",  -- e.g. "▶ " if you want
        },
        remaining = {
            enabled = true,
            x = props.x + props.width + 6,
            y = props.y + 8,
            font_size = 9,
            font_color = "#FFFFFFFF",
            prefix = "-", -- prefix before remaining time
        }
    }

    -- draw bar
    draw_curved_progress_bar(cr, pct, props)

    -- draw elapsed label
    if label_props.elapsed.enabled then
        local col = hex_to_rgba(label_props.elapsed.font_color)
        cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, label_props.elapsed.font_size)
        cairo_set_source_rgba(cr, table.unpack(col))

        cairo_move_to(cr, label_props.elapsed.x, label_props.elapsed.y)
        cairo_show_text(cr,
            (label_props.elapsed.prefix or "") .. format_time(song_position))
    end

    -- draw remaining label
    if label_props.remaining.enabled then
        local col = hex_to_rgba(label_props.remaining.font_color)
        cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, label_props.remaining.font_size)
        cairo_set_source_rgba(cr, table.unpack(col))

        cairo_move_to(cr, label_props.remaining.x, label_props.remaining.y)
        cairo_show_text(cr,
            (label_props.remaining.prefix or "") ..
            format_time(math.max(0, song_length - song_position)))
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    return ""
end



-- VOLUME BAR (curved, horizontal or vertical, with configurable label inside Lua)
function conky_curved_volume_bar(orientation, show_label)
    if conky_window == nil then return "" end
    local cs = cairo_xlib_surface_create(conky_window.display,
                                         conky_window.drawable,
                                         conky_window.visual,
                                         conky_window.width,
                                         conky_window.height)
    local cr = cairo_create(cs)

    -- get volume
    local volume_output = safe_popen("playerctl volume")
    local volume = tonumber(volume_output) or 0
    local volume_text = string.format("%.0f%%", volume * 100)

    -- bar properties
    local props = {
        x = 128, y = 110,
        width = 220, height = 8,
        bg_color = "#969696AA",
        fg_color = "#dd5a17FF",
        radius = 4,
    }

    -- label properties (configure here)
    local label_props = {
        enabled = true,
        x = 145,
        y = 58,
        prefix = " ",
        font_size = 0,
        font_color = "#dd5a17FF", -- red with full opacity
    }

    -- draw bar
    if orientation == "vertical" then
        local pct_h = volume * props.height
        -- background
        draw_rounded_rect(cr, props.x, props.y - props.height, props.width, props.height, props.radius)
        cairo_set_source_rgba(cr, table.unpack(hex_to_rgba(props.bg_color)))
        cairo_fill(cr)
        -- foreground
        draw_rounded_rect(cr, props.x, props.y - pct_h, props.width, pct_h, props.radius)
        cairo_set_source_rgba(cr, table.unpack(hex_to_rgba(props.fg_color)))
        cairo_fill(cr)
    else
        draw_curved_progress_bar(cr, volume, props)
    end

    -- label
    if show_label and label_props.enabled then
        local text_color = hex_to_rgba(label_props.font_color)

        cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, label_props.font_size)
        cairo_set_source_rgba(cr, table.unpack(text_color))

        cairo_move_to(cr, label_props.x, label_props.y)
        cairo_show_text(cr, (label_props.prefix or "VOL ") .. volume_text)
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    return ""
end
