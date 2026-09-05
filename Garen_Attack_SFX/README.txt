Garen default-skin basic attack SFX extraction

Game WAD source:
D:\WeGameApps\????\Game\DATA\FINAL\Champions\Garen.wad.client

Extracted WAD resources copied to:
C:\Users\Lenovo\Desktop\garen_sfx_extract

Resources used from Garen.wad.client:
data/characters/garen/skins/skin0.bin
assets/sounds/wwise2016/sfx/characters/garen/skins/base/garen_base_sfx_audio.bnk
assets/sounds/wwise2016/sfx/characters/garen/skins/base/garen_base_sfx_events.bnk

Tools used:
LeagueToolkit/wadtools v0.5.7, with latest Mimir/CommunityDragon hash tables downloaded by wadtools
Morilli/bnk-extract v1.9_fix1
vgmstream r2117

Confirmed included events:
Play_sfx_Garen_GarenBasicAttack_OnCast - base attack swing/whoosh variants
Play_sfx_Garen_GarenBasicAttack2_OnCast - second base attack swing/whoosh variants
Play_sfx_Garen_GarenBasicAttack_OnHit and Play_sfx_Garen_GarenBasicAttack2_OnHit - base attack impact variants; these reuse the same WEM audio ID pool, so exported hit WAVs are de-duplicated

Excluded events/pools:
GarenCritAttack_OnCast / GarenCritAttack_OnHit
GarenQAttack_OnCast
GarenQ/GarenW/GarenE/GarenR events
emote/3D loops, passive, death and other non-basic-attack SFX
voice/language WADs were not used

Confirmed WAV files:
garen_basic_attack_swing_01.wav | Event: Play_sfx_Garen_GarenBasicAttack_OnCast | Event action/group: 3603 | WEM audio ID: 20848802
garen_basic_attack_swing_02.wav | Event: Play_sfx_Garen_GarenBasicAttack_OnCast | Event action/group: 3603 | WEM audio ID: 470705115
garen_basic_attack_swing_03.wav | Event: Play_sfx_Garen_GarenBasicAttack_OnCast | Event action/group: 3603 | WEM audio ID: 147893136
garen_basic_attack_swing_04.wav | Event: Play_sfx_Garen_GarenBasicAttack_OnCast | Event action/group: 3603 | WEM audio ID: 1246050
garen_basic_attack_swing_05.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnCast | Event action/group: 3605 | WEM audio ID: 498203661
garen_basic_attack_swing_06.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnCast | Event action/group: 3605 | WEM audio ID: 160268863
garen_basic_attack_swing_07.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnCast | Event action/group: 3605 | WEM audio ID: 745780724
garen_basic_attack_swing_08.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnCast | Event action/group: 3605 | WEM audio ID: 3618390
garen_basic_attack_hit_01.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 1004934447 | WEM audio ID: 79667740
garen_basic_attack_hit_02.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 1004934447 | WEM audio ID: 14110164
garen_basic_attack_hit_03.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 1004934447 | WEM audio ID: 36191544
garen_basic_attack_hit_04.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 1004934447 | WEM audio ID: 53736152
garen_basic_attack_hit_05.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 197700997 | WEM audio ID: 19449746
garen_basic_attack_hit_06.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 197700997 | WEM audio ID: 18709251
garen_basic_attack_hit_07.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 197700997 | WEM audio ID: 117531801
garen_basic_attack_hit_08.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 197700997 | WEM audio ID: 120191057
garen_basic_attack_hit_09.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 281933185 | WEM audio ID: 206316614
garen_basic_attack_hit_10.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 281933185 | WEM audio ID: 162685102
garen_basic_attack_hit_11.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 281933185 | WEM audio ID: 57311359
garen_basic_attack_hit_12.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 281933185 | WEM audio ID: 63889480
garen_basic_attack_hit_13.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 432925646 | WEM audio ID: 13912708
garen_basic_attack_hit_14.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 432925646 | WEM audio ID: 188285667
garen_basic_attack_hit_15.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 432925646 | WEM audio ID: 45134918
garen_basic_attack_hit_16.wav | Event: Play_sfx_Garen_GarenBasicAttack2_OnHit; also shared by GarenBasicAttack_OnHit | Event action/group: 432925646 | WEM audio ID: 178848513

Candidates:
None. The BasicAttack event mapping was available and specific enough to avoid fallback extraction.

Notes:
The original League of Legends client files were only read. All extraction and conversion happened in copied files under Desktop\garen_sfx_extract and Desktop\Garen_Attack_SFX.
