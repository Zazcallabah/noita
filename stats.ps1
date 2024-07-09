# decryption keys and method sourced from https://lightbourn.net/games/Noita/editor.html
write-host "Credit to https://lightbourn.net/games/Noita/editor.html"

function SymmetricEncrypt {
	param(
		[byte[]]$data,
		[string]$keyString,
		[string]$ivString
	)

	$Value = $data
	$Key = [Convert]::FromHexString($keyString)
	$Nonce = [Convert]::FromHexString($ivString)

	<#
	Code from https://www.powershellgallery.com/packages/AnsibleVault/0.2.0/Content/Private%5CInvoke-AESCTRCycle.ps1 :

	Copyright: (c) 2018, Jordan Borean (@jborean93) <jborean93@gmail.com>
	MIT License (see LICENSE or https://opensource.org/licenses/MIT)
	The .NET class AesCryptoServiceProvider does not have a native
	CTR mode so this must be done manually. Thanks to Hans Wolff at
	https://gist.github.com/hanswolff/8809275, I've been able to use that code
	as a reference and create a PowerShell function to do the same.
	#>
    $counter_cipher = New-Object System.Security.Cryptography.AesCryptoServiceProvider
    $counter_cipher.Mode = [System.Security.Cryptography.CipherMode]::ECB
    $counter_cipher.Padding = [System.Security.Cryptography.PaddingMode]::None
    $counter_encryptor = $counter_cipher.CreateEncryptor($Key, (New-Object -TypeName byte[] -ArgumentList($counter_cipher.BlockSize / 8)))

    $xor_mask = New-Object -TypeName System.Collections.Queue
    $output = New-Object -TypeName byte[] -ArgumentList $Value.Length
    for ($i = 0; $i -lt $Value.Length; $i++) {
        if ($xor_mask.Count -eq 0) {
            $counter_mode_block = New-Object -TypeName byte[] -ArgumentList ($counter_cipher.BlockSize / 8)
            $counter_encryptor.TransformBlock($Nonce, 0, $Nonce.Length, $counter_mode_block, 0) > $null

            for ($j = $Nonce.Length - 1; $j -ge 0; $j--) {
                $current_nonce_value = $Nonce[$j]
                if ($current_nonce_value -eq 255) {
                    $Nonce[$j] = 0
                } else {
                    $Nonce[$j] += 1
                }

                if ($Nonce[$j] -ne 0) {
                    break
                }
            }

            foreach ($counter_byte in $counter_mode_block) {
                $xor_mask.Enqueue($counter_byte)
            }
        }

        $current_mask = $xor_mask.Dequeue()
        $output[$i] = [byte]($Value[$i] -bxor $current_mask)
    }

    return [byte[]]$output
}

function LoadFile {
	param($path,$key,$iv)
	$data = get-content -asbytestream $path

	$output = SymmetricEncrypt -data $data -keystring $key -ivstring $iv
	$resultStr = [System.Text.Encoding]::Utf8.GetString($output)
	return $resultStr
}

function SaveFile {
	param($dataStr,$path,$key,$iv)
	$data = [System.Text.Encoding]::Utf8.GetBytes($dataStr)
	$output = SymmetricEncrypt -data $data -keystring $key -ivstring $iv
	set-content -asbytestream -path $path -value $output
}

$files = @{
	"session"=@{
		path="$($env:USERPROFILE)\AppData\LocalLow\Nolla_Games_Noita\save00\session_numbers.salakieli";
		k="4b6e6f776c6564676549735468654869";
		v="57686f576f756c646e74476976654576";
	};
	"stats"=@{
			path="$($env:USERPROFILE)\AppData\LocalLow\Nolla_Games_Noita\save00\stats\_stats.salakieli";
			k="536563726574734f66546865416c6c53";
			v="54687265654579657341726557617463";
	};
	"streaks"=@{
			path="$($env:USERPROFILE)\AppData\LocalLow\Nolla_Games_Noita\save00\stats\_streaks.salakieli";
			k="536563726574734f66546865416c6c53";
			v="54687265654579657341726557617463";
	}
}
#   "internal_alchemy_list" :
#     key : fromHexString("31343439363631363932313933343032"),
#     iv : fromHexString("38313632343338393133393638333733"),

if( test-path $files["session"].path ) {
	write-host "Session numbers content:"
	[xml]$data = LoadFile -path $files["session"].path -key $files["session"].k -iv $files["session"].v

	write-host "`tBIOME_MAP = $($data.SessionNumbers.BIOME_MAP)"
	write-host "`tBIOME_MAP_PIXEL_SCENES = $($data.SessionNumbers.BIOME_MAP_PIXEL_SCENES)"
	write-host "`tDESIGN_NEW_GAME_PLUS_ATTACK_SPEED = $($data.SessionNumbers.DESIGN_NEW_GAME_PLUS_ATTACK_SPEED)"
	write-host "`tDESIGN_NEW_GAME_PLUS_HP_SCALE_MAX = $($data.SessionNumbers.DESIGN_NEW_GAME_PLUS_HP_SCALE_MAX)"
	write-host "`tDESIGN_NEW_GAME_PLUS_HP_SCALE_MIN = $($data.SessionNumbers.DESIGN_NEW_GAME_PLUS_HP_SCALE_MIN)"
	write-host "`tDESIGN_SCALE_ENEMIES = $($data.SessionNumbers.DESIGN_SCALE_ENEMIES)"
	write-host "`tNEW_GAME_PLUS_COUNT = $($data.SessionNumbers.NEW_GAME_PLUS_COUNT)"
	write-host "`tis_biome_map_initialized = $($data.SessionNumbers.is_biome_map_initialized)"
}

if( test-path $files["streaks"].path ) {
	write-host "Streaks content:"
	[xml]$data = LoadFile -path $files["streaks"].path -key $files["streaks"].k -iv $files["streaks"].v

	write-host "`tcurrent_streak_count = $($data.GameStreaks.current_streak_count)"
	write-host "`thas_started_streak_attempt = $($data.GameStreaks.has_started_streak_attempt)"
	write-host "`tversion = $($data.GameStreaks.version)"
}

if( test-path $files["stats"].path ) {
	write-host "Stats content:"
	[xml]$data = LoadFile -path $files["stats"].path -key $files["stats"].k -iv $files["stats"].v

	write-host "`tDEBUG_FIXED_STATS = $($data.GameStats.DEBUG_FIXED_STATS)"
	write-host "`tDEBUG_HOW_MANY_RESETS = $($data.GameStats.DEBUG_HOW_MANY_RESETS)"
	write-host "`tsession_dead = $($data.GameStats.session_dead)"
	write-host "`tSTATS_VERSION = $($data.GameStats.STATS_VERSION)"

	$data.GameStats.KEY_VALUE_STATS.E | format-table

	($data.GameStats.session,$data.GameStats.highest,$data.GameStats.global,$data.GameStats.prev_best)|select enemies_killed,gold,hp,items,places_visited,playtime_str|format-table

	# SaveFile -dataStr $content_str "$PSScriptRoot/out.bin" -key $files["stats"].k -iv $files["stats"].v
}

# <session   biomes_visited_with_wands="0" damage_taken="0" dead="1" death_count="0"  death_pos.x="570.643" death_pos.y="980.997" enemies_killed="17"   gold="215"       gold_all="215" gold_infinite="0" healed="0" heart_containers="0" hp="200"   items="2"   kicks="0" killed_by="" killed_by_extra="" places_visited="1" playtime="311.6" playtime_str="0:05:11" projectiles_shot="0" streaks="0" teleports="0" wands_edited="0" world_seed="1190610761" >
# <highest   biomes_visited_with_wands="0" damage_taken="0" dead="0" death_count="0"  death_pos.x="6377.48" death_pos.y="15167"   enemies_killed="857"  gold="100000244" gold_all="0"   gold_infinite="0" healed="0" heart_containers="0" hp="6845"  items="99"  kicks="0" killed_by="" killed_by_extra="" places_visited="24" playtime="18171.1" playtime_str="5:02:51" projectiles_shot="0" streaks="1" teleports="0" wands_edited="0" world_seed="0" >
# <global    biomes_visited_with_wands="0" damage_taken="0" dead="0" death_count="46" death_pos.x="0"       death_pos.y="0"       enemies_killed="3409" gold="123210684" gold_all="0"   gold_infinite="0" healed="0" heart_containers="0" hp="16594" items="506" kicks="0" killed_by="" killed_by_extra="" places_visited="154" playtime="84422.8" playtime_str="23:27:02" projectiles_shot="0" streaks="0" teleports="0" wands_edited="0" world_seed="0" >
# <prev_best biomes_visited_with_wands="0" damage_taken="0" dead="0" death_count="0"  death_pos.x="6377.48" death_pos.y="15167"   enemies_killed="857"  gold="100000244" gold_all="0"   gold_infinite="0" healed="0" heart_containers="0" hp="6845"  items="99"  kicks="0" killed_by="" killed_by_extra="" places_visited="24" playtime="18171.1" playtime_str="5:02:51" projectiles_shot="0" streaks="1" teleports="0" wands_edited="0" world_seed="0" >

# $files | %{
# 	write-host $_.path
# 	$content = LoadFile -path $_.path -key $_.k -iv $_.v
# 	$c = [xml]$content
# #	write-host $content
#
# }

