# Metroidvania System

Metroidvania System (abbrevated as MetSys) is a general-purpose toolkit for creating metroidvania games in Godot game engine.

Features:
- Map Viewer will highlight the currently opened scene on map

Terminology
Room, Border, Corner, Passage, Wall, Cell

Themes

## List of included example themes
### AoS
![](Media/ThemeAoS.png)

Inspired by Castlevania: Aria of Sorrow. Simple blue squares with white, shared borders. Notably it displays room connections as colored lines. Has no symbols. Player location is white shrinking dot.
### BS
![](Media/ThemeBS.png)

Inspired by Bloodstained: Ritual of the Night. Rectangular light-blue cells with shared borders and normal room connections (i.e. hole-like). Also no symbols. Player location is a stylized dot showing exact location.
### Exquisite
![](Media/ThemeExquisite.png)

Original (and default) theme created for MetSys. Rectangular cells, customizes every available element of the theme to look fancy. Has a few random symbols. Player location is a rotating symbol that shows exact position.
### MF
![](Media/ThemeMF.png)

Inspired by Metroid Fusion. Simple square cells defaulting to magenta color and a texture for empty cells. Has a bunch of symbols and extra border styles for doors. Includes symbols for collected and uncollected items. Player location is a blinking square.
### SotN
![](Media/ThemeSotN.png)

Inspired by Castlevania: Symphony of the Night. Basically the same as BS, but with square rooms. Player location similar to AoS, but animated a bit differently.
### RR
![](Media/ThemeRR.png)

Inspired by Rabi-Ribi. Unlike other themes, cell borders are colored. Has many symbols, including various collectibles. Notably, the collectible symbols are displayed only when a collectible is acquired. Player locations is a rounded square with smoothed blinking.
### VoF
![](Media/ThemeVoF.png)

Inspired by Voice of Flowers (which is created by me). In fact it uses some of the old sprites from the game. Square cells with visible separators and a texture for empty space. Has a bunch of various symbols of mixed quality and an extra border style for abyss. No symbols for collectibles. Player location is a rotating head.
### Zeric
![](Media/ThemeZeric.png)

Inspired by map guides made by user Zeric ([Example])(https://gamefaqs.gamespot.com/gba/589456-castlevania-aria-of-sorrow/map/772-castle-map). The only theme that uses are possible corner styles for shared borders. Has a few non-collectible symbols and extra border styles. Player locations is a symbol.

Info co gdziej jest w przykładowym projekcie
can't have multiple handlers in tree
separatory mogą być mniejsze niż środek