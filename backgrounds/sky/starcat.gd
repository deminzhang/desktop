## Yale Bright Star Catalogue (BSC5, CDS V/50) reader.
##
## The file is fixed-width ASCII, 197 bytes per record, 9110 records, with the
## field table taken straight from the catalogue's ReadMe (see data/SOURCES.md).
## Only what the sky needs is read: HR number, name, J2000 position, V magnitude
## and B-V colour.
##
## Positions are kept in degrees; direction() is the single place that turns
## them into a vector on the celestial sphere, so every stage (star field, S2
## constellation lines, S3 alt/az) shares one convention.
class_name StarCat
extends RefCounted

const CATALOG := "res://backgrounds/sky/data/catalog.txt"

## Fixed-width field offsets, 0-based: [start, length].
const HR := [0, 4]
const NAME := [4, 10]
const RA_H := [75, 2]
const RA_M := [77, 2]
const RA_S := [79, 4]
const DEC_SIGN := [83, 1]
const DEC_D := [84, 2]
const DEC_M := [86, 2]
const DEC_S := [88, 2]
const VMAG := [102, 5]
const BV := [109, 5]
## Shortest line that still carries every field above.
const MIN_LINE := 114

## Bayer codes as the catalogue writes them, paired with the Greek letter the
## figures are written in.
const BAYER_CODES := ["Alp", "Bet", "Gam", "Del", "Eps", "Zet", "Eta", "The", "Iot",
	"Kap", "Lam", "Mu", "Nu", "Xi", "Omi", "Pi", "Rho", "Sig", "Tau", "Ups", "Phi",
	"Chi", "Psi", "Ome"]
const BAYER_LETTERS := ["α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ", "λ", "μ",
	"ν", "ξ", "ο", "π", "ρ", "σ", "τ", "υ", "φ", "χ", "ψ", "ω"]

var hr := PackedInt32Array()
var names := PackedStringArray()
var ra := PackedFloat32Array()   ## degrees, J2000
var dec := PackedFloat32Array()  ## degrees, J2000
var mag := PackedFloat32Array()  ## V magnitude
var bv := PackedFloat32Array()   ## B-V colour index
var bayer := PackedStringArray()     ## Greek letter, "" when unnamed by Bayer
var abbrev := PackedStringArray()    ## IAU constellation abbreviation
var superscript := PackedInt32Array()  ## 1 or 2 for α1/α2, else 0
var flamsteed := PackedInt32Array()  ## Flamsteed number, 0 when absent

var _by_designation := {}


static func load_default() -> StarCat:
	return load_file(CATALOG)


static func load_file(path: String) -> StarCat:
	if not FileAccess.file_exists(path):
		push_error("StarCat: catalogue missing at %s" % path)
		return null
	return parse(FileAccess.get_file_as_string(path))


static func parse(text: String) -> StarCat:
	var cat := StarCat.new()
	for line in text.split("\n"):
		if line.length() < MIN_LINE:
			continue
		var ra_h := field(line, RA_H)
		var sign := field(line, DEC_SIGN)
		var vmag := field(line, VMAG)
		# the catalogue itself blanks the position fields of withdrawn records
		if ra_h.is_empty() or vmag.is_empty() or sign.is_empty():
			continue
		var seconds := float(field(line, RA_S))
		var dec := float(field(line, DEC_D)) \
				+ float(field(line, DEC_M)) / 60.0 \
				+ float(field(line, DEC_S)) / 3600.0
		cat.hr.append(int(field(line, HR)))
		var designation := field(line, NAME)
		cat.names.append(designation)
		cat.abbrev.append(designation.substr(designation.length() - 3, 3)
				if designation.length() >= 3 else "")
		var digits := ""
		for k in designation.length():
			var c := designation.substr(k, 1)
			if not c.is_valid_int():
				break
			digits += c
		cat.flamsteed.append(int(digits) if not digits.is_empty() else 0)
		var head := designation.substr(0, maxi(designation.length() - 3, 0))
		var letter := ""
		var superscript := 0
		for b in BAYER_CODES.size():
			var at := head.find(BAYER_CODES[b])
			if at < 0:
				continue
			letter = BAYER_LETTERS[b]
			var after := head.substr(at + 3, 1)
			superscript = int(after) if after.is_valid_int() else 0
			break
		cat.bayer.append(letter)
		cat.superscript.append(superscript)
		cat.ra.append((float(ra_h) + float(field(line, RA_M)) / 60.0
				+ seconds / 3600.0) * 15.0)
		cat.dec.append(dec if sign != "-" else -dec)
		cat.mag.append(float(vmag))
		var colour := field(line, BV)
		cat.bv.append(float(colour) if not colour.is_empty() else 0.0)
	return cat


func count() -> int:
	return mag.size()


## Index of the star with this designation, or -1. `script_index` is 0 for a
## plain letter, 1/2 for α1/α2. Built on first use.
func find(letter: String, constellation: String, script_index := 0) -> int:
	if _by_designation.is_empty():
		for i in count():
			if bayer[i] != "":
				_by_designation["%s|%s|%d" % [bayer[i], abbrev[i], superscript[i]]] = i
	return int(_by_designation.get("%s|%s|%d" % [letter, constellation, script_index], -1))


## Index of the star with this Flamsteed number, or -1. Several bright stars (α
## Leonis Minoris, β Lyncis, ...) only have a Flamsteed number in this catalogue.
func find_flamsteed(number: int, constellation: String) -> int:
	for i in count():
		if flamsteed[i] == number and abbrev[i] == constellation:
			return i
	return -1


## Star indices per constellation abbreviation, from the catalogue's own names.
func members() -> Dictionary:
	var out := {}
	for i in count():
		if abbrev[i] == "":
			continue
		var list: Array = out.get(abbrev[i], [])
		list.append(i)
		out[abbrev[i]] = list
	return out


## Unit vector for a J2000 position, in the sphere's frame:
##   +X = (RA 0h, Dec 0°), +Y = north celestial pole, +Z = (RA 18h, Dec 0°)
## The mapping is a rotation (determinant +1), so constellations keep their
## handedness instead of coming out mirrored.
static func direction(ra_deg: float, dec_deg: float) -> Vector3:
	var ra_rad := deg_to_rad(ra_deg)
	var cos_dec := cos(deg_to_rad(dec_deg))
	return Vector3(cos_dec * cos(ra_rad), sin(deg_to_rad(dec_deg)), -cos_dec * sin(ra_rad))


static func field(line: String, spec: Array) -> String:
	return line.substr(int(spec[0]), int(spec[1])).strip_edges()
