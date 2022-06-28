--By originalnicodr and Otis_inf

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

    local new_light = create_gameobj(ternary(createSpotLight, "Spotlight ", "Pointlight ")..tostring(lightNo), {ternary(createSpotLight, "via.render.IESLightSpot", "via.render.PointLight")})
	local light_props = lua_find_component(new_light, ternary(createSpotLight, "via.render.SpotLight", "via.render.PointLight"))
	
    light_props:call("set_Enabled", true)
    light_props:call("set_Color", Vector3f.new(1, 1, 1))
    light_props:call("set_Intensity", 10000.0)
	light_props:call("set_ImportantLevel", 0)
	light_props:call("set_BlackBodyRadiation", false)
	light_props:call("set_UsingSameIntensity", false)

    light_props:call("set_ShadowEnable", true)

    -- Aparently you can pass enum vaules like this
    light_props:call("set_ShadowCastFlag", 3)
	
    move_light_to_camera(new_light)
	light_props:call("update")
	
    lightTableEntry = {
		id = lightNo,
        light = new_light,
        light_props = light_props,
        showLightEditor = false,
        attachedToCam = false,
		typeDescription = ternary(createSpotLight, "Spotlight ", "Pointlight ")
    }

    table.insert( lTable, lightTableEntry )
end

local lightsTable = {}
local lightCounter = 0

local function getNewLightNo()
	lightCounter = lightCounter+1
	return lightCounter
end

--UI---------------------------------------------------------
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

		if imgui.button("Edit light") then
			lightEntry.showLightEditor = true
		end

		imgui.same_line()

		if imgui.button("Delete Light") then 
			light:call("destroy", light)
			table.remove(lightsTable, i)
		end

		imgui.pop_id()
    end

    imgui.text(" ")
    imgui.text(" ")
end)

local function common_light_sliders(lightEntry)
    imgui.text("Common light properties")
    imgui.text("---------------------------------")

    local light = lightEntry.light
    local light_props = lightEntry.light_props

    changed, newValue = imgui.drag_float("Intensity", light_props:call("get_Intensity"), 1, 0, 100000)
    if changed then light_props:call("set_Intensity", newValue) end
    
    changed, new_color = imgui.color_picker3("Light color", light_props:call("get_Color"))
    if changed then
        light_props:call("set_BlackBodyRadiation", false)
        light_props:call("set_Color", new_color)
    end

    changed, newValue = imgui.drag_float("Temperature", light_props:call("get_Temperature"), 1, 0, 10000)
    if changed then
        light_props:call("set_BlackBodyRadiation", true)
        light_props:call("set_Temperature", newValue)
    end
    
    changed, newValue = imgui.drag_float("Bounce intensity", light_props:call("get_BounceIntensity"), 0.01, 0, 1000)
    if changed then light_props:call("set_BounceIntensity", newValue) end

    changed, newValue = imgui.drag_float("Min roughness", light_props:call("get_MinRoughness"), 0.01, -10, 100)
    if changed then light_props:call("set_MinRoughness", newValue) end
    
    changed, newValue = imgui.drag_float("AO Efficiency", light_props:call("get_AOEfficiency"), 0.01, 0, 10)
    if changed then light_props:call("set_AOEfficiency", newValue) end

    changed, newValue = imgui.drag_float("Volumetric scattering intensity", light_props:call("get_VolumetricScatteringIntensity"), 0.01, 0, 1000)
    if changed then light_props:call("set_VolumetricScatteringIntensity", newValue) end

    local changed, enabledValue = imgui.checkbox("Using Same Intensity", light_props:call("get_UsingSameIntensity"))
    if changed then
        light_props:call("set_UsingSameIntensity", enabledValue)
    end
end

local function spotlight_sliders(lightEntry)
    imgui.text("Spotlight properties")
    imgui.text("---------------------------------")

    local light = lightEntry.light
    local light_props = lightEntry.light_props

    changed, newValue = imgui.drag_float("Radius", light_props:call("get_Radius"), 0.01, 0, 100000)
    if changed then light_props:call("set_Radius", newValue) end

    changed, newValue = imgui.drag_float("Cone", light_props:call("get_Cone"), 0.01, 0, 100000)
    if changed then light_props:call("set_Cone", newValue) end

    -- Have no idea what this is
    --changed, newValue = imgui.drag_float("Unit", light_props:call("get_Unit"), 0.01, 0, 100000)
    --if changed then light_props:call("set_Unit", newValue) end

    changed, newValue = imgui.drag_float("Effective Range", light_props:call("get_ReferenceEffectiveRange"), 0.01, 0, 100000)
    if changed then light_props:call("set_ReferenceEffectiveRange", newValue) end

    changed, newValue = imgui.drag_float("Spread", light_props:call("get_Spread"), 0.01, 0, 100000)
    if changed then light_props:call("set_Spread", newValue) end

    changed, newValue = imgui.drag_float("Falloff", light_props:call("get_Falloff"), 0.01, 0, 100000)
    if changed then light_props:call("set_Falloff", newValue) end

    local changed, enabledValue = imgui.checkbox("Shadow Enable", light_props:call("get_ShadowEnable"))
    if changed then
        light_props:call("set_ShadowEnable", enabledValue)
    end

    -- Havent noticed much difference with the settings below

    local changed, enabledValue = imgui.checkbox("BackGround Shadow Enable", light_props:call("get_BackGroundShadowEnable"))
    if changed then
        light_props:call("set_BackGroundShadowEnable", enabledValue)
    end

    local changed, enabledValue = imgui.checkbox("Force Shadow Cache Enable", light_props:call("get_ForceShadowCacheEnable"))
    if changed then
        light_props:call("set_ForceShadowCacheEnable", enabledValue)
    end

    local changed, enabledValue = imgui.checkbox("Uniform Shadow Enbale", light_props:call("get_UniformShadowEnbale"))
    if changed then
        light_props:call("set_UniformShadowEnbale", enabledValue)
    end

    changed, newValue = imgui.drag_float("Shadow Lod Bias", light_props:call("get_ShadowLodBias"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowLodBias", newValue) end

    changed, newValue = imgui.drag_float("Shadow Near Plane", light_props:call("get_ShadowNearPlane"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowNearPlane", newValue) end

    changed, newValue = imgui.drag_float("Shadow Variance", light_props:call("get_ShadowVariance"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowVariance", newValue) end

    changed, newValue = imgui.drag_float("Shadow Bias", light_props:call("get_ShadowBias"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowBias", newValue) end

    changed, newValue = imgui.drag_float("Shadow Depth Bias", light_props:call("get_ShadowDepthBias"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowDepthBias", newValue) end

    changed, newValue = imgui.drag_float("Shadow Slope Bias", light_props:call("get_ShadowSlopeBias"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowSlopeBias", newValue) end

    changed, newValue = imgui.drag_float("Detail Shadow", light_props:call("get_DetailShadow"), 0.01, 0, 100000)
    if changed then light_props:call("set_DetailShadow", newValue) end

end

local function pointlight_sliders(lightEntry)
    imgui.text("Pointlight properties")
    imgui.text("---------------------------------")

    local light = lightEntry.light
    local light_props = lightEntry.light_props

    changed, newValue = imgui.drag_float("Radius", light_props:call("get_Radius"), 0.01, 0, 100000)
    if changed then light_props:call("set_Radius", newValue) end

    changed, newValue = imgui.drag_float("Effective Range", light_props:call("get_ReferenceEffectiveRange"), 0.01, 0, 100000)
    if changed then light_props:call("set_ReferenceEffectiveRange", newValue) end

    changed, newValue = imgui.drag_float("Illuminance Threshold", light_props:call("get_IlluminanceThreshold"), 0.01, 0, 100000)
    if changed then light_props:call("set_IlluminanceThreshold", newValue) end

    local changed, enabledValue = imgui.checkbox("Shadow Enable", light_props:call("get_ShadowEnable"))
    if changed then
        light_props:call("set_ShadowEnable", enabledValue)
    end

    local changed, enabledValue = imgui.checkbox("BackGround Shadow Enable", light_props:call("get_BackGroundShadowEnable"))
    if changed then
        light_props:call("set_BackGroundShadowEnable", enabledValue)
    end

    local changed, enabledValue = imgui.checkbox("Force Shadow Cache Enable", light_props:call("get_ForceShadowCacheEnable"))
    if changed then
        light_props:call("set_ForceShadowCacheEnable", enabledValue)
    end

    changed, newValue = imgui.drag_float("Shadow Lod Bias", light_props:call("get_ShadowLodBias"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowLodBias", newValue) end

    changed, newValue = imgui.drag_float("Shadow Near Plane", light_props:call("get_ShadowNearPlane"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowNearPlane", newValue) end

    changed, newValue = imgui.drag_float("Shadow Bias", light_props:call("get_ShadowBias"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowBias", newValue) end

    changed, newValue = imgui.drag_float("Shadow Depth Bias", light_props:call("get_ShadowDepthBias"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowDepthBias", newValue) end

    changed, newValue = imgui.drag_float("Shadow Slope Bias", light_props:call("get_ShadowSlopeBias"), 0.01, 0, 100000)
    if changed then light_props:call("set_ShadowSlopeBias", newValue) end

end
------------------------------------------------------------------------

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

            common_light_sliders(lightEntry)

            if (lightEntry.typeDescription == "Spotlight ") then
                spotlight_sliders(lightEntry)
            else
                pointlight_sliders(lightEntry)
            end

            imgui.end_window()
			imgui.pop_id()
			light_props:call("update")
        end
    end
end)
-------------------------------------------------------------------------