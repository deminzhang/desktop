## The twenty-eight 宿's own star groups (星官), drawn as figures on the sphere: the
## Chinese half of the sky's line layer, next to the 88 IAU figures Constellations
## writes.
##
## A 宿 is not one figure but a bag of 星官 (角宿 has eleven), and a 星官 is a chain of
## stars in the order they are numbered (一, 二, 三 …) - which is the order the traditional
## charts draw them in, so a chain of designations is the whole figure. A 星官 drawn with
## branches keeps one chain per branch (亢宿's 亢 is drawn κ-ι-φ and κ-λ): the figures here
## are the star sets of the 伊世同 table carried onto the line structure of the reference
## below, and a branch is what that structure has.
##
## The stars are named the way 伊世同《中西对照恒星图表》(1981) names them - Bayer letter
## or Flamsteed number, with the constellation, and the star names are the ones its tables
## use (角宿一 = α Vir, 库楼二 = η Cen …) - resolved against the catalogue's own
## designations, like every other line on this sky (README「数据源与许可」: no coordinate table enters
## the repo). BSC5 names a star by no Bayer letter and no Flamsteed number sometimes (the
## Latin-lettered ones such as g Cen, and a few dozen of the 星官's fainter stars): those
## are written "HR 5192" and resolved with StarCat.find_hr(), because the HR number is the
## catalogue's own key and the only name it has. Only the 星官's own stars are drawn - the
## 清《仪象考成》 additions (增星) are not in this table.
##
## Sources and what they left out are in data/SOURCES.md: the star lists are the
## 伊世同-based tables on the 星官 articles of zh.wikipedia, and the line structure (which
## stars of a 星官 are one part, and in what order a part runs) was checked against
## Stellarium's 中国星空 sky culture, which gives the same figures as HIP numbers - same
## stars, same parts, nothing taken from it (the same cross-check Constellations' figures
## went through). The two differ on a handful of stars (its 库楼 carries HD 107931 where
## 库楼九 = D Cen is the 伊世同 star, its 天街 carries 50 ω2 Tau where the table has 43 ω1
## Tau …); this table follows the 伊世同 star lists throughout, and 35 星官 (the one-star
## asterisks: 大角, 招摇, 北落师门 …) are here from the reference alone, their articles
## carrying no table.
##
## What is missing is missing for one reason: BSC5 stops at V ≈ 6.5, so the fainter
## stars of the source tables have no row to be written as (data/SOURCES.md counts the
## source side: 218 星官 1070 星 read, 50 rows landing nowhere). A star the catalogue does
## not have was dropped when this table was written, and the chain it stood in is split
## there - never bridged, because a line between the stars that did resolve is a chord the
## sky never had. Measured 2026-10-15 (a probe over every entry): every designation this
## table does carry resolves - 209 星官, 947 designation rows, 873 distinct stars - so the
## 星名 counts in the comments above each 宿 are the whole of what is drawn, and the
## missing stars are missing as *names*, not as failed lookups.
class_name MansionFigures
extends RefCounted

const FIGURES := {
	## 角宿 11 星官 41 星
	"角": {
		"角": ["α Vir ζ Vir"],
		"平道": ["θ Vir 82 Vir"],
		"天田": ["τ Vir 78 Vir"],
		"周鼎": ["β Com 37 Com 41 Com"],
		"进贤": ["44 Vir"],
		"天门": ["53 Vir 69 Vir"],
		"平": ["γ Hya π Hya"],
		"库楼": ["ζ Cen η Cen θ Cen 2 Cen HR 5089 HR 4940 γ Cen τ Cen HR 4652 σ Cen"],
		"柱": ["HR 5378 ψ Cen", "υ2 Cen υ1 Cen", "ι Lup τ1 Lup", "4 Cen HR 5210 1 Cen π Cen", "ι Cen"],
		"衡": ["ν Cen μ Cen φ Cen χ Cen"],
		"南门": ["ε Cen α1 Cen"],
	},
	## 亢宿 7 星官 20 星
	"亢": {
		"亢": ["κ Vir ι Vir φ Vir", "κ Vir λ Vir"],
		"大角": ["α Boo"],
		"左摄提": ["ο Boo π1 Boo π2 Boo ζ Boo"],
		"右摄提": ["η Boo τ Boo υ Boo"],
		"顿顽": ["1 Lup φ1 Lup"],
		"阳门": ["HR 5471"],
		"折威": ["50 Hya 4 Lib 12 Lib σ Lib"],
	},
	## 氐宿 11 星官 34 星
	"氐": {
		"氐": ["α2 Lib ι1 Lib γ Lib β Lib"],
		"天乳": ["μ Ser"],
		"招摇": ["γ Boo"],
		"梗河": ["ε Boo σ Boo ρ Boo"],
		"帝席": ["12 Boo 11 Boo 9 Boo"],
		"亢池": ["20 Boo 14 Boo 18 Boo"],
		"阵车": ["58 Hya 60 Hya 2 Lup"],
		"骑官": ["γ Lup δ Lup κ Cen β Lup λ Lup ε Lup μ Lup π Lup ο Lup α Lup"],
		"车骑": ["ζ Lup ρ Lup σ Lup"],
		"天辐": ["υ Lib τ Lib"],
		"骑阵将军": ["κ1 Lup"],
	},
	## 房宿 8 星官 22 星
	"房": {
		"房": ["β1 Sco δ Sco π Sco ρ Sco"],
		"钩钤": ["ω1 Sco ω2 Sco", "ω1 Sco β1 Sco"],
		"键闭": ["ν Sco"],
		"罚": ["18 Sco 11 Sco 49 Lib"],
		"东咸": ["φ Oph χ Oph ψ Oph ω Oph"],
		"西咸": ["48 Lib θ Lib η Lib"],
		"日": ["κ Lib"],
		"从官": ["χ Lup ψ2 Lup"],
	},
	## 心宿 2 星官 5 星
	"心": {
		"心": ["σ Sco α Sco τ Sco"],
		"积卒": ["θ Lup η Lup"],
	},
	## 尾宿 4 星官 20 星（神宫、鱼 的星不在 BSC5 或源表未列，未画）
	"尾": {
		"尾": ["ε Sco μ1 Sco ζ1 Sco ζ2 Sco η Sco θ Sco ι1 Sco κ Sco λ Sco", "κ Sco υ Sco"],
		"龟": ["ε1 Ara γ Ara δ Ara η Ara ζ Ara"],
		"天江": ["HR 6401 θ Oph 44 Oph"],
		"傅说": ["HR 6630"],
	},
	## 箕宿 3 星官 8 星
	"箕": {
		"箕": ["γ2 Sgr δ Sgr ε Sgr η Sgr"],
		"糠": ["45 Oph"],
		"杵": ["σ Ara α Ara β Ara"],
	},
	## 斗宿 10 星官 47 星
	"斗": {
		"斗": ["φ Sgr λ Sgr μ Sgr σ Sgr τ Sgr ζ Sgr"],
		"建": ["ξ2 Sgr ο Sgr π Sgr 43 Sgr ρ1 Sgr υ Sgr"],
		"天弁": ["α Sct δ Sct", "β Sct η Sct 12 Aql λ Aql 15 Aql 14 Aql"],
		"鳖": ["α Tel η1 CrA ζ CrA δ CrA β CrA α CrA γ CrA ε CrA", "κ2 CrA θ CrA α Tel"],
		"天鸡": ["55 Sgr 56 Sgr"],
		"天龠": ["HR 6672", "58 Oph", "52 Oph 51 Oph", "3 Sgr"],
		"狗国": ["ω Sgr", "62 Sgr 59 Sgr ω Sgr"],
		"天渊": ["β2 Sgr β1 Sgr α Sgr"],
		"狗": ["χ1 Sgr"],
		"农丈人": ["HR 7029"],
	},
	## 牛宿 11 星官 47 星
	"牛": {
		"牛": ["π Cap ο Cap ρ Cap", "ρ Cap"],
		"天田": ["HR 8110 ω Cap", "HR 8110", "ω Cap ψ Cap"],
		"九坎": ["HR 8100"],
		"河鼓": ["β Aql α Aql γ Aql"],
		"织女": ["HR 7051 α Lyr ζ1 Lyr"],
		"左旗": ["α Sge β Sge δ Sge ζ Sge γ Sge", "11 Sge HR 7664 ρ Aql"],
		"右旗": ["μ Aql σ Aql δ Aql ν Aql ι Aql 42 Aql κ Aql 56 Aql"],
		"天桴": ["θ Aql 62 Aql 58 Aql η Aql"],
		"罗堰": ["τ Cap υ Cap 17 Cap"],
		"渐台": ["δ2 Lyr", "γ Lyr ι Lyr"],
		"辇道": ["13 Lyr η Lyr θ Lyr 4 Cyg 17 Cyg"],
	},
	## 女宿 7 星官 40 星（十二国 的星不在 BSC5 或源表未列，未画）
	"女": {
		"女": ["ε Aqr μ Aqr 4 Aqr 3 Aqr"],
		"离珠": ["1 Aqr 71 Aql 70 Aql 69 Aql"],
		"败瓜": ["ε Del η Del θ Del ι Del κ Del"],
		"瓠瓜": ["γ2 Del α Del β Del δ Del γ2 Del", "β Del ζ Del"],
		"天津": ["ζ Cyg υ Cyg τ Cyg ν Cyg α Cyg 30 Cyg δ Cyg γ Cyg ε Cyg ζ Cyg"],
		"奚仲": ["κ Cyg ι2 Cyg θ Cyg"],
		"扶筐": ["46 Dra 45 Dra 39 Dra ο Dra 48 Dra 49 Dra 51 Dra"],
	},
	## 虚宿 10 星官 27 星
	"虚": {
		"虚": ["β Aqr α Equ"],
		"司命": ["26 Aqr"],
		"司禄": ["11 Peg 25 Aqr"],
		"司危": ["β Equ 9 Equ"],
		"司非": ["γ Equ δ Equ"],
		"哭": ["μ Cap 38 Aqr"],
		"泣": ["ρ Aqr θ Aqr"],
		"天垒城": ["ξ Aqr", "λ Cap ω Cap", "29 Cap ν Aqr 17 Aqr 19 Aqr"],
		"败臼": ["γ Gru λ Gru γ PsA 19 PsA"],
		"璃瑜": ["α Mic ε Mic 5 PsA"],
	},
	## 危宿 11 星官 50 星
	"危": {
		"危": ["α Aqr θ Peg ε Peg"],
		"坟墓": ["ζ2 Aqr γ Aqr", "ζ2 Aqr η Aqr", "ζ2 Aqr π Aqr"],
		"人": ["2 Peg 1 Peg 9 Peg 12 Peg"],
		"杵": ["1 Lac π2 Peg 23 Peg"],
		"臼": ["32 Peg ι Peg κ Peg μ1 Cyg"],
		"车府": ["15 Lac 11 Lac 2 Lac ρ Cyg", "ξ Cyg 74 Cyg"],
		"天钩": ["4 Cep θ Cep η Cep α Cep ξ Cep 26 Cep ι Cep ο Cep"],
		"造父": ["δ Cep ζ Cep λ Cep μ Cep ν Cep"],
		"盖屋": ["ο Aqr 32 Aqr"],
		"虚梁": ["44 Aqr 51 Aqr κ Aqr"],
		"天钱": ["13 PsA θ PsA ι PsA μ PsA τ PsA 13 PsA"],
	},
	## 室宿 11 星官 87 星
	"室": {
		"室": ["α Peg β Peg"],
		"离宫": ["λ Peg μ Peg", "ο Peg η Peg", "τ Peg υ Peg", "μ Peg", "η Peg", "τ Peg"],
		"雷电": ["70 Peg 66 Peg 55 Peg σ Peg ξ Peg ζ Peg"],
		"垒壁阵": ["29 Psc 27 Psc 30 Psc 33 Psc 29 Psc", "27 Psc φ Aqr λ Aqr σ Aqr ι Aqr δ Cap γ Cap ε Cap κ Cap δ Cap"],
		"羽林军": ["29 Aqr 35 Aqr 41 Aqr", "47 Aqr 49 Aqr λ PsA", "ε PsA 21 PsA", "υ Aqr 68 Aqr", "66 Aqr HR 8544", "56 Aqr 50 Aqr 45 Aqr", "58 Aqr", "83 Aqr", "χ Aqr ω1 Aqr ω2 Aqr"],
		"𫓧钺": ["103 Aqr 106 Aqr 108 Aqr"],
		"北落师门": ["α PsA"],
		"八魁": ["6 Cet 2 Cet 1 Cet", "6 Cet 3 Cet", "6 Cet 9 Cet", "6 Cet 7 Cet"],
		"天纲": ["δ PsA"],
		"土公吏": ["31 Peg 36 Peg"],
		"螣蛇": ["α Lac 4 Lac π2 Cyg π1 Cyg", "HR 8281 13 Cep ε Cep β Lac σ Cas ρ Cas τ Cas", "9 Lac 3 And 7 And 8 And λ And ψ And κ And ι And"],
	},
	## 壁宿 6 星官 17 星
	"壁": {
		"壁": ["γ Peg α And"],
		"霹雳": ["β Psc γ Psc θ Psc ι Psc ω Psc"],
		"云雨": ["κ Psc 21 Psc λ Psc"],
		"天厩": ["θ And ρ And σ And"],
		"𫓧锧": ["48 Cet", "υ Cet 56 Cet"],
		"土公": ["32 Psc"],
	},
	## 奎宿 9 星官 41 星
	"奎": {
		"奎": ["η And ζ And", "ε And δ And π And ν And μ And β And τ Psc 91 Psc υ Psc φ Psc χ Psc HR 310 η And"],
		"外屏": ["ξ Psc α Psc", "μ Psc υ Psc ζ Psc ε Psc δ Psc"],
		"天溷": ["21 Cet φ3 Cet 18 Cet φ1 Cet"],
		"土司空": ["β Cet"],
		"军南门": ["φ And"],
		"阁道": ["ι Cas ε Cas δ Cas μ Cas", "ν Cas ο Cas"],
		"附路": ["ζ Cas"],
		"王良": ["β Cas κ Cas η Cas α Cas λ Cas"],
		"策": ["γ Cas"],
	},
	## 娄宿 6 星官 32 星
	"娄": {
		"娄": ["α Ari β Ari γ2 Ari"],
		"左更": ["ν Ari μ Ari ο Ari σ Ari π Ari"],
		"右更": ["ρ Psc η Psc π Psc ο Psc"],
		"天仓": ["ι Cet η Cet θ Cet ζ Cet τ Cet 57 Cet"],
		"天庾": ["ν For ω For β For"],
		"天大将军": ["γ1 And φ Per", "49 And χ And υ And τ And 56 And β Tri γ Tri δ Tri γ1 And"],
	},
	## 胃宿 7 星官 37 星
	"胃": {
		"胃": ["35 Ari 39 Ari"],
		"天廪": ["5 Tau", "ξ Tau ο Tau"],
		"天囷": ["α Cet κ2 Cet λ Cet μ Cet ξ1 Cet ξ2 Cet ν Cet γ Cet δ Cet 75 Cet 70 Cet 63 Cet 66 Cet"],
		"大陵": ["9 Per τ Per ι Per κ Per β Per ρ Per 16 Per 12 Per"],
		"天船": ["η Per γ Per α Per ψ Per δ Per 48 Per μ Per HR 1330 HR 1314"],
		"积尸": ["π Per"],
		"积水": ["λ Per"],
	},
	## 昴宿 9 星官 46 星
	"昴": {
		"昴": ["17 Tau 19 Tau 21 Tau 20 Tau", "17 Tau 23 Tau η Tau 27 Tau"],
		"天河": ["62 Ari"],
		"月": ["37 Tau"],
		"天阴": ["ζ Ari δ Ari", "ζ Ari"],
		"蒭藁": ["ρ Cet 77 Cet 67 Cet", "71 Cet HR 692 ε Cet"],
		"天苑": ["γ Eri π Eri δ Eri ε Eri ζ Eri η Eri π Cet τ1 Eri τ2 Eri τ3 Eri τ4 Eri τ5 Eri τ6 Eri τ7 Eri τ8 Eri τ9 Eri"],
		"卷舌": ["ν Per ε Per ξ Per ζ Per ο Per 40 Per"],
		"天谗": ["42 Per"],
		"砺石": ["ψ Tau 44 Tau χ Tau φ Tau"],
	},
	## 毕宿 15 星官 93 星
	"毕": {
		"毕": ["ε Tau δ3 Tau δ1 Tau γ Tau α Tau θ1 Tau 71 Tau λ Tau"],
		"附耳": ["σ2 Tau"],
		"天街": ["κ2 Tau ω1 Tau"],
		"天节": ["π Tau ρ Tau", "π Tau 57 Tau 79 Tau 90 Tau 93 Tau 88 Tau 66 Tau"],
		"诸王": ["136 Tau 125 Tau 118 Tau 103 Tau 99 Tau τ Tau"],
		"天高": ["ι Tau 97 Tau 109 Tau ι Tau"],
		"九州殊口": ["ο1 Eri ξ Eri ν Eri 56 Eri HR 1505"],
		"五车": ["ι Aur α Aur β Aur θ Aur β Tau"],
		"柱": ["ε Aur ζ Aur η Aur ε Aur", "υ Aur ν Aur τ Aur υ Aur", "χ Aur 26 Aur"],
		"天潢": ["19 Aur φ Aur", "19 Aur σ Aur", "19 Aur μ Aur", "19 Aur 14 Aur"],
		"咸池": ["ρ Aur HR 1825 λ Aur"],
		"天关": ["ζ Tau"],
		"参旗": ["ο1 Ori ο2 Ori 6 Ori π1 Ori π2 Ori π3 Ori π4 Ori π5 Ori π6 Ori"],
		"九斿": ["HR 1469 μ Eri ω Eri 63 Eri 64 Eri 60 Eri 58 Eri 54 Eri 1 Lep"],
		"天园": ["δ Phe χ Eri φ Eri κ Eri 64 Eri", "θ1 Eri θ2 Eri HR 1143 HR 1190 HR 1195 υ4 Eri", "υ2 Eri υ1 Eri"],
	},
	## 觜宿 3 星官 17 星
	"觜": {
		"觜": ["λ Ori φ1 Ori", "λ Ori φ2 Ori"],
		"司怪": ["139 Tau 1 Gem χ2 Ori χ1 Ori"],
		"座旗": ["ψ6 Aur 16 Lyn ψ4 Aur ψ5 Aur ψ2 Aur ψ7 Aur ψ3 Aur 51 Aur 59 Aur"],
	},
	## 参宿 7 星官 28 星
	"参": {
		"参": ["α Ori ζ Ori ε Ori δ Ori β Ori", "δ Ori γ Ori", "ζ Ori κ Ori"],
		"伐": ["42 Ori θ2 Ori ι Ori", "42 Ori"],
		"玉井": ["λ Eri ψ Eri β Eri τ Ori"],
		"屏": ["μ Lep ε Lep"],
		"军井": ["ι Lep κ Lep λ Lep ν Lep"],
		"厕": ["α Lep β Lep γ Lep δ Lep"],
		"屎": ["μ Col"],
	},
	## 井宿 20 星官 69 星
	"井": {
		"井": ["λ Gem ζ Gem 36 Gem ε Gem", "36 Gem ν Gem μ Gem", "ν Gem γ Gem ζ Gem", "γ Gem ξ Gem", "μ Gem"],
		"钺": ["η Gem"],
		"南河": ["ε CMi β CMi α CMi"],
		"北河": ["β Gem α Gem ρ Gem"],
		"天樽": ["57 Gem δ Gem ω Gem"],
		"五诸侯": ["θ Gem τ Gem ι Gem υ Gem φ Gem"],
		"积水": ["λ Per"],
		"积薪": ["κ Gem"],
		"水府": ["ν Ori ξ Ori 72 Ori 69 Ori"],
		"水位": ["6 CMi 11 CMi 8 Cnc HR 3208"],
		"四渎": ["HR 2649 17 Mon 13 Mon ε Mon"],
		"军市": ["β CMa ν3 CMa κ CMa", "17 CMa ο1 CMa ξ1 CMa β CMa"],
		"野鸡": ["ν2 CMa"],
		"丈人": ["α Col ε Col"],
		"子": ["λ Col β Col"],
		"孙": ["κ Col θ Col"],
		"阙丘": ["21 Mon 18 Mon"],
		"天狼": ["α CMa"],
		"弧矢": ["δ CMa η CMa HR 3017", "ο Pup", "η CMa ε CMa κ CMa π Pup HR 3017"],
		"老人": ["α Car"],
	},
	## 鬼宿 6 星官 25 星（积尸 的星不在 BSC5 或源表未列，未画）
	"鬼": {
		"鬼": ["θ Cnc η Cnc γ Cnc δ Cnc"],
		"爟": ["ψ Cnc λ Cnc φ1 Cnc 15 Cnc"],
		"天狗": ["HR 3426 HR 3477", "β Pyx α Pyx γ Pyx δ Pyx"],
		"外厨": ["2 Hya HR 3459 14 Hya"],
		"天社": ["γ2 Vel HR 3445 δ Vel φ Vel κ Vel HR 3803", "γ1 Vel"],
		"天记": ["λ Vel"],
	},
	## 柳宿 2 星官 11 星
	"柳": {
		"柳": ["ρ Hya η Hya σ Hya δ Hya ε Hya ζ Hya ω Hya θ Hya"],
		"酒旗": ["ψ Leo ξ Leo ω Leo"],
	},
	## 星宿 5 星官 37 星（天稷 的星不在 BSC5 或源表未列，未画）
	"星": {
		"星": ["α Hya τ1 Hya τ2 Hya ι Hya", "α Hya 27 Hya 26 Hya HR 3785", "α Hya HR 3785"],
		"天相": ["17 Sex α Sex ε Sex"],
		"轩辕": ["HR 3579 HR 3612 38 Lyn α Lyn 15 Leo κ Leo λ Leo ε Leo μ Leo ζ Leo γ1 Leo η Leo α Leo ο Leo", "α Leo ρ Leo", "α Leo"],
		"御女": ["τ Dra 50 Dra", "τ Dra χ Dra"],
		"内平": ["22 LMi 21 LMi 13 LMi"],
	},
	## 张宿 1 星官 9 星（天庙 的星不在 BSC5 或源表未列，未画）
	"张": {
		"张": ["υ1 Hya λ Hya μ Hya HR 3963", "υ1 Hya HR 3963", "υ1 Hya κ Hya", "μ Hya"],
	},
	## 翼宿 1 星官 21 星（东瓯 的星不在 BSC5 或源表未列，未画）
	"翼": {
		"翼": ["α Crt γ Crt", "α Crt λ Crt", "α Crt ν Hya", "γ Crt ζ Crt λ Crt", "ζ Crt η Crt", "γ Crt δ Crt ι Crt κ Crt ε Crt", "ε Crt θ Crt HR 4529", "λ Crt β Crt"],
	},
	## 轸宿 6 星官 16 星（军门、器府 的星不在 BSC5 或源表未列，未画）
	"轸": {
		"轸": ["β Crv δ Crv γ Crv ε Crv", "γ Crv", "δ Crv", "ε Crv"],
		"长沙": ["ζ Crv"],
		"左辖": ["η Crv"],
		"右辖": ["α Crv"],
		"青丘": ["β Hya", "HR 4449 ξ Hya HR 4458 ο Hya"],
		"土司空": ["β Cet"],
	},
}


## The 宿 this table has figures for, in the order they are written.
static func mansions() -> Array:
	return FIGURES.keys()


## How many 星官 宿 `mansion` is drawn as.
static func guan_count(mansion: String) -> int:
	return (FIGURES[mansion] as Dictionary).size()


## How many stars the table names for 宿 `mansion` - the stars that are drawn, so it is the
## 伊世同 count of the 宿 minus whatever BSC5 does not carry (角宿: 41 of 41).
static func star_count(mansion: String) -> int:
	var total := 0
	var groups: Dictionary = FIGURES[mansion]
	for guan: String in groups:
		for chain: String in groups[guan]:
			total += chain.split(" ", false).size() / 2
	return total


## Every chain of every 宿 in the table, as unit directions on the sphere - what the sky
## hands to SkyLines.polyline_layer.
static func chains(catalogue: StarCat) -> Array:
	var out := []
	for mansion: String in mansions():
		out.append_array(mansion_chains(catalogue, mansion))
	return out


## The chains of one 宿, in 星官 order and then in part order. A chain a missing star
## stands in the middle of is drawn as the two runs either side of it (see _chain).
static func mansion_chains(catalogue: StarCat, mansion: String) -> Array:
	var out := []
	var groups: Dictionary = FIGURES[mansion]
	for guan: String in groups:
		for chain: String in groups[guan]:
			for stars: PackedInt32Array in _chain(catalogue, mansion, guan, chain):
				if stars.size() < 2:
					continue
				var line := []
				for star in stars:
					line.append(StarCat.direction(catalogue.ra[star], catalogue.dec[star]))
				out.append(line)
	return out


## Where each 星官's own name goes: the middle of the stars it is drawn by. The sky hangs
## a name on every 星官 in the table (SkyLabels), the way it does for the 88.
##
## A 星官 whose stars are in several parts is named at the middle of the parts that are
## actually drawn: 柱十 π Cen stands 30° west of the rest of 柱, and a name averaged over
## it would sit in empty sky next to nothing. A 星官 that is a single star all through
## (进贤) has no drawn part, so its own star carries the name.
static func anchors(catalogue: StarCat) -> Array:
	var out := []
	for mansion: String in mansions():
		var groups: Dictionary = FIGURES[mansion]
		for guan: String in groups:
			var parts := []
			var drawn := false
			for text: String in groups[guan]:
				for stars: PackedInt32Array in _chain(catalogue, mansion, guan, text):
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


## Star index for one designation of this table, or -1. A Flamsteed number and a Greek
## Bayer letter go to Constellations.star_of(), which is where every other designation on
## this sky is resolved; "HR" is this table's own, for the stars BSC5 names by no
## designation at all.
static func star_of(catalogue: StarCat, designation: String, abbrev: String) -> int:
	if designation == "HR":
		return catalogue.find_hr(int(abbrev))
	return Constellations.star_of(catalogue, designation, abbrev)


## The runs one chain's designations resolve to, and the one place a missing star is
## reported. A star the catalogue does not have cuts the chain in two there rather than
## being bridged: a line between the stars that did resolve is a chord the sky never had.
static func _chain(catalogue: StarCat, mansion: String, guan: String,
		chain: String) -> Array:
	var runs := []
	var run := PackedInt32Array()
	var tokens := chain.split(" ", false)
	for i in range(0, tokens.size(), 2):
		var star := star_of(catalogue, tokens[i], tokens[i + 1])
		if star < 0:
			push_warning("MansionFigures: %s宿 %s has no %s %s"
					% [mansion, guan, tokens[i], tokens[i + 1]])
			if run.size() > 0:
				runs.append(run)
				run = PackedInt32Array()
			continue
		run.append(star)
	if run.size() > 0:
		runs.append(run)
	return runs
