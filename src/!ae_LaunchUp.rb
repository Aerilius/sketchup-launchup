# Load the normal support files.
require 'sketchup.rb'
require 'extensions.rb'


# Create the extension.
ext = SketchupExtension.new('LaunchUp', 'ae_LaunchUp/LaunchUp.rb')

# Attach some nice info.
ext.creator     = 'Aerilius'
ext.version     = '1.0.6'
ext.copyright   = '2011-2013, Andreas Eisenbarth'
ext.description = 'A searchable quick launcher for SketchUp tools.'

# Register and load the extension on startup.
Sketchup.register_extension(ext, true)
