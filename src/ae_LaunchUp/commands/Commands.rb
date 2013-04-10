module AE


module LaunchUp


require(File.join(PATH_ROOT, 'Translate.rb'))


module Commands


=begin
• Having UI::Command objects of all native tools in ObjectSpace can be useful for
  many plugins. One could think about making this a Community Extension, or shipping
  SketchUp Next with UI::Command object for all tools and functions.
  How do I know if such command objects exist, to avoid duplication?
• This file has intentionally minimal indentation to facilitate editing by scripts.
• Missing commands:
  Paste in Place
  Intersect faces
  viewRedo:
  Entity Info
  split
  Import
  Export
  Solid Tools > Subtract
  SectionsCuts
  SectionsOutlines
• send_action codes that don't work on OSX: (they are supposed to be cross-platform)
  Sketchup.send_action("addBuilding:")
  Sketchup.send_action("getCurrentView:")
  Sketchup.send_action("getModels:")
  Sketchup.send_action("shareModel:")
  Sketchup.send_action("uploadComponent:")
  Sketchup.send_action("cut:")
  Sketchup.send_action("copy:")
  Sketchup.send_action("paste:")
  # Sketchup.send_action("selectionZoomExt:") # This works: Sketchup.send_action('viewZoomToSelection:')
  Sketchup.send_action("placeModel:")
  Sketchup.send_action("getPhotoTexture:")
  Apart from that, all return true, no matter whether they fail or don't exist.
  We also need feature testing to know which send_action codes are available.
=end


TRANSLATE = Translate.new("Commands", File.join(PATH_ROOT, "lang")) unless defined?(self::TRANSLATE)
OSX = ( Object::RUBY_PLATFORM =~ /(darwin)/i ) unless defined?(self::OSX)
WIN = ( !OSX ) unless defined?(self::WIN)


module Command # Mixin

  def keywords
    return ( @keywords ? @keywords : [] )
  end

  def keywords=(array)
    return @keywords = [] unless array.is_a?(Array)
    @keywords = array
    array.each{|k| t = TRANSLATE[k]; @keywords << t if t != k }
    return @keywords
  end

  def category
    return @category
  end

  def category=(text)
    return @category = text.split(">").map{|s| TRANSLATE[s.strip]}.join(" › ")
    # return @category = TRANSLATE[text]
  end

  # def name...
  # def description...
  # def proc...
  # def validation_proc...

end # module Command


unless file_loaded?(__FILE__)


# File


cmd = UI::Command.new(TRANSLATE["New"]) { Sketchup.send_action("newDocument:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Create a new model."]
cmd.small_icon = "./FileNewSmall.png"
cmd.large_icon = "./FileNewLarge.png"
cmd.category = "File"
cmd.keywords = ["new", "open"]


cmd = UI::Command.new(TRANSLATE["Open"]) { Sketchup.send_action("openDocument:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Open an existing model."]
cmd.small_icon = "./FileOpenSmall.png"
cmd.large_icon = "./FileOpenLarge.png"
cmd.category = "File"
cmd.keywords = ["open"]


cmd = UI::Command.new(TRANSLATE["Save"]) { Sketchup.send_action("saveDocument:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Save the active model."]
cmd.small_icon = "./FileSaveSmall.png"
cmd.large_icon = "./FileSaveLarge.png"
cmd.category = "File"
cmd.keywords = ["save"]


cmd = UI::Command.new(TRANSLATE["Print…"]) { Sketchup.send_action("printDocument:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Print the active model."]
cmd.small_icon = "./FilePrintSmall.png"
cmd.large_icon = "./FilePrintLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.entities.length > 0
    MF_ENABLED
  else
    MF_GRAYED
  end
}
cmd.category = "File"
cmd.keywords = ["print"]


unless OSX
cmd = UI::Command.new(TRANSLATE["Add New Building"]) { Sketchup.send_action("addBuilding:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Add a new building model using Google Building Maker."]
cmd.small_icon = "./16x16_Building_Maker.png"
cmd.large_icon = "./24x24_Building_Maker.png"
cmd.category = "File > Building Maker"
cmd.keywords = ["google"]
end

unless OSX
cmd = UI::Command.new(TRANSLATE["Add Location"]) { Sketchup.send_action("getCurrentView:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Add a geo-location to the model, and gather site information nearby."]
cmd.small_icon = "./model_here_16.png"
cmd.large_icon = "./model_here_24.png"
cmd.category = "File > Geo-location"
cmd.keywords = ["geo-reference", "location", "add", "place", "imagery", "satellite", "earth", "map", "terrain", "google"]
end


cmd = UI::Command.new(TRANSLATE["Clear Location"]) {
  m = Sketchup.active_model
  m.attribute_dictionaries["GeoReference"]["UsesGeoReferencing"] = false
  t = m.layers["Google Earth Terrain"]
  s = m.layers["Google Earth Snapshot"]
  ents = []
  m.entities.each{|e| ents << e if e.valid? && e.respond_to?(:layer) && (e.layer == t || e.layer == s) }
  ents.each{|e| e.erase! if e.valid?}
  m.layers.purge_unused
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Clear the model's geo-location."]
cmd.small_icon = "./FileGeoLocationClearSmall.png"
cmd.large_icon = "./FileGeoLocationClearLarge.png"
cmd.set_validation_proc {
  (Sketchup.active_model.georeferenced?) ? MF_ENABLED : MF_DISABLED
}
cmd.category = "File > Geo-location"
cmd.keywords = ["geo-reference", "location", "clear", "remove", "delete", "terrain", "google"]


cmd = UI::Command.new(TRANSLATE["Show Terrain"]) {
  t = Sketchup.active_model.layers["Google Earth Terrain"]
  s = Sketchup.active_model.layers["Google Earth Snapshot"]
  if t && t.visible?
    s.visible = true if s
    t.visible = false
  elsif s && s.visible?
    s.visible = false
    t.visible = true if t
  else
    s.visible = true if s
  end
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Toggle terrain on and off."]
cmd.small_icon = "./TerrainToggle-16x16.png"
cmd.large_icon = "./TerrainToggle-24x24.png"
cmd.set_validation_proc {
  (Sketchup.active_model.georeferenced?) ? MF_ENABLED : MF_DISABLED
}
cmd.category = "File > Geo-location"


unless OSX
cmd = UI::Command.new(TRANSLATE["Get Models"]) { Sketchup.send_action("getModels:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Get a model from 3D Warehouse."]
cmd.small_icon = "./get-from-warehouse-16.png"
cmd.large_icon = "./get-from-warehouse-24.png"
cmd.category = "File > 3D Warehouse"
cmd.keywords = ["3dwh", "galery", "get", "download"]
end


cmd = UI::Command.new(TRANSLATE["Share Model"]) { Sketchup.send_action("shareModel:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Share this model to 3D Warehouse."]
cmd.small_icon = "./post-to-warehouse-16.png"
cmd.large_icon = "./post-to-warehouse-24.png"
cmd.set_validation_proc {
  if Sketchup.active_model.entities.length > 0
    MF_ENABLED
  else
    MF_GRAYED
  end
}
cmd.category = "File > 3D Warehouse"
cmd.keywords = ["3dwh", "gallery", "share", "upload"]


unless OSX
cmd = UI::Command.new(TRANSLATE["Share Component"]) { Sketchup.send_action("uploadComponent:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Share the selected component to 3D Warehouse."]
cmd.small_icon = "./16x16_postcomponent.png"
cmd.large_icon = "./24x24_postcomponent.png"
cmd.set_validation_proc {
  if Sketchup.active_model.selection.length == 1 && Sketchup.active_model.selection.first.is_a?(Sketchup::ComponentInstance)
    MF_ENABLED
  else
    MF_GRAYED
  end
}
cmd.category = "File > 3D Warehouse"
cmd.keywords = ["3dwh", "gallery", "share", "upload"]
end


# Edit


cmd = UI::Command.new(TRANSLATE["Undo"]) { Sketchup.send_action("editUndo:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Undo"]
cmd.small_icon = "./EditUndoSmall.png"
cmd.large_icon = "./EditUndoLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.modified?
    MF_ENABLED
  else
    MF_GRAYED
  end
}
cmd.category = "Edit"
cmd.keywords = ["back"]


cmd = UI::Command.new(TRANSLATE["Redo"]) { Sketchup.send_action("editRedo:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Redo the previously undone action."]
cmd.small_icon = "./EditRedoSmall.png"
cmd.large_icon = "./EditRedoLarge.png"
cmd.category = "Edit"


unless OSX
cmd = UI::Command.new(TRANSLATE["Cut"]) { Sketchup.send_action("cut:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Cut"]
cmd.small_icon = "./EditCutSmall.png"
cmd.large_icon = "./EditCutLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.selection.length > 0
    MF_ENABLED
  else
    MF_GRAYED
  end
}
cmd.category = "Edit"
cmd.keywords = ["clipboard"]
end


unless OSX
cmd = UI::Command.new(TRANSLATE["Copy"]) { Sketchup.send_action("copy:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Copy"]
cmd.small_icon = "./EditCopySmall.png"
cmd.large_icon = "./EditCopyLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.selection.length > 0
    MF_ENABLED
  else
    MF_GRAYED
  end
}
cmd.category = "Edit"
cmd.keywords = ["copy", "clipboard"]
end


unless OSX
cmd = UI::Command.new(TRANSLATE["Paste"]) { Sketchup.send_action("paste:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Paste"]
cmd.small_icon = "./EditPasteSmall.png"
cmd.large_icon = "./EditPasteLarge.png"
cmd.category = "Edit"
cmd.keywords = ["paste", "insert", "clipboard"]
end


cmd = UI::Command.new(TRANSLATE["Erase"]) { Sketchup.send_action("editDelete:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Erase"]
cmd.small_icon = "./EditDeleteSmall.png"
cmd.large_icon = "./EditDeleteLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.selection.length > 0
    MF_ENABLED
  else
    MF_GRAYED
  end
}
cmd.category = "Edit"
cmd.keywords = ["erase", "delete", "remove"]


cmd = UI::Command.new(TRANSLATE["Hide"]) { Sketchup.send_action("editHide:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Hide Selected Geometry"]
cmd.small_icon = "./EditHideSelectedSmall.png"
cmd.large_icon = "./EditHideSelectedLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.selection.length < 1
    MF_GRAYED
  else
    MF_ENABLED
  end
}
cmd.category = "Edit"
cmd.keywords = ["mask"]


cmd = UI::Command.new(TRANSLATE["Unhide"]) { Sketchup.send_action("editUnhide:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Unhide Selected Geometry"]
cmd.small_icon = "./EditUnhideSelectedSmall.png"
cmd.large_icon = "./EditUnhideSelectedLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.selection.length < 1
    MF_GRAYED
  else
    MF_ENABLED
  end
}
cmd.category = "Edit"
cmd.keywords = ["show"]


cmd = UI::Command.new(TRANSLATE["Make Component"]) {
  if not (Sketchup.send_action(21083) rescue false)
    # Fallback if send_action code returns false.
    # BUG: SketchUp on OSX returns always true, but it returns error for Fixnum
    # argument. We rescue it and do the fallback.
    m = Sketchup.active_model
    c = m.active_entities.add_group(m.selection.to_a)
    c.to_component
    m.selection.clear
    m.selection.add(c)
  end
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Make a Component from selected entities."]
cmd.small_icon = "./MakeCompSmall.png"
cmd.large_icon = "./MakeCompLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.selection.length > 0
    MF_ENABLED
  else
    MF_GRAYED
  end
}
cmd.category = "Edit"
cmd.keywords = ["make", "create"]


cmd = UI::Command.new(TRANSLATE["Make Group"]) {
  m = Sketchup.active_model
  g = m.active_entities.add_group(m.selection.to_a)
  m.selection.clear
  m.selection.add(g)
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Make a Group from selected entities."]
cmd.small_icon = "./MakeGroupSmall.png"
cmd.large_icon = "./MakeGroupLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.selection.length > 0
    MF_ENABLED
  else
    MF_GRAYED
  end
}
cmd.category = "Edit"
cmd.keywords = ["make", "create"]


# View


cmd = UI::Command.new(TRANSLATE["Toggle Hidden"]) { Sketchup.send_action("viewShowHidden:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Toggle Hidden Geometry"]
cmd.small_icon = "./ToggleHiddenSmall.png"
cmd.large_icon = "./ToggleHiddenLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["DrawHidden"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View"


cmd = UI::Command.new(TRANSLATE["Toggle Axes"]) { Sketchup.send_action("viewShowAxes:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Toggle Axes"]
cmd.small_icon = "./ToggleAxesSmall.png"
cmd.large_icon = "./ToggleAxesLarge.png"
cmd.category = "View"


cmd = UI::Command.new(TRANSLATE["Hide Guides"]) {
  Sketchup.active_model.rendering_options["HideConstructionGeometry"] = !Sketchup.active_model.rendering_options["HideConstructionGeometry"]
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display Construction Geometry"]
cmd.small_icon = "./ToggleGuidesSmall.png"
cmd.large_icon = "./ToggleGuidesLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["HideConstructionGeometry"] == false
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View"


cmd = UI::Command.new(TRANSLATE["Shadows"]) {
  Sketchup.active_model.shadow_info["DisplayShadows"] =! Sketchup.active_model.shadow_info["DisplayShadows"]
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display Shadows"]
cmd.small_icon = "./ToggleShadowsSmall.png"
cmd.large_icon = "./ToggleShadowsLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.shadow_info["DisplayShadows"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View"


cmd = UI::Command.new(TRANSLATE["Fog"]) {
  Sketchup.active_model.rendering_options["DisplayFog"] = !Sketchup.active_model.rendering_options["DisplayFog"]
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display Fog"]
cmd.small_icon = "./ToggleFogSmall.png"
cmd.large_icon = "./ToggleFogLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["DisplayFog"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View"


# View →  Edge Style


cmd = UI::Command.new(TRANSLATE["Display Edges"]) {
  if Sketchup.active_model.rendering_options["EdgeDisplayMode"] == 0
    Sketchup.active_model.rendering_options["EdgeDisplayMode"] = 1
  else
    Sketchup.active_model.rendering_options["EdgeDisplayMode"] = 0
  end
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display Edges"]
cmd.small_icon = "./ToggleEdgesSmall.png"
cmd.large_icon = "./ToggleEdgesLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["EdgeDisplayMode"] == 0
    MF_UNCHECKED
  else
    MF_CHECKED
  end
}
cmd.category = "View > Edge Style"


=begin # not found
cmd = UI::Command.new(TRANSLATE["Back Edges"]) {
  Sketchup.active_model.rendering_options["ModelTransparency"] = !Sketchup.active_model.rendering_options["ModelTransparency"]
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display the model with back edges dashed."]
cmd.small_icon = "./RenderBackEdgesSmall.png"
cmd.large_icon = "./RenderBackEdgesLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["ModelTransparency"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = TRANSLATE["View > Edge Style"]

=end


cmd = UI::Command.new(TRANSLATE["Profiles"]) {
  opts = Sketchup.active_model.rendering_options
  opts["DrawSilhouettes"] = !opts["DrawSilhouettes"]
  true
}
cmd.extend(Command)
cmd.tooltip = TRANSLATE["Display Profiles"]
cmd.small_icon = "./ToggleProfilesSmall.png"
cmd.large_icon = "./ToggleProfilesLarge.png"
cmd.status_bar_text = TRANSLATE["Display Profiles"]
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["DrawSilhouettes"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Edge Style"


cmd = UI::Command.new(TRANSLATE["Depth Cue"]) {
  opts = Sketchup.active_model.rendering_options
  opts["DrawDepthQue"] = !opts["DrawDepthQue"]
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display Depth Cue"]
cmd.small_icon = "./ToggleDepthCueSmall.png"
cmd.large_icon = "./ToggleDepthCueLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["DrawDepthQue"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Edge Style"


cmd = UI::Command.new(TRANSLATE["Jitter Edges"]) {
  Sketchup.active_model.rendering_options["JitterEdges"] = !Sketchup.active_model.rendering_options["JitterEdges"]
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Jitter Edges"]
cmd.small_icon = "./ToggleJitterSmall.png"
cmd.large_icon = "./ToggleJitterLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["JitterEdges"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Edge Style"


cmd = UI::Command.new(TRANSLATE["End Points"]) {
  opts = Sketchup.active_model.rendering_options
  opts["DrawLineEnds"] = !opts["DrawLineEnds"]
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display End Points"]
cmd.small_icon = "./ToggleEndpointsSmall.png"
cmd.large_icon = "./ToggleEndpointsLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["DrawLineEnds"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Edge Style"


cmd = UI::Command.new(TRANSLATE["Edge Color Mode"]) {
  ro = Sketchup.active_model.rendering_options
  ecm = ro["EdgeColorMode"]
  ecm = ((ecm + 1) % 3)
  ro["EdgeColorMode"] = ecm
  Sketchup.set_status_text(TRANSLATE["Egde Color Mode: "] + TRANSLATE["by Material", "all same", "by Axis"][ecm])
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Cycle Edge Color Mode"]
cmd.small_icon = "./EdgeColorModeSmall.png"
cmd.large_icon = "./EdgeColorModeLarge.png"
cmd.category = "View > Edge Style"


cmd = UI::Command.new(TRANSLATE["Edge Color by Material"]) {
  ro = Sketchup.active_model.rendering_options
  ecm = ro["EdgeColorMode"]
  if ecm != 0
    ecm = 0
    Sketchup.set_status_text(TRANLSATE["Egde Color Mode: by Material"])
  else
    ecm = 1
    Sketchup.set_status_text(TRANSLATE["Egde Color Mode: Default"])
  end
  ro["EdgeColorMode"] = ecm
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Toggle Edge Color by Material"]
cmd.small_icon = "./ToggleMaterialEdgeSmall.png"
cmd.large_icon = "./ToggleMaterialEdgeLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["EdgeColorMode"] == 0
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Edge Style"


cmd = UI::Command.new(TRANSLATE["Edge Color by Axis"]) {
  ro = Sketchup.active_model.rendering_options
  ecm = ro["EdgeColorMode"]
  if ecm != 2
    ecm = 2
    Sketchup.set_status_text(TRANSLATE["Egde Color Mode: by Axis"])
  else
    ecm = 1
    Sketchup.set_status_text(TRANSLATE["Egde Color Mode: Default"])
  end
  ro["EdgeColorMode"] = ecm
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Toggle Edge Color by Axis"]
cmd.small_icon = "./ToggleAxisEdgeSmall.png"
cmd.large_icon = "./ToggleAxisEdgeLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["EdgeColorMode"] == 2
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Edge Style"


cmd = UI::Command.new(TRANSLATE["Color By Layer"]) {
  Sketchup.active_model.rendering_options["DisplayColorByLayer"] = !Sketchup.active_model.rendering_options["DisplayColorByLayer"]
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Toggle Color By Layer"]
cmd.small_icon = "./ToggleColorByLayerSmall.png"
cmd.large_icon = "./ToggleColorByLayerLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["DisplayColorByLayer"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Edge Style"


# View → Face Style


cmd = UI::Command.new(TRANSLATE["X-Ray Mode"]) {
  Sketchup.active_model.rendering_options["ModelTransparency"] = !Sketchup.active_model.rendering_options["ModelTransparency"]
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display the model with globally transparent faces."]
cmd.small_icon = "./ToggleXraySmall.png"
cmd.large_icon = "./ToggleXrayLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["ModelTransparency"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Face Style"


cmd = UI::Command.new(TRANSLATE["Wireframe"]) {
  Sketchup.active_model.rendering_options["RenderMode"] = 0
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display in wireframe mode."]
cmd.small_icon = "./RenderWireframeSmall.png"
cmd.large_icon = "./RenderWireframeLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["RenderMode"] == 0
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Face Style"


cmd = UI::Command.new(TRANSLATE["Hidden Line"]) {
  Sketchup.active_model.rendering_options["RenderMode"] = 1
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display in hidden line mode."]
cmd.small_icon = "./RenderHiddenlineSmall.png"
cmd.large_icon = "./RenderHiddenlineLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["RenderMode"] == 1
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Face Style"


cmd = UI::Command.new(TRANSLATE["Shaded"]) {
  Sketchup.active_model.rendering_options["RenderMode"] = 2
  Sketchup.active_model.rendering_options["Texture"] = false
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display in shaded mode."]
cmd.small_icon = "./RenderShadedSmall.png"
cmd.large_icon = "./RenderShadedLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["RenderMode"] == 2 and Sketchup.active_model.rendering_options["Texture"] == false
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Face Style"


cmd = UI::Command.new(TRANSLATE["Textured"]) {
  Sketchup.active_model.rendering_options["RenderMode"] = 2
  Sketchup.active_model.rendering_options["Texture"] = true
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display shaded using textures."]
cmd.small_icon = "./RenderTexturedSmall.png"
cmd.large_icon = "./RenderTexturedLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["RenderMode"] == 2 and Sketchup.active_model.rendering_options["Texture"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Face Style"


cmd = UI::Command.new(TRANSLATE["Monochrome"]) { Sketchup.active_model.rendering_options["RenderMode"] = 5 }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Display the model with only front and back face colors."]
cmd.small_icon = "./RenderMonochromeSmall.png"
cmd.large_icon = "./RenderMonochromeLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["RenderMode"] == 5
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Face Style"


# View → Component Editing


cmd = UI::Command.new(TRANSLATE["Hide Rest"]) {
  Sketchup.active_model.rendering_options["InactiveHidden"] = !Sketchup.active_model.rendering_options["InactiveHidden"]
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Hide Rest of Model"]
cmd.small_icon = "./EditHideRestLarge.png"
cmd.large_icon = "./EditHideRestLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["InactiveHidden"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Component Editing"
cmd.keywords = ["hide", "fade", "inactive", "components"]


cmd = UI::Command.new(TRANSLATE["Hide Similar"]) {
  Sketchup.active_model.rendering_options["InstanceHidden"] = !Sketchup.active_model.rendering_options["InstanceHidden"]
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Hide Similar Components"]
cmd.small_icon = "./EditHideSimilarLarge.png"
cmd.large_icon = "./EditHideSimilarLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.rendering_options["InstanceHidden"] == true
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "View > Component Editing"
cmd.keywords = ["hide", "fade", "instance", "components"]


# Camera


cmd = UI::Command.new(TRANSLATE["Previous"]) { Sketchup.send_action("viewUndo:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Undo the previous camera view."]
cmd.small_icon = "./ViewUndoSmall.png"
cmd.large_icon = "./ViewUndoLarge.png"
cmd.category = "Camera"


# Camera → Standard Views


cmd = UI::Command.new(TRANSLATE["Top"]) { Sketchup.send_action("viewTop:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Top View"]
cmd.small_icon = "./ViewTopSmall.png"
cmd.large_icon = "./ViewTopLarge.png"
cmd.category = "Camera > Standard Views"


cmd = UI::Command.new(TRANSLATE["Bottom"]) { Sketchup.send_action("viewBottom:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Bottom View"]
cmd.small_icon = "./ViewBottomSmall.png"
cmd.large_icon = "./ViewBottomLarge.png"
cmd.category = "Camera > Standard Views"


cmd = UI::Command.new(TRANSLATE["Front"]) { Sketchup.send_action("viewFront:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Front View"]
cmd.small_icon = "./ViewFrontSmall.png"
cmd.large_icon = "./ViewFrontLarge.png"
cmd.category = "Camera > Standard Views"


cmd = UI::Command.new(TRANSLATE["Back"]) { Sketchup.send_action("viewBack:") }
cmd.extend(Command)
cmd.small_icon = "./ViewBackSmall.png"
cmd.large_icon = "./ViewBackLarge.png"
cmd.category = "Camera > Standard Views"


cmd = UI::Command.new(TRANSLATE["Left"]) { Sketchup.send_action("viewLeft:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Back View"]
cmd.small_icon = "./ViewLeftSmall.png"
cmd.large_icon = "./ViewLeftLarge.png"
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Left View"]
cmd.category = "Camera > Standard Views"


cmd = UI::Command.new(TRANSLATE["Right"]) { Sketchup.send_action("viewRight:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Right View"]
cmd.small_icon = "./ViewRightSmall.png"
cmd.large_icon = "./ViewRightLarge.png"
cmd.category = "Camera > Standard Views"


cmd = UI::Command.new(TRANSLATE["Iso"]) { Sketchup.send_action("viewIso:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Move the camera to the nearest isometric view of the model."]
cmd.small_icon = "./ViewIsoSmall.png"
cmd.large_icon = "./ViewIsoLarge.png"
cmd.category = "Camera > Standard Views"
cmd.keywords = ["parallel"]


cmd = UI::Command.new(TRANSLATE["Perspective"]) { Sketchup.send_action("viewPerspective:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Camera Perspective"]
cmd.small_icon = "./TogglePerspectiveSmall.png"
cmd.large_icon = "./TogglePerspectiveLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.active_view.camera.perspective?
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Camera"


cmd = UI::Command.new(TRANSLATE["Orbit"]) { Sketchup.send_action("selectOrbitTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Orbit the camera view about the model."]
cmd.small_icon = "./OrbitSmall.png"
cmd.large_icon = "./OrbitLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "CameraOrbitTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Camera"
cmd.keywords = ["rotate"]


cmd = UI::Command.new(TRANSLATE["Pan"]) { Sketchup.send_action("selectDollyTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Pan the camera view vertically or horizontally."]
cmd.small_icon = "./PanSmall.png"
cmd.large_icon = "./PanLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "CameraDollyTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Camera"
cmd.keywords = ["Hand"]
cmd.keywords = ["dolly"]


cmd = UI::Command.new(TRANSLATE["Field of View"]) { Sketchup.send_action("selectFieldOfViewTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Change the field of view."]
cmd.small_icon = "./FovSmall.png"
cmd.large_icon = "./FovLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "CameraFOVTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Camera"


cmd = UI::Command.new(TRANSLATE["Zoom"]) { Sketchup.send_action("selectZoomTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Zoom the camera view in or out."]
cmd.small_icon = "./ZoomSmall.png"
cmd.large_icon = "./ZoomLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "CameraZoomTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Camera"
cmd.keywords = ["enlarge"]


cmd = UI::Command.new(TRANSLATE["Zoom Window"]) { Sketchup.send_action("selectZoomWindowTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Zoom the camera to show everything inside the selected window."]
cmd.small_icon = "./ZoomWindowSmall.png"
cmd.large_icon = "./ZoomWindowLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "CameraZoomWindowTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Camera"


cmd = UI::Command.new(TRANSLATE["Zoom Extents"]) {
  if Sketchup.active_model.selection.length <= 0
    Sketchup.send_action("viewZoomExtents:")
  else
    Sketchup.send_action('viewZoomToSelection:')
  end
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Zoom to show the selection or the entire model if no selection."]
cmd.small_icon = "./ZoomExtentsSmall.png"
cmd.large_icon = "./ZoomExtentsLarge.png"
cmd.category = "Camera"
cmd.keywords = ["zoom"]


cmd = UI::Command.new(TRANSLATE["Camera Position"]) { Sketchup.send_action("selectPositionCameraTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Position the camera view with a specific location, eye height and direction."]
cmd.small_icon = "./PlaceCameraSmall.png"
cmd.large_icon = "./PlaceCameraLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "PositionCameraTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Camera"


cmd = UI::Command.new(TRANSLATE["Walk"]) { Sketchup.send_action("selectWalkTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Walk with the camera."]
cmd.small_icon = "./WalkSmall.png"
cmd.large_icon = "./WalkLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "CameraWalkTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Camera"


cmd = UI::Command.new(TRANSLATE["Look"]) { Sketchup.send_action("selectTurnTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Pivot camera view about a stationary point."]
cmd.small_icon = "./LookSmall.png"
cmd.large_icon = "./LookLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "CameraTurnTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Camera"


cmd = UI::Command.new(TRANSLATE["Image Igloo"]) { Sketchup.send_action("selectImageIglooTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Show all matched photos around the model."]
cmd.small_icon = "./CameraImageIglooSmall.png"
cmd.large_icon = "./CameraImageIglooLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "CameraTurnTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Camera"


# Draw


cmd = UI::Command.new(TRANSLATE["Line"]) { Sketchup.send_action("selectLineTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Draw edges from point to point."]
cmd.small_icon = "./LineSmall.png"
cmd.large_icon = "./LineLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "SketchTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Draw"


cmd = UI::Command.new(TRANSLATE["Arc"]) { Sketchup.send_action("selectArcTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Draw arcs from point to point with bulge."]
cmd.small_icon = "./ToolArcSmall.png"
cmd.large_icon = "./ToolArcLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "ArcTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Draw"
cmd.keywords = ["arc", "curve"]


cmd = UI::Command.new(TRANSLATE["Freehand"]) { Sketchup.send_action("selectFreehandTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Draw freehand lines by clicking and dragging."]
cmd.small_icon = "./FreehandSmall.png"
cmd.large_icon = "./FreehandLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "FreehandTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Draw"
cmd.keywords = ["curve", "poly", "line"]


cmd = UI::Command.new(TRANSLATE["Rectangle"]) { Sketchup.send_action("selectRectangleTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Draw rectangular faces from corner to corner."]
cmd.small_icon = "./RectangleSmall.png"
cmd.large_icon = "./RectangleLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "RectangleTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Draw"


cmd = UI::Command.new(TRANSLATE["Circle"]) { Sketchup.send_action("selectCircleTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Draw circles from center point to radius."]
cmd.small_icon = "./ToolCircleSmall.png"
cmd.large_icon = "./ToolCircleLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "CircleTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Draw"
cmd.keywords = ["circle"]


cmd = UI::Command.new(TRANSLATE["Polygon"]) { Sketchup.send_action("selectPolygonTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Draw N-sided polygons from center point to radius."]
cmd.small_icon = "./PolygonSmall.png"
cmd.large_icon = "./PolygonLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "PolyTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Draw"
cmd.keywords = ["polygon"]


# Tools


cmd = UI::Command.new(TRANSLATE["Select"]) { Sketchup.send_action("selectSelectionTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Select entities"]
cmd.small_icon = "./SelectSmall.png"
cmd.large_icon = "./SelectLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "SelectionTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["Eraser"]) { Sketchup.send_action("selectEraseTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Erase, soften or smooth entities in the model."]
cmd.small_icon = "./EraserSmall.png"
cmd.large_icon = "./EraserLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "EraseTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["Paint Bucket"]) { Sketchup.send_action("selectPaintTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Apply color and material to entities in the model."]
cmd.small_icon = "./PaintSmall.png"
cmd.large_icon = "./PaintLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "PaintTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["Move"]) { Sketchup.send_action("selectMoveTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Move, stretch, copy and array selected entities."]
cmd.small_icon = "./MoveSmall.png"
cmd.large_icon = "./MoveLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "MoveTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"
cmd.keywords = ["move", "displace"]


cmd = UI::Command.new(TRANSLATE["Rotate"]) { Sketchup.send_action("selectRotateTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Rotate, stretch, copy and array selected entities about an axis."]
cmd.small_icon = "./RotateSmall.png"
cmd.large_icon = "./RotateLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "RotateTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["Scale"]) { Sketchup.send_action("selectScaleTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Scale and stretch selected entities."]
cmd.small_icon = "./ScaleSmall.png"
cmd.large_icon = "./ScaleLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "ScaleTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"
cmd.keywords = ["scale", "resize", "bigger", "smaller"]


cmd = UI::Command.new(TRANSLATE["Push/Pull"]) { Sketchup.send_action("selectPushPullTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Push and pull faces."]
cmd.small_icon = "./PushPullSmall.png"
cmd.large_icon = "./PushPullLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "PushPullTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"
cmd.keywords = ["push", "pull", "extrude"]


cmd = UI::Command.new(TRANSLATE["Follow"]) { Sketchup.send_action("selectExtrudeTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Follow a path with a selected face."]
cmd.small_icon = "./FollowMeSmall.png"
cmd.large_icon = "./FollowMeLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "ExtrudeTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"
cmd.keywords = ["follow", "extrude", "path"]


cmd = UI::Command.new(TRANSLATE["Offset"]) { Sketchup.send_action("selectOffsetTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Offset selected edges in a plane."]
cmd.small_icon = "./OffsetSmall.png"
cmd.large_icon = "./OffsetLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "OffsetTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["Tape"]) { Sketchup.send_action("selectMeasureTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Measure distances, create guide lines or points."]
cmd.small_icon = "./TapeSmall.png"
cmd.large_icon = "./TapeLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "MeasureTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["Protractor"]) { Sketchup.send_action("selectProtractorTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Measure angles and create guides."]
cmd.small_icon = "./ProtractorSmall.png"
cmd.large_icon = "./ProtractorLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "ProtractorTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["Axis"]) { Sketchup.send_action("selectAxisTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Move or orient the axis."]
cmd.small_icon = "./ToolAxesLarge.png"
cmd.large_icon = "./ToolAxesSmall.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "SketchCSTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["Dimension"]) { Sketchup.send_action("selectDimensionTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Draw Dimension"]
cmd.small_icon = "./ToolDimensionSmall.png"
cmd.large_icon = "./ToolDimensionLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "DimensionTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["Text"]) { Sketchup.send_action("selectTextTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Draw text labels."]
cmd.small_icon = "./TextSmall.png"
cmd.large_icon = "./TextLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "TextTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["3D Text Tool"]) { Sketchup.send_action("select3dTextTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Create 3D Text"]
cmd.small_icon = "./16x16_3dText.png"
cmd.large_icon = "./24x24_3dText.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "3DTextTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


cmd = UI::Command.new(TRANSLATE["Section"]) { Sketchup.send_action("selectSectionPlaneTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Section"]
cmd.small_icon = "./SectionSmall.png"
cmd.large_icon = "./SectionLarge.png"
cmd.set_validation_proc {
  if Sketchup.active_model.tools.active_tool_id != 0 && Sketchup.active_model.tools.active_tool_name == "SectionPlaneTool"
    MF_CHECKED
  else
    MF_UNCHECKED
  end
}
cmd.category = "Tools"


# Solid Tools


cmd = UI::Command.new(TRANSLATE["Outer Shell"]) {
  groups = Sketchup.active_model.selection.find_all{|e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.manifold? }
  next false unless groups.length >= 2
  group = groups.shift
  group = group.outer_shell(groups.shift) until groups.empty?
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Combine all selected solids into a single solid and remove all interior entities."]
cmd.small_icon = "./16x16_tb_solidshell.png"
cmd.large_icon = "./24x24_tb_solidshell.png"
cmd.set_validation_proc {
  s = Sketchup.active_model.selection
  if s.length < 2 || s.find{|e| !e.is_a?(Sketchup::Group) && !e.is_a?(Sketchup::ComponentInstance) }
    MF_GRAYED
  else
    MF_ENABLED
  end
}
cmd.category = "Tools > Solid Tools"
cmd.keywords = ["solid", "shell"]


if Sketchup.is_pro?


cmd = UI::Command.new(TRANSLATE["Intersect"]) {
  groups = Sketchup.active_model.selection.find_all{|e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.manifold? }
  next false unless groups.length >= 2
  group = groups.shift
  group = group.intersect(groups.shift) until groups.empty?
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Intersect all selected solids but keep only their intersection in the model."]
cmd.small_icon = "./16x16_tb_solidintersect.png"
cmd.large_icon = "./24x24_tb_solidintersect.png"
cmd.set_validation_proc {
  s = Sketchup.active_model.selection
  if s.length < 2 || s.find{|e| !e.is_a?(Sketchup::Group) && !e.is_a?(Sketchup::ComponentInstance) }
    MF_GRAYED
  else
    MF_ENABLED
  end
}
cmd.category = "Tools > Solid Tools"
cmd.keywords = ["solid", "intersect", "cut"]


cmd = UI::Command.new(TRANSLATE["Union"]) {
  groups = Sketchup.active_model.selection.find_all{|e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.manifold? }
  next false unless groups.length >= 2
  group = groups.shift
  group = group.union(groups.shift) until groups.empty?
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Combine all selected solids into a single solid and keep interior voids."]
cmd.small_icon = "./16x16_tb_solidunion.png"
cmd.large_icon = "./24x24_tb_solidunion.png"
cmd.set_validation_proc {
  s = Sketchup.active_model.selection
  if s.length < 2 || s.find{|e| !e.is_a?(Sketchup::Group) && !e.is_a?(Sketchup::ComponentInstance) }
    MF_GRAYED
  else
    MF_ENABLED
  end
}
cmd.category = "Tools > Solid Tools"
cmd.keywords = ["solid", "combine"]


cmd = UI::Command.new(TRANSLATE["Trim"]) {
  groups = Sketchup.active_model.selection.find_all{|e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.manifold? }
  next false unless groups.length >= 2
  group = groups.shift
  group = group.trim(groups.shift) until groups.empty?
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Trim first solid against second solid and keep both in the model."]
cmd.small_icon = "./16x16_tb_solidtrim.png"
cmd.large_icon = "./24x24_tb_solidtrim.png"
cmd.set_validation_proc {
  s = Sketchup.active_model.selection
  if s.length < 2 || s.find{|e| !e.is_a?(Sketchup::Group) && !e.is_a?(Sketchup::ComponentInstance) }
    MF_GRAYED
  else
    MF_ENABLED
  end
}
cmd.category = "Tools > Solid Tools"
cmd.keywords = ["solid", "reduce"]


cmd = UI::Command.new(TRANSLATE["Split"]) {
  groups = Sketchup.active_model.selection.find_all{|e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.manifold? }
  next false unless groups.length >= 2
  group = groups.shift
  group = group.split(groups.shift) until groups.empty?
  true
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Intersect all selected solids and keep all results in the model."]
cmd.small_icon = "./16x16_tb_solidsplit.png"
cmd.large_icon = "./24x24_tb_solidsplit.png"
cmd.set_validation_proc {
  s = Sketchup.active_model.selection
  if s.length < 2 || s.find{|e| !e.is_a?(Sketchup::Group) && !e.is_a?(Sketchup::ComponentInstance) }
    MF_GRAYED
  else
    MF_ENABLED
  end
}
cmd.category = "Tools > Solid Tools"
cmd.keywords = ["solid", "split"]


end # is_pro?


# Window


# UI.model_info_pages
# ["Animation", "Components", "Credits", "Dimensions", "File", "Geo-location", "Rendering", "Statistics", "Text", "Units"]
UI.model_info_pages.each{ |page|
  cmd = UI::Command.new(TRANSLATE[page]) { UI.show_model_info(page) }
  cmd.extend(Command)
  cmd.tooltip = cmd.status_bar_text = TRANSLATE["Show %0", TRANSLATE[page]] # TODO: gets stuck at first value of page
  cmd.small_icon = "./ModelInfoSmall.png"
  cmd.large_icon = "./ModelInfoLarge.png"
  cmd.category = "Window > Model Info"
  cmd.keywords = ["model", "info", page]
}


# UI.show_inspector
# ["Materials", "Components", "Styles", "Scenes", "Shadows", "Layers", "SoftenEdges", "Outliner", "Instructor", "Fog", "MatchPhoto"]
UI.inspector_names.each{ |inspector|
  cmd = UI::Command.new(TRANSLATE[inspector]) { UI.show_inspector(inspector) }
  cmd.extend(Command)
  cmd.tooltip = cmd.status_bar_text = TRANSLATE["Show %0 dialog", TRANSLATE[inspector]]
  cmd.small_icon = "./Inspector#{inspector}Small.png" if File.exists?("./Inspector#{inspector}Small.png")
  cmd.large_icon = "./Inspector#{inspector}Large.png" if File.exists?("./Inspector#{inspector}Large.png")
  cmd.category = "Window"
  cmd.keywords = ["background", "watermark", "sketchy"] if inspector == "Scenes"
}


cmd = UI::Command.new(TRANSLATE["Show Ruby Panel"]) { Sketchup.send_action("showRubyPanel:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Show Ruby Panel"]
cmd.small_icon = "./ShowRubyPanelSmall.png"
cmd.large_icon = "./ShowRubyPanelLarge.png"
cmd.category = "Window"


# Pages / Scenes


cmd = UI::Command.new(TRANSLATE["Add Scene"]) { Sketchup.send_action("pageAdd:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Add Scene"]
cmd.small_icon = "./PageAddSmall.png"
cmd.large_icon = "./PageAddLarge.png"
cmd.category = "Scenes"
cmd.keywords = ["page", "slide", "scene", "add", "new"]


cmd = UI::Command.new(TRANSLATE["Update Scene"]) { Sketchup.active_model.pages.selected_page.update }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Update Scene"]
cmd.small_icon = "./PageUpdateSmall.png"
cmd.large_icon = "./PageUpdateLarge.png"
cmd.category = "Scenes"
cmd.keywords = ["page", "slide", "scene", "update"]


cmd = UI::Command.new(TRANSLATE["Delete Scene"]) { Sketchup.send_action("pageDelete:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Delete Scene"]
cmd.small_icon = "./PageDeleteSmall.png"
cmd.large_icon = "./PageDeleteLarge.png"
cmd.category = "Scenes"
cmd.keywords = ["page", "slide", "scene", "delete", "remove"]


cmd = UI::Command.new(TRANSLATE["Previous Scene"]) { Sketchup.send_action("pagePrevious:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Previous Scene"]
cmd.small_icon = "./PagePrevSmall.png"
cmd.large_icon = "./PagePrevLarge.png"
cmd.category = "Scenes"
cmd.keywords = ["page", "slide", "scene", "previous"]


cmd = UI::Command.new(TRANSLATE["Next Scene"]) { Sketchup.send_action("pageNext:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Next Scene"]
cmd.small_icon = "./PageNextSmall.png"
cmd.large_icon = "./PageNextLarge.png"
cmd.category = "Scenes"
cmd.keywords = ["page", "slide", "scene", "next"]


# Layers



# Preferences


# UI.preferences_pages
# ["Accelerator", "Applications", "Compatibility", "Drawing", "Extensions", "FileLocations", "General", "GraphicsCard", "Templates", "Workspace"]
UI.preferences_pages.each{|page|
  cmd = UI::Command.new(TRANSLATE[page]) { UI.show_preferences(page) }
  cmd.extend(Command)
  cmd.tooltip = cmd.status_bar_text = TRANSLATE["#{page} Preferences"]
  cmd.small_icon = (File.exists?("./Preferences#{page}Small.png")) ? "./Preferences#{page}Small.png" : "./PreferencesSmall.png"
  cmd.large_icon = (File.exists?("./Preferences#{page}Large.png")) ? "./Preferences#{page}Large.png" : "./PreferencesLarge.png"
  cmd.category = "Preferences"
  cmd.keywords = ["preferences", "settings", "options", page]
  cmd.keywords << "OpenGL" if page == "GraphicsCard"
}


# Entity


cmd = UI::Command.new(TRANSLATE["Explode"]) {
  ss = Sketchup.active_model.selection
  Sketchup.active_model.start_operation("ungroup")
  ss.each do |s|
    if s.respond_to?("explode")
      ents = s.explode
      ents = ents.select{|e| e.is_a?(Sketchup::Drawingelement)}
      ss.add ents
    end
  end
  Sketchup.active_model.commit_operation
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Ungroup"]
cmd.small_icon = "./UngroupSmall.png"
cmd.large_icon = "./UngroupLarge.png"
cmd.set_validation_proc{
  ss = Sketchup.active_model.selection
  MF_GRAYED unless ss.length > 0
  ss = ss.select {|s| s.respond_to? "explode"}
  if ss.length > 0
    MF_ENABLED
  else
    MF_GRAYED
  end
}
cmd.category = "Entity"


# Other


cmd = UI::Command.new(TRANSLATE["Center"]) {
  ss = Sketchup.active_model.selection
  bb = Geom::BoundingBox.new
  if ss.length > 0
    ss.each {|s| bb.add s.bounds }
  else
    bb = Sketchup.active_model.bounds
  end
  center = bb.center
  camera = Sketchup.active_model.active_view.camera
  vec = camera.target - center
  eye = camera.eye
  target = camera.target - vec
  camera.set(eye, target, [0, 0, 1])
}
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Center Selected"]
cmd.small_icon = "./CenterSelectionSmall.png"
cmd.large_icon = "./CenterSelectionLarge.png"
cmd.category = "Camera"


unless OSX
cmd = UI::Command.new(TRANSLATE["Add Photo Texture"]) { Sketchup.send_action("getPhotoTexture:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Add photographic textures to the selected face."]
cmd.small_icon = "./16x16_Photo_Textures.png"
cmd.large_icon = "./24x24_Photo_Textures.png"
cmd.category = "Face"
cmd.keywords = ["photo texture", "street-view"]
end


unless OSX
cmd = UI::Command.new(TRANSLATE["Preview in Google Earth"]) { Sketchup.send_action("placeModel:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Preview this model in Google Earth."]
cmd.small_icon = "./ToolExportGESmall.png"
cmd.large_icon = "./ToolExportGELarge.png"
cmd.category = "Google"
end


cmd = UI::Command.new(TRANSLATE["Set North Tool"]) { Sketchup.send_action("selectNorthTool:") }
cmd.extend(Command)
cmd.tooltip = cmd.status_bar_text = TRANSLATE["Center Selected"]
cmd.small_icon = Sketchup.find_support_file("SolarNorth/northtext_small.png", "Tools")
cmd.large_icon = Sketchup.find_support_file("SolarNorth/northtext.png", "Tools")
cmd.category = "Solar North"


file_loaded(__FILE__)
end # unless file_loaded?



end # module AE::LaunchUp::Commands



end # module LaunchUp



end # module AE
