## The twenty-eight 宿 (README「星点、记号与取舍」): the equatorial divisions of the Chinese sky.
##
## Each 宿 opens at its 距星 - the "determinative star" its span is measured from -
## and runs to the right ascension of the next one's, so the 宿度 are the 距星's RA
## spans and the divisions are equatorial rather than ecliptic (the ecliptic's own
## 十二宫 and 廿四节气 are Ecliptic's). The 距星 are named here by designation alone
## and their positions are looked up in the star catalogue the sky already carries,
## so this file adds no coordinates and no third-party data (README「数据源与许可」's red line).
##
## The classic 宿度 - 角 11.83°, 井 32.53°, 觜 1.97° as the shortest of them - come
## out of these spans to within a degree or two: the old values are the 距星 of their
## own epoch, and two thousand years of precession have moved them.
class_name Mansions
extends RefCounted

const NAMES := ["角", "亢", "氐", "房", "心", "尾", "箕", "斗", "牛", "女", "虚", "危",
		"室", "壁", "奎", "娄", "胃", "昴", "毕", "觜", "参", "井", "鬼", "柳", "星",
		"张", "翼", "轸"]

## One entry per 宿, in the same order: the 距星 as [Bayer letter, Flamsteed number,
## the Bayer script (0 plain, 1/2 for α1/α2), constellation abbreviation]. Nearly all
## are named by Bayer; 胃 and 昴 carry only a Flamsteed number in this catalogue, 氐
## is α² rather than α¹, and 尾, 箕, 张 are the scripted pairs (μ¹ Sco, γ² Sgr,
## υ¹ Hya).
const DISTANCE_STARS := [
	["α", 0, 0, "Vir"], ["κ", 0, 0, "Vir"], ["α", 0, 2, "Lib"], ["π", 0, 0, "Sco"],
	["σ", 0, 0, "Sco"], ["μ", 0, 1, "Sco"], ["γ", 0, 2, "Sgr"], ["φ", 0, 0, "Sgr"],
	["β", 0, 0, "Cap"], ["ε", 0, 0, "Aqr"], ["β", 0, 0, "Aqr"], ["α", 0, 0, "Aqr"],
	["α", 0, 0, "Peg"], ["γ", 0, 0, "Peg"], ["η", 0, 0, "And"], ["β", 0, 0, "Ari"],
	["", 35, 0, "Ari"], ["", 17, 0, "Tau"], ["ε", 0, 0, "Tau"], ["λ", 0, 0, "Ori"],
	["ζ", 0, 0, "Ori"], ["μ", 0, 0, "Gem"], ["θ", 0, 0, "Cnc"], ["δ", 0, 0, "Hya"],
	["α", 0, 0, "Hya"], ["υ", 0, 1, "Hya"], ["α", 0, 0, "Crt"], ["γ", 0, 0, "Crv"],
]

## What the sky writes for a 宿 it cannot find its 距星 for: a division with no star
## to start at is not a division, so the whole layer is held back instead.
const MISSING := -1

var catalogue: StarCat
## Right ascension of each 宿's opening, J2000 degrees, in NAMES order.
var boundary_ra := PackedFloat32Array()
## Catalogue index of each 距星, or MISSING. All of them resolve in BSC5.
var distance_index := PackedInt32Array()


## Resolves the 距星 and their right ascensions against `catalogue`.
static func build(catalogue: StarCat) -> Mansions:
	var mansions := Mansions.new()
	mansions.catalogue = catalogue
	for index in NAMES.size():
		var spec: Array = DISTANCE_STARS[index]
		var star := (catalogue.find_flamsteed(int(spec[1]), String(spec[3]))
				if String(spec[0]) == "" else
				catalogue.find(String(spec[0]), String(spec[3]), int(spec[2])))
		if star < 0:
			push_warning("Mansions: no 距星 for 宿 '%s' (%s %s)"
					% [NAMES[index], spec[0], spec[3]])
		mansions.distance_index.append(star)
		mansions.boundary_ra.append(catalogue.ra[star] if star >= 0 else 0.0)
	return mansions


## Whether every 宿 found its 距星.
func complete() -> bool:
	for star in distance_index:
		if star == MISSING:
			return false
	return true


## The 宿度 of `index`: from its 距星's right ascension to the next one's, degrees
## eastwards along the equator.
func span(index: int) -> float:
	return fposmod(boundary_ra[(index + 1) % NAMES.size()] - boundary_ra[index], 360.0)


## The right ascension the sky writes 宿 `index`'s own name at: the middle of it.
func centre_ra(index: int) -> float:
	return fposmod(boundary_ra[index] + span(index) * 0.5, 360.0)


## Which 宿 a right ascension falls in (0..27).
func index_of(ra_deg: float) -> int:
	var ra := fposmod(ra_deg, 360.0)
	for index in NAMES.size() - 1:
		var into := fposmod(ra - boundary_ra[index], 360.0)
		if into < span(index):
			return index
	# the last one owns whatever is left, including the wrap across 0h
	return NAMES.size() - 1


## Which 宿 a right ascension falls in, its name, and the degrees into it.
func of_ra(ra_deg: float) -> Dictionary:
	var index := index_of(ra_deg)
	return {"index": index, "name": NAMES[index],
			"degrees": fposmod(fposmod(ra_deg, 360.0) - boundary_ra[index], 360.0)}


## The unit direction of 宿 `index`'s own mark on the sphere: the middle of its span,
## on the equator the divisions are measured along.
func centre_direction(index: int) -> Vector3:
	return StarCat.direction(centre_ra(index), 0.0)
