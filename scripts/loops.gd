class_name Loops
## Endless loops (Crypt Pass). Below the free floors the crypt comes round again in loops
## of five floors. After each loop's last boss the player either banks the run (and gets
## a coin bonus) or descends into the next loop. Going deeper, they pick one Omen out of
## three: Omens stack, each makes the crypt harder in one way and adds to the score.
## Every loop is also a little darker.

const FLOORS := 5
## Banking a run at the end of a loop pays the run's coins again, plus a quarter more
## for every Omen braved.
const BANK_BONUS := 1.0
const OMEN_BANK := 0.25
## Each Omen adds this much to the score multiplier.
const OMEN_SCORE := 0.25
## Rerolls handed out between loops (along with full health).
const LOOP_REROLLS := 2

## Version 241 (whole-game review fix 12): all seven used to be numbers (10% faster, 30% less
## healing, a faster chain drain...). Three now change the rules of a room instead:
## Graves (a fallen skeleton's grave bursts with spikes a moment later), the Stalker (a
## shade you can't hurt comes for you while you stand still, stalker.gd) and Night (the crypt goes
## dark and only the hero's lantern lights it). Haste and Ash are gone; Night keeps its id.
const OMENS := [
	{"id": "graves", "title": "Omen of Graves", "text": "Fallen skeletons burst into bone spikes a moment later", "short": "Graves burst\ninto spikes"},
	{"id": "stalker", "title": "Omen of the Stalker", "text": "A shade you can't hurt creeps closer while you stand still", "short": "A shade hunts\nyou when still"},
	{"id": "night", "title": "Omen of Night", "text": "The crypt goes dark: only your lantern lights the way", "short": "The crypt\ngoes dark"},
	{"id": "bones", "title": "Omen of Bones", "text": "Skeletons have 25% more health"},
	{"id": "blades", "title": "Omen of Blades", "text": "Skeletons hit 25% harder"},
	{"id": "horde", "title": "Omen of the Horde", "text": "One more skeleton every wave"},
	{"id": "gold", "title": "Omen of Gold", "text": "Twice the elites, +50% coins"},
]


## Loop 1 is floors 1-5, loop 2 is floors 6-10, and so on.
static func loop_of(floor_num: int) -> int:
	return (maxi(floor_num, 1) - 1) / FLOORS + 1


## True on the last floor of a loop (5, 10, 15...).
static func loop_end(floor_num: int) -> bool:
	return floor_num % FLOORS == 0


static func get_omen(id: String) -> Dictionary:
	for o: Dictionary in OMENS:
		if o.id == id:
			return o
	return {}


## Three different Omens to choose from.
static func choices() -> Array:
	var pool := OMENS.duplicate()
	pool.shuffle()
	return pool.slice(0, 3)


## How many Omens are in play in total.
static func total(omens: Dictionary) -> int:
	var n := 0
	for id in omens:
		n += int(omens[id])
	return n


## "Bones x2, Haste" for the run report and the Omen screen.
static func names(omens: Dictionary) -> String:
	var parts := []
	for id in omens:
		var title: String = get_omen(id).get("title", id).trim_prefix("Omen of ").trim_prefix("the ")
		parts.append(title + (" x%d" % omens[id] if int(omens[id]) > 1 else ""))
	return ", ".join(parts)
