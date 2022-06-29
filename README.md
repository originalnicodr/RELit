# RELit

*Copypasting from the [Cyberlit guide](https://framedsc.com/GeneralGuides/cyberlit.htm) for now. Will fine tune it later on.*

**Point lights** radiate light in all directions from a single point in 3D space. It's best used for environmental lighting due to its omnidirectionality.

**Spot lights** shoot a cone of light in a specified direction, also from a single point in 3D space. This is best used for lighting portraits, as it can be aimed at certain parts of a face.

## Position

## Color picker / RGB / HSV / Hex
A standard visual color picker is available for easily picking a color. The next three rows of controls are three different ways of specifying a color, the 8-bit RGB decimal triplet, Hue-Saturation-Value, or the 8-bit RGB hexadecimal triplet (hex).

## Temperature
This adds to any set colors with a color that corresponds to the temperature of an ideal black-body radiator. In other words, you can set warm and cool lights with this. Represented in Kelvin, you can mimic sunlight, candlelight, and various other natural lights with this setting.

## Intensity
This controls how bright the light is.

## Radius
This controls how far the light can travel, likely in in-game meters.

## Falloff
This controls the intensity falloff of the light. Setting this to Inverse-square mimics how light intensity would dim in the real world as it gets further from the source. Setting this to None maintains light intensity throughout the light radius.

## Min Bias
This overrides the roughness of the specular highlights produced by a light when shone on a surface. Values to 127 appear to make specular highlights rougher. A flip happens at 128, where specular highlights are now sharp and become more rough until they return to default at 255.

## Spread
This controls the softness of the light relative to the outer angle, in degrees. Anything within the inner cone will be evenly lit while the light gradually falls off closer to the outer cone. Setting inner angle to be equal or greater than outer angle creates a spotlight with hard edges.

## Cone
This controls how wide the whole cone of light is, in degrees.

## Bounce intensity

## AO Efficencty

## Volumetric Scattering Intensity

[Maybe include an image of multiple lights of different colours being mixed]

## Shadow Bias
This appears to be a modifier of fade distance.