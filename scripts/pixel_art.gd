class_name PixelArt
extends RefCounted

## Every sprite in the game, stored as character grids and turned into textures
## at load time. No PNGs, no importer, no .import files — the art lives in the
## source and is built by Image.set_pixel() when the game boots.

const TILE := 8

const GRIDS := {
	"player_idle": [
		"..####..",
		".#cccc#.",
		"#cccccc#",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		".#CCCC#.",
		".#D##D#.",
		"..#..#..",
	],
	"player_run_a": [
		"..####..",
		".#cccc#.",
		"#cccccc#",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		".#CCCC#.",
		"..#DD#..",
		".##..##.",
	],
	"player_run_b": [
		"........",
		"..####..",
		".#cccc#.",
		"#cccccc#",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		".#CCCC#.",
		".#D##D#.",
	],
	"player_jump": [
		"..####..",
		".#cccc#.",
		"#cccccc#",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		"#CCCCCC#",
		".#D##D#.",
		"..#..#..",
	],
	"player_fall": [
		"........",
		"..####..",
		".#cccc#.",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		"#CCCCCC#",
		"#D#..#D#",
		".#....#.",
	],
	# The two seconds after a pound lands. Legs gone: the body keeps the same
	# ground line every other frame stands on — the bottom row is where the
	# feet were — and loses its height off the top instead, which is the shape
	# the collision box takes too. Squarer eyes because there is no walk cycle
	# to carry the expression while it lasts.
	"player_stump": [
		"........",
		"........",
		"........",
		"..####..",
		".#cccc#.",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		"..####..",
	],
	"player_wall": [
		"..####..",
		".#cccc#.",
		"#cccccc#",
		"#ccwwcc#",
		"#cc#w#c#",
		"#cccccc#",
		"#CCCCCC#",
		".#CCCC#.",
		".#DD##..",
		"..##....",
	],

	# --- bombado -------------------------------------------------------------
	# Sandbox-only super form (doc/bombadao). Thirty-six by forty-four instead of
	# the usual eight by ten: the arms deliberately hang outside the collision
	# box, which is only eighteen wide, because a body this size reads by
	# silhouette and a hitbox that matched it would snag on every corner.
	#
	# The head is the player's own, copied pixel for pixel out of
	# "player_idle" above — about twelve wide against thirty-six of shoulder.
	# That is
	# what keeps this reading as him rather than as some other character: the
	# same skull, the same two white eyes, the same pupils.
	#
	# Grooves between muscles are 'D' — the dark shade of the player's own
	# colour — never '#'; a near-black line at this scale punches a hole
	# through the muscle instead of separating it. '#' is spent on the outer
	# contour and on those pupils, and nowhere else.
	#
	# Light comes from above, and every muscle is built the same way: 'c' along
	# its top edge, 'C' through the middle, 'D' where it turns under, 'S' in
	# the crease where one muscle meets the next. 'S' is the fourth shade these
	# grids alone use (Palette.CYAN_DEEP) — three was enough for an eight-by-ten
	# sprite but not for this one, where the step from 'c' to 'C' is too small
	# to carve a pec away from a deltoid and every crease disappeared.
	#
	# Two rules keep that fourth shade from taking over. 'S' goes on undersides
	# and on the outline the softener replaces, never on a long line — in the
	# deep shade a centre line stops reading as a sternum and starts reading as
	# a stripe splitting him in half. And the linea alba is one pixel wide, not
	# two: the torso is ten pixels across, where the reference photograph spends
	# a twentieth of its width on that groove and this would spend a fifth.
	#
	# The arm went through three drafts. It has to be a whole limb — deltoid,
	# bicep, elbow, forearm, fist — and it has to hang clear of the ribs from
	# the armpit down, with real background between the two, ending at hip
	# height. An arm that merges into the torso and fades out level with the
	# navel reads as a flipper, which is what the second draft looked like.
	#
	# 'c'/'C'/'D' are recoloured per player by Player._player_texture(), same as
	# every player_* grid, so the buff form inherits the multiplayer colour.
	"buff_idle": [
		"...............######...............",
		"..............#cccccc#..............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"............##wwwccwww##............",
		"............##wwwccwww##............",
		"............##ww#cc#ww##............",
		"............##cccccccc##............",
		"............##cccccccc##............",
		"............##CCCDDCCC##............",
		"......####CCCCCDDDDDDCCCCC####......",
		"......####CCCCCDDDDDDCCCCC####......",
		"....##CccccCCCCCCCCCCCCCCCccccDD#...",
		"...#CCCCCCCCcccccCCccCCCCCCCCCCC#...",
		"...#CCCCCCCCcccccCCccCCCCCCCCCCC#...",
		"...#CCCCDDCcCCCccCCccCCCcCDDDCCCS##.",
		".##CCCCCSSDCCCCCCCDCCCCCCCSSCCCCC##.",
		".##CCCCCSSDCCCCCCCDCCCCCCCSSCCCCC##.",
		".##CCCCcDDSDDDDCCDDDDCDDDSSSCCCCCCC#",
		"#CCCCCCC##SSDDDCCCCCCDDDDS##CCCCCCC#",
		"#CCCCCCC##SSDDDCCCCCCDDDDS##CCCCCCC#",
		"#CCCDDD#..#SCCDCCCDCCDDDS#..#DDDCCC#",
		"#CCCCC#....#CCDCCCCCCCCC#....#CCCCC#",
		"#CCCCC#....#CCCCCCDCCCCC#....#CCCCC#",
		"#CCCCC#....#CCCCCCDCCCCC#....#CCCCC#",
		"#CCCDD#....#DDDCCCDCCDDD#....#DDCCC#",
		"#CCcDD#....#CCDDDCCDDDCCC#...#DDCCC#",
		"#CCcDD#....#CCDDDCCDDDCCC#...#DDCCC#",
		"#CCCCCD#..#CccCDDCCDDCCCC#..#DCCCCC#",
		".##CCCD#..#CCCCDDSSDDCCCC#..#DCCCDD#",
		".##CCCD#..#CCCCDDSSDDCCCC#..#DCCCDD#",
		".##DCC#...#CCCCDD##DDCCCC#...#DDC##.",
		"...####...#DCCC##..##CCCD#...####...",
		"...####...#DCCC##..##CCCD#...####...",
		"..........#CCCS##..##SDDC#..........",
		"..........#CDD#......#DDCD##........",
		"..........#CDD#......#DDCD##........",
		"..........#CDD#......#CCDD##........",
		"..........#CDD#......#DDD#..........",
		"..........#CDD#......#DDD#..........",
		"........##DC##........##DD##........",
		"........##DD##........##DD##........",
		"........##DD##........##DD##........",
		".......#######........#######.......",
	],
	"buff_run_a": [
		"...............######...............",
		"..............#cccccc#..............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"............##wwwccwww##............",
		"............##wwwccwww##............",
		"............##ww#cc#ww##............",
		"............##cccccccc##............",
		"............##cccccccc##............",
		"............##CCCDDCCC##............",
		"...........######CCCC#..#...........",
		"...........######CCCC#..#...........",
		"..........#ccccccCCCCC##C###........",
		"........##cccccccCCCCCCCCCCC#.......",
		"........##cccccccCCCCCCCCCCC#.......",
		"........##cccccccccCCCCCccCCC#......",
		".......#cccccccCCCCCCCCCCCCCCC##....",
		".......#cccccccCCCCCCCCCCCCCCC##....",
		"......#CccccccCCCCCCCDDDCCCCCC##....",
		"....##CCCCCcCCCCCCCCCCCCCCCCCDDD#...",
		"....##CCCCCcCCCCCCCCCCCCCCCCCDDD#...",
		"....##CCCCC#CCCCCDCCCCCCCC##DSDD#...",
		"....##CCCC#.##CCCCCCCCSSC#..#DDDD##.",
		"...#CCDC##..##CCCCCCCCCCC#...#DDDDD#",
		"...#CCDC##..##CCCCCCCCCCC#...#DDDDD#",
		".##CCCC#....##CCCDCCCCCCC#....##SDD#",
		".##CCC#....#CCCCCCCccDccC#....##DDD#",
		".##CCC#....#CCCCCCCccDccC#....##DDD#",
		"#CCCCC#.....##CCCScccccc#.......#DD#",
		"#CCC##........#CCCcccDcc#........##.",
		"#CCC##........#CCCcccDcc#........##.",
		"#CC#........##SSSSccccccc#..........",
		".##........#SSSSSS#cccccC#..........",
		".##........#SSSSSS#cccccC#..........",
		"...........#DDDSS#.##cCCCC##........",
		"........###DSSD##....#CCCD##........",
		".........###DSSD##..#CCCD##.........",
		"........#DDDDDD#....#CCCCCC#........",
		".......#DDDDD##......###CCCC#.......",
		".......#DDDDD##......###CCCC#.......",
		".....##DDDDD#...........#CCCC##.....",
		".####DDDD###.............##CCCC####.",
		".####DDDD###.............##CCCC####.",
		".########..................########.",
	],
	"buff_run_pass_a": [
		"...............######...............",
		"..............#cccccc#..............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"............##wwwccwww##............",
		"............##wwwccwww##............",
		"............##ww#cc#ww##............",
		"............##cccccccc##............",
		"............##cccccccc##............",
		"............##CCCDDCCC##............",
		"..........#ccccccCCCCC##C###........",
		"..........#ccccccCCCCC##C###........",
		"..........#ccccccCCCCCCCCCCC#.......",
		"..........#ccccccccCCCCCccCCC#......",
		"..........#ccccccccCCCCCccCCC#......",
		"........##cccccCCCCCCCCCCCCCC#......",
		"........##CccccCCCCCCDDDCCCCC#......",
		"........##CccccCCCCCCDDDCCCCC#......",
		".......#CCCCccCCCCCCCCCCCCCCC#......",
		".......#CCCCCCCCCDCCCCCCCCCCSD##....",
		".......#CCCCCCCCCDCCCCCCCCCCSD##....",
		".......#CCCCCCCCCCCCCCSSCCDDD#......",
		"........##CCCCCCCCCCCCCCCCDDD#......",
		"..........#DCCCCCDCCCCCCCCDDD#......",
		"..........#DCCCCCDCCCCCCCCDDD#......",
		"..........#CCCCCCCCccDccCCSSD#......",
		"..........#CCCCCCScccccccDDD#.......",
		"..........#CCCCCCScccccccDDD#.......",
		"...........#CCCCCCcccDccc####.......",
		"...........#CCCSSScccccc#...........",
		"...........#CCCSSScccccc#...........",
		"...........#SSSSSScccccc#...........",
		"...........#DDDSS#cccCcc#...........",
		"...........#DDDSS#cccCcc#...........",
		"..........#DSSD##.#CCCCC#...........",
		"...........#DDDDD#CCCCDD#...........",
		"...........#DDDDD#CCCCDD#...........",
		"............##DDDDcCCCCC#...........",
		"..............#DDDDCCCCCC#..........",
		"..............#DDDDCCCCCC#..........",
		"...............###DDDCCCC#..........",
		"..................####CCCC####......",
		"..................####CCCC####......",
		"......................########......",
	],
	"buff_run_b": [
		"...............######...............",
		"..............#cccccc#..............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"............##wwwccwww##............",
		"............##wwwccwww##............",
		"............##ww#cc#ww##............",
		"............##cccccccc##............",
		"............##cccccccc##............",
		"............##CCCDDCCC##............",
		"............##.##CCCC#..#c##........",
		"............##.##CCCC#..#c##........",
		"..........##DD#CCCCCCC##cccc#.......",
		"........##DCCCCCCCCCCCCCcccc#.......",
		"........##DCCCCCCCCCCCCCcccc#.......",
		".......#DDDCCCCCCccCCCccccccc#......",
		"......#DDDCCCCCCCCCCCCCCccccc#......",
		"......#DDDCCCCCCCCCCCCCCccccc#......",
		"......#DDDDCCCCCCCCCCDDDCccccC##....",
		"....##DSDDD#CCCCCCCCCCCCCcccCCCC#...",
		"....##DSDDD#CCCCCCCCCCCCCcccCCCC#...",
		"....##DDDD#.##CCCDCCCCCCCCCCCCCC#...",
		"...#DDDD##..##CCCCCCCCSSCC##CCCC#...",
		".##DDDD#....##CCCCCCCCCCC#..#CCCC##.",
		".##DDDD#....##CCCCCCCCCCC#..#CCCC##.",
		".##DSS#.....##CCCDCCCCCCC#...#CCDCC#",
		"#DDDDD#....#CCccccCCCDCCC#....##CCC#",
		"#DDDDD#....#CCccccCCCDCCC#....##CCC#",
		".##D##......##cccScCCCCC#.....##CCC#",
		"...#........##cccccCCDCC#.....##CCC#",
		"...#........##cccccCCDCC#.....##CCC#",
		"...........#cccccccSSSSS#.......#CC#",
		"...........#CCccccSSSSSSS#.......##.",
		"...........#CCccccSSSSSSS#.......##.",
		"..........#CCCCcc##SSSDDD#..........",
		"..........#CDDC##..##SDDSD###.......",
		"...........#CDDC####SDDSD###........",
		".........##CCCCC##..###DDDDD#.......",
		"........#CCCC###.......#DDDDD##.....",
		"........#CCCC###.......#DDDDD##.....",
		".......#CCCC#...........#DDDDDD#....",
		"..#####CCCC#.............###DDDD###.",
		"..#####CCCC#.............###DDDD###.",
		"..#########.................#######.",
	],
	"buff_run_pass_b": [
		"...............######...............",
		"..............#cccccc#..............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"............##wwwccwww##............",
		"............##wwwccwww##............",
		"............##ww#cc#ww##............",
		"............##cccccccc##............",
		"............##cccccccc##............",
		"............##CCCDDCCC##............",
		"...........#DD#CCCCCCC##cccc#.......",
		"...........#DD#CCCCCCC##cccc#.......",
		"..........#CCCCCCCCCCCCCcccc#.......",
		"..........#CCCCCCccCCCccccccc#......",
		"..........#CCCCCCccCCCccccccc#......",
		"........##CCCCCCCCCCCCCCccccc#......",
		"........##DCCCCCCCCCCDDDccccC#......",
		"........##DCCCCCCCCCCDDDccccC#......",
		"........##SDCCCCCCCCCCCCCcCCCC##....",
		".......#DDDDCCCCCDCCCCCCCCCCCC##....",
		".......#DDDDCCCCCDCCCCCCCCCCCC##....",
		"........##DDCCCCCCCCCCSSCcCCCC##....",
		"........##DDCCCCCCCCCCCCCC##CC##....",
		"........##DSCCCCCDCCCCCCC#..#DCC#...",
		"........##DSCCCCCDCCCCCCC#..#DCC#...",
		"........##DCCCCCCCCccDccC#..#CCC#...",
		"..........#DCCCCCScccccc#...#CCCC##.",
		"..........#DCCCCCScccccc#...#CCCC##.",
		"..........####CCCCcccDcc#....#CC#...",
		"..............#SSSccccccc#...####...",
		"..............#SSSccccccc#...####...",
		"...............##SSccccccC##........",
		"...............##SDSScccCCCC#.......",
		"...............##SDSScccCCCC#.......",
		"...............##DSDDSCCCDCC#.......",
		"...............##DDDDDCCCCCC#.......",
		"...............##DDDDDCCCCCC#.......",
		"...............##DDDDDCCCC##........",
		".................#DDDCCCCC##........",
		".................#DDDCCCCC##........",
		"..................#DDDCCCCCC#.......",
		"..................#DDDDDCC##........",
		"..................#DDDDDCC##........",
		"...................#########........",
	],

	# Vertical jump with no horizontal movement. Head and torso stay exactly
	# frontal; only knees tuck upward. Side-facing jump grids remain for
	# jumps carrying horizontal speed.
	"buff_jump_front": [
		"...............######...............",
		"..............#cccccc#..............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"............##wwwccwww##............",
		"............##wwwccwww##............",
		"............##ww#cc#ww##............",
		"............##cccccccc##............",
		"............##cccccccc##............",
		"............##CCCDDCCC##............",
		"......####CCCCCDDDDDDCCCCC####......",
		"......####CCCCCDDDDDDCCCCC####......",
		"....##CccccCCCCCCCCCCCCCCCccccDD#...",
		"...#CCCCCCCCcccccCCccCCCCCCCCCCC#...",
		"...#CCCCCCCCcccccCCccCCCCCCCCCCC#...",
		"...#CCCCDDCcCCCccCCccCCCcCDDDCCCS##.",
		".##CCCCCSSDCCCCCCCDCCCCCCCSSCCCCC##.",
		".##CCCCCSSDCCCCCCCDCCCCCCCSSCCCCC##.",
		".##CCCCcDDSDDDDCCDDDDCDDDSSSCCCCCCC#",
		"#CCCCCCC##SSDDDCCCCCCDDDDS##CCCCCCC#",
		"#CCCCCCC##SSDDDCCCCCCDDDDS##CCCCCCC#",
		"#CCCDDD#..#SCCDCCCDCCDDDS#..#DDDCCC#",
		"#CCCCC#....#CCDCCCCCCCCC#....#CCCCC#",
		"#CCCCC#....#CCCCCCDCCCCC#....#CCCCC#",
		"#CCCCC#....#CCCCCCDCCCCC#....#CCCCC#",
		"#CCCDD#....#DDDCCCDCCDDD#....#DDCCC#",
		"#CCcDD#....#CCDDDCCDDDCCC#...#DDCCC#",
		"#CCcDD#....#CCDDDCCDDDCCC#...#DDCCC#",
		"#CCCCCD#..#CccCDDCCDDCCCC#..#DCCCCC#",
		".##CCCD#..#CCCCDDSSDDCCCC#..#DCCCDD#",
		".##CCCD#..#CCCCDDSSDDCCCC#..#DCCCDD#",
		".##DCC#...#CCCCDD##DDCCCC#...#DDC##.",
		".....####...#DCCC##CCCD#...####.....",
		".....####...#DCCC##CCCD#...####.....",
		"............#CCCS##SDDC#............",
		"............#CDD#..#DDCD##..........",
		"............#CDD#..#DDCD##..........",
		"............#CDD#..#CCDD##..........",
		"............#CDD#..#DDD#............",
		"............#CDD#..#DDD#............",
		"....................................",
		"....................................",
		"....................................",
		"....................................",
	],
	"buff_jump": [
		"...............######...............",
		"..............#cccccc#..............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"............##wwwccwww##............",
		"............##wwwccwww##............",
		"............##ww#cc#ww##............",
		"............##cccccccc##............",
		"............##cccccccc##............",
		"............##CCCDDCCC##............",
		"...........######CCCC#..#...........",
		"...........######CCCC#..#...........",
		"..........#ccccccCCCCC##C###........",
		"........##cccccccCCCCCCCCCCC#.......",
		"........##cccccccCCCCCCCCCCC#.......",
		"........##cccccccccCCCCCccCCC#......",
		".......#cccccccCCCCCCCCCCCCCCC##....",
		".......#cccccccCCCCCCCCCCCCCCC##....",
		"......#CccccccCCCCCCCDDDCCCCCC##....",
		"....##CCCCCcCCCCCCCCCCCCCCCCCDDD#...",
		"....##CCCCCcCCCCCCCCCCCCCCCCCDDD#...",
		"....##CCCCC#CCCCCDCCCCCCCC##DSDD#...",
		"....##CCCC#.##CCCCCCCCSSC#..#DDDD##.",
		"...#CCDC##..##CCCCCCCCCCC#...#DDDDD#",
		"...#CCDC##..##CCCCCCCCCCC#...#DDDDD#",
		".##CCCC#....##CCCDCCCCCCC#....##SDD#",
		".##CCC#....#CCCCCCCccDccC#....##DDD#",
		".##CCC#....#CCCCCCCccDccC#....##DDD#",
		"#CCCCC#.....##CCCScccccc#.......#DD#",
		"#CCC##........#CCCcccDcc#........##.",
		"#CCC##........#CCCcccDcc#........##.",
		"#CC#........##SSSSccccccc#..........",
		".##........#SSSSSS#cccccC#..........",
		".##........#SSSSSS#cccccC#..........",
		"...........#DDDSS#.##cCCCC##........",
		"........###DSSD##....#CCCD##........",
		".........###DSSD##..#CCCD##.........",
		"........#DDDDDD#....#CCCCCC#........",
		".......#DDDDD##......###CCCC#.......",
		".......#DDDDD##......###CCCC#.......",
		".....##DDDDD#...........#CCCC##.....",
		".####DDDD###.............##CCCC####.",
		".####DDDD###.............##CCCC####.",
		".########..................########.",
	],
	"buff_air": [
		"...............######...............",
		"..............#cccccc#..............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"............##wwwccwww##............",
		"............##wwwccwww##............",
		"............##ww#cc#ww##............",
		"............##cccccccc##............",
		"............##cccccccc##............",
		"............##CCCDDCCC##............",
		"...........######CCCC#..#...........",
		"...........######CCCC#..#...........",
		"..........#ccccccCCCCC##C###........",
		"........##cccccccCCCCCCCCCCC#.......",
		"........##cccccccCCCCCCCCCCC#.......",
		"........##cccccccccCCCCCccCCC#......",
		".......#cccccccCCCCCCCCCCCCCCC##....",
		".......#cccccccCCCCCCCCCCCCCCC##....",
		"......#CccccccCCCCCCCDDDCCCCCC##....",
		"....##CCCCCcCCCCCCCCCCCCCCCCCDDD#...",
		"....##CCCCCcCCCCCCCCCCCCCCCCCDDD#...",
		"....##CCCCC#CCCCCDCCCCCCCC##DSDD#...",
		"....##CCCC#.##CCCCCCCCSSC#..#DDDD##.",
		"...#CCDC##..##CCCCCCCCCCC#...#DDDDD#",
		"...#CCDC##..##CCCCCCCCCCC#...#DDDDD#",
		".##CCCC#....##CCCDCCCCCCC#....##SDD#",
		".##CCC#....#CCCCCCCccDccC#....##DDD#",
		".##CCC#....#CCCCCCCccDccC#....##DDD#",
		"#CCCCC#.....##CCCScccccc#.......#DD#",
		"#CCC##........#CCCcccDcc#........##.",
		"#CCC##........#CCCcccDcc#........##.",
		"...........#SSSSSScccccc#...........",
		"...........#DDDSS#cccCcc#...........",
		"...........#DDDSS#cccCcc#...........",
		"..........#DSSD##.#CCCCC#...........",
		"...........#DDDDD#CCCCDD#...........",
		"...........#DDDDD#CCCCDD#...........",
		"............##DDDDcCCCCC#...........",
		"..............#DDDDCCCCCC#..........",
		"..............#DDDDCCCCCC#..........",
		"...............###DDDCCCC#..........",
		"..................####CCCC####......",
		"..................####CCCC####......",
		"......................########......",
	],
	"buff_fall": [
		"...............######...............",
		"..............#cccccc#..............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"............##wwwccwww##............",
		"............##wwwccwww##............",
		"............##ww#cc#ww##............",
		"............##cccccccc##............",
		"............##cccccccc##............",
		"............##CCCDDCCC##............",
		"............##.##CCCC#..#c##........",
		"............##.##CCCC#..#c##........",
		"..........##DD#CCCCCCC##cccc#.......",
		"........##DCCCCCCCCCCCCCcccc#.......",
		"........##DCCCCCCCCCCCCCcccc#.......",
		".......#DDDCCCCCCccCCCccccccc#......",
		"......#DDDCCCCCCCCCCCCCCccccc#......",
		"......#DDDCCCCCCCCCCCCCCccccc#......",
		"......#DDDDCCCCCCCCCCDDDCccccC##....",
		"....##DSDDD#CCCCCCCCCCCCCcccCCCC#...",
		"....##DSDDD#CCCCCCCCCCCCCcccCCCC#...",
		"....##DDDD#.##CCCDCCCCCCCCCCCCCC#...",
		"...#DDDD##..##CCCCCCCCSSCC##CCCC#...",
		".##DDDD#....##CCCCCCCCCCC#..#CCCC##.",
		".##DDDD#....##CCCCCCCCCCC#..#CCCC##.",
		".##DSS#.....##CCCDCCCCCCC#...#CCDCC#",
		"#DDDDD#....#CCccccCCCDCCC#....##CCC#",
		"#DDDDD#....#CCccccCCCDCCC#....##CCC#",
		".##D##......##cccScCCCCC#.....##CCC#",
		"...#........##cccccCCDCC#.....##CCC#",
		"...#........##cccccCCDCC#.....##CCC#",
		"...........#cccccccSSSSS#.......#CC#",
		"...........#CCccccSSSSSSS#.......##.",
		"...........#CCccccSSSSSSS#.......##.",
		"..........#CCCCcc##SSSDDD#..........",
		"..........#CDDC##..##SDDSD###.......",
		"...........#CDDC####SDDSD###........",
		".........##CCCCC##..###DDDDD#.......",
		"........#CCCC###.......#DDDDD##.....",
		"........#CCCC###.......#DDDDD##.....",
		".......#CCCC#...........#DDDDDD#....",
		"..#####CCCC#.............###DDDD###.",
		"..#####CCCC#.............###DDDD###.",
		"..#########.................#######.",
	],
	"buff_rise": [
		"....................................",
		"....................................",
		"....................................",
		"....######.....######.....######....",
		"...#CCCCCC#...#cccccc#....##CCCC#...",
		"...#CCCCCC#...#cccccc#....##CCCC#...",
		".##CDD####..##cccccccc##..####DDc##.",
		"#CCc##......##wwwccwww##......##cCC#",
		"#CCc##......##wwwccwww##......##cCC#",
		"#CCCCC#...####w##cc##w####....##CCC#",
		"#CCCDDC###cC##cccccccc##Cc####DDCCC#",
		"#CCCDDC###cC##cccccccc##Cc####DDCCC#",
		"#CCCDDCcCCCC##CCCCCCCC##CCCCcCDDDCC#",
		"#DDCCCDCCCDCCCcccCCcccCCCDCCCDCCCDD#",
		"#DDCCCDCCCDCCCcccCCcccCCCDCCCDCCCDD#",
		"###CCCCDSSDcCCCCCCCccCCCcDSSDCCCC##.",
		"...#DDCDSSSCCCCccCCccCCCCSSS#CDD#...",
		"...#DDCDSSSCCCCccCCccCCCCSSS#CDD#...",
		"....####SSCSDDCCCDDCCCDDSD##.###....",
		"........##CDDDDCCCCCCDDDDD##........",
		"........##CDDDDCCCCCCDDDDD##........",
		"..........##DDDCCCCCCCDD##..........",
		"............##DCCCCCCD##............",
		"............##CDDCCCCC##............",
		"............##CDDCCCCC##............",
		"............##DDDCCDDD##............",
		"...........#ccCDDCCDDCcc#...........",
		"...........#ccCDDCCDDCcc#...........",
		"..........#CCCCDDDDDDCCCC#..........",
		"..........#CCCCDD##DDCCCC#..........",
		"..........#CCCCDD##DDCCCC#..........",
		"..........#DCCD##..##DCC#...........",
		"..........#CDD#......#DDC#..........",
		"..........#CDD#......#DDC#..........",
		"..........#DCC#......#CCD#..........",
		"..........#CDD#......#DDC#..........",
		"..........#CDD#......#DDC#..........",
		"..........#D##........##C#..........",
		"........######..........####........",
		"........######..........####........",
		"........##DD##..........#DDD#.......",
		"........##DC##..........#CDD#.......",
		"........##DC##..........#CDD#.......",
		".......#######..........######......",
	],
	"buff_pose_double": [
		"....................................",
		"....................................",
		"....................................",
		"....######.....######.....######....",
		"...#CCCCCC#...#cccccc#....##CCCC#...",
		"...#CCCCCC#...#cccccc#....##CCCC#...",
		".##CDD####..##cccccccc##..####DDc##.",
		"#CCc##......##wwwccwww##......##cCC#",
		"#CCc##......##wwwccwww##......##cCC#",
		"#CCCCC#...####w##cc##w####....##CCC#",
		"#CCCDDC###cC##cccccccc##Cc####DDCCC#",
		"#CCCDDC###cC##cccccccc##Cc####DDCCC#",
		"#CCCDDCcCCCC##CCCCCCCC##CCCCcCDDDCC#",
		"#DDCCCDCCCDCCCcccCCcccCCCDCCCDCCCDD#",
		"#DDCCCDCCCDCCCcccCCcccCCCDCCCDCCCDD#",
		"###CCCCDSSDcCCCCCCCccCCCcDSSDCCCC##.",
		"...#DDCDSSSCCCCccCCccCCCCSSS#CDD#...",
		"...#DDCDSSSCCCCccCCccCCCCSSS#CDD#...",
		"....####SSCSDDCCCDDCCCDDSD##.###....",
		"........##CDDDDCCCCCCDDDDD##........",
		"........##CDDDDCCCCCCDDDDD##........",
		"..........##DDDCCCCCCCDD##..........",
		"............##DCCCCCCD##............",
		"............##CDDCCCCC##............",
		"............##CDDCCCCC##............",
		"............##DDDCCDDD##............",
		"...........#ccCDDCCDDCcc#...........",
		"...........#ccCDDCCDDCcc#...........",
		"..........#CCCCDDDDDDCCCC#..........",
		"..........#CCCCDD##DDCCCC#..........",
		"..........#CCCCDD##DDCCCC#..........",
		"..........#DCCD##..##DCC#...........",
		"..........#CDD#......#DDC#..........",
		"..........#CDD#......#DDC#..........",
		"..........#DCC#......#CCD#..........",
		"..........#CDD#......#DDC#..........",
		"..........#CDD#......#DDC#..........",
		"..........#D##........##C#..........",
		"........######..........####........",
		"........######..........####........",
		"........##DD##..........#DDD#.......",
		"........##DC##..........#CDD#.......",
		"........##DC##..........#CDD#.......",
		".......#######..........######......",
	],
	"buff_pose_lat": [
		"....................................",
		"...............######...............",
		"...............######...............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"............##cccccccc##............",
		"........###.##wwwccwww##............",
		"......##CCC###w##cc##w########......",
		"......##CCC###w##cc##w########......",
		"....##CcCCcC##cccccccc##CccccC##....",
		"....##CCCCCC##CCCCCCCC##CcCCCcCC#...",
		"....##CCCCCC##CCCCCCCC##CcCCCcCC#...",
		"...#CCCCDDCcCCCccCCccCccCCCCCCCC#...",
		".##cCCCCDDCcCCCCCCCCCCCCcCDDCCCCD##.",
		".##cCCCCDDCcCCCCCCCCCCCCcCDDCCCCD##.",
		"#CCCCCCcDDSCCCCCCDCCCcCCCDSScCCCC##.",
		"#CCcDDDC##SSDDDDDDDDDDDDSSDDCCCCCCC#",
		"#CCcDDDC##SSDDDDDDDDDDDDSSDDCCCCCCC#",
		"#CCcccC#..#DDDCCCCCCCDDDSD##DDCCCCC#",
		"#CCCCCC#...#CCDCCDCDDCDDD#..#CccCCC#",
		"#CCCCCC#...#CCDCCDCDDCDDD#..#CccCCC#",
		"#DDCCCcC###DCCDCCCCDDDDD#.##CcCCDCC#",
		".###CCCcCCCDCCCCCDCDDCSSS#DDcCCCC##.",
		"....###CccDDDDCCCCCDDDDDcCccCCCC###.",
		"....###CccDDDDCCCCCDDDDDcCccCCCC###.",
		".......#DDDCDDDDDDDDDSDDCCCC####....",
		"........##CcDDDCCCDDDCSSDC##........",
		"........##CcDDDCCCDDDCSSDC##........",
		"........##cCCCSDDDSCCcCCSS##........",
		"........##CCCCDSS#SCCCCCC#..........",
		"........##CCCCDSS#SCCCCCC#..........",
		"........##DCCCC##.#CCCCCC#..........",
		"..........#DCCD##..##CDDC#..........",
		"..........#DCCD##..##CDDC#..........",
		"...........#CCD##..##SDDCD##........",
		"...........#DDC##....#DDDC##........",
		"...........#DDC##....#DDDC##........",
		"...........#CCD##.....##CC##........",
		"............##D##.......#C##........",
		"............##D##.......#C##........",
		"...........#CCD##........#CC#.......",
		".......#DDD#..............##DD##....",
		".......#DDD#..............##DD##....",
		".......#######...........#######....",
	],
	"buff_pose_side": [
		"..............#####.................",
		"............##ccccc##...............",
		"............##ccccc##...............",
		"...........#ccccccccc#..............",
		"..........##wwwcccwww#..............",
		"..........##wwwcccwww#..............",
		".......###C#ww#ccc#ww###............",
		".......#ccC#ccccccccc#CC#...........",
		".......#ccC#ccccccccc#CC#...........",
		"......#CCCC#CCCCCCCCC#cc#...........",
		"......#CCCCCCCDDDCCccCCC#...........",
		"......#CCCCCCCDDDCCccCCC#...........",
		"......#DCCCCCCCCCDCCCSDDD#..........",
		"......#DDDCCCCCccCSDDDDDDC##........",
		"......#DDDCCCCCccCSDDDDDDC##........",
		"......#DSSDcccCCCCSDDCDDDC##........",
		".......#SSDCCCCCCCCDDDSSDC##........",
		".......#SSDCCCCCCCCDDDSSDC##........",
		".......#DDSDCCCCCCcCCSSSCCCC#.......",
		"........##SSDDCCCDDCCCSSDCCC#.......",
		"........##SSDDCCCDDCCCSSDCCC#.......",
		"..........#DSSDCCCCCCcCCDCCC#.......",
		"..........#CDDSSSDCDDCCCcCCC#.......",
		"..........#CDDCDDSSSSSSSCCCC#.......",
		"..........#CDDCDDSSSSSSSCCCC#.......",
		"..........#DDDCCCCDSSS######........",
		"..........#DCCCccCCCC#..............",
		"..........#DCCCccCCCC#..............",
		"...........#CCCCCCCcc#..............",
		"...........#DDCCCCCCC#..............",
		"...........#DDCCCCCCC#..............",
		"...........#SSDDDDDDDC##............",
		"............##SSSSDCCC##............",
		"............##SSSSDCCC##............",
		"...........#SSDSSDCCCD##............",
		"..........#DDDSSSCCCC#..............",
		"..........#DDDSSSCCCC#..............",
		"..........#DDDD##DCCC#..............",
		"..........#DDD#..#CCC#..............",
		"..........#DDD#..#CCC#..............",
		"..........#D##...#C##...............",
		"..........#D##...#CCC###............",
		"..........#D##...#CCC###............",
		"..........####...#######............",
	],
	"buff_pose_crab": [
		"...............######...............",
		"..............#cccccc#..............",
		"..............#cccccc#..............",
		"............##cccccccc##............",
		"..........####wwwccwww##............",
		"..........####wwwccwww##............",
		".......###CC##w##cc##w###...........",
		"......#CcccC##cccccccc##C#..........",
		"......#CcccC##cccccccc##C#..........",
		"......#cCCCC##CCCCCCCC##CC##........",
		"......#CCCCCCCDccCCCCCccCD##........",
		"......#CCCCCCCDccCCCCCccCD##........",
		"......#CCCCCDDDCCCCCCDCCCSSS#.......",
		"......#DCCCCCCCDDDCDDSDDDDCC#.......",
		"......#DCCCCCCCDDDCDDSDDDDCC#.......",
		"......#CcccCCCCDDSDDDCDDSCCCD#......",
		".......#CCCCCCCDDDDCCDDDSDCCC#......",
		".......#CCCCCCCDDDDCCDDDSDCCC#......",
		".......#DDDCCCCcccCSSDSSSDccC#......",
		"........##DCCCCCCCCCCSSSCCDDC#......",
		"........##DCCCCCCCCCCSSSCCDDC#......",
		"..........#DCCCCCCCcccCCCCCC##......",
		"...........#DDDCCCCCCCCCCC##........",
		"...........#SSSSSSSSSSSSDC##........",
		"...........#SSSSSSSSSSSSDC##........",
		"...........#CCDDDDDDDDSSS#..........",
		"...........#CCDCCDCCCCCC#...........",
		"...........#CCDCCDCCCCCC#...........",
		"............##DCCCCCCCccC#..........",
		"..............#DDDCCCCCCC#..........",
		"..............#DDDCCCCCCC#..........",
		"..............#SSDDCCCCCDC##........",
		"..............#SSSSSSDCCCC##........",
		"..............#SSSSSSDCCCC##........",
		"..............#SSDSDDcCCCD##........",
		"............##DDDDSDDCCCC#..........",
		"............##DDDDSDDCCCC#..........",
		"............##DDDDSSSDCC#...........",
		"............##DDD#DCCC##............",
		"............##DDD#DCCC##............",
		"............##D##.#CC#..............",
		"...........#DDD##..###..............",
		"...........#DDD##..###..............",
		"...........#######.#####............",
	],
	"buff_pose_back": [
		"....#######...............#######...",
		"...#ccCCCC#..............#CCCCcc#...",
		"...#ccCCCC#..............#CCCCcc#...",
		".##CCC#####....######....#####CCc##.",
		"#CCC##........#cccccc#........##CCC#",
		"#CCC##........#cccccc#........##CCC#",
		"#CCCCC#.....##cccccccc##.....#CCCCC#",
		"#CCcCCS#######cccccccc#######SDDcCC#",
		"#CCcCCS#######cccccccc#######SDDcCC#",
		"#CCCDDcCCCcc##cccccccc##ccCCccCCCCC#",
		"#CCCCCCCCCcC##cccccccc##CcCCCCCCCCC#",
		"#CCCCCCCCCcC##cccccccc##CcCCCCCCCCC#",
		"#SSCCCCDCCCc##CCCCCCCC##cCCCDCCCD##.",
		".###CCCDSSDDDDCCCCCCCCDDDDSSDCCC###.",
		".###CCCDSSDDDDCCCCCCCCDDDDSSDCCC###.",
		"....####DDCDCCCCCCCCCCCCDCDD####....",
		"........##CCCCCCCCCCCCCCCC##........",
		"........##CCCCCCCCCCCCCCCC##........",
		"........##CCCCDDDCCCCDCCCD##........",
		"..........#DCCCCCDDCCCCCD#..........",
		"..........#DCCCCCDDCCCCCD#..........",
		"...........#DDCCCDDCCDDD#...........",
		"............##DDDCDDDD##............",
		"............##CCCDDCCC##............",
		"............##CCCDDCCC##............",
		"...........#CCCccCCCCc##............",
		"...........#CCCccCCCCCCC#...........",
		"...........#CCCccCCCCCCC#...........",
		"..........#cCCDCCDDCCDCCc#..........",
		"..........#CCCDSS#SSSDCCC#..........",
		"..........#CCCDSS#SSSDCCC#..........",
		"..........#CCCC##.#DDCCCC#..........",
		"..........#DDDD##..##DDDD#..........",
		"..........#DDDD##..##DDDD#..........",
		"........##CCDD#......#DDC#..........",
		"........##cC##.......#CCCc##........",
		"........##cC##.......#CCCc##........",
		"........##CC##........##CC##........",
		"........##C#..........##DC##........",
		"........##C#..........##DC##........",
		".......#DDC#............#CDD#.......",
		".......#DDD#............#DDD#.......",
		".......#DDD#............#DDD#.......",
		".......#####..########..#####.......",
	],
	"buff_pose_point": [
		"....................................",
		"....................................",
		"....................................",
		".................................###",
		"................................#CC#",
		"................................#CC#",
		".............................###cDD#",
		"...........######.........###CCC####",
		"..........#cccccc#........###CCC####",
		"..........#cccccc#.......#CCcC##....",
		"........##cccccccc##.####CCCC#......",
		"........##wwwccwww##.####CCCC#......",
		"........##wwwccwww##.CCCCCDD#.......",
		"........##ww#cc#ww##.CCCCD##........",
		"........##cccccccc##.CCCCD##........",
		"......#.##cccccccc##.DCCD#..........",
		"....##C.##CCCDDCCC##.S###...........",
		"....##CC##CCCCCCCC#SSS###...........",
		"...#ccCDCCCCCCCCCCCCC#..............",
		".##CCCCDCCCDCCCCCCCDD#..............",
		".##CCCCDCCCDCCCCCCCDD#..............",
		".##CCCD#DDCDDDCCCCD##...............",
		".##CDD#.##DCDDCDDD#.................",
		".##DCCD#..#DDDDDDC#.................",
		".##DCCD#..#DDDDDDC#.................",
		"...###DD##DCDDCCCC#.................",
		"......##SSCCCCcCCCC###..............",
		"......##SSCCCCcCCCC###..............",
		"........##DDDDCCCCCCCc##............",
		".......#CCDSSSSDDCCCCCCC#...........",
		".......#CCDSSSSDDCCCCCCC#...........",
		"......#CCCCD#####DDDDCCC#...........",
		"...###DDCCD#.....#SDDCCC#...........",
		"...###DDCCD#.....#SDDCCC#...........",
		"...#ccCD###.......#CCCCC#...........",
		".##CCC##..........#DDC##............",
		".##CCC##..........#DDC##............",
		"#CCD##.............###..............",
		"#DD#..............#CCD##............",
		"#DD#..............#CCD##............",
		"####...........##.#######...........",
		"####..............#..#DDD#..........",
		"####..............#..#DDD#..........",
		"######.............#######..........",
	],
	"buff_pose_kneel": [
		"....................................",
		"....######......######..............",
		"....######.....#cccccc#.............",
		"...#CCCCCC#....#cccccc#.............",
		".##CCC####...##cccccccc##...........",
		".##CCC####...##wwwccwww##...........",
		".##c##.......##wwwccwww##...........",
		"#CCCCC#...##.##ww#cc#ww##...........",
		"#CCCCC#...##.##cccccccc##...........",
		"#CCCCCS###Cc.##cccccccc##.####......",
		"#CCCDDCcCCCC.##CCCDDCCC##.CCc#......",
		"#CCCDDCcCCCC##CCCCCCCC##ccCCc#......",
		"#DDDCCCCCCDCccCDDCCccCCCCCCCCC##....",
		"#DDCCCDDSSDcccCCCcCCCCCCCCCCCCCC###.",
		"#DDCCCDDSSDcccCCCcCCCCCCCCCCCCCC###.",
		".###DDCCSSCcCCCCCCCCCCCCDDCCCCCCc##.",
		"....######CCCCDCCcCCCCDDSDcccCCCCCC#",
		"....######CCCCDCCcCCCCDDSDcccCCCCCC#",
		"..........#CDDSDDCCDDDSSSSCCCDCCCCC#",
		"...........#CCDCCDDDDDDDDS##SCccCCC#",
		"...........#CCDCCDDDDDDDDS##SCccCCC#",
		"...........#CCDCCCDCCDDDD#..#CCCDCC#",
		"...........#DDCCCCDCCDDD#...#CCCCDD#",
		"......#####.##CDDCDCCCDDS###CCCCD##.",
		"......#####.##CDDCDCCCDDS###CCCCD##.",
		"...###CcCCC#SSCCCCDCCDSSCCCCCC###...",
		".##CcccCCCCCDDDDDDDDDDDDCcCCD#......",
		".##CcccCCCCCDDDDDDDDDDDDCcCCD#......",
		".##CDDCCCCCCDDDCCDDCCCDDDCDD#.......",
		".##CCCDDCCCCDDSCCDCccCCCS###........",
		".##CCCDDCCCCDDSCCDCccCCCS###........",
		".##CCCCDSSDDDDS##SCCCCCC#...........",
		"...#CCCcSS#####..#CCCCCCC#..........",
		"...#CCCcSS#####..#CCCCCCC#..........",
		"...#CCDC##.......#CCCCCC#.....##....",
		"...#DDCD##.......#CCCCCCD#####CC#...",
		"...#DDCD##.......#CCCCCCD#####CC#...",
		"....##CC##........#CCCCCDCCCCCCC#...",
		"......#C##........#CCCDDDCDD##DD#...",
		"......#C##........#CCCDDDCDD##DD#...",
		"...###CC##.........##CCCD###..###...",
		".##DDDC#...........##CDDD#..........",
		".##DDDC#...........##CDDD#..........",
		"#######...........##########........",
	],

	"slime_a": [
		"........",
		"..####..",
		".#gggg#.",
		"#gwggwg#",
		"#g#gg#g#",
		"#gggggg#",
		"#GGGGGG#",
		".######.",
	],
	"slime_b": [
		"........",
		"........",
		"..####..",
		".#gggg#.",
		"#gwggwg#",
		"#g#gg#g#",
		"#GGGGGG#",
		".######.",
	],
	"gem": [
		"..yy..",
		".ywwy.",
		"yywyyy",
		"yyyyyy",
		".yYYy.",
		"..YY..",
	],
	"spike": [
		"........",
		"...##...",
		"..#w1#..",
		"..#11#..",
		".#1112#.",
		".#1122#.",
		"#112222#",
		"#MMMMMM#",
	],
	"spring": [
		"........",
		"........",
		"........",
		"..####..",
		".#mmmm#.",
		"#mMMMMm#",
		"#MMMMMM#",
		"########",
	],
	"spring_fired": [
		"..####..",
		".#mmmm#.",
		"#mmmmmm#",
		"#mMMMMm#",
		"#MMMMMM#",
		"########",
		"........",
		"........",
	],
	"saw_a": [
		"...##...",
		"..#11#..",
		".#1111#.",
		"##11ww1#",
		"#1ww11##",
		".#1111#.",
		"..#11#..",
		"...##...",
	],
	"saw_b": [
		"..#..#..",
		".#1111#.",
		"#111111#",
		".11ww11.",
		".11ww11.",
		"#111111#",
		".#1111#.",
		"..#..#..",
	],
	"bat_a": [
		"........",
		"#p....p#",
		"#pp..pp#",
		".#pppp#.",
		"..#ww#..",
		"..#pp#..",
		"...##...",
		"........",
	],
	"bat_b": [
		"........",
		"........",
		"..#pp#..",
		".#pppp#.",
		"#p#ww#p#",
		"#pp##pp#",
		".#....#.",
		"........",
	],
	"crumble": [
		"########",
		"#122211#",
		"#122211#",
		"#111111#",
		"#112221#",
		"#112221#",
		"#122211#",
		"########",
	],
	"crumble_cracked": [
		"########",
		"#12#211#",
		"#1#2211#",
		"#11#111#",
		"#112#21#",
		"#1122#11",
		"#12#211#",
		"########",
	],
	"platform_icon": [
		"........",
		"........",
		"........",
		"########",
		"#yyyyyy#",
		"#YYYYYY#",
		"########",
		"........",
	],
	"breakable": [
		"########",
		"#YYyyYY#",
		"#Yy##yY#",
		"#yy##yy#",
		"#yy##yy#",
		"#Yy##yY#",
		"#YYyyYY#",
		"########",
	],
	"crystal": [
		"...##...",
		"..#cc#..",
		".#cwwc#.",
		"#cwwwwc#",
		"#cwwwwc#",
		".#cCCc#.",
		"..#CC#..",
		"...##...",
	],
	"crystal_used": [
		"...ff...",
		"..f..f..",
		".f....f.",
		"f......f",
		"f......f",
		".f....f.",
		"..f..f..",
		"...ff...",
	],
	"timed_on": [
		"########",
		"#pppppp#",
		"#pbbbbp#",
		"#pbbbbp#",
		"#pbbbbp#",
		"#pbbbbp#",
		"#pppppp#",
		"########",
	],
	"timed_off": [
		"ff....ff",
		"f......f",
		"........",
		"........",
		"........",
		"........",
		"f......f",
		"ff....ff",
	],
	"door": [
		"..########..",
		".#pppppppp#.",
		"#pp######pp#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#pp######pp#",
		".##########.",
	],

	# Codex icons. Every one is 8x8, exactly like the entity sprites, so the
	# book can scale all of them by the same integer factor — mixing a 12x16
	# door with 8x8 creatures made one tower over the rest.
	#
	# Abilities get pictograms rather than player poses: run, jump, wall, stomp
	# and dash are the *same* two or three sprites in the game (idle, jump,
	# fall), so a page per ability showed the same little blue figure five times
	# over. An arrow says which verb it is; a character sprite cannot.
	"icon_run": [
		"........",
		"..c..c..",
		"...c..c.",
		"....c..c",
		"...c..c.",
		"..c..c..",
		"........",
		"11111111",
	],
	"icon_jump": [
		"...cc...",
		"..cccc..",
		".cccccc.",
		"...cc...",
		"...cc...",
		"...cc...",
		"........",
		"11111111",
	],
	"icon_wall": [
		"..cc.111",
		".cccc111",
		"ccccc111",
		"..cc.111",
		"..cc.111",
		"..cc.111",
		"..cc.111",
		".....111",
	],
	"icon_stomp": [
		"...cc...",
		"...cc...",
		"...cc...",
		".cccccc.",
		"..cccc..",
		"...cc...",
		"........",
		"11.11.11",
	],
	"icon_dash": [
		"........",
		"1.......",
		".....c..",
		"......c.",
		"11cccccc",
		"......c.",
		".....c..",
		"1.......",
	],
	# Step 23 — echo. A loop closing on itself: the one pictogram in the set
	# that reads as "return" rather than "go".
	# Step 24 — clone. A footprint trailing off from the figure: the same
	# shape, one step behind.
	"icon_clone": [
		"..pp....",
		".p..p...",
		".p..p...",
		".pppp...",
		"....p...",
		"...pp...",
		"........",
		"11111111",
	],
	"icon_echo": [
		"..pp....",
		".p..p...",
		"p....p..",
		"p....p..",
		".p..p...",
		"..pp....",
		"........",
		"11111111",
	],
	"icon_charge": [
		"...cc...",
		"..cccc..",
		"...cc...",
		"........",
		"11111111",
		"........",
		"11111111",
		"........",
	],
	"icon_pound": [
		"...mm...",
		"...mm...",
		".mmmmmm.",
		"..mmmm..",
		"...mm...",
		"........",
		"11111111",
		"m......m",
	],
	# Three links climbing the same diagonal, cool to hot: the colour code the
	# in-game popup uses (cyan, gold, white) read backwards as a staircase.
	"icon_combo": [
		"......w.",
		".....ww.",
		"....yy..",
		"...yy...",
		"..cc....",
		".cc.....",
		"........",
		"........",
	],
	# The playable door is 12x16; this is its 8x8 stand-in for the book.
	"icon_door": [
		"..####..",
		".#pppp#.",
		".#pbbp#.",
		".#pbbp#.",
		".#pbbp#.",
		".#pbbp#.",
		".#pwbp#.",
		".######.",
	],
	# Open book for the corner button.
	#
	# Two things this had to get right. The outer edges run straight down: an
	# earlier attempt started the top rows inset and widened them going down,
	# which is the silhouette of two hills, not a book. Only the *top* edge
	# steps inward, and that is what reads as pages fanned open.
	#
	# The rim is gold, not OUTLINE. OUTLINE is #07070f against a #0f0f1b
	# background — darker than the thing it is meant to stand out from, so it
	# vanished and left an undefined white blob with no spine. Gold separates
	# from the background and matches the cover on the codex page.
	"icon_book": [
		"YY...........YY",
		"YwwY.......YwwY",
		"YwwwwY...YwwwwY",
		"YwwwwwY.YwwwwwY",
		"YwwwwwwYwwwwwwY",
		"Yw1111wYw1111wY",
		"YwwwwwwYwwwwwwY",
		"Yw1111wYw1111wY",
		"YwwwwwwYwwwwwwY",
		"YyyyyyyYyyyyyyY",
		".YYYYYYYYYYYYY.",
	],
	# Compact control icon used by title and pause. Strong outer steps, a square
	# axle and top-to-bottom shading keep it readable as a gear at 2x scale.
	"icon_gear": [
		"....####....",
		"....#ww#....",
		"..##w11w##..",
		".##w1111w##.",
		"##w11##11w##",
		"#w11#bb#11w#",
		"#111#bb#111#",
		"##111##111##",
		".##111111##.",
		"..##2222##..",
		"....#22#....",
		"....####....",
	],
	# --- ice, conveyors, retracting spikes ---
	"ice": [
		"########",
		"#wwCCCC#",
		"#wCCCCC#",
		"#CCCwCC#",
		"#CCCCCC#",
		"#CCwCCC#",
		"#CCCCCC#",
		"########",
	],
	# Four phases of one belt tile, each a pixel further along than the last.
	# The chevrons have a period of four pixels, so the fourth frame lands
	# exactly back on the first and the run scrolls without a seam. Rows are
	# lit plate, five rows of chevron, roller studs, base outline — and no side
	# edges, because a belt is drawn as one strip and any vertical line would
	# show up as a false joint every eight pixels.
	"belt_0": [
		"11111111",
		"c222c222",
		"2c222c22",
		"22c222c2",
		"2c222c22",
		"c222c222",
		"2fff2fff",
		"########",
	],
	"belt_1": [
		"11111111",
		"2c222c22",
		"22c222c2",
		"222c222c",
		"22c222c2",
		"2c222c22",
		"f2fff2ff",
		"########",
	],
	"belt_2": [
		"11111111",
		"22c222c2",
		"222c222c",
		"c222c222",
		"222c222c",
		"22c222c2",
		"ff2fff2f",
		"########",
	],
	"belt_3": [
		"11111111",
		"222c222c",
		"c222c222",
		"2c222c22",
		"c222c222",
		"222c222c",
		"fff2fff2",
		"########",
	],
	# Risen: the same silhouette as a fixed spike, so the danger reads the same.
	"spike_up": [
		"........",
		"...##...",
		"..#w1#..",
		"..#11#..",
		".#1112#.",
		".#1122#.",
		"#112222#",
		"#MMMMMM#",
	],
	# Retracted: a base plate you can walk over.
	"spike_low": [
		"........",
		"........",
		"........",
		"........",
		"........",
		"..#11#..",
		"#112222#",
		"#MMMMMM#",
	],
	# A blade that fills more than one tile is built from three pieces: the
	# point on top, shaft in the middle, and the base plate at the bottom.
	# 'spike_up' stays the whole thing at once, for the one-tile case and the
	# codex entry.
	"spike_tip": [
		"...##...",
		"..#w1#..",
		"..#11#..",
		".#1112#.",
		".#1112#.",
		".#1122#.",
		".#1122#.",
		".#1122#.",
	],
	"spike_shaft": [
		".#1122#.",
		".#w122#.",
		".#1122#.",
		".#1122#.",
		".#1122#.",
		".#w122#.",
		".#1122#.",
		".#1122#.",
	],
	"spike_base": [
		".#1122#.",
		".#1122#.",
		".#w122#.",
		".#1122#.",
		".#1122#.",
		".#1122#.",
		"#112222#",
		"#MMMMMM#",
	],
	# Step 12 — switches and gates. The lever leans toward the side it means:
	# left and dim when off, right and lit when on. Gate is a filled block
	# behind the same outline every wall has, versus an outline with nothing
	# behind it — full versus empty is the whole vocabulary a 8x8 tile has for
	# "in your way" against "not in your way any more".
	"switch_off": [
		"........",
		"..1.....",
		"..11....",
		"...11...",
		"....11..",
		"..2222..",
		".222222.",
		"........",
	],
	"switch_on": [
		"........",
		".....c..",
		"....cc..",
		"...cc...",
		"..cc....",
		"..2222..",
		".222222.",
		"........",
	],
	# Step 24 — clone fantasma. A plate that reads as pressed or not: taller and
	# grey when idle, squashed and glowing cyan the instant real weight sits on
	# it — same "flat is inactive, lit is active" language switch_on/off use.
	"sensor_off": [
		"........",
		"........",
		"..####..",
		".#1111#.",
		"#111111#",
		"#GGGGGG#",
		"########",
		"........",
	],
	"sensor_on": [
		"........",
		"........",
		"........",
		"..####..",
		".#cccc#.",
		"#CCCCCC#",
		"########",
		"........",
	],
	"gate_solid": [
		"########",
		"#yyyyyy#",
		"#yYYYYy#",
		"#yYyyYy#",
		"#yYyyYy#",
		"#yYYYYy#",
		"#yyyyyy#",
		"########",
	],
	"gate_open": [
		"########",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"########",
	],
	# Step 13 — wind. Invisible in the room itself (the particles are the
	# tell); these two exist only so the sandbox editor has something to show
	# where a designer put one.
	"wind_up": [
		"........",
		"...cc...",
		"..cccc..",
		"........",
		"...cc...",
		"..cccc..",
		"........",
		"........",
	],
	"wind_side": [
		"........",
		"..c.....",
		".cc.....",
		"cccccc..",
		".cc.....",
		"..c.....",
		"........",
		"........",
	],
	# Step 14 — phase block. A real outline, same as every other block in the
	# game, so the silhouette still reads as a wall — the dotted border this
	# used to have broke that read entirely, closer to noise than a block.
	# Diagonal purple stripes inside instead of scattered dots: caution-tape
	# language for "not always solid," on a shape you can still tell is one.
	# Level dims it further (modulate.a) while it is actually passable.
	# Step 21 — ghost blocks. Body colour marks which rule the block obeys —
	# grey-blue for 'h' (still), amber for 'H' (moving) — so the pause bars and
	# the arrows are backup reading, not the only signal. GhostBlock itself
	# fades the whole sprite's alpha for the intangible state; the art here
	# never changes, only how solid it looks.
	"ghost_h": [
		"########",
		"#111111#",
		"#1c##c1#",
		"#1c##c1#",
		"#1c##c1#",
		"#1c##c1#",
		"#111111#",
		"########",
	],
	"ghost_H": [
		"########",
		"#222222#",
		"#2y2y22#",
		"#22y2y2#",
		"#2y2y22#",
		"#22y2y2#",
		"#222222#",
		"########",
	],
	# Step 22 — gravity zones. Codex icon only — the real in-room zone is its
	# own backdrop layer now (see Level._bake_gravity_zones()), a tinted wall
	# with a lit edge rather than this checker; the icon stays a simple
	# pictogram of the same idea for the book page.
	"grav_zone": [
		"b.b.b.b.",
		".b.b.b.b",
		"b.b.b.b.",
		".b.b.b.b",
		"b.b.b.b.",
		".b.b.b.b",
		"b.b.b.b.",
		".b.b.b.b",
	],
	# Fundo — no-dash. Codex/palette icon only, same split as grav_zone: the
	# real in-room zone is its own backdrop layer (Level._bake_mod_zones()).
	# A dash arrow with a bar through it, gold like the crystal that refills
	# the move it cancels here.
	"no_dash_zone": [
		"........",
		"..y..y..",
		".yyyyy..",
		"yyyyyyyy",
		".yyyyy..",
		"..y..y..",
		"........",
		"........",
	],
	# Fundo — no-pound. Same idea, a downward stomp arrow with a bar through
	# it, cyan-dark to sit apart from no-dash's gold.
	"no_pound_zone": [
		"..D..D..",
		"..D..D..",
		"..DDD...",
		"DDDDDDDD",
		"..DDD...",
		"...D....",
		"........",
		"........",
	],
	"phase_block": [
		"########",
		"#p.p.p.#",
		"#.p.p.p#",
		"#p.p.p.#",
		"#.p.p.p#",
		"#p.p.p.#",
		"#.p.p.p#",
		"########",
	],
	# Step 15 — portals. Same ring, cyan for one end and purple for the other —
	# the colour is the only thing that says which tile belongs to which pair.
	"portal_a": [
		"........",
		"..cccc..",
		".c....c.",
		"c......c",
		"c......c",
		".c....c.",
		"..cccc..",
		"........",
	],
	"portal_b": [
		"........",
		"..pppp..",
		".p....p.",
		"p......p",
		"p......p",
		".p....p.",
		"..pppp..",
		"........",
	],
	# Step 16 — lasers. The core brightens through the cycle: grey dormant,
	# cyan warning, white firing. The beam itself is draw_rect(), not a
	# sprite — its length changes every shot.
	"laser_idle": [
		"........",
		".######.",
		".#1111#.",
		".#1221#.",
		".#1221#.",
		".#1111#.",
		".######.",
		"........",
	],
	"laser_warn": [
		"........",
		".######.",
		".#cccc#.",
		".#cCCc#.",
		".#cCCc#.",
		".#cccc#.",
		".######.",
		"........",
	],
	"laser_fire": [
		"........",
		".######.",
		".#wwww#.",
		".#wCCw#.",
		".#wCCw#.",
		".#wwww#.",
		".######.",
		"........",
	],
	# Step 17 — ferry bat. Two tiles wide, with a gold strip along the back
	# that reads as "you can stand here" the way the plain bat never needed
	# to. A blank row used to sit between that strip and the bat's own body,
	# so the two read as an orange bar floating over an unrelated purple
	# blob rather than one creature gripping its perch — wingtips now touch
	# the strip directly, same claw-on-a-branch read a hanging bat needs.
	# ferry_dive is the wings-closed silhouette it drops into when the
	# deadline runs out.
	"ferry_a": [
		"yyyyyyyyyyyyyyyy",
		"..#p......p#....",
		".#pp......pp#...",
		"..#pppppppp#....",
		"...#w####w#.....",
		"....########....",
		"................",
		"................",
	],
	"ferry_b": [
		"yyyyyyyyyyyyyyyy",
		"...#p......p#...",
		"....#p....p#....",
		"..#pp########pp#",
		"...#wwwwwwww#...",
		"....########....",
		"................",
		"................",
	],
	"ferry_dive": [
		"................",
		"................",
		".....######.....",
		"....#pppppp#....",
		"....#pwwwwp#....",
		"....#pppppp#....",
		".....######.....",
		"................",
	],
	# --- shielded and elastic enemies ---
	# Same trick as the slime's walk: frame b drops one body row and shifts
	# everything down into it, so the whole plate squashes on the beat instead
	# of just the eyes flickering. Feet stay pinned to the bottom row in both.
	"shield_a": [
		"........",
		"..####..",
		"#w1111w#",
		".#gggg#.",
		"#gwggwg#",
		"#g#gg#g#",
		"#GGGGGG#",
		".######.",
	],
	"shield_b": [
		"........",
		"........",
		"..####..",
		"#w1111w#",
		"#ggwwgg#",
		"#g#gg#g#",
		"#GGGGGG#",
		".######.",
	],
	"elastic_a": [
		"........",
		"..####..",
		".#yyyy#.",
		"#ywyywy#",
		"#y#yy#y#",
		"#yyyyyy#",
		"#YYYYYY#",
		".######.",
	],
	"elastic_b": [
		"........",
		"........",
		"..####..",
		".#yyyy#.",
		"#ywyywy#",
		"#yyyyyy#",
		"#YYYYYY#",
		".######.",
	],
	# --- collectibles and medals ---
	"gem_secret": [
		"..pp..",
		".pwwp.",
		"ppwppp",
		"pppppp",
		".pMMp.",
		"..MM..",
	],
	# Drawn white and tinted at the call site, so one grid serves both the
	# earned and the unearned state.
	"medal_time": [
		"#######",
		"#wwwww#",
		"#.www.#",
		"#..w..#",
		"#.www.#",
		"#wwwww#",
		"#######",
	],
	"medal_gems": [
		"...w...",
		"..www..",
		".wwwww.",
		"wwwwwww",
		".wwwww.",
		"..www..",
		"...w...",
	],
	"medal_clean": [
		".wwwww.",
		"wwwwwww",
		"wwwwwww",
		"wwwwwww",
		".wwwww.",
		"..www..",
		"...w...",
	],
}

static var _cache: Dictionary = {}


## Texture for a named grid, built once and reused.
static func tex(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	# A missing grid used to take the whole frame down with an invalid index.
	# A loud warning and a blank texture is the better trade: the sprite is
	# obviously absent on screen and the room stays playable.
	if not GRIDS.has(name):
		push_error("PixelArt: no sprite named '%s'" % name)
		_cache[name] = from_grid(["."])
		return _cache[name]
	var t := from_grid(GRIDS[name])
	_cache[name] = t
	return t


## Small shared cache for textures that are built rather than drawn from a grid
## — a belt band the width of its run, for instance. Rooms rebuild on every
## death, so without this the same strip is rebaked hundreds of times.
static func has_cached(key: String) -> bool:
	return _cache.has(key)


static func cached(key: String) -> ImageTexture:
	return _cache[key]


static func store(key: String, t: ImageTexture) -> ImageTexture:
	_cache[key] = t
	return t


static func from_grid(rows: Array) -> ImageTexture:
	var h := rows.size()
	var w := 0
	for row in rows:
		w = maxi(w, (row as String).length())
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var c: Color = Palette.CHARS.get(row[x], Color(0, 0, 0, 0))
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Flat coloured rectangle, handy for bars and flashes.
static func solid(size: Vector2i, color: Color) -> ImageTexture:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


# ----------------------------------------------------------------- tiles ---

## Paint one 8x8 terrain tile into `img`, shading its exposed edges.
## The neighbour flags say whether solid ground continues in that direction.
static func paint_tile(img: Image, tx: int, ty: int, up: bool, down: bool,
		left: bool, right: bool) -> void:
	var ox := tx * TILE
	var oy := ty * TILE

	for y in TILE:
		for x in TILE:
			img.set_pixel(ox + x, oy + y, Palette.FRAME)

	# Two speckles per tile, placed by a cheap deterministic hash so the
	# terrain has texture without ever shimmering between frames.
	var h := (tx * 73856093) ^ (ty * 19349663)
	var s1 := Vector2i(2 + absi(h) % 4, 3 + absi(h / 7) % 4)
	var s2 := Vector2i(1 + absi(h / 13) % 5, 2 + absi(h / 31) % 5)
	img.set_pixel(ox + s1.x, oy + s1.y, Palette.BG_SOFT)
	img.set_pixel(ox + s2.x, oy + s2.y, Palette.BG_SOFT)

	if not left:
		for y in TILE:
			img.set_pixel(ox, oy + y, Palette.OUTLINE)
	if not right:
		for y in TILE:
			img.set_pixel(ox + TILE - 1, oy + y, Palette.OUTLINE)
	if not down:
		for x in TILE:
			img.set_pixel(ox + x, oy + TILE - 1, Palette.OUTLINE)
	if not up:
		# Lit rim on anything you can stand on.
		for x in TILE:
			img.set_pixel(ox + x, oy, Palette.CYAN_MID)
			img.set_pixel(ox + x, oy + 1, Palette.CYAN_DARK)
		if not left:
			img.set_pixel(ox, oy, Palette.OUTLINE)
		if not right:
			img.set_pixel(ox + TILE - 1, oy, Palette.OUTLINE)


## A vertical run of ordinary wall, left edge exposed — the texture a wall you
## can cling to actually has in a room, not a flat rectangle standing in for
## it. `up` and `down` are true for every tile (the column keeps going past
## both ends), so paint_tile only outlines the exposed left face and leaves
## the lit rim for an actual floor tile to use.
static var _wall_cache: Dictionary = {}

static func wall_strip(tiles: int) -> ImageTexture:
	if _wall_cache.has(tiles):
		return _wall_cache[tiles]
	var img := Image.create_empty(TILE, TILE * tiles, false, Image.FORMAT_RGBA8)
	for ty in tiles:
		paint_tile(img, 0, ty, true, true, false, true)
	var t := ImageTexture.create_from_image(img)
	_wall_cache[tiles] = t
	return t


## One-way platform: a thin lit slab you can jump up through.
static func paint_platform(img: Image, tx: int, ty: int) -> void:
	var ox := tx * TILE
	var oy := ty * TILE
	for x in TILE:
		img.set_pixel(ox + x, oy, Palette.CYAN_MID)
		img.set_pixel(ox + x, oy + 1, Palette.CYAN_DARK)
		img.set_pixel(ox + x, oy + 2, Palette.OUTLINE)


## Step 22 — gravity zone. The BACKDROP category's first member: painted onto
## its own layer behind the terrain (Level._bake_gravity_zones()), never the
## terrain texture itself, so a creature, a gem or the player's own sprite —
## anything in _entities — draws over it exactly as if it were not there.
## The checker is the same mark it always was; only the layer it lives on
## changed, so it never again gets mistaken for a texture on a real block.
static func paint_gravity_zone(img: Image, tx: int, ty: int, up: bool, down: bool,
		left: bool, right: bool) -> void:
	var ox := tx * TILE
	var oy := ty * TILE
	for y in TILE:
		for x in TILE:
			if (x + y) % 2 == 0:
				img.set_pixel(ox + x, oy + y, Palette.BG_SOFT)

	var edge := Palette.PURPLE
	edge.a = 0.5
	if not up:
		for x in TILE:
			img.set_pixel(ox + x, oy, edge)
	if not down:
		for x in TILE:
			img.set_pixel(ox + x, oy + TILE - 1, edge)
	if not left:
		for y in TILE:
			img.set_pixel(ox, oy + y, edge)
	if not right:
		for y in TILE:
			img.set_pixel(ox + TILE - 1, oy + y, edge)


## Fundo — no-dash zone. Same checker as paint_gravity_zone, same technique,
## only the colour moves: the faintest gold wash on the checker itself, not
## just the edge, so it still reads as "the same kind of thing as the
## gravity zone" at a glance — the checker stays close to unlit, and the
## edge is what actually says which Fundo tile this is.
static func paint_no_dash_zone(img: Image, tx: int, ty: int, up: bool, down: bool,
		left: bool, right: bool) -> void:
	var ox := tx * TILE
	var oy := ty * TILE
	var checker := Palette.BG_SOFT.lerp(Palette.GOLD_DARK, 0.12)
	for y in TILE:
		for x in TILE:
			if (x + y) % 2 == 0:
				img.set_pixel(ox + x, oy + y, checker)

	var edge := Palette.GOLD
	edge.a = 0.5
	if not up:
		for x in TILE:
			img.set_pixel(ox + x, oy, edge)
	if not down:
		for x in TILE:
			img.set_pixel(ox + x, oy + TILE - 1, edge)
	if not left:
		for y in TILE:
			img.set_pixel(ox, oy + y, edge)
	if not right:
		for y in TILE:
			img.set_pixel(ox + TILE - 1, oy + y, edge)


## Fundo — no-pound zone. Same as paint_no_dash_zone, cyan instead of gold so
## it never gets mistaken for it when the two overlap.
static func paint_no_pound_zone(img: Image, tx: int, ty: int, up: bool, down: bool,
		left: bool, right: bool) -> void:
	var ox := tx * TILE
	var oy := ty * TILE
	var checker := Palette.BG_SOFT.lerp(Palette.CYAN_DARK, 0.12)
	for y in TILE:
		for x in TILE:
			if (x + y) % 2 == 0:
				img.set_pixel(ox + x, oy + y, checker)

	var edge := Palette.CYAN_MID
	edge.a = 0.5
	if not up:
		for x in TILE:
			img.set_pixel(ox + x, oy, edge)
	if not down:
		for x in TILE:
			img.set_pixel(ox + x, oy + TILE - 1, edge)
	if not left:
		for y in TILE:
			img.set_pixel(ox, oy + y, edge)
	if not right:
		for y in TILE:
			img.set_pixel(ox + TILE - 1, oy + y, edge)


## Ice tile: flat frozen body with a hard frost crust on any face you can land
## on. Built the same way ordinary terrain is — a solid fill plus a couple of
## hash-placed marks — so it sits in the same art, and the cyan plus the bright
## top are what tell you it is slippery before you step on it.
static func paint_ice(img: Image, tx: int, ty: int, up: bool, down: bool,
		left: bool, right: bool) -> void:
	var ox := tx * TILE
	var oy := ty * TILE

	for y in TILE:
		for x in TILE:
			img.set_pixel(ox + x, oy + y, Palette.CYAN_DARK)

	# Deterministic marks, same trick as paint_tile: texture that never
	# shimmers between frames because it is derived from the tile position.
	var h := absi((tx * 374761393) ^ (ty * 668265263))
	img.set_pixel(ox + 1 + h % 5, oy + 2 + (h / 7) % 4, Palette.CYAN_MID)
	img.set_pixel(ox + 2 + (h / 13) % 4, oy + 3 + (h / 31) % 4, Palette.CYAN_MID)

	# Every third tile or so catches a glint: a small cross, bright in the
	# middle. Sparse on purpose — a sparkle on every tile reads as noise.
	if h % 3 == 0:
		var cx := 2 + (h / 61) % 4
		var cy := 3 + (h / 97) % 3
		img.set_pixel(ox + cx, oy + cy, Palette.WHITE)
		img.set_pixel(ox + cx - 1, oy + cy, Palette.CYAN_MID)
		img.set_pixel(ox + cx + 1, oy + cy, Palette.CYAN_MID)
		img.set_pixel(ox + cx, oy + cy - 1, Palette.CYAN_MID)
		img.set_pixel(ox + cx, oy + cy + 1, Palette.CYAN_MID)

	if not left:
		for y in TILE:
			img.set_pixel(ox, oy + y, Palette.OUTLINE)
	if not right:
		for y in TILE:
			img.set_pixel(ox + TILE - 1, oy + y, Palette.OUTLINE)
	if not down:
		for x in TILE:
			img.set_pixel(ox + x, oy + TILE - 1, Palette.OUTLINE)
	if not up:
		# Frost crust: a hard white lip over a cyan band, brighter than the
		# lit rim on plain terrain so the two never get confused mid-run.
		for x in TILE:
			img.set_pixel(ox + x, oy, Palette.WHITE)
			img.set_pixel(ox + x, oy + 1, Palette.CYAN)
		if not left:
			img.set_pixel(ox, oy, Palette.OUTLINE)
		if not right:
			img.set_pixel(ox + TILE - 1, oy, Palette.OUTLINE)


# ------------------------------------------------------------- title cube ---

## The logo cube, rebuilt from the same maths as logo/make_logo.py.
static func cube(size_faces: int = 8) -> ImageTexture:
	var side := size_faces
	var img := Image.create_empty(18, 8 + side + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ox := 1
	var oy := 1

	for r in 8:
		var half := r if r < 4 else 7 - r
		var x0 := 7 - (half * 2 + 1)
		var x1 := 8 + (half * 2 + 1)
		for x in range(x0, x1 + 1):
			img.set_pixel(ox + x, oy + r, Palette.CYAN)

	for x in 8:
		var ytop := 4 + x / 2
		for y in range(ytop, ytop + side):
			img.set_pixel(ox + x, oy + y, Palette.CYAN_MID)
	for x in range(8, 16):
		var ytop := 4 + (15 - x) / 2
		for y in range(ytop, ytop + side):
			img.set_pixel(ox + x, oy + y, Palette.CYAN_DARK)

	for p: Vector2i in [Vector2i(5, 2), Vector2i(6, 2), Vector2i(4, 3), Vector2i(5, 3), Vector2i(7, 1)]:
		img.set_pixel(ox + p.x, oy + p.y, Palette.WHITE)

	_outline_image(img, Palette.OUTLINE)
	return ImageTexture.create_from_image(img)


## Two square rings sharing a middle edge — reads as an infinity symbol at
## small pixel sizes without needing a diagonal curve. Used by the mode-select
## screen for endless, the way cube() is used there for story.
static func infinity_icon(loop: int = 7) -> ImageTexture:
	var img := Image.create_empty(loop * 4 + 2, loop * 2 + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ox := 1
	var oy := 1

	for side in 2:
		var x0 := side * loop * 2
		for y in loop * 2:
			for x in loop * 2:
				var on_border := x == 0 or x == loop * 2 - 1 or y == 0 or y == loop * 2 - 1
				if not on_border:
					continue
				var shade := Palette.PURPLE if (x + y) % 3 != 0 else Palette.MAGENTA
				img.set_pixel(ox + x0 + x, oy + y, shade)

	img.set_pixel(ox + loop - 1, oy + 1, Palette.WHITE)
	img.set_pixel(ox + loop * 3, oy + 1, Palette.WHITE)

	_outline_image(img, Palette.OUTLINE)
	return ImageTexture.create_from_image(img)


## Wrap every opaque pixel with `color` on its empty orthogonal neighbours.
static func _outline_image(img: Image, color: Color) -> void:
	var todo: Array[Vector2i] = []
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a == 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if n.x < 0 or n.y < 0 or n.x >= img.get_width() or n.y >= img.get_height():
					continue
				if img.get_pixel(n.x, n.y).a == 0.0:
					todo.append(n)
	for p in todo:
		img.set_pixel(p.x, p.y, color)
