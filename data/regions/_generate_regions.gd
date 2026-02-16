## Region generation reference -- NOT runtime code.
## This file documents the design decisions for the initial 36 regions.
## Actual .tres files are the source of truth.
##
## Map Layout:
##   IDs 0-6:   Northern Mountains (7 regions)
##   IDs 7-14:  Western Desert (8 regions)
##   IDs 15-22: Central River Basin (8 regions) -- River Basin civ starts at 15
##   IDs 23-29: Eastern Coastline (7 regions) -- Coastal civ starts at 25
##   IDs 30-35: Southern Plains (6 regions)
##
## Starting Capitals:
##   River Basin Power:      region 15 (Central River Basin)
##   Mountain Stronghold:    region 3  (Northern Mountains)
##   Coastal Expansionist:   region 25 (Eastern Coastline)
##
## Adjacency is roughly geographic -- each region borders 2-5 neighbors.
## Cross-zone adjacency connects the map zones together.
