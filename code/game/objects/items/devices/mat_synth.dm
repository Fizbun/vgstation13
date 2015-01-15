#define MAX_MATSYNTH_MATTER 60
#define MAT_SYNTH_ROBO 50

#define MAT_COST_COMMON		1
#define MAT_COST_MEDIUM		5
#define MAT_COST_RARE		15

/obj/item/device/material_synth
	name = "material synthesizer"
	desc = "A device capable of producing very little material with a great deal of investment. Use wisely."
	icon = 'icons/obj/device.dmi'
	icon_state = "mat_synthoff"

	flags = FPRINT
	siemens_coefficient = 1
	w_class = 3.0
	origin_tech = "engineering=4;materials=5;power=3"

	var/mode = 1	//0 is material selection, 1 is material production
	var/emagged = 0

	var/obj/item/stack/sheet/active_material = /obj/item/stack/sheet/metal
	var/list/materials_scanned = list(	"metal" = /obj/item/stack/sheet/metal,
										"glass" = /obj/item/stack/sheet/glass,
										"reinforced glass" = /obj/item/stack/sheet/rglass,
										"plasteel" = /obj/item/stack/sheet/plasteel)
	var/matter = 0

/obj/item/device/material_synth/robot //MoMMI version, has more materials
	materials_scanned = list(	"plasma glass" = /obj/item/stack/sheet/glass/plasmaglass,
								"reinforced plasma glass" = /obj/item/stack/sheet/rglass/plasmarglass,
								"metal" = /obj/item/stack/sheet/metal,
								"glass" = /obj/item/stack/sheet/glass,
								"reinforced glass" = /obj/item/stack/sheet/rglass,
								"plasteel" = /obj/item/stack/sheet/plasteel)

/obj/item/device/material_synth/robot/cyborg //Cyborg version, has less materials and the ability to make tiles & rods (as borgs can't do it themselves)
	materials_scanned = list(	"metal" = /obj/item/stack/sheet/metal,
								"glass" = /obj/item/stack/sheet/glass,
								"reinforced glass" = /obj/item/stack/sheet/rglass,
								"floor tiles" = /obj/item/stack/tile/plasteel,
								"metal rods" = /obj/item/stack/rods)

/obj/item/device/material_synth/update_icon()
	icon_state = "mat_synth[mode ? "on" : "off"]"



/obj/item/device/material_synth/proc/create_material(mob/user, var/material)
	var/obj/item/stack/sheet/material_type = material

	if(isrobot(user))
		var/mob/living/silicon/robot/R = user
		if(material_type && R.cell.charge)
			var/modifier = MAT_COST_COMMON
			if(initial(active_material.perunit) < 3750)
				modifier = MAT_COST_MEDIUM
			if(initial(active_material.perunit) < 2000)
				modifier = MAT_COST_RARE
			var/amount = Clamp(round(input("How many sheets of [material_type] do you want to synthesize") as num), 0, 50)
			if(amount)
				if(TakeCost(amount, modifier, R))
					var/obj/item/stack/sheet/inside_sheet = (locate(material_type) in R.module.modules)
					if(!inside_sheet)
						var/obj/item/stack/sheet/created_sheet = new material_type(R.module)
						R.module.modules +=  created_sheet//cyborgs can get a free sheet, honk!
						if((created_sheet.amount + amount) <= created_sheet.max_amount)
							created_sheet.amount += amount
							R << "Added [amount] of [material_type] to the stack."
						else
							if(created_sheet.amount <= created_sheet.max_amount)
								var/transfer_amount = min(created_sheet.max_amount - created_sheet.amount, amount)
								created_sheet.amount += transfer_amount
								amount -= transfer_amount
							if(amount >= 1 && (created_sheet.amount >= created_sheet.max_amount))
								R << "Dropping [amount], you cannot hold anymore of [material_type]."
								var/obj/item/stack/sheet/dropped_sheet = new material_type(get_turf(src))
								dropped_sheet.amount = amount
					else
						if((inside_sheet.amount + amount) <= inside_sheet.max_amount)
							inside_sheet.amount += amount
							R << "Added [amount] of [material_type] to the stack."
							return
						else
							if(inside_sheet.amount <= inside_sheet.max_amount)
								var/transfer_amount = min(inside_sheet.max_amount - inside_sheet.amount, amount)
								inside_sheet.amount += transfer_amount
								amount -= transfer_amount
							if(amount >= 1 && (inside_sheet.amount >= inside_sheet.max_amount))
								R << "Dropping [amount], you cannot hold anymore of [material_type]."
								var/obj/item/stack/sheet/dropped_sheet = new material_type(get_turf(src))
								dropped_sheet.amount = amount
					R.module.rebuild()
					R.hud_used.update_robot_modules_display()
					return
				else
					R << "<span class='warning'>You can't make that much [material_type] without shutting down!</span>"
					return

				return

		else if(R.cell.charge)
			R << "You need to select a sheet type first!"
			return
	else
		if(material_type && matter)
			var/modifier = MAT_COST_COMMON
			if(initial(active_material.perunit) < 3750) //synthesizing is EXPENSIVE
				modifier = MAT_COST_MEDIUM
			if(initial(active_material.perunit) < 2000)
				modifier = MAT_COST_RARE
			var/tospawn = Clamp(round(input("How many sheets of [material_type] do you want to synthesize? (0 - [matter / modifier])") as num), 0, round(matter / modifier))
			if(tospawn)
				var/obj/item/stack/sheet/spawned_sheet = new active_material(get_turf(src))
				spawned_sheet.amount = tospawn
				TakeCost(tospawn, modifier, user)
		else if(matter)
			user << "You must select a sheet type first!"
			return
		else
			user << "\The [src] is empty!"

	return 1
/obj/item/device/material_synth/afterattack(var/obj/target, mob/user)
	if(istype(target, /obj/item/stack/sheet))
		for(var/matID in materials_scanned)
			if(materials_scanned[matID] == target.type)
				user <<"<span class='rose'>You've already scanned \the [target].</span>"
				return
		materials_scanned["[initial(target.name)]"] = target.type
		user <<"<span class='notice'>You successfully scan \the [target] into \the [src]'s material banks.</span>"
		return 1
	return ..()

/obj/item/device/material_synth/attackby(var/obj/O, mob/user)
	if(istype(O, /obj/item/weapon/rcd_ammo))
		var/obj/item/weapon/rcd_ammo/RA = O
		if(matter + 10 > MAX_MATSYNTH_MATTER)
			user <<"\The [src] can't take any more material right now."
			return
		else
			matter += 10
			qdel(RA)
	if(istype(O, /obj/item/weapon/card/emag))
		if(!emagged)
			emagged = 1
			var/matter_rng = rand(5, 25)
			if(matter >= matter_rng)
				var/obj/item/device/spawn_item = pick(typesof(/obj/item/device) - /obj/item/device) //we make any kind of device. It's a surprise!
				user.visible_message("<span class='rose'>\The [src] in [user]'s hands appears to be trying to synthesize... \a [initial(spawn_item.name)]?</span>",
									 "You hear a loud popping noise.")
				user <<"<span class='warning'>\The [src] pops and fizzles in your hands, before creating... \a [initial(spawn_item.name)]?</span>"
				sleep(10)
				new spawn_item(get_turf(src))
				matter -= matter_rng
				return 1
			else
				user<<"<span class='danger'>The lack of matter in \the [src] shorts out the device!</span>"
				explosion(src.loc, 0,0,1,2) //traitors - fuck them, am I right?
				qdel(src)
		else
			user<<"You don't think you can do that again..."
			return
	return ..()

/obj/item/device/material_synth/attack_self(mob/user)
	if(materials_scanned.len)
		var/selection = materials_scanned[input("Select the material you'd like to synthesize", "Change Material Type") as null|anything in materials_scanned]
		if(selection)
			active_material = selection
			user << "<span class='notice'>You switch \the [src] to synthesize [initial(active_material.name)]</span>"
		else
			active_material = null
	else
		user << "<span class='warning'>ERROR: NO MATERIAL DATA FOUND</span>"
		return 0
	create_material(user, active_material)

/obj/item/device/material_synth/proc/TakeCost(var/spawned, var/modifier, mob/user)
	if(spawned)
		matter -= round(spawned * modifier)

//mommis matter synth lacks the capability to scan new materials.
obj/item/device/material_synth/robot/afterattack(/obj/target, mob/user)
	user << "<span class='notice'>Your [src.name] does not contain this functionality.</span>"
	return 0

/obj/item/device/material_synth/robot/TakeCost(var/spawned, var/modifier, mob/user)
	if(isrobot(user))
		var/mob/living/silicon/robot/R = user
		return R.cell.use(spawned*modifier*MAT_SYNTH_ROBO)
	return