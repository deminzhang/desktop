## The 88 constellations: IAU abbreviation, Latin and Chinese names, and the
## figure to draw between their stars.
##
## Figures are written as Bayer-letter pairs ("α-β") and resolved against the
## catalogue's own designations (StarCat.bayer/abbrev), so the lines follow the
## stars the catalogue carries instead of a second coordinate table, and they
## turn with SkyRoot like everything else on the sphere.
##
## The figures are self-authored (计划 §6.3 keeps third-party line data out of the
## repo). Two asterisms act as the regression check after any edit: Orion's belt
## (δ-ε-ζ, which must stay collinear) and the Big Dipper's pointers (α-β, which
## must point at Polaris).
class_name Constellations
extends RefCounted

const TABLE := {
	"And": {"latin": "Andromeda", "zh": "仙女座", "figure": "α-δ δ-β β-γ γ-α α-μ"},
	"Ant": {"latin": "Antlia", "zh": "唧筒座", "figure": "α-ε ε-ι"},
	"Aps": {"latin": "Apus", "zh": "天燕座", "figure": "α-γ γ-δ δ-β"},
	"Aqr": {"latin": "Aquarius", "zh": "宝瓶座", "figure": "α-β β-δ δ-ζ ζ-γ γ-η η-π"},
	"Aql": {"latin": "Aquila", "zh": "天鹰座", "figure": "γ-α α-β β-ζ ζ-θ θ-λ λ-δ"},
	"Ara": {"latin": "Ara", "zh": "天坛座", "figure": "α-β β-γ γ-ζ ζ-α"},
	"Ari": {"latin": "Aries", "zh": "白羊座", "figure": "α-β β-γ"},
	"Aur": {"latin": "Auriga", "zh": "御夫座", "figure": "α-β β-θ θ-ι ι-α α-ε ε-η"},
	"Boo": {"latin": "Boötes", "zh": "牧夫座", "figure": "α-ε ε-δ δ-β β-γ γ-α α-η"},
	"Cae": {"latin": "Caelum", "zh": "雕具座", "figure": "α-β β-γ"},
	"Cam": {"latin": "Camelopardalis", "zh": "鹿豹座", "figure": "α-β β-γ"},
	"Cnc": {"latin": "Cancer", "zh": "巨蟹座", "figure": "α-β β-δ δ-γ γ-α α-ι"},
	"CVn": {"latin": "Canes Venatici", "zh": "猎犬座", "figure": "α2-β"},
	"CMa": {"latin": "Canis Major", "zh": "大犬座", "figure": "α-β β-δ δ-ε ε-η η-σ σ-δ α-ε"},
	"CMi": {"latin": "Canis Minor", "zh": "小犬座", "figure": "α-β α-ε"},
	"Cap": {"latin": "Capricornus", "zh": "摩羯座", "figure": "α-β β-ψ ψ-ω ω-ζ ζ-δ δ-γ γ-α"},
	"Car": {"latin": "Carina", "zh": "船底座", "figure": "α-β β-υ υ-θ θ-ω ω-α"},
	"Cas": {"latin": "Cassiopeia", "zh": "仙后座", "figure": "β-α α-γ γ-δ δ-ε"},
	"Cen": {"latin": "Centaurus", "zh": "半人马座", "figure": "α1-β β-θ θ-γ γ-ε ε-ζ ζ-η"},
	"Cep": {"latin": "Cepheus", "zh": "仙王座", "figure": "α-γ γ-β β-ζ ζ-α α-η η-ι ι-β"},
	"Cet": {"latin": "Cetus", "zh": "鲸鱼座", "figure": "α-γ γ-β β-δ δ-ζ ζ-τ τ-η η-θ ι-β"},
	"Cha": {"latin": "Chamaeleon", "zh": "堰蜓座", "figure": "α-γ γ-β β-θ"},
	"Cir": {"latin": "Circinus", "zh": "圆规座", "figure": "α-β β-γ γ-α"},
	"Col": {"latin": "Columba", "zh": "天鸽座", "figure": "α-β β-γ γ-δ δ-α α-ε"},
	"Com": {"latin": "Coma Berenices", "zh": "后发座", "figure": "α-β β-γ γ-α"},
	"CrA": {"latin": "Corona Australis", "zh": "南冕座", "figure": "α-β β-γ γ-δ δ-ε ε-α"},
	"CrB": {"latin": "Corona Borealis", "zh": "北冕座", "figure": "α-β β-γ γ-δ δ-ε ε-θ θ-α"},
	"Crv": {"latin": "Corvus", "zh": "乌鸦座", "figure": "α-β β-δ δ-γ γ-ε ε-α β-ε"},
	"Crt": {"latin": "Crater", "zh": "巨爵座", "figure": "α-β β-γ γ-δ δ-α α-η"},
	"Cru": {"latin": "Crux", "zh": "南十字座", "figure": "α-β β-δ δ-γ γ-α α-ε"},
	"Cyg": {"latin": "Cygnus", "zh": "天鹅座", "figure": "α-γ γ-β β-ε ε-δ δ-α α-η η-ι"},
	"Del": {"latin": "Delphinus", "zh": "海豚座", "figure": "α-β β-γ γ-δ δ-ε ε-α"},
	"Dor": {"latin": "Dorado", "zh": "剑鱼座", "figure": "α-β β-γ γ-δ"},
	"Dra": {"latin": "Draco", "zh": "天龙座", "figure": "γ-β β-δ δ-ζ ζ-η η-θ θ-ι ι-α α-κ κ-λ λ-δ α-ε"},
	"Equ": {"latin": "Equuleus", "zh": "小马座", "figure": "α-β β-δ δ-γ"},
	"Eri": {"latin": "Eridanus", "zh": "波江座", "figure": "α-θ θ-γ γ-β β-ε ε-δ δ-ζ ζ-η η-τ τ-υ υ-κ κ-ι"},
	"For": {"latin": "Fornax", "zh": "天炉座", "figure": "α-β β-ν"},
	"Gem": {"latin": "Gemini", "zh": "双子座", "figure": "α-τ τ-ε ε-η η-β β-υ υ-δ δ-ζ ζ-γ γ-η"},
	"Gru": {"latin": "Grus", "zh": "天鹤座", "figure": "α-β β-γ γ-δ δ-α α-ι ι-θ"},
	"Her": {"latin": "Hercules", "zh": "武仙座", "figure": "ζ-ε ε-π π-η η-ζ α-β β-γ γ-δ δ-ε ε-ζ ζ-η"},
	"Hor": {"latin": "Horologium", "zh": "时钟座", "figure": "α-β β-γ γ-δ"},
	"Hya": {"latin": "Hydra", "zh": "长蛇座", "figure": "α-β β-γ γ-δ δ-ε ε-ζ ζ-η η-θ θ-ι ι-υ υ-λ"},
	"Hyi": {"latin": "Hydrus", "zh": "水蛇座", "figure": "α-β β-γ γ-δ"},
	"Ind": {"latin": "Indus", "zh": "印第安座", "figure": "α-β β-γ γ-θ θ-α"},
	"Lac": {"latin": "Lacerta", "zh": "蝎虎座", "figure": "α-β β-1"},
	"Leo": {"latin": "Leo", "zh": "狮子座", "figure": "α-η η-γ γ-ζ ζ-μ μ-ε ε-δ δ-β β-θ θ-γ"},
	"LMi": {"latin": "Leo Minor", "zh": "小狮座", "figure": "46-β β-21"},
	"Lep": {"latin": "Lepus", "zh": "天兔座", "figure": "α-β β-γ γ-δ δ-ε ε-α α-μ"},
	"Lib": {"latin": "Libra", "zh": "天秤座", "figure": "α-β β-γ γ-σ σ-α α-τ"},
	"Lup": {"latin": "Lupus", "zh": "豺狼座", "figure": "α-β β-γ γ-δ δ-ε ε-ζ ζ-η"},
	"Lyn": {"latin": "Lynx", "zh": "天猫座", "figure": "α-38 38-15 15-2"},
	"Lyr": {"latin": "Lyra", "zh": "天琴座", "figure": "α-β β-γ γ-δ δ-ζ ζ-β α-ε ε-ζ"},
	"Men": {"latin": "Mensa", "zh": "山案座", "figure": "α-β β-γ"},
	"Mic": {"latin": "Microscopium", "zh": "显微镜座", "figure": "α-β β-γ"},
	"Mon": {"latin": "Monoceros", "zh": "麒麟座", "figure": "α-β β-γ γ-δ δ-ε"},
	"Mus": {"latin": "Musca", "zh": "苍蝇座", "figure": "α-β β-γ γ-δ δ-α α-ε"},
	"Nor": {"latin": "Norma", "zh": "矩尺座", "figure": "γ2-δ δ-ε ε-η η-ι1"},
	"Oct": {"latin": "Octans", "zh": "南极座", "figure": "α-β β-γ γ-δ"},
	"Oph": {"latin": "Ophiuchus", "zh": "蛇夫座", "figure": "α-β β-γ γ-δ δ-ε ε-ζ ζ-η η-θ θ-ι ι-κ κ-α"},
	"Ori": {"latin": "Orion", "zh": "猎户座", "figure": "λ-α λ-γ α-ζ ζ-ε ε-δ δ-γ ζ-β δ-κ"},
	"Pav": {"latin": "Pavo", "zh": "孔雀座", "figure": "α-β β-γ γ-δ δ-ε ε-α"},
	"Peg": {"latin": "Pegasus", "zh": "飞马座", "figure": "α-β β-γ γ-α α-ε ε-ζ ζ-η η-θ"},
	"Per": {"latin": "Perseus", "zh": "英仙座", "figure": "α-β β-δ δ-γ γ-α α-ε ε-ζ ζ-η"},
	"Phe": {"latin": "Phoenix", "zh": "凤凰座", "figure": "α-β β-γ γ-δ δ-ε ε-α"},
	"Pic": {"latin": "Pictor", "zh": "绘架座", "figure": "α-β β-γ"},
	"Psc": {"latin": "Pisces", "zh": "双鱼座", "figure": "α-η η-γ γ-θ θ-ι ι-λ λ-κ κ-ω"},
	"PsA": {"latin": "Piscis Austrinus", "zh": "南鱼座", "figure": "α-β β-γ γ-δ δ-ε ε-ι ι-μ"},
	"Pup": {"latin": "Puppis", "zh": "船尾座", "figure": "ζ-π π-ρ ρ-ξ ξ-ν ν-τ"},
	"Pyx": {"latin": "Pyxis", "zh": "罗盘座", "figure": "α-β β-γ γ-δ"},
	"Ret": {"latin": "Reticulum", "zh": "网罟座", "figure": "α-β β-γ γ-δ δ-α"},
	"Sge": {"latin": "Sagitta", "zh": "天箭座", "figure": "α-β β-γ γ-δ δ-α"},
	"Sgr": {"latin": "Sagittarius", "zh": "人马座", "figure": "α-β β-γ γ-δ δ-ε ε-ζ ζ-φ φ-λ λ-σ σ-τ τ-ζ"},
	"Sco": {"latin": "Scorpius", "zh": "天蝎座", "figure": "α-β β-δ δ-π π-σ σ-α α-τ τ-ε ε-μ μ-ζ ζ-η η-θ θ-ι ι-κ κ-λ λ-υ"},
	"Scl": {"latin": "Sculptor", "zh": "玉夫座", "figure": "α-β β-γ"},
	"Sct": {"latin": "Scutum", "zh": "盾牌座", "figure": "α-β β-γ"},
	"Ser": {"latin": "Serpens", "zh": "巨蛇座", "figure": "α-β β-γ γ-δ δ-ε ε-ζ ζ-η"},
	"Sex": {"latin": "Sextans", "zh": "六分仪座", "figure": "α-β β-γ"},
	"Tau": {"latin": "Taurus", "zh": "金牛座", "figure": "α-γ γ-δ δ-ε ε-β β-α α-ζ ζ-λ"},
	"Tel": {"latin": "Telescopium", "zh": "望远镜座", "figure": "α-ζ ζ-η η-ι"},
	"Tri": {"latin": "Triangulum", "zh": "三角座", "figure": "α-β β-γ γ-α"},
	"TrA": {"latin": "Triangulum Australe", "zh": "南三角座", "figure": "α-β β-γ γ-α"},
	"Tuc": {"latin": "Tucana", "zh": "杜鹃座", "figure": "α-β β-γ γ-δ"},
	"UMa": {"latin": "Ursa Major", "zh": "大熊座", "figure": "α-β β-γ γ-δ δ-α δ-ε ε-ζ ζ-η α-θ θ-ι ι-κ κ-λ λ-μ"},
	"UMi": {"latin": "Ursa Minor", "zh": "小熊座", "figure": "α-δ δ-ε ε-ζ ζ-η η-β β-γ γ-ζ"},
	"Vel": {"latin": "Vela", "zh": "船帆座", "figure": "γ2-δ δ-λ λ-κ κ-φ φ-μ μ-ψ"},
	"Vir": {"latin": "Virgo", "zh": "室女座", "figure": "α-γ γ-η η-β β-ε ε-δ δ-γ γ-ο ο-μ μ-ν"},
	"Vol": {"latin": "Volans", "zh": "飞鱼座", "figure": "α-β β-γ γ-δ"},
	"Vul": {"latin": "Vulpecula", "zh": "狐狸座", "figure": "α-13 13-23"},
}


static func abbreviations() -> Array:
	var keys := TABLE.keys()
	keys.sort()
	return keys


static func latin(abbrev: String) -> String:
	return String(TABLE[abbrev]["latin"]) if TABLE.has(abbrev) else abbrev


static func chinese(abbrev: String) -> String:
	return String(TABLE[abbrev]["zh"]) if TABLE.has(abbrev) else abbrev


## Resolves one figure into star index pairs of `catalogue`. Anything that cannot
## be resolved is reported instead of being dropped silently: a mistyped letter
## would otherwise just make a line disappear.
static func figure(catalogue: StarCat, abbrev: String) -> Array:
	var out := []
	for pair in String(TABLE[abbrev].get("figure", "")).split(" ", false):
		var ends := pair.split("-")
		if ends.size() != 2:
			continue
		var a := star_of(catalogue, ends[0], abbrev)
		var b := star_of(catalogue, ends[1], abbrev)
		if a < 0 or b < 0:
			push_warning("Constellations: %s has no %s-%s"
					% [abbrev, ends[0] if a < 0 else "", ends[1] if b < 0 else ""])
			continue
		out.append(Vector2i(a, b))
	return out


## "α", "α2" or "46" -> index in `catalogue`, -1 when the designation is missing.
static func star_of(catalogue: StarCat, designation: String, abbrev: String) -> int:
	if designation.is_valid_int():
		return catalogue.find_flamsteed(int(designation), abbrev)
	var letter := designation
	var superscript := 0
	var last := designation.substr(designation.length() - 1, 1)
	if last.is_valid_int():
		letter = designation.substr(0, designation.length() - 1)
		superscript = int(last)
	if superscript > 0:
		return catalogue.find(letter, abbrev, superscript)
	# a plain letter may belong to a pair the catalogue splits as α1/α2: take the
	# brighter of the two
	var first := catalogue.find(letter, abbrev, 0)
	if first >= 0:
		return first
	var a := catalogue.find(letter, abbrev, 1)
	var b := catalogue.find(letter, abbrev, 2)
	if a < 0:
		return b
	if b < 0:
		return a
	return a if catalogue.mag[a] <= catalogue.mag[b] else b
