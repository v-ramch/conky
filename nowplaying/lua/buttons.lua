-- 2025 v_ramch

local lgi = require('lgi')
local Gtk = lgi.require('Gtk', '3.0')
local GdkPixbuf = lgi.require('GdkPixbuf', '2.0')
local Gdk = lgi.require('Gdk', '3.0')
local GLib = lgi.require('GLib', '2.0')

local app = Gtk.Application({ application_id = 'com.spotify.controller' })

-- List of supported players
local players = { 'spotify', 'audacious', 'vlc' }

-- Function to get the active player
local function get_active_player()
    for _, player in ipairs(players) do
        local handle = io.popen(string.format('playerctl --player=%s status 2>/dev/null', player))
        local status = handle:read("*l")
        handle:close()
        if status and status ~= "No players found" then
            return player
        end
    end
    return nil
end

function app:on_activate()
    -- Function to load and resize an image
    local function create_resized_image(image_path, width, height)
        local pixbuf = GdkPixbuf.Pixbuf.new_from_file(image_path)
        return pixbuf:scale_simple(width, height, GdkPixbuf.InterpType.BILINEAR)
    end

    -- Apply custom CSS to remove hover and focus effects
    local css_provider = Gtk.CssProvider()
    css_provider:load_from_data([[
        button {
            background: none;
            border: none;
            box-shadow: none;
        }
        button:hover, button:focus, button:active {
            background: none;
            outline: none;
            box-shadow: none;
        }
    ]])
    
    Gtk.StyleContext.add_provider_for_screen(Gdk.Display.get_default():get_default_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    -- Starting location for buttons
    local base_x, base_y = 155, 1127
    local button_size = 20

    -- Define location path for button images
    local image_base_path = '/home/vramch/.conky/nowplaying/buttons/'

    -- Function to create a button with an image, position, and image size
    local function create_button(image_name, x_offset, y_offset, command)
        local image_path = image_base_path .. image_name
        local x, y = base_x + x_offset, base_y + y_offset

        -- Create a transparent window
        local button = Gtk.Window({ 
            type = Gtk.WindowType.TOPLEVEL, 
            decorated = false 
        })
        button:set_default_size(button_size, button_size)
        button:move(x, y)
        button:set_app_paintable(true)

	-- prevent taskbar entries
	button:set_skip_taskbar_hint(true)
	button:set_keep_above(true)   -- optional, keeps above other windows

        -- Ensure proper transparency handling
        local screen = button:get_screen()
        local visual = screen:get_rgba_visual()
        if visual then
            button:set_visual(visual)
        end

        -- Transparent container
        local event_box = Gtk.EventBox()
        event_box:set_visible_window(false)  -- Make sure the event box does not draw anything

        -- Load and resize the image properly
        local pixbuf = GdkPixbuf.Pixbuf.new_from_file(image_path)
        local scaled_pixbuf = pixbuf:scale_simple(button_size, button_size, GdkPixbuf.InterpType.BILINEAR)
        local image = Gtk.Image.new_from_pixbuf(scaled_pixbuf)

        -- Button settings
        local btn = Gtk.Button()
        btn:add(image)
        btn:set_size_request(button_size, button_size)
        btn:set_relief(Gtk.ReliefStyle.NONE)
        btn:set_opacity(1)  -- Ensure the button remains visible
        btn:get_style_context():add_class("flat") -- Prevent highlight on mouseover
        btn:get_style_context():add_class("no-focus") -- Ensure no focus highlight
        btn:set_can_focus(false)  -- Disable focus behavior

        -- Click action
        btn.on_clicked = function()
            local player = get_active_player()
            if player then
                os.execute(string.format('playerctl --player=%s %s', player, command))
            else
                print("No active player found")
            end
        end

        -- Add button inside transparent event box
        event_box:add(btn)
        button:add(event_box)
        button:show_all()

        return button
    end

    -- Function to create a toggle button for shuffle
    local function create_shuffle_button(x_offset, y_offset)
        local shuffle_on_image_path = image_base_path .. 'shuon.png'
        local shuffle_off_image_path = image_base_path .. 'shuoff.png'

        local shuffle_on_image = create_resized_image(shuffle_on_image_path, button_size, button_size)
        local shuffle_off_image = create_resized_image(shuffle_off_image_path, button_size, button_size)

        local x, y = base_x + x_offset, base_y + y_offset

        -- Create a transparent window
        local button = Gtk.Window({ 
            type = Gtk.WindowType.TOPLEVEL, 
            decorated = false 
        })
        button:set_default_size(button_size, button_size)
        button:move(x, y)
        button:set_app_paintable(true)

	-- prevent taskbar entries
	button:set_skip_taskbar_hint(true)
	button:set_keep_above(true)   -- optional, keeps above other windows

        -- Ensure proper transparency handling
        local screen = button:get_screen()
        local visual = screen:get_rgba_visual()
        if visual then
            button:set_visual(visual)
        end

        -- Transparent container
        local event_box = Gtk.EventBox()
        event_box:set_visible_window(false)  -- Make sure the event box does not draw anything

        -- Load and resize the image properly
        local img_shuffle = Gtk.Image.new_from_pixbuf(shuffle_off_image)

        -- Button settings
        local btn = Gtk.Button()
        btn:add(img_shuffle)
        btn:set_size_request(button_size, button_size)
        btn:set_relief(Gtk.ReliefStyle.NONE)
        btn:set_opacity(1)  -- Ensure the button remains visible
        btn:get_style_context():add_class("flat") -- Prevent highlight on mouseover
        btn:get_style_context():add_class("no-focus") -- Ensure no focus highlight
        btn:set_can_focus(false)  -- Disable focus behavior

        -- Function to update the shuffle button image based on the current shuffle status
        local function update_shuffle_image()
            local player = get_active_player()
            if player then
                local handle = io.popen(string.format('playerctl --player=%s shuffle', player))
                local shuffle_status = handle:read("*l")
                handle:close()

                -- Update the image based on the shuffle status
                if shuffle_status == "On" then
                    img_shuffle:set_from_pixbuf(shuffle_on_image)
                else
                    img_shuffle:set_from_pixbuf(shuffle_off_image)
                end
            end
        end

        -- Click action to toggle shuffle
        btn.on_clicked = function()
            local player = get_active_player()
            if player then
                os.execute(string.format('playerctl --player=%s shuffle toggle', player))
                -- Add a small delay to ensure the shuffle status is updated
                GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, function()
                    update_shuffle_image()
                    return false  -- Stop the timeout after running once
                end)
            else
                print("No active player found")
            end
        end

        -- Initialize the shuffle button image based on the current shuffle status
        update_shuffle_image()

        -- Add button inside transparent event box
        event_box:add(btn)
        button:add(event_box)
        button:show_all()

        return button
    end

    -- Create buttons - position will be set from starting location co-ordinates
    local btn_prev = create_button('back.png', 10, 0, 'previous')
    local btn_play_pause = create_button('playbl.png', 44, 0, 'play-pause')
    local btn_next = create_button('next.png', 78, 0, 'next')

   local btn_vol_up = create_button('volume-up.png', 112, 0, 'volume 0.05+')
   local btn_vol_down = create_button('volume-down.png', -24, 0, 'volume 0.05-')

    -- Create shuffle toggle button
    local btn_shuffle = create_shuffle_button(175, 0)

    -- Run the application
    app:add_window(btn_prev)
    app:add_window(btn_play_pause)
    app:add_window(btn_next)
    app:add_window(btn_vol_up)
    app:add_window(btn_vol_down)
    app:add_window(btn_shuffle)
end

app:run({})