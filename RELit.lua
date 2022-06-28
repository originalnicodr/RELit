--By originalnicodr and Otis_inf

local lightsTable = {}
local lightCounter = 0
local gameName = reframework:get_game_name()

function create_gameobj(name, component_names)
    local new_gameobj = sdk.find_type_definition("via.GameObject"):get_method("create(System.String)"):call(nil, name)
    if new_gameobj and new_gameobj:add_ref() and new_gameobj:call(".ctor") then
        for i, comp_name in ipairs(component_names or {}) do 
            local td = sdk.find_type_definition(comp_name)
            local new_component = td and new_gameobj:call("createComponent(System.Type)", td:get_runtime_type())
            if new_component and new_component:add_ref() then 
                new_component:call(".ctor()")
            end
        end
        return new_gameobj
    end
end

local function lua_find_component(gameobj, component_name)
	local out = gameobj:call("getComponent(System.Type)", sdk.typeof(component_name))
	if out then return out end
	local components = gameobj:call("get_Components")
	if tostring(components):find("SystemArray") then
		components = components:get_elements()
		for i, component in ipairs(components) do 
			if component:call("ToString") == component_name then 
				return component
			end
		end
	end
end

function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end
 
local function write_vec34(managed_object, offset, vector, doVec3)
	if sdk.is_managed_object(managed_object) then 
		managed_object:write_float(offset, vector.x)
		managed_object:write_float(offset + 4, vector.y)
		managed_object:write_float(offset + 8, vector.z)
		if not doVec3 and vector.w then managed_object:write_float(offset + 12, vector.w) end
	end
end

local function write_mat4(managed_object, offset, mat4)
	if sdk.is_managed_object(managed_object) then 
		write_vec34(managed_object, offset, 	 mat4[0])
		write_vec34(managed_object, offset + 16, mat4[1])
		write_vec34(managed_object, offset + 32, mat4[2])
		write_vec34(managed_object, offset + 48, mat4[3])
	end
end

local function move_light_to_camera(light)
    local lightTransform = light:call("get_Transform")
    local camera = sdk.get_primary_camera()
	local cameraObject = camera:call("get_GameObject")
	local cameraTransform = cameraObject:call("get_Transform")
	lightTransform:set_position(cameraTransform:get_position())
	lightTransform:set_rotation(cameraTransform:get_rotation())
	-- write matrix directly. Matrix is at offset 0x80
	write_mat4(lightTransform, 0x80, cameraTransform:call("get_WorldMatrix"))
end

local function ternary(cond, T, F)
	if cond then return T else return F end
end

local function add_new_light(lTable, createSpotLight, lightNo)

	local componentToCreate = ternary(createSpotLight, "via.render.SpotLight", "via.render.PointLight")
    local new_light = create_gameobj(ternary(createSpotLight, "Spotlight ", "Pointlight ")..tostring(lightNo), {componentToCreate})
	local light_props = lua_find_component(new_light, componentToCreate)
	
    light_props:call("set_Enabled", true)
    light_props:call("set_Color", Vector3f.new(1, 1, 1))
    light_props:call("set_Intensity", 1000.0)
	light_props:call("set_ImportantLevel", 0)
	light_props:call("set_BlackBodyRadiation", false)
	light_props:call("set_UsingSameIntensity", false)
	light_props:call("set_BackGroundShadowEnable", false)
    light_props:call("set_ShadowEnable", true)

    move_light_to_camera(new_light)
	light_props:call("update")
	
    lightTableEntry = {
		id = lightNo,
        light = new_light,
        light_props = light_props,
        showLightEditor = false,
        attachedToCam = false,
		typeDescription = ternary(createSpotLight, "Spotlight ", "Pointlight "),
		isSpotLight = createSpotLight
    }

    table.insert( lTable, lightTableEntry )
end

local function getNewLightNo()
	lightCounter = lightCounter+1
	return lightCounter
end

--UI---------------------------------------------------------
local function handleFloatValue(light_props, captionString, getterFuncName, setterFuncName, stepSize, min, max)
	changed, newValue = imgui.drag_float(captionString, light_props:call(getterFuncName), stepSize, min, max)
	if changed then light_props:call(setterFuncName, newValue) end
end

local function handleBoolValue(light_props, captionString, getterFuncName, setterFuncName)
	changed, enabledValue = imgui.checkbox(captionString, light_props:call(getterFuncName))
	if changed then light_props:call(setterFuncName, enabledValue) end
end

re.on_draw_ui(function()
    imgui.collapsing_header("RELit")

    if imgui.button("Add new spotlight") then 
        add_new_light(lightsTable, true, getNewLightNo())
    end
	imgui.same_line()
    if imgui.button("Add new pointlight") then 
        add_new_light(lightsTable, false, getNewLightNo())
    end

    imgui.spacing()

    for i, lightEntry in ipairs(lightsTable) do
        local light = lightEntry.light
        local light_props = lightEntry.light_props

        imgui.push_id(lightEntry.id)
		local changed, enabledValue = imgui.checkbox("", light_props:call("get_Enabled"))
		if changed then
			light_props:call("set_Enabled", enabledValue)
		end

		imgui.same_line()

		imgui.text(lightEntry.typeDescription..tostring(i))
		imgui.same_line()

		if imgui.button("Move To Camera") then 
			move_light_to_camera(light)
		end

		imgui.same_line()

		local changed, attachedToCamValue = imgui.checkbox("Attach to camera", lightEntry.attachedToCam)
		if changed then
			lightEntry.attachedToCam = attachedToCamValue
		end

		imgui.same_line()

		if imgui.button(" Edit ") then
			lightEntry.showLightEditor = true
		end

		imgui.same_line()

		if imgui.button("Delete") then 
			light:call("destroy", light)
			table.remove(lightsTable, i)
		end

		imgui.pop_id()
    end

    imgui.text(" ")
    imgui.text(" ")
end)


--Light Editor window UI-------------------------------------------------------
re.on_frame(function()
    for i, lightEntry in ipairs(lightsTable) do
		local light = lightEntry.light
		local light_props = lightEntry.light_props

		if lightEntry.attachedToCam then
			move_light_to_camera(light)
		end

        if lightEntry.showLightEditor then

			imgui.push_id(lightEntry.id)
            lightEntry.showLightEditor = imgui.begin_window(lightEntry.typeDescription..tostring(i).." editor", true, 64)

			handleFloatValue(light_props, "Intensity", "get_Intensity", "set_Intensity", 1, 0, 100000)
			
			changed, new_color = imgui.color_picker3("Light color", light_props:call("get_Color"))
			if changed then
				light_props:call("set_Color", new_color)
			end

			if gameName~="dmc5" then
				-- temperature settings don't work for some reason in DMC5
				handleBoolValue(light_props, "Use temperature", "get_BlackBodyRadiation", "set_BlackBodyRadiation")
				handleFloatValue(light_props, "Temperature", "get_Temperature", "set_Temperature", 10, 0, 10000)
			end
			handleFloatValue(light_props, "Bounce intensity", "get_BounceIntensity", "set_BounceIntensity", 0.01, 0, 1000)
			handleFloatValue(light_props, "Min roughness", "get_MinRoughness", "set_MinRoughness", 0.01, 0, 1.0)
			handleFloatValue(light_props, "AO Efficiency", "get_AOEfficiency", "set_AOEfficiency", 0.0001, 0, 10)
			handleFloatValue(light_props, "Volumetric scattering intensity", "get_VolumetricScatteringIntensity", "set_VolumetricScatteringIntensity", 0.01, 0, 100000)

			-- Have no idea what this is
			--changed, newValue = imgui.drag_float("Unit", light_props:call("get_Unit"), 0.01, 0, 100000)
			--if changed then light_props:call("set_Unit", newValue) end

			handleFloatValue(light_props, "Radius", "get_Radius", "set_Radius", 0.01, 0, 100000)
			handleFloatValue(light_props, "Illuminance Threshold", "get_IlluminanceThreshold", "set_IlluminanceThreshold", 0.01, 0, 100000)

			if lightEntry.isSpotLight then
				handleFloatValue(light_props, "Cone", "get_Cone", "set_Cone", 0.01, 0, 1000)
				handleFloatValue(light_props, "Spread", "get_Spread", "set_Spread", 0.01, 0, 100)
				handleFloatValue(light_props, "Falloff", "get_Falloff", "set_Falloff", 0.01, 0, 100)
			end
			handleBoolValue(light_props, "Enable shadows", "get_ShadowEnable", "set_ShadowEnable")
			handleFloatValue(light_props, "Shadow bias", "get_ShadowBias", "set_ShadowBias", 0.0000001, 0, 1.0)
			handleFloatValue(light_props, "Shadow blur", "get_ShadowVariance", "set_ShadowVariance", 0.0001, 0, 1.0)
			handleFloatValue(light_props, "Shadow lod bias", "get_ShadowLodBias", "set_ShadowLodBias", 0.0000001, 0, 1.0)
			handleFloatValue(light_props, "Shadow depth bias", "get_ShadowDepthBias", "set_ShadowDepthBias", 0.0000001, 0, 1.0)
			handleFloatValue(light_props, "Shadow slope bias", "get_ShadowSlopeBias", "set_ShadowSlopeBias", 0.0000001, 0, 1.0)
			handleFloatValue(light_props, "Shadow near plane", "get_ShadowNearPlane", "set_ShadowNearPlane", 0.00001, 0, 1.0)

			if lightEntry.isSpotLight then
				handleFloatValue(light_props, "Detail shadow", "get_DetailShadow", "set_DetailShadow", 0.001, 0, 1.0)
			end 
			
			imgui.spacing()
			imgui.text(" ")
			imgui.same_line()
			if imgui.button("Close") then
				lightEntry.showLightEditor = false
			end
			imgui.spacing()

            imgui.end_window()
			imgui.pop_id()
			light_props:call("update")
        end
    end
end)
-------------------------------------------------------------------------