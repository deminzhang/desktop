## Where the sky is watched from (计划 §9).
##
## Latitude and east longitude alone fix the horizon; the UTC offset is only for
## reading the clock back in the observer's local time, which the HUD's time bar
## (S7) does. Beijing until something can change it.
class_name Observer
extends RefCounted

var place := "北京"
var latitude := 39.9042     ## degrees north
var longitude := 116.4074   ## degrees east of Greenwich
var utc_offset := 8.0       ## hours


## The observer's wall clock for a Unix instant, as a Godot datetime dictionary.
func local_datetime(unix: float) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(unix + utc_offset * 3600.0))
