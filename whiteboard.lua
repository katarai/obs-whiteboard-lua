-- OBS Whiteboard Script
-- Authors: Mike Welsh (mwelsh@gmail.com), Tari, Exeldro
-- v2.0


obs               = obslua
hotkey_clear      = obs.OBS_INVALID_HOTKEY_ID
hotkey_color      = obs.OBS_INVALID_HOTKEY_ID
hotkey_erase      = obs.OBS_INVALID_HOTKEY_ID
hotkey_mouse      = obs.OBS_INVALID_HOTKEY_ID
needs_clear       = false
swap_pen          = false
eraser            = false
scene_name        = nil
setting_update    = false
draw_line_ends    = true
prev_window       = nil
prev_window_match = false
show_mouse        = true

eraser_v4     = obs.vec4()

color_array   = {}
size_array    = {}
hotkey_array  = {}
eraser_size   = 10
size_max      = 50
pens_max     = 10
pen_count    = 1
pen_index    = 1
mouse_size   = 10
mouse_color  = 0xff0000ff

dot_vert = obs.gs_vertbuffer_t
line_vert = obs.gs_vertbuffer_t
mouse_vert = obs.gs_vertbuffer_t

bit = require("bit")
winapi = require("winapi")
require("winapi.cursor")
require("winapi.keyboard")
require("winapi.window")
require("winapi.winbase")

local source_def = {}
source_def.id = "whiteboard"
source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO, obs.OBS_SOURCE_CUSTOM_DRAW)

source_def.get_name = function()
    return "Whiteboard"
end

source_def.create = function(source, settings)
    local data = {}
    
    data.active = false
    
    obs.vec4_from_rgba(eraser_v4, 0x00000000)
    
    data.mouse_pos = nil
    
    -- Create the vertices needed to draw our lines.
    update_vertices()

    local video_info = obs.obs_video_info()
    if obs.obs_get_video_info(video_info) then
        data.width = video_info.base_width
        data.height = video_info.base_height

        create_whiteboard_texture(data)
    else
        print "Failed to get video resolution"
    end

    return data
end

source_def.destroy = function(data)
    obs.obs_enter_graphics()
    obs.gs_texture_destroy(data.texture)
    obs.obs_leave_graphics()
end

-- A function named script_load will be called on startup
function script_load(settings)
    hotkey_clear = obs.obs_hotkey_register_frontend("whiteboard.clear", "Clear Whiteboard", clear)
    if hotkey_clear == nil then
        hotkey_clear = obs.OBS_INVALID_HOTKEY_ID
    end
    local hotkey_save_array = obs.obs_data_get_array(settings, "whiteboard.clear")
    obs.obs_hotkey_load(hotkey_clear, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
    
    hotkey_color = obs.obs_hotkey_register_frontend("whiteboard.colorswap", "Swap Whiteboard Pencil", penswap)
    if hotkey_color == nil then
        hotkey_color = obs.OBS_INVALID_HOTKEY_ID
    end
    local hotkey_save_array2 = obs.obs_data_get_array(settings, "whiteboard.colorswap")
    obs.obs_hotkey_load(hotkey_color, hotkey_save_array2)
    obs.obs_data_array_release(hotkey_save_array2)
    
    hotkey_erase = obs.obs_hotkey_register_frontend("whiteboard.erasertoggle", "Toggle Whiteboard Eraser", erasertoggle)
    if hotkey_erase == nil then
        hotkey_erase = obs.OBS_INVALID_HOTKEY_ID
    end
    local hotkey_save_array4 = obs.obs_data_get_array(settings, "whiteboard.erasertoggle")
    obs.obs_hotkey_load(hotkey_erase, hotkey_save_array4)
    obs.obs_data_array_release(hotkey_save_array4)

    hotkey_mouse = obs.obs_hotkey_register_frontend("whiteboard.mousetoggle", "Toggle Whiteboard Mouse", mousetoggle)
    if hotkey_mouse == nil then
        hotkey_mouse = obs.OBS_INVALID_HOTKEY_ID
    end
    local hotkey_save_array5 = obs.obs_data_get_array(settings, "whiteboard.mousetoggle")
    obs.obs_hotkey_load(hotkey_mouse, hotkey_save_array5)
    obs.obs_data_array_release(hotkey_save_array5)
    
    script_update(settings)
end

function script_update(settings)
    show_mouse = obs.obs_data_get_bool(settings, "show_mouse")
    mouse_color = obs.obs_data_get_int(settings, "mouse_color")
    mouse_size = obs.obs_data_get_int(settings, "mouse_size")

    pen_count = obs.obs_data_get_int(settings, "pen_count")
    for i = 1, pen_count, 1 
    do 
        local setting_name = "pen_" .. i .. "_color"
        color_array[i] = obs.obs_data_get_int(settings, setting_name)
        setting_name = "pen_" .. i .. "_size"
        size_array[i] = obs.obs_data_get_int(settings, setting_name)
        if #(hotkey_array) < i or hotkey_array[i] == nil or hotkey_array[i] == obs.OBS_INVALID_HOTKEY_ID then
            hotkey_array[i] = obs.obs_hotkey_register_frontend("whiteboard.pen_" .. i .. "_hotkey", "Swap To Whiteboard Pen "..i, (function(pressed) if not pressed then return end swaptopen(i) end))
            if hotkey_array[i] == nil then
                hotkey_array[i] = obs.OBS_INVALID_HOTKEY_ID
            end
            local hotkey_save_array = obs.obs_data_get_array(settings, "whiteboard.".."pen_" .. i .. "_hotkey")
            obs.obs_hotkey_load(hotkey_array[i], hotkey_save_array)
            obs.obs_data_array_release(hotkey_save_array)
        end
    end
    eraser = obs.obs_data_get_bool(settings, "eraser")
    eraser_size = obs.obs_data_get_int(settings, "eraser_size")
    
    -- Set setting_update to true in order to trigger an update to the
    -- vertices used to draw our lines. This is deferred to the graphics
    -- loop (in source_def.video_tick()) to avoid potential race
    -- conditions.
    setting_update = true
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
    local hotkey_save_array = obs.obs_hotkey_save(hotkey_clear)
    obs.obs_data_set_array(settings, "whiteboard.clear", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
    
    hotkey_save_array = obs.obs_hotkey_save(hotkey_color)
    obs.obs_data_set_array(settings, "whiteboard.colorswap", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
       
    hotkey_save_array = obs.obs_hotkey_save(hotkey_erase)
    obs.obs_data_set_array(settings, "whiteboard.erasertoggle", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_mouse)
    obs.obs_data_set_array(settings, "whiteboard.mousetoggle", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    for i = 1, pen_count, 1 
    do 
        if #(hotkey_array) >= i and hotkey_array[i] ~= nil or hotkey_array[i] ~= obs.OBS_INVALID_HOTKEY_ID then
            hotkey_save_array = obs.obs_hotkey_save(hotkey_array[i])
            obs.obs_data_set_array(settings, "whiteboard.pen_" .. i .. "_hotkey", hotkey_save_array)
            obs.obs_data_array_release(hotkey_save_array)
        end
    end
end

source_def.video_tick = function(data, dt)
    local video_info = obs.obs_video_info()

    -- Check to see if stream resoluiton resized and recreate texture if so
    -- TODO: Is there a signal that does this?
    if obs.obs_get_video_info(video_info) and (video_info.base_width ~= data.width or video_info.base_height ~= data.height) then
        data.width = video_info.base_width
        data.height = video_info.base_height
        create_whiteboard_texture(data)
    end

    if data.texture == nil then
        return
    end
    
    if not data.active then
        return
    end

    if needs_clear then
        local prev_render_target = obs.gs_get_render_target()
        local prev_zstencil_target = obs.gs_get_zstencil_target()

        obs.gs_viewport_push()
        obs.gs_set_viewport(0, 0, data.width, data.height)

        obs.obs_enter_graphics()
        obs.gs_set_render_target(data.texture, nil)
        obs.gs_clear(obs.GS_CLEAR_COLOR, obs.vec4(), 1.0, 0)

        obs.gs_viewport_pop()
        obs.gs_set_render_target(prev_render_target, prev_zstencil_target)

        obs.obs_leave_graphics()

        needs_clear = false
    end

    if swap_pen then
        pen_index = pen_index + 1
        if pen_index > pen_count then
            pen_index = 1
        end
        swap_pen = false
        setting_update = true
    end
       
    -- If the size of the pencil was changed, we need to update the
    -- vertices used to draw our line.
    if setting_update then
        update_vertices()
        setting_update = false
    end

    local window = winapi.GetForegroundWindow()
    if window == nil then
        data.mouse_pos = nil
        return
    end
    if window ~= prev_window then
        local buf = winapi.wcs("                                                                                                    ")
        winapi.InternalGetWindowText(window, buf)
        local window_name = winapi.mbs(buf)
        prev_window_match = window_match(window_name) and (string.find(window_name, "Windowed Projector", 1, true) or string.find(window_name, "Fullscreen Projector", 1, true))
        prev_window = window
        return
    end
    if prev_window_match == false then
        data.mouse_pos = nil
        return
    end
    local window_rect = winapi.GetClientRect(window)
    local window_width = window_rect.right - window_rect.left
    local window_height = window_rect.bottom - window_rect.top
    if window_width <= 0 or window_height <= 0 then
        data.mouse_pos = nil
        return
    end

    local mouse_pos = winapi.GetCursorPos()
    if not winapi.ScreenToClient(window, mouse_pos) then
        data.mouse_pos = nil
        return
    end    
    
    local output_aspect = data.width / data.height
    local window_aspect = window_width / window_height
    local offset_x = 0
    local offset_y = 0
    if window_aspect >= output_aspect then
        offset_x = (window_width - window_height * output_aspect) / 2
    else
        offset_y = (window_height - window_width / output_aspect) / 2
    end

    mouse_pos.x = data.width * (mouse_pos.x - offset_x) / (window_width - offset_x*2)
    mouse_pos.y = data.height * (mouse_pos.y - offset_y) / (window_height - offset_y*2)

    if data.mouse_pos ~= nil and data.mouse_pos.x == mouse_pos.x and data.mouse_pos.y == mouse_pos.y then
        return       
    end

    local mouse_valid = mouse_pos.x >= 0 and mouse_pos.x < data.width and mouse_pos.y >= 0 and mouse_pos.y < data.height
    
    local mouse_down = winapi.GetAsyncKeyState(winapi.VK_LBUTTON)
    if mouse_down then
        if data.mouse_pos == nil then
            if not mouse_valid then
                return
            end
            data.mouse_pos = mouse_pos
        end
        if valid_position(mouse_pos.x, mouse_pos.y, data.mouse_pos.x, data.mouse_pos.y, data.width, data.height) then
            effect = obs.obs_get_base_effect(obs.OBS_EFFECT_DEFAULT)
            if not effect then
                return
            end

            obs.obs_enter_graphics()

            local prev_render_target = obs.gs_get_render_target()
            local prev_zstencil_target = obs.gs_get_zstencil_target()

            obs.gs_set_render_target(data.texture, nil)
            obs.gs_viewport_push()
            obs.gs_set_viewport(0, 0, data.width, data.height)
            obs.gs_projection_push()
            obs.gs_ortho(0, data.width, 0, data.height, 0.0, 1.0)

            obs.gs_blend_state_push()
            obs.gs_reset_blend_state()
            
            -- Set the color being used (or set the eraser).
            local solid = obs.obs_get_base_effect(obs.OBS_EFFECT_SOLID)
            local color = obs.gs_effect_get_param_by_name(solid, "color")
            local tech  = obs.gs_effect_get_technique(solid, "Solid")

            local size = 2
            if eraser then
                obs.gs_blend_function(obs.GS_BLEND_SRCALPHA, obs.GS_BLEND_SRCALPHA)
                obs.gs_effect_set_vec4(color, eraser_v4)
                size = eraser_size
            else
                local color_v4 = obs.vec4()
                obs.vec4_from_rgba(color_v4, color_array[pen_index])
                obs.gs_effect_set_vec4(color, color_v4)
                size = size_array[pen_index]
            end
        
            obs.gs_technique_begin(tech)
            obs.gs_technique_begin_pass(tech, 0)

            -- Calculate distance mouse has traveled since our
            -- last update.
            local dx = mouse_pos.x - data.mouse_pos.x
            local dy = mouse_pos.y - data.mouse_pos.y
            local len = math.sqrt(dx*dx + dy*dy)
            local angle = math.atan2(dy, dx)
            
            
            -- Perform matrix transformations for the dot at the
            -- start of the line (start cap).
            obs.gs_matrix_push()
            obs.gs_matrix_identity()
            obs.gs_matrix_translate3f(data.mouse_pos.x, data.mouse_pos.y, 0)

            if draw_line_ends then
                obs.gs_matrix_push()
                obs.gs_matrix_translate3f(-size, -size, 0)
                
                -- Draw start of line.
                obs.gs_load_vertexbuffer(dot_vert)
                obs.gs_draw(obs.GS_LINESTRIP, 0, 0)

                obs.gs_matrix_pop()
            end

            -- Perform matrix transformations for the actual line.
            obs.gs_matrix_rotaa4f(0, 0, 1, angle)
            obs.gs_matrix_translate3f(0, -size, 0)
            obs.gs_matrix_scale3f(len / size, 1.0, 1.0)

            -- Draw actual line.
            obs.gs_load_vertexbuffer(line_vert)
            obs.gs_draw(obs.GS_TRIS, 0, 0)

            if draw_line_ends then
                -- Perform matrix transforms for the dot at the end
                -- of the line (end cap).
                obs.gs_matrix_identity()
                obs.gs_matrix_translate3f(mouse_pos.x, mouse_pos.y, 0)
                obs.gs_matrix_translate3f(-size, -size, 0)
                obs.gs_load_vertexbuffer(dot_vert)
                obs.gs_draw(obs.GS_LINESTRIP, 0, 0)
            end

            -- Done drawing line, restore everything.
            obs.gs_technique_end_pass(tech)
            obs.gs_technique_end(tech)

            obs.gs_matrix_pop()

            obs.gs_projection_pop()
            obs.gs_viewport_pop()
            obs.gs_blend_state_pop()
            obs.gs_set_render_target(prev_render_target, prev_zstencil_target)

            obs.obs_leave_graphics()
            
        end
    end
    if mouse_valid then
        data.mouse_pos = mouse_pos
    else
        data.mouse_pos = nil
    end
end

-- Check whether current foreground window is relevant to us.
function window_match(window_name)
    
    local valid_names = {}
    
    -- If studio mode is enabled, only allow drawing on main
    -- window (Program). If non-studio mode, allow drawing on
    -- the (Preview) window, instead.
    if obs.obs_frontend_preview_program_mode_active() then
        table.insert(valid_names, "(Program)")
    else
        table.insert(valid_names, "(Preview)")
    end
    
    -- Always allow drawing on projection of the scene containing
    -- the active whiteboard.
    if scene_name then
        table.insert(valid_names, scene_name)
    end

    -- Check that the currently selected projector matches one
    -- of the ones listed above.
    for name_index = 1, #valid_names do        
        local start, finish = string.find(window_name, valid_names[name_index], 1, true)
        if start and string.len(window_name) == finish then
            return true
        end
    end
    return false
end

function update_vertices()
    obs.obs_enter_graphics()
    
    -- LINE VERTICES
    -- Create vertices for line of given width (user-defined 'size').
    -- These vertices are for two triangles that make up each line.
    obs.gs_render_start(true)
    local size = 2
    if eraser then
        size = eraser_size
    else
        size = size_array[pen_index]
    end
    local width = size * 2
    obs.gs_vertex2f(0, 0)
    obs.gs_vertex2f(size, 0)
    obs.gs_vertex2f(0, width)
    obs.gs_vertex2f(0, width)
    obs.gs_vertex2f(size, width)
    obs.gs_vertex2f(size, 0)
    
    line_vert = obs.gs_render_save()
    
    
    -- DOT VERTICES
    -- Create vertices for a dot (filled circle) of specified width,
    -- which is used to round off the ends of the lines.
    local decision = 0
    local xcoord = 0
     -- set initial ycoord to radius of circle (user-defined 'size')
    local ycoord = size
    
    obs.gs_render_start(true)
    while ycoord >= xcoord do
        -- shift the actual coordinates by the size of the circle,
        -- so the entire circle has positive coordinates
        local y_pos = ycoord + size
        local y_neg = -ycoord + size
        local x_pos = xcoord + size
        local x_neg = -xcoord + size
        -- create horizontal lines to fill the entire circle
        obs.gs_vertex2f(x_pos, y_pos)
        obs.gs_vertex2f(x_neg, y_pos)
        obs.gs_vertex2f(x_pos, y_neg)
        obs.gs_vertex2f(x_neg, y_neg)
        obs.gs_vertex2f(y_pos, x_pos)
        obs.gs_vertex2f(y_neg, x_pos)
        obs.gs_vertex2f(y_pos, x_neg)
        obs.gs_vertex2f(y_neg, x_neg)
        
        -- update coordinates and decision parameter
        xcoord = xcoord + 1
        if decision < 0 then
            ycoord = ycoord
            decision = decision + (2 * xcoord) + 1
        else
            ycoord = ycoord - 1
            decision = decision + (2 * xcoord) + 1 - (2 * ycoord)
        end
    end
    
    dot_vert = obs.gs_render_save()    

    size = mouse_size
    decision = 0
    xcoord = 0
     -- set initial ycoord to radius of circle (user-defined 'size')
    ycoord = size
    
    obs.gs_render_start(true)
    while ycoord >= xcoord do
        -- shift the actual coordinates by the size of the circle,
        -- so the entire circle has positive coordinates
        local y_pos = ycoord + size
        local y_neg = -ycoord + size
        local x_pos = xcoord + size
        local x_neg = -xcoord + size
        -- create horizontal lines to fill the entire circle
        obs.gs_vertex2f(x_pos, y_pos)
        obs.gs_vertex2f(x_neg, y_pos)
        obs.gs_vertex2f(x_pos, y_neg)
        obs.gs_vertex2f(x_neg, y_neg)
        obs.gs_vertex2f(y_pos, x_pos)
        obs.gs_vertex2f(y_neg, x_pos)
        obs.gs_vertex2f(y_pos, x_neg)
        obs.gs_vertex2f(y_neg, x_neg)
        
        -- update coordinates and decision parameter
        xcoord = xcoord + 1
        if decision < 0 then
            ycoord = ycoord
            decision = decision + (2 * xcoord) + 1
        else
            ycoord = ycoord - 1
            decision = decision + (2 * xcoord) + 1 - (2 * ycoord)
        end
    end
    
    mouse_vert = obs.gs_render_save()    
    obs.obs_leave_graphics()
end

function valid_position(cur_x, cur_y, prev_x, prev_y, width, height)
    -- If the mouse is within the boundaries of the screen, or was
    -- previously within the boundaries of the screen, it is a valid
    -- position to draw a line to.
    if ((cur_x >= 0 and cur_x < width and cur_y >= 0 and cur_y < height)
        or(prev_x >= 0 and prev_x < width and prev_y >= 0 and prev_y < height)) then
        return true
    end    
    return false
end

function clear(pressed)
    if not pressed then
        return
    end

    needs_clear = true
end

function penswap(pressed)
    if not pressed then
        return
    end

    swap_pen = true
    eraser = false
end

function swaptopen(index)
    pen_index = index
    setting_update = true
    eraser = false
end

function erasertoggle(pressed)
    if not pressed then
        return
    end

    eraser = not eraser
    setting_update = true
end

function mousetoggle(pressed)
    if not pressed then
        return
    end
    show_mouse = not show_mouse
end

function clear_button()
    needs_clear = true
end

function image_source_load(image, file)
    obs.obs_enter_graphics()
    obs.gs_image_file_free(image);
    obs.obs_leave_graphics()

    obs.gs_image_file_init(image, file);

    obs.obs_enter_graphics()
    obs.gs_image_file_init_texture(image);
    obs.obs_leave_graphics()

    if not image.loaded then
        print("failed to load texture " .. file);
    end
end

function create_whiteboard_texture(data)
    obs.obs_enter_graphics()
    
    if data.texture ~= nil then
        obs.gs_texture_destroy(data.texture)
    end

    data.texture = obs.gs_texture_create(data.width, data.height, obs.GS_RGBA, 1, nil, obs.GS_RENDER_TARGET)
    print("create whiteboard texture " .. data.width .. " " .. data.height)

    obs.obs_leave_graphics()
end

-- Render our output to the screen.
source_def.video_render = function(data, effect)
    effect = obs.obs_get_base_effect(obs.OBS_EFFECT_DEFAULT)

    if effect and data.texture then
        obs.gs_blend_state_push()
        obs.gs_reset_blend_state()
        obs.gs_matrix_push()
        obs.gs_matrix_identity()

        while obs.gs_effect_loop(effect, "Draw") do
            obs.obs_source_draw(data.texture, 0, 0, 0, 0, false);
        end
        if show_mouse and data.mouse_pos ~= nil then
            --obs.gs_blend_state_push()
            --obs.gs_reset_blend_state()
            
            -- Set the color being used (or set the eraser).
            local solid = obs.obs_get_base_effect(obs.OBS_EFFECT_SOLID)
            local color = obs.gs_effect_get_param_by_name(solid, "color")
            local tech  = obs.gs_effect_get_technique(solid, "Solid")

            local color_v4 = obs.vec4()
            obs.vec4_from_rgba(color_v4, mouse_color)
            obs.gs_effect_set_vec4(color, color_v4)
        
            obs.gs_technique_begin(tech)
            obs.gs_technique_begin_pass(tech, 0)

            obs.gs_matrix_identity()
            obs.gs_matrix_translate3f(data.mouse_pos.x, data.mouse_pos.y, 0)
            obs.gs_matrix_translate3f(-mouse_size, -mouse_size, 0)
            obs.gs_load_vertexbuffer(mouse_vert)
            obs.gs_draw(obs.GS_LINESTRIP, 0, 0)

            obs.gs_technique_end_pass(tech)
            obs.gs_technique_end(tech)
        end

        obs.gs_matrix_pop()
        obs.gs_blend_state_pop()
    end
end

source_def.get_width = function(data)
    return 0
end

source_def.get_height = function(data)
    return 0
end

-- When source is active, get the currently displayed scene's name and
-- set the active flag to true.
source_def.activate = function(data)
    local scene = obs.obs_frontend_get_current_scene()
    scene_name = obs.obs_source_get_name(scene)
    data.active = true
    obs.obs_source_release(scene)
end

source_def.deactivate = function(data)
    data.active = false
end

function pen_count_changed(props, property, settings)
    pen_count = obs.obs_data_get_int(settings, "pen_count")
    for i = 1,pen_count,1 
    do 
        local prop_name = "pen_" .. i .. "_group"
        local p = obs.obs_properties_get(props, prop_name)
        if p == nil then
            local group = obs.obs_properties_create()
            obs.obs_properties_add_group(props, prop_name, "Pen "..i, obs.OBS_GROUP_NORMAL, group)
            prop_name = "pen_" .. i .. "_size"
            obs.obs_properties_add_int_slider(group, prop_name, "Size", 1, size_max, 1)
            prop_name = "pen_" .. i .. "_color"
            obs.obs_properties_add_color(group, prop_name, "Color") 
        end
    end

    for i = pen_count + 1, pens_max, 1 
    do 
        local prop_name = "pen_" .. i .. "_group"
        obs.obs_properties_remove_by_name(props, prop_name)
    end
    return true
end

function script_properties()
    local properties = obs.obs_properties_create()

    obs.obs_properties_add_int_slider(properties, "mouse_size", "Mouse Size", 1, size_max * 2, 1)
    obs.obs_properties_add_color(properties, "mouse_color", "Color")
    obs.obs_properties_add_bool(properties, "show_mouse", "Show Mouse")
   
    obs.obs_properties_add_int_slider(properties, "eraser_size", "Eraser Size", 1, size_max * 2, 1)
    obs.obs_properties_add_bool(properties, "eraser", "Eraser")
    
    obs.obs_properties_add_button(properties, "clear", "Clear Whiteboard", clear_button)
    
    local pens = obs.obs_properties_add_int_slider(properties, "pen_count", "Pens", 1, pens_max, 1)
    obs.obs_property_set_modified_callback(pens, pen_count_changed)
    for i = 1, pen_count, 1 
    do 
        local prop_name = "pen_" .. i .. "_group"
        local p = obs.obs_properties_get(properties, prop_name)
        if p == nil then
            local group = obs.obs_properties_create()
            obs.obs_properties_add_group(properties, prop_name, "Pen "..i, obs.OBS_GROUP_NORMAL, group)
            prop_name = "pen_" .. i .. "_size"
            obs.obs_properties_add_int_slider(group, prop_name, "Size", 1, size_max, 1)
            prop_name = "pen_" .. i .. "_color"
            obs.obs_properties_add_color(group, prop_name, "Color") 
        end
    end
    return properties
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "show_mouse", true)
    obs.obs_data_set_default_int(settings, "mouse_size", 10)
    obs.obs_data_set_default_int(settings, "mouse_color", 0xff0000ff)

    obs.obs_data_set_default_int(settings, "eraser_size", 10)
    obs.obs_data_set_default_bool(settings, "eraser", false)
    obs.obs_data_set_default_int(settings, "pen_count", 1)
    obs.obs_data_set_default_int(settings, "pen_1_size", 2)
    obs.obs_data_set_default_int(settings, "pen_1_color", 0xFF000000)
end

function script_description()
    -- Using [==[ and ]==] as string delimiters, purely for IDE syntax parsing reasons.
    return [==[Adds a whiteboard.
    
Add this source on top of your scene, then project your entire scene and draw on the projector window. Each scene can have one whiteboard.
    
Hotkeys can be set to toggle pen, mouse and eraser. An additional hotkey can be set to wipe the canvas.
    
The settings on this page will unfortunately not update in real-time when using hotkeys, due to limitations with OBS's script properties.]==]
end


obs.obs_register_source(source_def)
