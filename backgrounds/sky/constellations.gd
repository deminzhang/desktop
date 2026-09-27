## The 88 constellations: IAU abbreviation, Latin and Chinese names, and the
## figure to draw between their stars.
##
## Figures are written as Bayer-letter pairs ("α-β") and resolved against the
## catalogue's own designations (StarCat.bayer/abbrev), so the lines follow the
## stars the catalogue carries instead of a second coordinate table, and they
## turn with SkyRoot like everything else on the sphere.
##
## The figures are the traditional asterisms (计划 §6.3 keeps third-party line
## data out of the repo: no coordinate list is copied, the shapes are written
## here as designation pairs). A star a figure needs but the catalogue files
## under a neighbour - the Argo pieces, Serpens Cauda, Auriga's base - is
## short-cut onto the nearest stars this constellation may name, so a handful of
## segments are straight chords of the traditional path.
##
## Two asterisms act as the regression check after any edit: Orion's belt
## (δ-ε-ζ, which must stay collinear) and the Big Dipper's pointers (α-β, which
## must point at Polaris). Two more are worth a look, both from the 2026-10-09
## round: Draco must not cut across Ursa Minor, and no figure should cross
## itself except Crux's two bars and Carina's beams.
class_name Constellations
extends RefCounted

const TABLE := {
	"And": {"latin": "Andromeda", "zh": "仙女座", "figure": "α-δ π-δ π-ι ε-δ ε-ζ δ-β ζ-η ν-μ ν-φ μ-β φ-51 β-γ1 ο-ι λ-κ ι-κ κ-ψ"},
	"Ant": {"latin": "Antlia", "zh": "唧筒座", "figure": "ε-α α-ι"},
	"Aps": {"latin": "Apus", "zh": "天燕座", "figure": "α-δ1 δ1-β γ-β"},
	"Aqr": {"latin": "Aquarius", "zh": "宝瓶座", "figure": "ε-μ μ-β β-α β-ι α-θ α-γ γ-ζ2 π-ζ2 ζ2-η η-λ λ-ψ2 88-ψ2 ψ2-98 ψ2-104"},
	"Aql": {"latin": "Aquila", "zh": "天鹰座", "figure": "ζ-δ ζ-α λ-δ δ-α δ-η γ-α α-β η-θ β-θ"},
	"Ara": {"latin": "Ara", "zh": "天坛座", "figure": "η-ζ η-δ ζ-ε1 ε1-α β-α γ-δ"},
	"Ari": {"latin": "Aries", "zh": "白羊座", "figure": "γ2-β β-α α-41"},
	"Aur": {"latin": "Auriga", "zh": "御夫座", "figure": "ι-η ι-θ ε-ζ ε-α η-α α-δ α-β δ-β β-θ"},
	"Boo": {"latin": "Boötes", "zh": "牧夫座", "figure": "τ-η η-α κ1-λ κ1-θ α-ρ α-ζ α-ε λ-θ λ-γ ρ-γ γ-β ε-δ β-δ"},
	"Cae": {"latin": "Caelum", "zh": "雕具座", "figure": "δ-α α-β β-γ1"},
	"Cam": {"latin": "Camelopardalis", "zh": "鹿豹座", "figure": "γ-α α-β 7-β"},
	"Cnc": {"latin": "Cancer", "zh": "巨蟹座", "figure": "β-δ γ-δ γ-ι δ-α"},
	"CVn": {"latin": "Canes Venatici", "zh": "猎犬座", "figure": "β-α1"},
	"CMa": {"latin": "Canis Major", "zh": "大犬座", "figure": "ζ-ε β-α α-ι α-ο2 θ-ι θ-γ ι-γ ε-σ σ-δ ο2-δ δ-η"},
	"CMi": {"latin": "Canis Minor", "zh": "小犬座", "figure": "β-α"},
	"Cap": {"latin": "Capricornus", "zh": "摩羯座", "figure": "α1-β α1-θ β-ρ ρ-ψ ψ-ω ω-ζ θ-ι ι-γ ζ-δ γ-δ"},
	"Car": {"latin": "Carina", "zh": "船底座", "figure": "α-β χ-ε χ-ι ε-ι β-ω ι-θ ω-θ"},
	"Cas": {"latin": "Cassiopeia", "zh": "仙后座", "figure": "β-α α-γ γ-δ δ-ε"},
	"Cen": {"latin": "Centaurus", "zh": "半人马座", "figure": "π-δ ο1-ρ δ-σ ρ-σ σ-γ γ-ε ι-ν ε-ζ ε-β ε-α1 ν-μ ν-θ μ-ζ θ-η η-κ"},
	"Cep": {"latin": "Cepheus", "zh": "仙王座", "figure": "θ-η η-α α-β α-μ β-ι β-γ μ-ε ζ-ε ζ-δ δ-ι ι-γ"},
	"Cet": {"latin": "Cetus", "zh": "鲸鱼座", "figure": "ι-β ι-η β-τ η-θ θ-ζ τ-ζ ζ-ο ο-δ ξ2-ν ξ2-μ ν-γ δ-γ γ-α μ-λ λ-α"},
	"Cha": {"latin": "Chamaeleon", "zh": "堰蜓座", "figure": "α-γ γ-δ1 γ-ε δ1-β ε-β"},
	"Cir": {"latin": "Circinus", "zh": "圆规座", "figure": "α-β α-γ"},
	"Col": {"latin": "Columba", "zh": "天鸽座", "figure": "ε-α α-β β-η β-δ"},
	"Com": {"latin": "Coma Berenices", "zh": "后发座", "figure": "γ-β α-β"},
	"CrA": {"latin": "Corona Australis", "zh": "南冕座", "figure": "θ-η2 η2-ζ ε-γ ζ-δ γ-α δ-β α-β"},
	"CrB": {"latin": "Corona Borealis", "zh": "北冕座", "figure": "β-θ β-α α-γ γ-δ δ-ε ε-ι"},
	"Crv": {"latin": "Corvus", "zh": "乌鸦座", "figure": "α-ε ε-γ ε-β γ-δ δ-β"},
	"Crt": {"latin": "Crater", "zh": "巨爵座", "figure": "α-β α-δ β-λ δ-ε δ-γ λ-γ ε-θ γ-ζ ζ-η"},
	"Cru": {"latin": "Crux", "zh": "南十字座", "figure": "δ-γ δ-β α1-γ"},
	"Cyg": {"latin": "Cygnus", "zh": "天鹅座", "figure": "κ-ι2 β1-η ι2-δ δ-γ η-γ γ-α γ-ε ε-ζ"},
	"Del": {"latin": "Delphinus", "zh": "海豚座", "figure": "ε-β β-α β-δ α-γ1 δ-γ1"},
	"Dor": {"latin": "Dorado", "zh": "剑鱼座", "figure": "γ-α α-ζ α-β ζ-β β-δ"},
	"Dra": {"latin": "Draco", "zh": "天龙座", "figure": "λ-κ κ-α α-ι ι-θ θ-η η-ζ ζ-φ β-ν2 β-γ ν2-ξ ξ-γ ξ-δ φ-χ φ-δ δ-ε"},
	"Equ": {"latin": "Equuleus", "zh": "小马座", "figure": "γ-δ δ-α"},
	"Eri": {"latin": "Eridanus", "zh": "波江座", "figure": "α-χ χ-φ φ-κ κ-ι ι-θ1 τ1-η τ1-τ3 η-ε θ1-υ4 τ3-τ4 τ4-τ5 ε-δ τ5-τ6 δ-π π-γ τ6-υ2 γ-ο1 ο1-ν υ4-43 43-υ2 ν-μ μ-β"},
	"For": {"latin": "Fornax", "zh": "天炉座", "figure": "ν-β β-α"},
	"Gem": {"latin": "Gemini", "zh": "双子座", "figure": "η-μ μ-ε γ-ξ γ-ζ ε-τ ζ-δ τ-α λ-δ δ-υ α-β υ-β"},
	"Gru": {"latin": "Grus", "zh": "天鹤座", "figure": "γ-λ λ-μ1 α-δ2 α-β μ1-δ1 δ1-δ2 δ2-β β-ε ε-ζ"},
	"Her": {"latin": "Hercules", "zh": "武仙座", "figure": "χ-φ φ-τ τ-σ γ-β β-ζ β-α1 σ-η ζ-η ζ-ε η-π ε-δ ε-π δ-μ π-ρ ρ-θ μ-ξ ξ-ο"},
	"Hor": {"latin": "Horologium", "zh": "时钟座", "figure": "η-ζ η-ι ζ-μ ι-α β-μ"},
	"Hya": {"latin": "Hydra", "zh": "长蛇座", "figure": "δ-σ δ-ε σ-η η-ρ ε-ρ ε-ζ ζ-θ θ-ι α-ι α-υ1 υ1-λ λ-μ μ-ν ν-ξ ξ-β β-γ γ-π π-58"},
	"Hyi": {"latin": "Hydrus", "zh": "水蛇座", "figure": "β-γ η2-α η2-δ δ-ε ε-γ"},
	"Ind": {"latin": "Indus", "zh": "印第安座", "figure": "α-η α-θ η-β β-δ θ-δ"},
	"Lac": {"latin": "Lacerta", "zh": "蝎虎座", "figure": "1-6 2-5 2-6 β-4 β-α 4-5 5-α 5-11 6-11"},
	"Leo": {"latin": "Leo", "zh": "狮子座", "figure": "ε-μ μ-ζ η-α η-γ1 α-θ ζ-γ1 γ1-δ δ-β θ-β"},
	"LMi": {"latin": "Leo Minor", "zh": "小狮座", "figure": "10-21 21-30 21-β 30-46 β-46"},
	"Lep": {"latin": "Lepus", "zh": "天兔座", "figure": "ε-μ ε-β μ-κ μ-λ μ-α β-γ α-ζ γ-δ ζ-η η-θ"},
	"Lib": {"latin": "Libra", "zh": "天秤座", "figure": "α2-σ α2-β α2-γ β-γ γ-υ υ-τ"},
	"Lup": {"latin": "Lupus", "zh": "豺狼座", "figure": "α-β α-ζ β-δ ζ-μ μ-ε δ-φ1 δ-γ φ1-ψ1 ε-γ γ-η ψ1-χ η-θ"},
	"Lyn": {"latin": "Lynx", "zh": "天猫座", "figure": "2-15 15-21 21-31 31-38 38-α"},
	"Lyr": {"latin": "Lyra", "zh": "天琴座", "figure": "α-ε2 α-ζ1 ε2-ζ1 ζ1-β ζ1-δ2 β-γ δ2-γ"},
	"Men": {"latin": "Mensa", "zh": "山案座", "figure": "η-β η-γ γ-α"},
	"Mic": {"latin": "Microscopium", "zh": "显微镜座", "figure": "ι-α ι-θ1 α-γ γ-ε ε-θ1"},
	"Mon": {"latin": "Monoceros", "zh": "麒麟座", "figure": "γ-β ε-13 ε-18 β-δ 13-15 18-δ δ-ζ α-ζ"},
	"Mus": {"latin": "Musca", "zh": "苍蝇座", "figure": "λ-ε ε-α γ-α γ-δ α-β β-δ"},
	"Nor": {"latin": "Norma", "zh": "矩尺座", "figure": "η-δ η-γ2 δ-ε γ2-ε"},
	"Oct": {"latin": "Octans", "zh": "南极座", "figure": "δ-ν δ-β ν-β"},
	"Oph": {"latin": "Ophiuchus", "zh": "蛇夫座", "figure": "δ-ε δ-λ ε-ζ ψ-ρ ψ-χ χ-φ φ-ζ λ-κ ζ-κ ζ-η κ-α η-θ η-β θ-45 α-β β-γ γ-ν"},
	"Ori": {"latin": "Orion", "zh": "猎户座", "figure": "π3-π2 π3-π4 π2-π1 π4-π5 π5-π6 π1-ο2 π1-γ ο2-11 11-15 β-η η-δ γ-δ γ-λ γ-α δ-ε λ-α ε-ζ ζ-κ ζ-α χ1-χ2 χ1-ν α-μ μ-ξ χ2-ξ"},
	"Pav": {"latin": "Pavo", "zh": "孔雀座", "figure": "η-π η-ζ π-ξ ξ-λ ζ-ε λ-δ ε-β δ-β α-β β-γ"},
	"Peg": {"latin": "Pegasus", "zh": "飞马座", "figure": "γ-α ε-θ κ-ι ι-λ θ-ζ π2-η ζ-ξ η-β ξ-α λ-μ μ-β β-α"},
	"Per": {"latin": "Perseus", "zh": "英仙座", "figure": "φ-θ θ-ι η-τ η-γ τ-ι π-ρ π-β γ-α ρ-ω β-κ β-ω ι-κ α-ψ ψ-δ δ-ν δ-48 ο-ζ ν-ε ζ-ξ ε-ξ λ-μ 48-μ"},
	"Phe": {"latin": "Phoenix", "zh": "凤凰座", "figure": "ε-α ε-β α-β β-ζ β-γ ζ-δ γ-δ"},
	"Pic": {"latin": "Pictor", "zh": "绘架座", "figure": "β-γ γ-α"},
	"Psc": {"latin": "Pisces", "zh": "双鱼座", "figure": "δ-ε δ-ω ε-ζ χ-φ χ-η τ-φ τ-υ φ-υ ζ-μ μ-ν η-ο ν-ξ ο-α ξ-α β-γ γ-7 γ-κ 7-θ κ-λ θ-ι ι-19 ι-ω λ-19"},
	"PsA": {"latin": "Piscis Austrinus", "zh": "南鱼座", "figure": "ι-θ ι-μ θ-μ μ-β μ-ε β-γ ε-α γ-δ δ-α"},
	"Pup": {"latin": "Puppis", "zh": "船尾座", "figure": "ν-π π-3 π-ξ 3-ο 3-ξ ο-ξ ξ-11 11-ρ ζ-ρ"},
	"Pyx": {"latin": "Pyxis", "zh": "罗盘座", "figure": "β-α α-γ"},
	"Ret": {"latin": "Reticulum", "zh": "网罟座", "figure": "β-δ β-α δ-ε α-ε"},
	"Sge": {"latin": "Sagitta", "zh": "天箭座", "figure": "α-δ β-δ δ-γ"},
	"Sgr": {"latin": "Sagittarius", "zh": "人马座", "figure": "γ2-δ γ2-ε μ-λ η-ε δ-ε δ-λ δ-φ ε-ζ λ-φ φ-σ φ-ζ ν1-σ ν1-ξ2 σ-ο σ-τ σ-ψ ξ2-ο ζ-τ ζ-α ο-π π-43 ψ-χ1 43-ρ1 β1-α ρ1-υ χ1-52 52-ω ι-θ1 ω-θ1"},
	"Sco": {"latin": "Scorpius", "zh": "天蝎座", "figure": "π-δ δ-β1 δ-σ σ-α α-τ τ-ε ε-μ1 μ1-ζ2 ζ2-η η-θ λ-κ θ-ι1 κ-ι1"},
	"Scl": {"latin": "Sculptor", "zh": "玉夫座", "figure": "α-δ γ-β γ-δ"},
	"Sct": {"latin": "Scutum", "zh": "盾牌座", "figure": "γ-α γ-δ α-β δ-β"},
	"Ser": {"latin": "Serpens", "zh": "巨蛇座", "figure": "δ-α δ-β ι-β ι-κ α-ε β-γ κ-γ ξ-η η-θ1"},
	"Sex": {"latin": "Sextans", "zh": "六分仪座", "figure": "γ-α γ-δ δ-β"},
	"Tau": {"latin": "Taurus", "zh": "金牛座", "figure": "ο-ξ ο-10 ξ-λ ξ-ν λ-γ γ-δ1 γ-θ2 δ1-ε ε-β θ2-α α-ζ"},
	"Tel": {"latin": "Telescopium", "zh": "望远镜座", "figure": "ε-α α-ζ"},
	"Tri": {"latin": "Triangulum", "zh": "三角座", "figure": "α-β α-γ β-γ"},
	"TrA": {"latin": "Triangulum Australe", "zh": "南三角座", "figure": "γ-β γ-α β-α"},
	"Tuc": {"latin": "Tucana", "zh": "杜鹃座", "figure": "ζ-β1 ζ-ε β1-γ α-δ α-γ δ-ε"},
	"UMa": {"latin": "Ursa Major", "zh": "大熊座", "figure": "ο-23 ο-υ ι-θ κ-θ 23-α θ-φ υ-β φ-β λ-ψ μ-ψ β-α β-γ α-δ ψ-χ ξ-ν ν-χ χ-γ γ-δ δ-ε ε-ζ ζ-η"},
	"UMi": {"latin": "Ursa Minor", "zh": "小熊座", "figure": "α-δ β-γ β-ζ γ-η ζ-η ζ-ε ε-δ"},
	"Vel": {"latin": "Vela", "zh": "船帆座", "figure": "γ2-λ δ-κ λ-ψ κ-φ ψ-μ φ-μ"},
	"Vir": {"latin": "Virgo", "zh": "室女座", "figure": "ν-β β-η η-γ γ-δ γ-θ δ-ε θ-α θ-ζ α-ι ζ-τ τ-109 ι-μ"},
	"Vol": {"latin": "Volans", "zh": "飞鱼座", "figure": "γ2-δ γ2-ε δ-ε ε-β ε-α β-α"},
	"Vul": {"latin": "Vulpecula", "zh": "狐狸座", "figure": "1-α α-13 13-15 15-23"},
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
