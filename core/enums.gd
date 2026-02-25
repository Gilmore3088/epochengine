class_name Enums
extends RefCounted

## All game enumerations for Epoch Engine.

enum TerrainType {
	RIVER_BASIN,
	PLAINS,
	MOUNTAINS,
	DESERT,
	JUNGLE,
	COASTLINE,
	TUNDRA,
	STEPPE,
	VOLCANIC_RIDGE,
}

enum HeroType {
	GENERAL,
	REFORMER,
	VISIONARY,
}

enum CivState {
	STABLE,
	GROWING,
	DECLINING,
	COLLAPSED,
}

enum DiplomaticRelation {
	NEUTRAL,
	ALLIED,
	AT_WAR,
}

enum GameSpeed {
	NORMAL,
	FAST,
	FASTEST,
	PAUSED,
}

enum TurnPhase {
	POPULATION_GROWTH,
	RESOURCE_PRODUCTION,
	RESOURCE_CONSUMPTION,
	STABILITY_RECALCULATION,
	AI_DECISIONS,
	WAR_RESOLUTION,
	HERO_AGING,
	GOLDEN_AGE_EVALUATION,
	TECH_EMERGENCE,
	END_OF_YEAR_LOGGING,
}

enum GovernanceTier {
	TRIBAL,        # 1-5 regions
	CHIEFDOM,      # 6-8 regions
	CITY_STATE,    # 9-12 regions
	KINGDOM,       # 13-18 regions
	EMPIRE,        # 19-25 regions
	FEDERATION,    # 26+ regions
}

enum GovernmentForm {
	TRIBAL,
	MONARCHY,
	AUTOCRACY,
	REPUBLIC,
}

enum SuccessionLaw {
	PRIMOGENITURE,
	ELECTIVE,
	MERITOCRATIC,
}

enum Epoch {
	PREHISTORIC,  # 0-2 technologies
	CLASSICAL,    # 3-5 technologies
	INDUSTRIAL,   # 6-8 technologies
	FUTURE,       # 9+ technologies
}

enum DevelopmentTier {
	WILD,                    # 0 - Natural terrain only
	RURAL_SETTLEMENT,        # 1 - Scattered farms, basic extraction
	STRUCTURED_AGRICULTURE,  # 2 - Defined towns, trade corridors
	URBANIZED,               # 3 - Dense population, admin importance
	INDUSTRIALIZED,          # 4 - Major economic hub, military value
	ADVANCED,                # 5 - Highly integrated, mega-urban
}

enum ResourceType {
	METALS,
	COMMERCE,
	LUXURY_GOODS,
	FUELS,
	MANUFACTURED,
	RARE_MATERIALS,
	DATA,
	STRATEGIC,
	ADV_ENERGY,
}

enum MapOverlay {
	TERRAIN,
	RESOURCES,
	SUPPLY_LINES,
	ALLIANCES,
	POLITICAL,
}

enum MapSize {
	SMALL,
	MEDIUM,
	LARGE,
}

enum BuildingType {
	GRANARY,
	BARRACKS,
	MARKET,
	WALLS,
	WORKSHOP,
	LIBRARY,
	MONUMENT,
	TOWN_HALL,
}

enum VisibilityState {
	HIDDEN,     # Unknown territory - dark fog
	EXPLORED,   # Previously visible - terrain known, stale data
	VISIBLE,    # Currently adjacent to owned territory - full detail
}

enum UnitType {
	WORKER,
	LEADER,
	EXPLORER,
}

enum DisasterType {
	VOLCANIC_ERUPTION,
	EARTHQUAKE,
	FLOOD,
	DROUGHT,
}

enum GovernorFocus {
	GROWTH,
	MILITARY,
	TRADE,
	KNOWLEDGE,
	INFRASTRUCTURE,
}
