extends SceneTree
func _initialize() -> void:
 var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]));var matched:=0
 for file in expected:
  if not FileAccess.file_exists("res://"+file) or FileAccess.get_sha256("res://"+file)!=expected[file]:push_error("PCK SOURCE MISMATCH "+file);quit(1);return
  matched+=1
 print("ROOT_PCK_SOURCE_MATCH ",matched,"/",expected.size());quit()
