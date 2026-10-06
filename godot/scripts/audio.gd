extends Node
class_name EmberAudio
var music: AudioStreamPlayer
var enabled: bool = true
var cache: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []

func _ready() -> void:
	music=AudioStreamPlayer.new()
	add_child(music)
	music.stream=AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes("res://assets/gatewater.ogg"))
	if music.stream is AudioStreamOggVorbis: music.stream.loop=true
	music.volume_db=-11
	for i in range(10):
		var v:=AudioStreamPlayer.new()
		add_child(v)
		voices.append(v)
	for name in ["jump","double_jump","dash","land","swing","hit","enemy_die","hurt","heal","beacon","relic","bell","boss_windup","slam","enemy_attack","pressure_click","pressure_vent","breaker_tuck","breaker_impact","carrier_sweep","stamp_windup","stamp_hit"]:
		cache[name]=synthesize(name)

func start() -> void:
	if enabled and not music.playing: music.play()

func toggle() -> void:
	enabled=not enabled
	if enabled: start()
	else: music.stop()

func synthesize(id: String) -> AudioStreamWAV:
	var durations: Dictionary={"jump":0.16,"double_jump":0.24,"dash":0.19,"land":0.08,"swing":0.19,"hit":0.16,"enemy_die":0.32,"hurt":0.29,"heal":0.60,"beacon":1.6,"relic":1.1,"bell":1.25,"boss_windup":0.55,"slam":0.4,"enemy_attack":0.18,"pressure_click":.09,"pressure_vent":.65,"breaker_tuck":.13,"breaker_impact":.3,"carrier_sweep":.23,"stamp_windup":.40,"stamp_hit":.24}
	var duration: float=durations[id]
	var sr:=22050
	var length:=int(sr*duration)
	var data:=PackedByteArray()
	data.resize(length*2)
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash(id)
	var phase:=0.0
	for i in range(length):
		var t:=float(i)/sr
		var u:=t/duration
		var env:=pow(1-u,2)*minf(t*200,1)
		var v:=0.0
		var noise:=rng.randf_range(-1,1)
		match id:
			"stamp_windup":v=(sin(t*TAU*(145+u*90))*.18+sin(t*TAU*610)*.06)*sin(PI*u)*minf(t*70,1)
			"stamp_hit":v=(sin(t*TAU*92)*.42+sin(t*TAU*371)*.13+noise*.22)*env
			"pressure_click","breaker_tuck":
				v=(sin(t*TAU*(520 if id=="pressure_click" else 280))*.3+noise*.12)*env
			"pressure_vent":v=(noise*.16+sin(t*TAU*83)*.05)*minf(u*8,1)*(1-u)
			"breaker_impact":v=(sin(t*TAU*(65+(1-u)*70))*.5+noise*.3)*env*.7
			"carrier_sweep":v=(noise*.25+sin(t*TAU*(110-u*55))*.15)*env
			"jump","double_jump":
				phase+=TAU*(210+u*280)/sr
				v=sin(phase)*env*0.25
			"dash","swing","enemy_attack":
				v=(noise*0.55+sin(t*TAU*(190-u*100))*0.25)*env*0.3
			"hit","slam","land","hurt":
				v=(sin(t*TAU*(65+(1-u)*70))*0.6+noise*0.5)*env*0.5
			"heal","beacon","relic","bell":
				var f:=440.0 if id in ["heal","relic"] else 220.0
				v=(sin(t*TAU*f)+sin(t*TAU*f*2.76)*0.28+sin(t*TAU*f*4.01)*0.12)*env*0.20
			"boss_windup": v=(sin(t*TAU*(95+u*80))*.25+noise*.08)*minf(u*5,1)*(1-u*.7)
			_: v=(noise*.2+sin(t*TAU*(220-u*170))*.2)*env
		data.encode_s16(i*2,clampi(int(v*32767),-32768,32767))
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=sr
	stream.data=data
	return stream

func play(id: String) -> void:
	if not enabled or not cache.has(id): return
	for voice in voices:
		if not voice.playing:
			voice.stream=cache[id]
			voice.volume_db=-8 if id not in ["hit","hurt","slam"] else -3
			voice.play()
			return
