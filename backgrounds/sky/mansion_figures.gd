## The twenty-eight 宿's own star groups (星官), drawn as figures on the sphere: the
## Chinese half of the sky's line layer, next to the 88 IAU figures Constellations
## writes.
##
## A 宿 is not one figure but a bag of 星官 (角宿 has eleven), and a 星官 is a chain of
## stars in the order they are numbered (一, 二, 三 …) - which is the order the
## traditional charts draw them in, so a chain of designations is the whole figure.
## A 星官 whose stars are numbered in several separate parts keeps one chain per part:
## 角宿's 柱 is "楼中柱有十五星，三三相著如鼎形" - five little groups spread round the
## outside of 库楼 - and one chain through all of it would run from 1 Cen to π Cen,
## 33° of line that is on no chart.
##
## The stars are named the way 伊世同《中西对照恒星图表》(1981) names them - Bayer letter
## or Flamsteed number, with the constellation - and resolved against the catalogue's
## own designations, like every other line on this sky (计划 §6.3: no coordinate table
## enters the repo). Only the 星官's own stars are drawn: the 清《仪象考成》 additions
## (增星) are not in this table.
##
## The chains were checked against Stellarium's 中国星空 sky culture, which gives the
## same figures as HIP numbers - same stars, same parts, nothing taken from it (the
## same cross-check Constellations' figures went through, data/SOURCES.md). It differs
## on one star: its 库楼 carries HD 107931 where the 伊世同 table has 库楼九 = D Cen, and
## the table below follows the latter.
class_name MansionFigures
extends RefCounted

## Bayer letters BSC5 cannot name. Four of 角宿's stars and one of 柱's carry a Latin
## letter rather than a Greek one (g Cen, d Cen, f Cen, D Cen, a Cen), and BSC5 writes
## no Latin-letter Bayer designation at all - it files those stars under no name, so the
## only key left is the HR number, which is also how a star is identified here. The HR
## numbers are the ones SIMBAD gives for those letters; they were checked against BSC5
## itself (the positions agree to 0.001°, and B, V show the same star).
const LETTERED := {
	"g Cen": 5192,   ## 库楼四
	"d Cen": 5089,   ## 库楼五
	"f Cen": 4940,   ## 库楼六
	"D Cen": 4652,   ## 库楼九
	"a Cen": 5378,   ## 柱五
}

## 宿 -> 星官 -> the chains that 星官 is drawn as. A chain is a space-separated list of
## designations (Bayer letter or Flamsteed number, then the constellation), in 星名
## order; a 星官 that is a single star is a chain of one and draws no line at all.
##
## Written 宿 by 宿 - 角宿 is the first, the rest follow as they are drawn (计划 §6.5
## S6): the 星官 table is the 伊世同 one, whose 星数 are the ones quoted per entry.
const FIGURES := {
	"角": {
		## 二星, 苍龙之角: 角宿一 α Vir (Spica) and 角宿二 ζ Vir, the 距星 of the 宿
		"角": ["α Vir ζ Vir"],
		## 二星 under the horn, the road that ran to the 秋分点 in 魏晋
		"平道": ["θ Vir 82 Vir"],
		## 二星: 天田一 78 Vir (o Vir) and 天田二 τ Vir
		"天田": ["78 Vir τ Vir"],
		## 三星, 后发座's trio round β Com
		"周鼎": ["β Com 37 Com 41 Com"],
		## 一星. 明末《崇祯历书》 moved it off θ Vir (which 平道 took) onto 44 Vir = k Vir
		"进贤": ["44 Vir"],
		## 二星, the gate the 黄道 passes through, between the two stars of 角
		"天门": ["53 Vir 69 Vir"],
		## 二星, 长蛇座's γ and π Hya - the judge of 断狱
		"平": ["γ Hya π Hya"],
		## 十星, "屈曲明": one long curve through 半人马座, from 库楼一 ζ Cen round to
		## 库楼十 σ Cen. The five 距星-less letters in the middle are LETTERED's
		"库楼": ["ζ Cen η Cen θ Cen g Cen d Cen f Cen γ Cen τ Cen D Cen σ Cen"],
		## 十一星 in five parts, all of them outside 库楼 itself: the υ pair, the 豺狼座
		## pair, a Cen with ψ Cen, the 4-3-1 Cen trio, and 柱十 π Cen and 柱十一 ι Cen
		## which stand alone 30° apart and are therefore two chains of one
		"柱": ["υ1 Cen υ2 Cen", "ι Lup τ1 Lup", "a Cen ψ Cen", "4 Cen 3 Cen 1 Cen",
				"π Cen", "ι Cen"],
		## 四星, "其中四星别名衡": the railing in front of 库楼, a straight run of four
		"衡": ["ν Cen μ Cen φ Cen χ Cen"],
		## 二星, 库楼's south gate: ε Cen and α Cen, the latter 南门二, the nearest star
		"南门": ["ε Cen α Cen"],
	},
}


## The 宿 this table has figures for, in the order they are written.
static func mansions() -> Array:
	return FIGURES.keys()


## How many 星官 宿 `mansion` is drawn as.
static func guan_count(mansion: String) -> int:
	return (FIGURES[mansion] as Dictionary).size()


## How many stars the table names for 宿 `mansion` - the 星官's own counts, so it is
## the number the 伊世同 table quotes for the 宿 (角宿: 41).
static func star_count(mansion: String) -> int:
	var total := 0
	var groups: Dictionary = FIGURES[mansion]
	for guan: String in groups:
		for chain: String in groups[guan]:
			total += chain.split(" ", false).size() / 2
	return total


## Every chain of every 宿 in the table, as unit directions on the sphere - what the
## sky hands to SkyLines.polyline_layer. A chain whose every star resolves is a
## polyline; a 星官 the catalogue cannot place is left out whole and reported, because
## half a figure drawn between the stars that did resolve is a chord the sky never had.
static func chains(catalogue: StarCat) -> Array:
	var out := []
	for mansion: String in mansions():
		out.append_array(mansion_chains(catalogue, mansion))
	return out


## The chains of one 宿, in 星官 order and then in part order.
static func mansion_chains(catalogue: StarCat, mansion: String) -> Array:
	var out := []
	var groups: Dictionary = FIGURES[mansion]
	for guan: String in groups:
		for chain: String in groups[guan]:
			var stars := _chain(catalogue, mansion, guan, chain)
			if stars.size() < 2:
				continue
			var line := []
			for star in stars:
				line.append(StarCat.direction(catalogue.ra[star], catalogue.dec[star]))
			out.append(line)
	return out


## Where each 星官's own name goes: the middle of the stars it is drawn by. The sky
## hangs a name on every 星官 in the table (SkyLabels), the way it does for the 88.
##
## A 星官 whose stars are in several parts is named at the middle of the parts that
## are actually drawn: 柱十 π Cen stands 30° west of the rest of 柱, and a name
## averaged over it would sit in empty sky next to nothing. A 星官 that is a single
## star all through (进贤) has no drawn part, so its own star carries the name.
static func anchors(catalogue: StarCat) -> Array:
	var out := []
	for mansion: String in mansions():
		var groups: Dictionary = FIGURES[mansion]
		for guan: String in groups:
			var parts := []
			var drawn := false
			for text: String in groups[guan]:
				var stars := _chain(catalogue, mansion, guan, text)
				parts.append(stars)
				drawn = drawn or stars.size() > 1
			var sum := Vector3.ZERO
			var count := 0
			for stars: PackedInt32Array in parts:
				if drawn and stars.size() < 2:
					continue
				for star in stars:
					sum += StarCat.direction(catalogue.ra[star], catalogue.dec[star])
					count += 1
			if count == 0:
				continue
			out.append({"name": guan, "direction": (sum / float(count)).normalized()})
	return out


## Star index for one designation of this table, or -1: a Flamsteed number, a Greek
## Bayer letter, or - the case Constellations cannot answer - one of LETTERED's Latin
## letters, which only an HR number names.
static func star_of(catalogue: StarCat, designation: String, abbrev: String) -> int:
	var lettered := int(LETTERED.get("%s %s" % [designation, abbrev], 0))
	if lettered != 0:
		return catalogue.find_hr(lettered)
	return Constellations.star_of(catalogue, designation, abbrev)


## One chain as star indices, and the one place a missing star is reported. A chain
## the catalogue cannot place whole comes back empty on purpose: half a figure drawn
## between the stars that did resolve is a chord the sky never had.
static func _chain(catalogue: StarCat, mansion: String, guan: String,
		chain: String) -> PackedInt32Array:
	var stars := PackedInt32Array()
	var tokens := chain.split(" ", false)
	for i in range(0, tokens.size(), 2):
		var star := star_of(catalogue, tokens[i], tokens[i + 1])
		if star < 0:
			push_warning("MansionFigures: %s宿 %s has no %s %s"
					% [mansion, guan, tokens[i], tokens[i + 1]])
			return PackedInt32Array()
		stars.append(star)
	return stars
