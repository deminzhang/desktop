## The twelve earthly branches - the one list the sky names them from.
##
## Three places put them on screen: the hour names of the time bar (子 covers
## 23:00-00:59), the compass card's outer ring, and the same ring marked on the
## ground below the horizon. They are also bearings: 子 is due north and the
## branches run 30 deg apart the way the sun goes, so 卯 is east and 酉 west.
class_name Branches
extends RefCounted

const NAMES := ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

## The bearing of one branch from the next.
const SPAN := 30.0


## The bearing of `index` (0 = 子, due north) eastwards.
static func bearing(index: int) -> float:
	return SPAN * float(index)


## Which branch an hour falls in: the traditional double hour starting at 23:00.
static func index_of_hour(hour: int) -> int:
	return (hour + 1) / 2 % 12


## The branch an hour falls in, the traditional double hour starting at 23:00.
static func of_hour(hour: int) -> String:
	return NAMES[index_of_hour(hour)]
