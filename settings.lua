data:extend({
    {
        type = "int-setting",
        name = "concreep range",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        maximum_value = 100,
        order = "010"
	},
	{
		type = "bool-setting",
		name = "creep landfill",
		setting_type = "runtime-global",
		default_value = false,
		order = "010"
    },
	{
		type = "bool-setting",
		name = "creep brick",
		setting_type = "runtime-global",
		default_value = true,
		order = "011"
    },
	{
		type = "bool-setting",
		name = "creep regular concrete",
		setting_type = "runtime-global",
		default_value = true,
		order = "013"
    },
	{
		type = "bool-setting",
		name = "creep refined concrete",
		setting_type = "runtime-global",
		default_value = true,
		order = "014"
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