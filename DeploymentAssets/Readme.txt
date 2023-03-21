RELit readme
==========================
RELit is a powerful tool to create spotlight and pointlights in RE powered games. Please read the requirements and how to install it.
RELit was written by Originalnicodr and Otis_Inf

Supported games: DMC5, Monster Hunter Rise, Resident Evil 2 Remake, Resident Evil 3 Remake, Resident Evil 7 and Resident Evil Village

Changelog
-----------
v1.1.4		- Added ReferenceEffectiveRange support, added more properties in for copy light to copy, changed volumetric scattering intensity step size to 1
v1.1.3		- Fixed scene light issue when switching scene lights off and on again
			- Filtered our lights from the scene lights list
			- Added a new button to copy light properties into a new light
v1.1.1		- Added scene light usage, refactored code, tweaked settings, restructured the UI to use a separate window, tweaked the light editor to use an initial size
v1.1		- Added tonemapping settings and updated some initial values
v1.0		- First release

Requirements
---------------
RELit depends on the REFramework by praydog. You need to download the REFramework version for your game, here:
https://github.com/praydog/REFramework/releases
Go to the latest release and then click the .zip file for the game you want to use RELit. 
For more information about REFramework, see https://github.com/praydog/REFramework

Installation
-------------
After downloading the REFramework zip for your game, unpack that zip into a folder. Then copy *only* the dinput8.dll and place
it in the game's folder, where the exe is. So e.g. in the case of DMC5, you download the DMC5.zip from the REFramework releases, 
unpack it into a folder and then copy the dinput8.dll file to the DMC5 game folder, which is <steam folder>\common\Devil May Cry 5

After you've installed the REFramework dll (the dinput8.dll), you can install the RELit mod into the game folder. 
Simply copy the reframework folder from the RELit zip into the game's folder (the same one into you placed the dinput8.dll).

Configuring RELit and REFramework
-----------
The default key to open the REFramework gui is the 'Insert' key. If you use the Otis_Inf cameras you'd like to rebind this key in REFramework
to another key, e.g. scroll lock. When the REFramework GUI is open, go to configuration and rebind the menu key there, by clicking 'Menu key'
and then pressing the key you want to use, e.g. scroll lock, to open the REFramework gui.

When the REFramework GUI is open, click on 'Script Generated UI', and you'll see the 'Show RELit UI' checkbox. Checking it will open the 
RELit window. It has an initial width and height, you can resize it which will be remembered for the next sessions.

After you've opened the RELit GUI, you can create lights, manage scene lights and use the tonemapper features. 

Creating lights
----------------
In the RELit GUI, click open 'Lights' to create custom lights. To create a light, click on the 'Add new spotlight' or 'Add new pointlight' buttons to create 
a light of that type. The light is created at the position of the camera. To edit light characteristics, click on the 'Edit' button next to the light in the 
list of lights, which appears after creating a light. To delete a light, click on the 'Delete' button.

Managing scene lights
-----------------------
When you click open the Scene Lights header, you can obtain the current scene lights by clicking the 'Update scene lights' button. After you've done that
you can switch the currently switched on lights off with the new 'Switch off scene lights' button. After you've done that you have to switch the lights
back on with the 'Switch scene lights back on' button before you can obtain the scene lights again. 

Tonemapper
-----------
When you click open the 'Tonemapper' header, you can switch off the Auto exposure setting of the tone mapper and when you switch it off, you can then control
the overall exposure of the scene, which affects all lights. 

FAQ
--------

Q: When I create a spotlight, I don't see any shadows!
A: That's likely because the Shadow near plane value is too low/wrong. Go into the light editor and increase the Shadow near plane value to a 
   higher value till you see the shadows appear and they look OK. 

Q: When I create a light, there are often big stripes in the shadow!
A: This is due to the default shadow bias. To correct the stripes, increase (or decrease) the shadow bias value till they're gone. 

Q: When I switch off all the scene lights there are still lights visible!
A: Not all elements emiting light are lights we can control. So the elements that are left that emit lights are elements that are other elemnets
   than lights and we can't control them being switched on/off, sadly.

Q: Can you add <Feature XYZ>
A: Sure, but it's likely not going to happen soon.

