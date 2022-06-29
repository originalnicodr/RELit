RELit readme
==========================
RELit is a powerful tool to create spotlight and pointlights in RE powered games. Please read the requirements and how to install it.
RELit was written by Originalnicodr and Otis_Inf

Supported games: DMC5, Monster Hunter Rise, Resident Evil 2 Remake, Resident Evil 3 Remake, Resident Evil 7 and Resident Evil Village

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

When the REFramework GUI is open, click on 'Script Generated UI' and then click on 'RELit' to open the menu. 

Creating lights
----------------

To create a light, click on the 'Add new spotlight' or 'Add new pointlight' buttons to create a light of that type. The light is created at the 
position of the camera. To edit light characteristics, click on the 'Edit' button next to the light in the list of lights, which appears after
creating a light. To delete a light, click on the 'Delete' button.


FAQ
--------

Q: When I attach a spotlight to the camera and move it, or sometimes when I create a spotlight close to a character, it's mostly black or flickers
A: This is an engine bug, it happens in some games and not in others. Try to move the light a bit so it shows properly

Q: When I create a light, there are often big stripes in the shadow!
A: This is due to the default shadow bias. To correct the stripes, increase (or decrease) the shadow bias value till they're gone. 

Q: Can you add <Feature XYZ>
A: Sure, but it's likely not going to happen soon.
