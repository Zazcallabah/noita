<#
.SYNOPSIS
Patch your noita save file to make the game a bit easier

.DESCRIPTION
This script can give you more money, more health, and a bunch of perks making learning and exploring noita easier.
Is easier more fun? You decide.

EXAMPLES:

./noita.ps1 -heal -boost -givePerks "enemyRadar,seeing,noBoom"
    Doubles your health bar, heals yourself to the new maximm, and gives yourself the enemy radar, all-seeing eye, and explosion immunity perks.

./noita.ps1 -boost -giveEdit
    Doubles your health bar without any healing, and gives the tinker with wands everywhere perk.

.PARAMETER boost
Double your current health bar size. Using this once on a new save file will increase it to 200HP. Using it once more will increase it to 400HP and so on.
This will not heal you on its own. Use the -heal parameter for that.

.PARAMETER heal
Reset your HP to your current maximum health. Using this and -boost at the same time will heal you up to your new maximum.

.PARAMETER giveEdit
Give yourself the 'Tinker with wands everywhere' perk.

.PARAMETER giveRadar
Give yourself the perks 'Item radar' and 'Wand radar'.

.PARAMETER money
Increase your current gold count by one order of magnitude. If you have exactly zero gold you instead end up with 1000 gold.

.PARAMETER givePerks
Give yourself any of the perks listed using the -list parameter. Separate multiple different perks using commas.

.PARAMETER list
List all perks that can be enabled using the -givePerks parameter. The 'Key' string listed is the value that should go in the comma separated list.

.PARAMETER dryRun
Test run this script without actually writing to your save file.
#>
param(
	[switch]$boost,
	[switch]$heal,
	[switch]$giveEdit,
	[switch]$giveRadar,
	[switch]$money,
	$givePerks,
	[switch]$list,
	[switch]$dryRun
)

function _perk_complex {
	param(
		$name,
		$desc,
		$icon,
		$effect,
		$label,
		$worldGlobal,
		$globalInit,
		$stackLimit,
		$luaScript
	)

	new-object psobject -property @{
		label=$label;
		name=$name;
		desc=$desc;
		icon=$icon;
		effect=$effect;
		worldGlobal=$worldGlobal;
		globalInit=$globalInit;
		stackLimit=$stackLimit;
		luaScript=$luaScript;
	}
}

function _perk {
	param($name,$limit,$luaScript,[switch]$effect)
	$lc = $name.ToLower()
	$desc = if($desc -ne $null){ $desc } else { $name }
	$icon_ = if($icon -ne $null){ $icon } else { $name }
	$effect_ = if($effect){ $name.ToUpper() } else { $null }
	$limit_ = if($limit -ne $null){ $limit } else { 1 }
	new-object psobject -property @{
		label=$name.ToUpper();
		name="`$perk_$lc";
		desc="`$perkdesc_$lc";
		icon="data/ui_gfx/perk_icons/$lc.png";
		effect=$effect_;
		worldGlobal=$null;
		globalInit=$null;
		stackLimit=$limit_;
		luaScript=$luaScript;
	}
}

$perkData = @{
	# broken	"vegetables"=(_perk "FOOD_CLOCK" -effect); not basic, probably needs script?

	# these untested ones need checkup with actual perk diff
	"untestedGreed"=(_perk "EXTRA_MONEY" -limit 128);
	"untestedTrickGreed"=(_perk "EXTRA_MONEY_TRICK_KILL" -limit 128); # probably also trick_kill_gold_multiplier="2" doubled?

	"untestedCrit"=(_perk "CRITICAL_HIT" -limit 128);
	"untestedPerkLottery"=(_perk "PERKS_LOTTERY" -limit 6);
	"untestedConcentratedSpells"=(_perk "LOWER_SPREAD" -limit 128);
	"untestedMoreLove"=(_perk "GENOME_MORE_LOVE" -limit 128);
	"untestedLivingEdge"=(_perk "LOW_HP_DAMAGE_BOOST" -effect);
	"untestedUnlimitedSpells"=(_perk "UNLIMITED_SPELLS" -effect); # probably perk_infinite_spells="0"

	"wandRadar"=(_perk -name "RADAR_WAND" -luaScript "radar_wand.lua");
	"itemRadar"=(_perk -name "RADAR_ITEM" -luaScript "radar_item.lua");
	"enemyRadar"=(_perk -name "RADAR_ENEMY" -luaScript "radar.lua");
	"editWands"=(_perk "EDIT_WANDS_EVERYWHERE" -effect);
	"ironStomach"=(_perk "IRON_STOMACH" -effect);

	# these should have _tags effect_protection
	"noMelee"=(_perk "PROTECTION_MELEE" -effect);
	"noSpark"=(_perk "PROTECTION_ELECTRICITY" -effect);
	"noFire"=(_perk "PROTECTION_FIRE" -effect);
	"noToxic"=(_perk "PROTECTION_RADIOACTIVITY" -effect);
	"noBoom"=(_perk "PROTECTION_EXPLOSION" -effect);

	"seeing"=(_perk "REMOVE_FOG_OF_WAR" -effect);

	"peace"=(_perk_complex -name "`$perk_peace_with_steve" -desc "`$perkdesc_peace_with_steve" -icon "data/ui_gfx/perk_icons/peace_with_gods.png" -label "PEACE_WITH_GODS" -worldGlobal "TEMPLE_PEACE_WITH_GODS" -stackLimit 1 );
	"extraPerk"=(_perk_complex -name "`$perk_extra_perk" -desc "`$perkdesc_extra_perk" -icon "data/ui_gfx/perk_icons/extra_perk.png" -label "EXTRA_PERK" -worldGlobal "TEMPLE_PERK_COUNT" -globalInit "4" -stackLimit 5 );
}

# SHIELD stacks 5 -seems complex adds extra xml (permanent shield)
# PROJECTILE_REPULSION stacks 128 probably needs extra xml (projectile repulsion field)
# PROJECTILE_HOMING (homing shots)
# GOLD_IS_FOREVER probably also  perk_gold_is_forever="0"
# TRICK_BLOOD_MONEY (blood money) (no effect, set   world component perk_trick_kills_blood_money="0"



if($list){
	write-host "available perks: "
	$perkData.Keys | %{ new-object psobject -property @{"key"=$_; "value"=$perkData[$_].label }}| sort value | format-table key,value
	return
}

$give = @()
if($givePerks -ne $null){
	$give = $givePerks -split ","
}

function IncrementWorldGlobal
{
	param($parent,$key,$init)

	$exists = $parent.Entity.WorldStateComponent.lua_globals.E | ?{ $_.key -eq $key }
	if($exists -ne $null){
		[int]$v2 = $exists.value
		$val = ($v2+1).ToString()
		$exists.value = $val
		write-verbose "incremented existing global $key -> $val"
	} else {
		$entity = $parent.CreateElement("E")
		$entity.SetAttribute("key",$key)
		$entity.SetAttribute("value",$init)
		$entity.InnerText ="`n"
		$parent.Entity.WorldStateComponent.lua_globals.AppendChild($entity)
		write-verbose "incremented new global $key -> $init"
	}
}
function SetWorldGlobal
{
	param($parent,$key,$val)

	$exists = $parent.Entity.WorldStateComponent.lua_globals.E | ?{ $_.key -eq $key }
	if($exists -ne $null){
		$exists.value = $val
		write-verbose "updated existing global $key -> $val"
	} else {
		$entity = $parent.CreateElement("E")
		$entity.SetAttribute("key",$key)
		$entity.SetAttribute("value",$val)
		$entity.InnerText ="`n"
		$parent.Entity.WorldStateComponent.lua_globals.AppendChild($entity)
		write-verbose "set new global $key -> $val"
	}
}

function AddWorldFlag
{
	param($parent,$name)
	$text = "`n`n        $name`n`n      "
	$flags = $parent.Entity.WorldStateComponent.SelectSingleNode("flags")
	$exists = $flags.string | ?{ $_ -eq $text }
	if( $exists.length -gt 0 ){
		write-verbose "world flag already exists"
		return
	}
	$entity = $parent.CreateElement("string")
	$entity.InnerText = $text
	$flags.AppendChild($entity)
	write-verbose "wrote world flag $name"
}

function AddLuaNode
{
	param($parent,$script)

	$entity = $parent.CreateElement("LuaComponent")
	$entity.SetAttribute("_enabled","1")
	$entity.SetAttribute("_tags","perk_component")
	$entity.SetAttribute("call_init_function","0")
	$entity.SetAttribute("enable_coroutines","0")
	$entity.SetAttribute("execute_every_n_frame","1")
	$entity.SetAttribute("execute_on_added","0")
	$entity.SetAttribute("execute_on_removed","0")
	$entity.SetAttribute("execute_times","0")
	$entity.SetAttribute("limit_all_callbacks","0")
	$entity.SetAttribute("limit_how_many_times_per_frame","-1")
	$entity.SetAttribute("limit_to_every_n_frame","-1")
	$entity.SetAttribute("mLastExecutionFrame","-1")
	$entity.SetAttribute("mModAppendsDone","1")
	$entity.SetAttribute("mTimesExecutedThisFrame","1")
	$entity.SetAttribute("remove_after_executed","0")
	$entity.SetAttribute("script_audio_event_dead","")
	$entity.SetAttribute("script_biome_entered","")
	$entity.SetAttribute("script_collision_trigger_hit","")
	$entity.SetAttribute("script_collision_trigger_timer_finished","")
	$entity.SetAttribute("script_damage_about_to_be_received","")
	$entity.SetAttribute("script_damage_received","")
	$entity.SetAttribute("script_death","")
	$entity.SetAttribute("script_electricity_receiver_electrified","")
	$entity.SetAttribute("script_electricity_receiver_switched","")
	$entity.SetAttribute("script_enabled_changed","")
	$entity.SetAttribute("script_inhaled_material","")
	$entity.SetAttribute("script_interacting","")
	$entity.SetAttribute("script_item_picked_up","")
	$entity.SetAttribute("script_kick","")
	$entity.SetAttribute("script_material_area_checker_failed","")
	$entity.SetAttribute("script_material_area_checker_success","")
	$entity.SetAttribute("script_physics_body_modified","")
	$entity.SetAttribute("script_polymorphing_to","")
	$entity.SetAttribute("script_portal_teleport_used","")
	$entity.SetAttribute("script_pressure_plate_change","")
	$entity.SetAttribute("script_shot","")
	$entity.SetAttribute("script_source_file","data/scripts/perks/$($script)")
	$entity.SetAttribute("script_teleported","")
	$entity.SetAttribute("script_throw_item","")
	$entity.SetAttribute("script_wand_fired","")
	$entity.SetAttribute("vm_type","SHARED_BY_MANY_COMPONENTS")
	$entity.InnerText ="`n"
	$parent.Entity.AppendChild($entity)
	write-verbose "wrote lua script tag $script"
}

function AddPerkNode
{
	param($parent,$name,$desc,$icon)

	$entity = $parent.CreateElement("Entity")
	$entity.SetAttribute("_version","1")
	$entity.SetAttribute("name","")
	$entity.SetAttribute("serialize","1")
	$entity.SetAttribute("tags","perk_entity")

	$transform = $parent.CreateElement("_Transform")
	$transform.SetAttribute("position.x","0")
	$transform.SetAttribute("position.y","0")
	$transform.SetAttribute("rotation","0")
	$transform.SetAttribute("scale.x","1")
	$transform.SetAttribute("scale.y","1")
	$transform.InnerText ="`n"
	$entity.AppendChild($transform)

	$uic = $parent.CreateElement("UIIconComponent")
	$uic.SetAttribute("_enabled","1")
	$uic.SetAttribute("description",$desc)
	$uic.SetAttribute("display_above_head","0")
	$uic.SetAttribute("display_in_hud","1")
	$uic.SetAttribute("icon_sprite_file",$icon)
	$uic.SetAttribute("is_perk","1")
	$uic.SetAttribute("name",$name)
	$uic.InnerText ="`n"
	$entity.AppendChild($uic)

	$parent.Entity.AppendChild($entity)
	write-verbose "added perk node $name"
}

function AddEffectNode
{
	param($parent,$effect)

	$entity = $parent.CreateElement("Entity")
	$entity.SetAttribute("_version","1")
	$entity.SetAttribute("name","")
	$entity.SetAttribute("serialize","1")
	$entity.SetAttribute("tags","perk_entity")

	$transform = $parent.CreateElement("_Transform")
	$transform.SetAttribute("position.x","15.7501")
	$transform.SetAttribute("position.y","2954")
	$transform.SetAttribute("rotation","0")
	$transform.SetAttribute("scale.x","1")
	$transform.SetAttribute("scale.y","1")
	$transform.InnerText ="`n"
	$entity.AppendChild($transform)

	$gec = $parent.CreateElement("GameEffectComponent")
	$gec.SetAttribute("_enabled","1")
	$gec.SetAttribute("_tags","perk_component")
	$gec.SetAttribute("caused_by_ingestion_status_effect","0")
	$gec.SetAttribute("caused_by_stains","0")
	$gec.SetAttribute("causing_status_effect","NONE")
	$gec.SetAttribute("custom_effect_id","")
	$gec.SetAttribute("disable_movement","0")
	$gec.SetAttribute("effect",$effect)
	$gec.SetAttribute("exclusivity_group","0")
	$gec.SetAttribute("frames","-1")
	$gec.SetAttribute("mCaster","0")
	$gec.SetAttribute("mCasterHerdId","0")
	$gec.SetAttribute("mCharmDisabledCameraBound","0")
	$gec.SetAttribute("mCharmEnabledTeleporting","0")
	$gec.SetAttribute("mCooldown","0")
	$gec.SetAttribute("mCounter","0")
	$gec.SetAttribute("mInvisible","0")
	$gec.SetAttribute("mIsExtension","0")
	$gec.SetAttribute("mIsSpent","0")
	$gec.SetAttribute("mSerializedData","")
	$gec.SetAttribute("no_heal_max_hp_cap","3.40282e+038")
	$gec.SetAttribute("polymorph_target","")
	$gec.SetAttribute("ragdoll_effect","NONE")
	$gec.SetAttribute("ragdoll_effect_custom_entity_file","")
	$gec.SetAttribute("ragdoll_fx_custom_entity_apply_only_to_largest_body","0")
	$gec.SetAttribute("ragdoll_material","air")
	$gec.SetAttribute("report_block_msg","1")
	$gec.SetAttribute("teleportation_delay_min_frames","30")
	$gec.SetAttribute("teleportation_probability","600")
	$gec.SetAttribute("teleportation_radius_max","1024")
	$gec.SetAttribute("teleportation_radius_min","128")
	$gec.SetAttribute("teleportations_num","0")
	$gec.InnerText ="`n"
	$entity.AppendChild($gec)

	$itc = $parent.CreateElement("InheritTransformComponent")
	$itc.SetAttribute("_enabled","1")
	$itc.SetAttribute("always_use_immediate_parent_rotation","0")
	$itc.SetAttribute("only_position","0")
	$itc.SetAttribute("parent_hotspot_tag","")
	$itc.SetAttribute("parent_sprite_id","-1")
	$itc.SetAttribute("rotate_based_on_x_scale","0")
	$itc.SetAttribute("use_root_parent","0")

	$t2 = $parent.CreateElement("Transform")
	$t2.SetAttribute("position.x","0")
	$t2.SetAttribute("position.y","0")
	$t2.SetAttribute("rotation","0")
	$t2.SetAttribute("scale.x","1")
	$t2.SetAttribute("scale.y","1")
	$t2.InnerText ="`n"
	$itc.AppendChild($t2)

	$entity.AppendChild($itc)

	$parent.Entity.AppendChild($entity)
	write-verbose "added effect node $effect"
}

function SaveToFile
{
	param($document,$path)

	$encoding = [System.Text.UTF8Encoding]::new($false)
	$settings = [System.Xml.XmlWriterSettings]@{
		Encoding = $encoding
		Indent = $true
		NewLineOnAttributes = $true
	}
	$writer = [System.Xml.XmlWriter]::Create($path, $settings)
	$document.Save($writer)
	$writer.Dispose()
}

function AddPerk
{
	param($document,$world,$perk)

	if($perk -eq $null){
		write-warning "null perk?"
		return
	}
	$label = $perk.label

	$extant = $document.Entity.Entity | ?{
		$_.tags -eq "perk_entity"
	} | ?{
		$_.UIIconComponent.name -eq $perk.name
	} | measure | select -expandproperty count
	write-verbose "perk stack limit: $($perk.stackLimit) comparing to $extant"
	if($extant -ge $perk.stackLimit){
		write-host "$($label) already patched"
		return
	}

	$result = AddPerkNode $document $perk.name $perk.desc $perk.icon
	if($perk.effect -ne $null){
		$result = AddEffectNode $document $perk.effect
	}
	$world.Entity.WorldStateComponent.mods_have_been_active_during_this_run = "0"
	$result = AddWorldFlag $world "PERK_PICKED_$label"
	$result = IncrementWorldGlobal $world "PERK_PICKED_$($label)_PICKUP_COUNT" "1"
	if($perk.luaScript -ne $null){
		$result = AddLuaNode $document $perk.luaScript
	}
	if($perk.worldGlobal -ne $null){
		if($perk.globalInit -ne $null){
			$result = IncrementWorldGlobal $world $perk.worldGlobal $perk.globalInit
		} else {
			$result = SetWorldGlobal $world $perk.worldGlobal "1"
		}
	}
	write-host "$($label) patched"
}

$path = "$($env:USERPROFILE)\AppData\LocalLow\Nolla_Games_Noita\save00\player.xml"
$pathWorld = "$($env:USERPROFILE)\AppData\LocalLow\Nolla_Games_Noita\save00\world_state.xml"

if(!(test-path $path) -or !(test-path $pathWorld)){
	write-warning "no save file found"
	return
}

[xml]$extant_file_content = get-content -encoding utf8 -raw $path
[xml]$extant_world = get-content -encoding utf8 -raw $pathWorld

if($extant_file_content.Entity.DamageModelComponent.max_hp -eq $null -or $extant_file_content.Entity.InventoryGuiComponent.wallet_money_target -eq $null){
	write-warning "xml not recognized"
	return
}
if($boost){
	$maxhp = [int]$extant_file_content.Entity.DamageModelComponent.max_hp
	if($maxhp -gt 2147483648){
		write-warning "hp reaching high levels"
	}
	$extant_file_content.Entity.DamageModelComponent.max_hp = $maxhp * 2
	write-host "boosted"
}
if($heal){
	$extant_file_content.Entity.DamageModelComponent.hp = $extant_file_content.Entity.DamageModelComponent.max_hp
	write-host "healed"
}
if($money){
	[int]$current_money = $extant_file_content.Entity.InventoryGuiComponent.wallet_money_target
	if($current_money -le 0){
		$current_money = 100;
	}
	$new_money = $current_money * 10
	$extant_file_content.Entity.InventoryGuiComponent.wallet_money_target = $new_money
	$extant_file_content.Entity.WalletComponent.money = $new_money
	$extant_file_content.Entity.WalletComponent.mMoneyPrevFrame = $new_money
	write-host "scrooged"
}

if($giveEdit){
	AddPerk $extant_file_content $extant_world $perkData["editWands"]
}

if($giveRadar){
	AddPerk $extant_file_content $extant_world $perkData["itemRadar"]
	AddPerk $extant_file_content $extant_world $perkData["wandRadar"]
}

$give | %{
	if($perkData.Keys -contains $_){
		AddPerk $extant_file_content $extant_world $perkData[$_]
	}
}

if( !$dryrun ){
	SaveToFile $extant_file_content $path
	SaveToFile $extant_world $pathWorld
	write-host "saved"
} else {
	write-host "dry run, not saving output"
}