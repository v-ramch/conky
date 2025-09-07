#!/usr/bin/env lua

-- download_artist_images.lua
local function safe_popen(command)
    local handle = io.popen(command)
    if handle then
        local result = handle:read("*all")
        handle:close()
        return result and result:gsub("%s*$", "") or ""
    end
    return ""
end

local function urlencode(str)
    return str:gsub("([^0-9a-zA-Z ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "+")
end

local function ensure_png_format(input_jpg, output_png)
    local check_type = safe_popen("file -b --mime-type " .. input_jpg)
    if check_type:match("jpeg") then
        os.execute(string.format("convert %s %s", input_jpg, output_png))
        os.remove(input_jpg)
    elseif not check_type:match("png") then
        print("Warning: Unsupported file format - " .. check_type)
    else
        if input_jpg ~= output_png then
            os.rename(input_jpg, output_png)
        end
    end
end

-- Get DuckDuckGo vqd token for image API
local function ddg_get_vqd(query)
    local tmp = "/tmp/ddg_token.html"
    local enhanced_query = query
    local lower_query = query:lower()
    
    local has_music_context = lower_query:match("artist") or 
                             lower_query:match("band") or 
                             lower_query:match("musician") or 
                             lower_query:match("singer") or
                             lower_query:match("rapper") or
                             lower_query:match("dj") or
                             lower_query:match("producer")
    
    if not has_music_context then
        enhanced_query = query .. " music artist"
    end
    
    local q = urlencode(enhanced_query)
    
    os.execute(string.format(
        "wget -q -U 'Mozilla/5.0' -O %s 'https://duckduckgo.com/?q=%s&iax=images&ia=images'",
        tmp, q
    ))
    local html = safe_popen("cat " .. tmp)
    os.remove(tmp)

    local vqd = html:match("vqd='(.-)'") or html:match('vqd=([%d%-]+)')
    return vqd or ""
end

-- Fetch image URLs from DuckDuckGo's JSON endpoint
local function ddg_fetch_image_urls(query)
    local enhanced_query = query
    local lower_query = query:lower()
    
    local has_music_context = lower_query:match("artist") or 
                             lower_query:match("band") or 
                             lower_query:match("musician") or 
                             lower_query:match("singer") or
                             lower_query:match("rapper") or
                             lower_query:match("dj") or
                             lower_query:match("producer")
    
    if not has_music_context then
        enhanced_query = query .. " music artist"
    end
    
    local vqd = ddg_get_vqd(enhanced_query)
    if vqd == "" then return {} end

    local tmp_json = "/tmp/ddg_img.json"
    local url = string.format(
        "https://duckduckgo.com/i.js?l=us-en&o=json&q=%s&vqd=%s&p=1&f=,,,,",
        urlencode(enhanced_query), vqd
    )

    os.execute(string.format(
        "wget -q -U 'Mozilla/5.0' --header='Referer: https://duckduckgo.com/' -O %s '%s'",
        tmp_json, url
    ))

    local json = safe_popen("cat " .. tmp_json)
    os.remove(tmp_json)

    local urls = {}
    for u in json:gmatch('"image"%s*:%s*"([^"]+)"') do
        table.insert(urls, u)
    end
    return urls
end

-- Main function to download artist images
local function download_artist_images(artist)
    if artist == "" then 
        print("No artist provided")
        return 
    end

    local home_path = os.getenv('HOME')
    local img_folder = home_path .. "/.conky/nowplaying/images/"
    
    print("Starting download for artist: " .. artist)
    print("Image folder: " .. img_folder)
    
    os.execute("mkdir -p " .. img_folder)

    -- Cleanup old numbered files
    for i = 1, 5 do
        local jpg_path = string.format("%s%d.jpg", img_folder, i)
        local png_path = string.format("%s%d.png", img_folder, i)
        os.execute("rm -f " .. jpg_path)
        os.execute("rm -f " .. png_path)
    end

    local urls = ddg_fetch_image_urls(artist)
    if #urls == 0 then
        print("No images found for artist: " .. artist)
        return
    end

    -- Shuffle URLs
    math.randomseed(os.time())
    for i = #urls, 2, -1 do
        local j = math.random(i)
        urls[i], urls[j] = urls[j], urls[i]
    end

    local count = math.min(5, #urls)
    for i = 1, count do
        local img_url = urls[i]
        local jpg_path = string.format("%s%d.jpg", img_folder, i)
        local png_path = string.format("%s%d.png", img_folder, i)

        print("Downloading image " .. i .. ": " .. img_url)
        os.execute(string.format("wget -q -U 'Mozilla/5.0' -O '%s' '%s'", jpg_path, img_url))
        ensure_png_format(jpg_path, png_path)
    end
    
    print("Downloaded " .. count .. " images for artist: " .. artist)
end

-- Get all command line arguments and combine them into a single artist name
local artist_arg = ""
if arg and #arg > 0 then
    artist_arg = table.concat(arg, " ")
end

if artist_arg ~= "" then
    download_artist_images(artist_arg)
else
    print("Usage: lua download_artist_images.lua \"Artist Name\"")
end