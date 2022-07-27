data:extend({
	{
		type = "string-setting",
		name = "allowed surfaces",
		setting_type = "runtime-global",
		default_value = "nauvis",
		auto_trim = true,
		allow_blank = false,
		order = "010"
	},
	{
		type = "int-setting",
		name = "concreep range",
		setting_type = "runtime-global",
		default_value = 100,
		minimum_value = 0,
		maximum_value = 100,
		order = "011"
	},
	{
		type = "bool-setting",
		name = "creep landfill",
		setting_type = "runtime-global",
		default_value = false,
		order = "012"
	},
	{
		type = "bool-setting",
		name = "creep brick",
		setting_type = "runtime-global",
		default_value = true,
		order = "013"
	},
	{
		type = "bool-setting",
		name = "creep regular concrete",
		setting_type = "runtime-global",
		default_value = true,
		order = "014"
	},
	{
		type = "bool-setting",
		name = "creep refined concrete",
		setting_type = "runtime-global",
		default_value = true,
		order = "015"
	},
	{
		type = "bool-setting",
		name = "upgrade brick",
		setting_type = "runtime-global",
		default_value = true,
		order = "020"
	},
	{
		type = "bool-setting",
		name = "upgrade concrete",
		setting_type = "runtime-global",
		default_value = true,
		order = "030"
	},
	{
		type = "bool-setting",
		name = "cover landfill",
		setting_type = "runtime-global",
		default_value = true,
		order = "040"
	},
	{
		type = "int-setting",
		name = "minimum robot",
		setting_type = "runtime-global",
		default_value = 30,
		minimum_value = 0,
		maximum_value = 100000,
		order = "041"
	},
	{
		type = "int-setting",
		name = "minimum item",
		setting_type = "runtime-global",
		default_value = 200,
		minimum_value = 1,
		maximum_value = 100000000,
		order = "042"
	},
	{
		type = "int-setting",
		name = "run every n updates",
		setting_type = "runtime-global",
		default_value = 60,
		minimum_value = 1,
		maximum_value = 1000,
		order = "043"
	},
	{
		type = "int-setting",
		name = "creepers per update",
		setting_type = "runtime-global",
		default_value = 5,
		minimum_value = 1,
		maximum_value = 1000,
		order = "044"
	},
	{
		type = "int-setting",
		name = "roboports per reinit pass",
		setting_type = "runtime-global",
		default_value = 1,
		minimum_value = 1,
		maximum_value = 1000,
		order = "045"
	},
	{
		type = "bool-setting",
		name = "debug",
		setting_type = "runtime-global",
		default_value = false,
		order = "990"
	},
	{
		type = "bool-setting",
		name = "debug function calls",
		setting_type = "runtime-global",
		default_value = false,
		order = "991"
	},
	{
		type = "bool-setting",
		name = "debug coroutine calls",
		setting_type = "runtime-global",
		default_value = false,
		order = "992"
	},
})