# <img src="Media/Icon.png" width="64" height="64"> Metroidvania System

Metroidvania System (abbrevated as MetSys) is a general-purpose toolkit for creating metroidvania games in Godot game engine. It helps with map design, navigation and presentation, tracking collectibles and provides basic save data functionality related to the system. Its components can be used independently, even for games that aren't metroidvanias.

This plugin evolved from various tools I made for my metroidvania game, [Voice of Flowers](https://store.steampowered.com/app/2609560?utm_source=GitHub&utm_medium=README_TOP&utm_campaign=MetSys). They were quite useful, so I decided to make them into a separate project that can be used in other games too.

Supports Godot **4.2** or newer.

## Instructions

[You can find instructions in the wiki.](https://github.com/KoBeWi/Metroidvania-System/wiki)

## Quick overview

Metroidvania System is designed as a general-purpose addon, mainly focused on 2D grid-based metroidvania games (either platformer or top-down). Grid-based, i.e. it assumes that the map is composed of rooms that fit on a square or rectangular grid. The main feature is the Map Editor, which helps designing the world layout by placing the map cells and customizing them. The map, while it's only representation of the game's world, can be integrated with the game by associating scenes with rooms on the map, making the room transitions much easier to implement and the general overview of the world is more convenient.

A small but important sub-system are object IDs. Whether it's a collectible, a switch, a breakable wall, some objects may need a persistent state. This is often achieved using a list of hard-coded "events". MetSys comes with an automated system that generates a unique ID for each object in scene (or outside scene); you can manage object persistence using just 2 methods with all-optional arguments. They can be used for non-metroidvania games too.

https://github.com/KoBeWi/Metroidvania-System/assets/2223172/4d8f3099-93be-4a90-98dd-178fc8b7b0b3

### Brief list of all features

#### Map Editor

- Place or remove map cells, connecting them in any grid-based shape.
- The map supports independent layers, allowing for sub-areas, parallel worlds etc.
- Map cells may have different colors and symbols.
- Cell borders are also colored independently and may have different textures.
- You can assign groups to cells, for easier runtime operations on multiple cells (like mapping or recoloring).
- Cells are automatically grouped into rooms and can have assigned scenes.
- You can define custom elements that draw arbitrary things on map (like elevators or location names).
- Add a special RoomInstance node to your scene to display the borders of currently edited room inside the 2D editor view.
- Full undo/redo support.

#### Map Viewer

- Same view as Map Editor, but provides more overview information.
- Click a room to open the assigned scene.
- A room is highlighted if it matches the currently opened scene.
- Define a list of collectibles found in your game, each with a name and an icon.
- Scan all scenes for collectibles from the list. They can be easily located afterwards and their total count is displayed.
- The collectibles can be also displayed on the world map, to get full overview.

#### Godot Editor integration

- Room borders are displayed directly in your scene.
- If there is a connected adjacent room, its scene preview will be displayed at the borders.
- You can click the previews to navigate to connected scenes.

#### Customize

- All map visual properties are stored in a custom resource - MapTheme, which can be swapped at any time (even at runtime).
- Cell appearance can be customized with textures and default colors for both center and borders.
- Cells can be either square or rectangular, providing separate set of borders for each shape.
- Cells support separators, i.e. soft-borders within the same room, to make the grid more accented.
- There is a texture for empty cells that can be drawn automatically.
- Mapped cells have a separate color set. You can also define what details are displayed for such cells.
- Player location on map can be customized and displayed automatically.
- The player location can be marked per-cell or per-pixel.
- A special drawing mode called "Shared Borders", which makes each border shared between neighboring cells, instead of each cell having a separate inner border.

#### Misc

- Map data is stored in a custom text format, which is designed to be space-efficient and VCS-friendly.
- Map data can also be exported to JSON.
- Validate map data for unused symbols, passages to nowhere etc.
- Validate map theme for anything that potentially leads to an error, like mismatched sizes, missing textures etc.

#### Runtime features

- Specify in-game cell size, i.e. how a single cell size on the minimap relates to in-game world.
- Player position tracking using a single method, which automatically discovers cells and sends scene change requests.
- Override existing cells, assigning them different colors, borders, symbols or even scenes.
- Create and customize new ad hoc cells to make random map generators.
- Register and store persistent objects to track their state using automatically or manually assigned IDs.
- Automatically mark discovered and acquired collectibles on the map.
- Request runtime save data in a form of a Dictionary, which contains discovered rooms, stored object IDs and customized cells. It can be loaded back at any time.
- Get world map coordinates for any object on a scene.
- Helper method for custom drawing on map (for anything not supported by other features).
- Template scripts and scenes for common functionality, including scene transitions, connection automapping, save management and minimaps.

## Closing words

MetSys is the most complex system I have designed and written. It's a result of my years of experience in making and playing different metroidvania games. Hopefully it helps someone make a great metroidvania and I'll be able to play it in the future ;)

The addon is fully open-source, so feel free to dive into the code and adapt it to your needs. If you find bugs or shortcomings in some features, or maybe something is not properly explained, feel free to open an issue. Feature requests are also welcome, but I can't promise I'll be implementing them.

Have fun.

___
You can support my metroidvania game by [adding it to your wishlist on Steam](https://store.steampowered.com/app/2609560?utm_source=GitHub&utm_medium=README&utm_campaign=MetSys#game_area_purchase).

You can find all my addons on my [profile page](https://github.com/KoBeWi).

<a href='https://ko-fi.com/W7W7AD4W4' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
