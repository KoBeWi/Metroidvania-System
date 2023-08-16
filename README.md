# Metroidvania System

Metroidvania System (abbrevated as MetSys) is a general-purpose toolkit for creating metroidvania games in Godot game engine. It helps with map design, navigation and presentation, tracking collectibles and provides basic save data functionality related to the system. It's components can be used independently, even for games that aren't metroidvanias.

## Getting started

MetSys is an addon and you install it normally - by copying the "addons/MetroidvaniaSystem" folder from this repository to the "addons/" directory in your project (create it if it doesn't exists). Once you copy the folder, go to Project -> Project Settings -> Plugins and tick the checkbox next to MetSys. Note that when the plugin is enabled for the first time, the editor will restart to properly setup the singleton. Once the plguin is activated, you will see MetSys button at the top of the Godot editor, next to 2D/3D views.

![](Media/IntroductionButton.png)

The addon comes with a sample project that shows example integration of the system. You can find more detailed instructions in this README.

### Terminology

This section explains the terminology used in this README and in the addon itself.
- Cell: The smallest unit of the game's world, represented by a square or rectangle on the game's map.
- Map: All of the placed cells, composing the game's world.
- Border: Edge of a cell. There are 2 types of borders:
  - Wall: Solid border with no holes.
  - Passage: A border with hole or another feature that signifies passage (e.g. a door).
- Corner: Meeting point of 2 or more borders.
- Room: A collection of multiple cells enclosed by borders on every side. In game they are tied to a scene.
- Explored Cell: A cell visited by the player that appears normally.
- Mapped Cell: An unvisited cell discovered via a mapping item that usually appears grayed-out.

## Quick overview

Metroidvania System is designed as a general-purpose addon, mostly focused on 2D grid-based metroidvania games (either platformer or top-down). Grid-based, i.e. it assumes that the map is composed of rooms that fit on a square or rectangular grid. The main feature is the Map Editor, which helps designing the world layout by placing map cells and customizing them. The map, while it's only representation of the game's world, can be integrated with the game by associating scenes with rooms on the map, making the room transitions much easier to implement and the general overview on the world is more convenient.

A small, but important sub-system are object IDs. Whether it's a collectible, a switch, a breakable wall, some objects may need a persistent state. This is often achieved using a list of hard-coded "events". MetSys comes with an automated system that generates a unique ID for each object in scene (or outside scene); you can manage object persistence using just 2 methods with all-optional arguments. They can be used for non-metroidvania games too.

### Brief list of all features

#### Map Editor

- Place or remove map cells, connecting them in any grid-based shape.
- The map supports independent layers, allowing for sub-areas, parallel worlds etc.
- Map cells may have different colors and symbols.
- Cell borders are also colored independently and may have different textures.
- You can assign groups to cells, for easier runtime operations on multiple cells (like mapping or recoloring).
- Cells are automatically grouped in rooms and can have assigned scenes.
- You can define custom elements that draw arbitrary things on map (like elevators or location names).
- Add special RoomInstance node to your scene to display the borders of currently edited room inside the 2D editor view.

#### Map Viewer

- Same view as Map Editor, but provides more overview information.
- Click a room to open the assigned scene.
- A room is highlighted if it matches the currently opened scene.
- Define a list of collectibles found in your game, each with a name and an icon.
- Scan all scenes for collectibles from the list. They can be easily located afterwards and their total count is displayed.
- TODO --------------

#### Customize

- All map visual properties are stored in a custom resource - MapTheme, which can be swapped at any time (even at runtime).
- Cell appearance can be customized with textures and default colors for both center and borders.
- Cells can be either square or rectangular, providing separate set of borders for each shape.
- Cells support separators, i.e. soft-borders within the same room, to make the grid more accented.
- There is a texture for empty cells that can be drawn automatically.
- Mapped, unexplored cells, have a separate color set. You can also define what details are displayed for such cells
- Player location on map can be customized and displayed automatically.
- The player location can be marked per-cell or per-pixel.
- A special drawing mode called "Shared Borders", which makes each border shared between neighboring cells, instead of each cell having a separate inner border.

#### Misc

- Map data is stored in a custom text format, which is designed to be space-efficient and VCS-friendly.
- Map data can also be exported to JSON.
- Validate map data for unused symbols, passages to nowhere etc.
- Validate map theme for anything that potentially lead to an error, like mismatched sizes, missing textures etc.

#### Runtime features

- Specify in-game cell size, i.e. how a single cell size on the minimap relates to in-game world.
- Player position tracking using a single method, which automatically discovers cells and sends scene change requests.
- Override existing cells, assigning them different colors, borders, symbols or even scenes.
- Create and customize new ad-hoc cells to make random map generators.
- Register and store persistent objects to track their state using automatically or manually assigned IDs.
- Automatically mark discovered and acquired collectibles on the map.
- Request runtime save data in a form of a Dictionary, which contains discovered rooms, stored object IDs and customized cells.
- Get map coordinates for any object on a scene.

## Editor guide

The plugin screen is called Metroidvania System Database and it has 3 tabs: Map Editor, Map Viewer and Manage.

![](Media/EditorDatabase.png)

## Runtime guide

## Sample project

## List of included example themes
### AoS
![](Media/ThemeAoS.png)

Inspired by Castlevania: Aria of Sorrow. Simple blue squares with white, shared borders. Notably it displays room connections as colored lines. Has no symbols. Player location is white shrinking dot, unexplored rooms display all connections.
### BS
![](Media/ThemeBS.png)

Inspired by Bloodstained: Ritual of the Night. Rectangular light-blue cells with shared borders and normal room connections (i.e. hole-like). Also no symbols. Player location is a stylized dot showing exact location and passages show normally in unexplored rooms.
### Exquisite
![](Media/ThemeExquisite.png)

Original (and default) theme created for MetSys. Rectangular cells, customizes every available element of the theme to look fancy. Has a few random symbols. Player location is a rotating symbol that shows exact position. Symbols appear in unexplored rooms, but not passages.
### MF
![](Media/ThemeMF.png)

Inspired by Metroid Fusion. Simple square cells defaulting to magenta color and a texture for empty cells. Has a bunch of symbols and extra border styles for doors. Includes symbols for collected and uncollected items. Player location is a blinking square. Symbols appear in unexplored rooms, but not passages.
### SotN
![](Media/ThemeSotN.png)

Inspired by Castlevania: Symphony of the Night. Basically the same as BS, but with square rooms. Player location similar to AoS, but animated a bit differently.
### RR
![](Media/ThemeRR.png)

Inspired by Rabi-Ribi. Unlike other themes, cell borders are colored. Has many symbols, including various collectibles. Notably, the collectible symbols are displayed only when a collectible is acquired. Player locations is a rounded square with smoothed blinking. Unexplored rooms display everything normally.
### VoF
![](Media/ThemeVoF.png)

Inspired by Voice of Flowers (which is created by me). In fact it uses some of the old sprites from the game. Square cells with visible separators and a texture for empty space. Has a bunch of various symbols of mixed quality and an extra border style for abyss. No symbols for collectibles. Player location is a rotating head. Unexplored rooms don't display anything, just cell color without any borders.
### Zeric
![](Media/ThemeZeric.png)

Inspired by map guides made by user Zeric ([Example](https://gamefaqs.gamespot.com/gba/589456-castlevania-aria-of-sorrow/map/772-castle-map)). The only theme that uses all possible corner styles for shared borders. Has a few non-collectible symbols and extra border styles. Player locations is a symbol, unexplored rooms display everything.

Info co gdziej jest w przykładowym projekcie
can't have multiple handlers in tree
separatory mogą być mniejsze niż środek