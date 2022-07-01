--//////////////////////////////////////////////////////////////////////////////////////////////
--MIT License
--Copyright (c) 2022 Frans 'Otis_Inf' Bouma & Nicolás 'originalnicodr' Uriel Navall 
--
--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.
--//////////////////////////////////////////////////////////////////////////////////////////////
-- Changelog
-- v1.11	- Added scene light usage, refactored code, tweaked settings, restructured the UI to use a separate window, tweaked the light editor to use an initial size
-- v1.1		- Added tonemapping settings and updated some initial values
-- v1.0		- First release
--//////////////////////////////////////////////////////////////////////////////////////////////

-----------Globals and Constants-----------
local DEBUG = false			-- set to true to enable debug controls and other debug code.

local relitVersion = "1.11"

local lightsTable = {}
local lightCounter = 0
local gameName = reframework:get_game_name()
local mainWindowVisible = false

-- light setting defaults
local intensityDefault = 1000.0
local colorDefault = Vector3f.new(1, 1, 1)
local shadowBiasDefault = 0.00050
local shadowDepthBiasDefault = 0.001
local shadowSlopeBiasDefault = 0.000055

local sceneLights = {}
local switchedOnOffSceneLights = {}

local customTonemapping = {
	autoExposure = true,
	exposure = 0,
	isInitialized = false
}
---------------------------------------

-----------Utility functions-----------

function create_gameobj(name, component_names)
    local newGameobj = sdk.find_type_definition("via.GameObject"):get_method("create(System.String)"):call(nil, name)
    if newGameobj and newGameobj:add_ref() and newGameobj:call(".ctor") then
        for i, compName in ipairs(component_names or {}) do 
            local td = sdk.find_type_definition(compName)
            local newComponent = td and newGameobj:call("createComponent(System.Type)", td:get_runtime_type())
            if newComponent and newComponent:add_ref() then 
                newComponent:call(".ctor()")
            end
        end
        return newGameobj
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

local function get_component_by_type(game_object, type_name)
    local t = sdk.typeof(type_name)

    if t == nil then 
        return nil
    end

    return game_object:call("getComponent(System.Type)", t)
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
 
local function write_vec34(managedObject, offset, vector, doVec3)
	if sdk.is_managed_object(managedObject) then 
		managedObject:write_float(offset, vector.x)
		managedObject:write_float(offset + 4, vector.y)
		managedObject:write_float(offset + 8, vector.z)
		if not doVec3 and vector.w then managedObject:write_float(offset + 12, vector.w) end
	end
end

local function write_mat4(managedObject, offset, mat4)
	if sdk.is_managed_object(managedObject) then 
		write_vec34(managedObject, offset, 	 mat4[0])
		write_vec34(managedObject, offset + 16, mat4[1])
		write_vec34(managedObject, offset + 32, mat4[2])
		write_vec34(managedObject, offset + 48, mat4[3])
	end
end

local function move_light_to_camera(lightGameObject)
    local lightTransform = lightGameObject:call("get_Transform")
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

local function get_new_light_no()
	lightCounter = lightCounter+1
	return lightCounter
end

------------------------------------------

local function add_new_light(createSpotLight, lightNo)
	local componentToCreate = ternary(createSpotLight, "via.render.SpotLight", "via.render.PointLight")
    local lightGameObject = create_gameobj(ternary(createSpotLight, "Spotlight ", "Pointlight ")..tostring(lightNo), {componentToCreate})
	local lightComponent = lua_find_component(lightGameObject, componentToCreate)
	
	local newLightIntensity = intensityDefault
	if gameName == "re8" then
		newLightIntensity = newLightIntensity * 10
	end
    lightComponent:call("set_Enabled", true)
    lightComponent:call("set_Color", colorDefault)
    lightComponent:call("set_Intensity", newLightIntensity)
	lightComponent:call("set_ImportantLevel", 0)
	lightComponent:call("set_BlackBodyRadiation", false)
	lightComponent:call("set_UsingSameIntensity", false)
	lightComponent:call("set_BackGroundShadowEnable", false)
    lightComponent:call("set_ShadowEnable", true)
	lightComponent:call("set_ShadowBias", shadowBiasDefault)
	lightComponent:call("set_ShadowVariance", 0)
	lightComponent:call("set_ShadowDepthBias", shadowDepthBiasDefault)
	lightComponent:call("set_ShadowSlopeBias", shadowSlopeBiasDefault)

    move_light_to_camera(lightGameObject)
	lightComponent:call("update")
	
    lightTableEntry = {
		id = lightNo,
        lightGameObject = lightGameObject,
        lightComponent = lightComponent,
        showLightEditor = false,
        attachedToCam = false,
		typeDescription = ternary(createSpotLight, "Spotlight ", "Pointlight "),
		isSpotLight = createSpotLight,
		showGizmo = false
    }

    table.insert(lightsTable, lightTableEntry )
end

local function switch_on_scene_lights()
	for i, lightEntry in ipairs(switchedOnOffSceneLights) do
		local lightGameObject = lightEntry.lightGameObject
		lightEntry.isEnabled = true
		lightGameObject:write_byte(0x13, 1)
	end
	-- clear the table. Holy moly this language is ... limited
	for k,v in pairs(switchedOnOffSceneLights) do switchedOnOffSceneLights[k]=nil end
end

local function switch_off_scene_lights()
	for i, lightEntry in ipairs(sceneLights) do
		if lightEntry.isEnabled then
			lightEntry.isEnabled = false
			local lightGameObject = lightEntry.lightGameObject
			lightGameObject:write_byte(0x13, 0)
			table.insert(switchedOnOffSceneLights, lightEntry)
		end
	end
end

local function get_scene_lights()
	local scene_manager = sdk.get_native_singleton("via.SceneManager")
	local scene_manager_type = sdk.find_type_definition("via.SceneManager")
	local scene = sdk.call_native_func(scene_manager, scene_manager_type, "get_CurrentScene")

	local transforms = scene:call("findComponents(System.Type)", sdk.typeof("via.Transform"))
	imgui.text(dump(transforms))

	local sceneLights = {}
		
	if tostring(transforms):find("SystemArray") and sdk.is_managed_object(transforms) then 
		for i, xform in ipairs(transforms) do 
			local gameObject = xform:call("get_GameObject")
			local lightType = " (SpotLight)"
			-- why would anyone want to use a switch/case statement.... 
			local component = get_component_by_type(gameObject,"via.render.SpotLight")
			if component == nil then
				component = get_component_by_type(gameObject, "via.render.PointLight")
				if component == nil then
					component = get_component_by_type(gameObject, "via.render.AreaLight")
					if component == nil then
						component = get_component_by_type(gameObject, "via.render.DirectionalLight")
						if component == nil then
							component = get_component_by_type(gameObject, "via.render.ProjectionSpotLight")
							if component == nil then
								component = get_component_by_type(gameObject, "via.render.SkyLight")
								if component == nil then
									component = get_component_by_type(gameObject, "via.render.Light")
									if component ~= nil then
										lightType = " (Light)"
									end
								else
									lightType = " (SkyLight)"
								end
							else
								lightType = " (ProjectionSpotLight)"
							end
						else
							lightType = " (DirectionalLight)"
						end
					else
						lightType = " (AreaLight)"
					end
				else
					lightType = " (PointLight)"
				end
			end
			
			if component ~= nil then
				sceneLightsEntry = {
					id = i,
					lightComponent = component,
					lightGameObject = gameObject,
					name = gameObject:call("get_Name")..lightType,
					isEnabled = component:call("get_Enabled")
				}
				table.insert(sceneLights, sceneLightsEntry)
			end
		end
	end
	return sceneLights
end

--UI---------------------------------------------------------
local function ui_margin()
	imgui.text(" ")
	imgui.same_line()
end

local function handle_float_value(lightComponent, captionString, getterFuncName, setterFuncName, stepSize, min, max)
	ui_margin()
	changed, newValue = imgui.drag_float(captionString, lightComponent:call(getterFuncName), stepSize, min, max)
	if changed then lightComponent:call(setterFuncName, newValue) end
end

local function handle_bool_value(lightComponent, captionString, getterFuncName, setterFuncName)
	ui_margin()
	changed, enabledValue = imgui.checkbox(captionString, lightComponent:call(getterFuncName))
	if changed then lightComponent:call(setterFuncName, enabledValue) end
end

--WIP--
function draw_gizmo(gameObject)
	local transform = gameObject:call("get_Transform")
    if transform == nil then return end

    local mat = transform:call("get_WorldMatrix")
    local changed = false

    changed, newMat = draw.gizmo(transform:get_address(), mat)

    if changed then
        transform:set_rotation(newMat:to_quat())
        transform:set_position(newMat[3])
    end

	draw.gizmo(transform:get_address(), newMat)
end

local function sliders_change_pos(lightGameObject)
    local lightGameObjectTransform = lightGameObject:call("get_Transform")
    local lightGameObjectPos = lightGameObjectTransform:get_position()
	local lightGameObjectAngles = lightGameObjectTransform:call("get_EulerAngle")
	
	if imgui.tree_node("Position / orientation") then
		-- X is right, Y is up, Z is out of the screen
		ui_margin()
		changedX, newXValue = imgui.drag_float("X (right)", lightGameObjectPos.x, 0.01, -10000, 10000)
		ui_margin()
		changedY, newYValue = imgui.drag_float("Y (up)", lightGameObjectPos.y, 0.01, -10000, 10000)
		ui_margin()
		changedZ, newZValue = imgui.drag_float("Z (out of the screen)", lightGameObjectPos.z, 0.01, -10000, 10000)

		ui_margin()
		changedPitch, newPitchValue = imgui.drag_float("Pitch", lightGameObjectAngles.x, 0.001, -3.1415924, 3.1415924)
		ui_margin()
		changedYaw, newYawValue = imgui.drag_float("Yaw", lightGameObjectAngles.y, 0.001, -3.1415924, 3.1415924)
		imgui.tree_pop()
	end
    if changedX or changedY or changedZ then
        if not changedX then newXValue = lightGameObjectPos.x end
        if not changedY then newYValue = lightGameObjectPos.y end
        if not changedZ then newZValue = lightGameObjectPos.z end
        lightGameObjectTransform:set_position(Vector3f.new(newXValue, newYValue, newZValue))
    end
	
	if changedPitch or changedYaw then
		if not changedPitch then newPitchValue = lightGameObjectAngles.x end
		if not changedYaw then newYawValue = lightGameObjectAngles.y end
		lightGameObjectTransform:call("set_EulerAngle", Vector3f.new(newPitchValue, newYawValue, lightGameObjectAngles.z))
		-- now grab the local matrix and write that as the world matrix, as the world matrix isn't updated but the local matrix is (and they should be the same)
		write_mat4(lightGameObjectTransform, 0x80, lightGameObjectTransform:call("get_LocalMatrix"))
	end
end

local function scene_lights_menu()
	if imgui.tree_node("Scene Lights") then
		-- first check if we've switched off all lights. If so, we can't update the scene lights till we switch them back on.
		local showUpdateSceneLightsButton = switchedOnOffSceneLights[1]== nil
		if showUpdateSceneLightsButton then
			if imgui.button("Update scene lights") then 
				sceneLights = get_scene_lights()
			end
		end
		
		if sceneLights[1] then
			if showUpdateSceneLightsButton then
				imgui.same_line()
			end

			local hasBulkSwitchedOffLights = (switchedOnOffSceneLights[1]~=nil)
			if imgui.button(ternary(hasBulkSwitchedOffLights, "Switch scene lights back on", "Switch off scene lights")) then
				if hasBulkSwitchedOffLights then
					switch_on_scene_lights()
				else
					switch_off_scene_lights()
				end
			end
		end
		
		for i, sceneLightsEntry in ipairs(sceneLights) do 
			local lightComponent = sceneLightsEntry.lightComponent
			local lightGameObject = sceneLightsEntry.lightGameObject
			
			imgui.push_id(sceneLightsEntry.id)
			local isEnabled = sceneLightsEntry.isEnabled			-- we need to do it this way otherwise Lua throws an error if we directly write the imgui.checkbox value into entry.isenabled
			local changed, isEnabled = imgui.checkbox("", isEnabled)
			if changed then
				sceneLightsEntry.isEnabled = isEnabled
				lightGameObject:write_byte(0x13, ternary(sceneLightsEntry.isEnabled, 1, 0))
			end

			imgui.same_line()
			if imgui.tree_node(sceneLightsEntry.name) then
				if imgui.tree_node("Light component") then
					object_explorer:handle_address(lightComponent)
					imgui.tree_pop()
				end
				if imgui.tree_node("Light game object") then
					object_explorer:handle_address(lightGameObject)
					imgui.tree_pop()
				end
				imgui.tree_pop()
			end
			imgui.pop_id()
		end

		imgui.tree_pop()
	end
end

local function tonemapping_menu()
	if imgui.tree_node("Tonemapping") then
		local camera = sdk.get_primary_camera()
		local cameraGameObject = camera:call("get_GameObject")
		local toneMapping = get_component_by_type(cameraGameObject,"via.render.ToneMapping")
		
		changed, enabledValue = imgui.checkbox("Auto Exposure", customTonemapping.autoExposure)
		if changed and enabledValue then customTonemapping.autoExposure = true end
		if changed and not enabledValue then customTonemapping.autoExposure = false end

		changed, newValue = imgui.drag_float("Exposure", customTonemapping.exposure, 0.01, -5, 25)
		if changed then customTonemapping.exposure = newValue end

		imgui.tree_pop()
	end
end

local function lights_menu()
	if imgui.tree_node("Lights") then
		if imgui.button("Add new spotlight") then 
			add_new_light(true, get_new_light_no())
		end
		imgui.same_line()
		if imgui.button("Add new pointlight") then 
			add_new_light(false, get_new_light_no())
		end

		for i, lightEntry in ipairs(lightsTable) do
			local lightGameObject = lightEntry.lightGameObject
			local lightComponent = lightEntry.lightComponent

			imgui.push_id(lightEntry.id)
			local changed, enabledValue = imgui.checkbox("", lightComponent:call("get_Enabled"))
			if changed then
				lightComponent:call("set_Enabled", enabledValue)
			end

			imgui.same_line()
			imgui.text(lightEntry.typeDescription..tostring(i))

			imgui.same_line()
			if imgui.button(" Edit ") then
				lightEntry.showLightEditor = true
			end

			imgui.same_line()
			if imgui.button("Move To Camera") then 
				move_light_to_camera(lightGameObject)
			end

			imgui.same_line()
			local changed, attachedToCamValue = imgui.checkbox("Attach to camera", lightEntry.attachedToCam)
			if changed then
				lightEntry.attachedToCam = attachedToCamValue
			end

			imgui.same_line()
			if imgui.button("Delete") then 
				lightGameObject:call("destroy", lightGameObject)
				table.remove(lightsTable, i)
			end
			
			imgui.pop_id()
		end
		imgui.tree_pop()
	end
end

function main_menu()
	if mainWindowVisible then 
		imgui.set_next_window_size(Vector2f.new(600, 300), 4)		-- first use ever
		mainWindowVisible = imgui.begin_window("RELit v"..relitVersion, mainWindowVisible, nil)
		
		lights_menu()
		scene_lights_menu()
		tonemapping_menu()

		imgui.text(" ")
		ui_margin()
		imgui.text("--------------------------------------------")
		ui_margin()
		imgui.text("RELit is (c) Originalnicodr & Otis_Inf")
		ui_margin()
		imgui.text("https://framedsc.com")
		ui_margin()
	end
	imgui.end_window()
end

--Light Editor window UI-------------------------------------------------------
function light_editor_menu()
	for i, lightEntry in ipairs(lightsTable) do
		local lightGameObject = lightEntry.lightGameObject
		local lightComponent = lightEntry.lightComponent

		if lightEntry.attachedToCam then
			move_light_to_camera(lightGameObject)
		end

        if lightEntry.showLightEditor then
			imgui.push_id(lightEntry.id)
			imgui.set_next_window_size(Vector2f.new(400, 600), 2)		-- Once
            lightEntry.showLightEditor = imgui.begin_window(lightEntry.typeDescription..tostring(i).." editor", true, 0)

			if DEBUG then
				imgui.spacing()
				ui_margin()
				changed, enabledValue = imgui.checkbox(captionString, lightEntry.showGizmo)
				if changed then lightEntry.showGizmo = enabledValue end
				imgui.same_line()
				imgui.text("Draw debug gizmo")

				if imgui.tree_node("Debug") then
					if imgui.tree_node("Light component") then
						object_explorer:handle_address(lightComponent)
						imgui.tree_pop()
					end
					if imgui.tree_node("Light game object") then
						object_explorer:handle_address(lightGameObject)
						imgui.tree_pop()
					end
					imgui.tree_pop()
				end
			end
			
            sliders_change_pos(lightGameObject)

			if imgui.tree_node("Light characteristics") then
				handle_float_value(lightComponent, "Intensity", "get_Intensity", "set_Intensity", 10, 0, 500000)

				imgui.spacing()
				ui_margin()
				
				changed, new_color = imgui.color_picker3("Light color", lightComponent:call("get_Color"))
				if changed then
					lightComponent:call("set_Color", new_color)
				end

				imgui.spacing()

				if gameName~="dmc5" then
					-- temperature settings don't work for some reason in DMC5
					handle_bool_value(lightComponent, "Use temperature", "get_BlackBodyRadiation", "set_BlackBodyRadiation")
					handle_float_value(lightComponent, "Temperature", "get_Temperature", "set_Temperature", 10, 1000, 20000)
				end
				handle_float_value(lightComponent, "Bounce intensity", "get_BounceIntensity", "set_BounceIntensity", 0.01, 0, 1000)
				handle_float_value(lightComponent, "Min roughness", "get_MinRoughness", "set_MinRoughness", 0.01, 0, 1.0)
				handle_float_value(lightComponent, "AO Efficiency", "get_AOEfficiency", "set_AOEfficiency", 0.0001, 0, 10)
				if gameName~="dmc5" then
					-- volumetric scattering intensity always reverts to 0 in DMC5. In most other games it has little/no effect either but we'll disable it for DMC5 only for now.
					handle_float_value(lightComponent, "Volumetric scattering intensity", "get_VolumetricScatteringIntensity", "set_VolumetricScatteringIntensity", 0.01, 0, 100000)
				end
				handle_float_value(lightComponent, "Radius", "get_Radius", "set_Radius", 0.01, 0, 100000)
				handle_float_value(lightComponent, "Illuminance Threshold", "get_IlluminanceThreshold", "set_IlluminanceThreshold", 0.01, 0, 100000)

				if lightEntry.isSpotLight then
					handle_float_value(lightComponent, "Cone", "get_Cone", "set_Cone", 0.01, 0, 1000)
					handle_float_value(lightComponent, "Spread", "get_Spread", "set_Spread", 0.01, 0, 100)
					handle_float_value(lightComponent, "Falloff", "get_Falloff", "set_Falloff", 0.01, 0, 100)
				end
				
				imgui.tree_pop()
			end
			
			if imgui.tree_node("Shadow settings") then
				imgui.spacing()
				handle_bool_value(lightComponent, "Enable shadows", "get_ShadowEnable", "set_ShadowEnable")
				handle_float_value(lightComponent, "Shadow bias", "get_ShadowBias", "set_ShadowBias", 0.000001, 0, 1.0)
				handle_float_value(lightComponent, "Shadow blur", "get_ShadowVariance", "set_ShadowVariance", 0.0001, 0, 1.0)
				handle_float_value(lightComponent, "Shadow lod bias", "get_ShadowLodBias", "set_ShadowLodBias", 0.0000001, 0, 1.0)
				handle_float_value(lightComponent, "Shadow depth bias", "get_ShadowDepthBias", "set_ShadowDepthBias", 0.00001, 0, 1.0)
				handle_float_value(lightComponent, "Shadow slope bias", "get_ShadowSlopeBias", "set_ShadowSlopeBias", 0.0000001, 0, 1.0)
				handle_float_value(lightComponent, "Shadow near plane", "get_ShadowNearPlane", "set_ShadowNearPlane", 0.001, 0, 5.0)

				if lightEntry.isSpotLight then
					handle_float_value(lightComponent, "Detail shadow", "get_DetailShadow", "set_DetailShadow", 0.001, 0, 1.0)
				end 
				imgui.tree_pop()
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

			lightComponent:call("update")
        end
    end
end

local function render_reFramework_ui()
	changed, showWindow = imgui.checkbox("Show RELit UI", mainWindowVisible)
	if changed then
		mainWindowVisible = showWindow
	end
	
	if mainWindowVisible then
		main_menu()
	end
end

re.on_draw_ui(render_reFramework_ui)

re.on_frame(function()
	--Update values that get reset every frame
	for i, entry in ipairs(sceneLights) do 
		lightComponent = entry.lightComponent
		lightComponent:call("set_Enabled", entry.isEnabled)
	end

	camera = sdk.get_primary_camera()
	cameraGameObject = camera:call("get_GameObject")
	toneMapping = get_component_by_type(cameraGameObject,"via.render.ToneMapping")

	if not customTonemapping.isInitialized then
		customTonemapping.autoExposure = toneMapping:call("getAutoExposure")
		customTonemapping.exposure = toneMapping:call("get_EV")
		customTonemapping.isInitialized = true
	end
	
	if not customTonemapping.autoExposure then
		toneMapping:call("setAutoExposure", 2)
		toneMapping:call("set_EV", customTonemapping.exposure)
	end

	light_editor_menu()
end)


