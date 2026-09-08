extends SceneTree
func _initialize():
 var f = FileAccess.open("res://docs/GODOT-LICENSE.txt", FileAccess.WRITE)
 f.store_string(Engine.get_license_text())
 f.store_string("\n\nTHIRD-PARTY LICENSES\n")
 for name in Engine.get_license_info():
  f.store_string("\n" + name + "\n" + str(Engine.get_license_info()[name]) + "\n")
 f.store_string("\nCOPYRIGHT NOTICES\n" + JSON.stringify(Engine.get_copyright_info(), "  "))
 f.close()
 quit()
