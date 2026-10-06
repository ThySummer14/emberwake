extends SceneTree
func _initialize() -> void:
 var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../builds/pack_source_hashes.json"))
 var packer:=PCKPacker.new();var err:int=packer.pck_start(ProjectSettings.globalize_path("res://../builds/Emberwake.pck"))
 if err!=OK:quit(1);return
 for file in expected:
  if FileAccess.get_sha256("res://"+file)!=expected[file]:push_error("Stale source manifest "+file);quit(1);return
  err=packer.add_file("res://"+file,"res://"+file)
  if err!=OK:push_error("Pack failed "+file);quit(1);return
 err=packer.flush();print("ROOT_PCK_BUILT files=",expected.size()," result=",err);quit(0 if err==OK else 1)
