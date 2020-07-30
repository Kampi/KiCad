from pcbnew import *

board = LoadBoard("C:\Users\Daniel.Kampert\Desktop\Git\SensorHub\hardware\SensorHub.kicad_pcb")
#board = pcbnew.GetBoard()
PlotController = PLOT_CONTROLLER(board)

PlotOptions = PlotController.GetPlotOptions()

# popt.SetOutputDirectory("plot/")
PlotOptions.SetOutputDirectory("C:\Users\Daniel.Kampert\Desktop\Test")



# Set some important plot options:
PlotOptions.SetPlotFrameRef(False)
PlotOptions.SetLineWidth(FromMM(0.35))

PlotOptions.SetAutoScale(False)
PlotOptions.SetScale(1)
PlotOptions.SetMirror(False)
PlotOptions.SetUseGerberAttributes(True)
PlotOptions.SetExcludeEdgeLayer(False)
PlotOptions.SetScale(1)
PlotOptions.SetUseAuxOrigin(False)

# This by gerbers only (also the name is truly horrid!)
PlotOptions.SetSubtractMaskFromSilk(False)

PlotController.SetLayer(F_SilkS)
PlotController.OpenPlotfile("Silk", PLOT_FORMAT_PDF, "Assembly guide")
PlotController.PlotLayer()

#########################
#### CuBottom.gbr    ####
#### CuTop.gbr       ####
#### EdgeCuts.gbr    ####
#### MaskBottom.gbr  ####
#### MaskTop.gbr     ####
#### PasteBottom.gbr ####
#### PasteTop.gbr    ####
#### SilkBottom.gbr  ####
#### SilkTop.gbr     ####
#########################
'''
# Once the defaults are set it become pretty easy...
# I have a Turing-complete programming language here: I'll use it...
# param 0 is a string added to the file base name to identify the drawing
# param 1 is the layer ID
plot_plan = [
    ( "CuTop", F_Cu, "Top layer" ),
    ( "CuBottom", B_Cu, "Bottom layer" ),
    ( "PasteBottom", B_Paste, "Paste Bottom" ),
    ( "PasteTop", F_Paste, "Paste top" ),
    ( "SilkTop", F_SilkS, "Silk top" ),
    ( "SilkBottom", B_SilkS, "Silk top" ),
    ( "MaskTop", F_Mask, "Mask top" ),
    ( "MaskBottom", B_Mask, "Mask bottom" ),
    ( "EdgeCuts", Edge_Cuts, "Edges" ),
]

for layer_info in plot_plan:
    pctl.SetLayer(layer_info[1])
    pctl.OpenPlotfile(layer_info[0], PLOT_FORMAT_PDF, layer_info[2])
    pctl.PlotLayer()

######################
#### AssyTop.pdf #####
######################

# Our fabricators want two additional gerbers:
# An assembly with no silk trim and all and only the references
# (you'll see that even holes have designators, obviously)
popt.SetSubtractMaskFromSilk(False)
popt.SetPlotReference(True)
popt.SetPlotValue(False)
popt.SetPlotInvisibleText(True)

pctl.SetLayer(F_SilkS)
pctl.OpenPlotfile("AssyTop", PLOT_FORMAT_PDF, "Assembly top")
pctl.PlotLayer()

###############################
#### AssyOutlinesTop.pdf  #####
###############################

# And a gerber with only the component outlines (really!)
popt.SetPlotReference(False)
popt.SetPlotInvisibleText(False)
pctl.SetLayer(F_SilkS)
pctl.OpenPlotfile("AssyOutlinesTop", PLOT_FORMAT_PDF, "Assembly outline top")
pctl.PlotLayer()

######################
#### Layout.pdf  #####
######################

# The same could be done for the bottom side, if there were components
popt.SetUseAuxOrigin(False)

## For documentation we also want a general layout PDF
## I usually use a shell script to merge the ps files and then distill the result
## Now I can do it with a control file. As a bonus I can have references in a
## different colour, too.

popt.SetPlotReference(True)
popt.SetPlotValue(True)
popt.SetPlotInvisibleText(False)
# Remember that the frame is always in color 0 (BLACK) and should be requested
# before opening the plot
popt.SetPlotFrameRef(False)
pctl.SetLayer(Dwgs_User)

pctl.OpenPlotfile("Layout", PLOT_FORMAT_PDF, "General layout")
pctl.PlotLayer()

# Do the PCB edges in yellow

pctl.SetLayer(Edge_Cuts)
pctl.PlotLayer()

## Comments in, uhmm... green

pctl.SetLayer(Cmts_User)
pctl.PlotLayer()

# Bottom mask as lines only, in red
#popt.SetMode(LINE)

pctl.SetLayer(B_Mask)
pctl.PlotLayer()

# Top mask as lines only, in blue

pctl.SetLayer(F_Mask)
pctl.PlotLayer()

# Top paste in light blue, filled

#popt.SetMode(FILLED)
pctl.SetLayer(F_Paste)
pctl.PlotLayer()

# Top Silk in cyan, filled, references in dark cyan

pctl.SetLayer(F_SilkS)
pctl.PlotLayer()

########################
#### Assembly.svg  #####
########################

popt.SetTextMode(PLOTTEXTMODE_STROKE)
pctl.SetLayer(F_Mask)
pctl.OpenPlotfile("Assembly", PLOT_FORMAT_PDF, "Master Assembly")
pctl.SetColorMode(True)

# We want *everything*
popt.SetPlotReference(True)
popt.SetPlotValue(True)
popt.SetPlotInvisibleText(True)

# Remember than the DXF driver assigns colours to layers. This means that
# we will be able to turn references on and off simply using their layers
# Also most of the layer are now plotted in 'line' mode, because DXF handles
# fill mode almost like sketch mode (this is to keep compatibility with
# most CAD programs; most of the advanced primitive attributes required are
# handled only by recent autocads...); also the entry level cads (qcad
# and derivatives) simply don't handle polyline widths...
# 
# Here I'm using numbers for colors and layers, I'm too lazy too look them up:P


#popt.SetMode(LINE)
pctl.SetLayer(B_SilkS)
pctl.PlotLayer()
pctl.SetLayer(F_SilkS)
pctl.PlotLayer()
pctl.SetLayer(B_Mask)
pctl.PlotLayer()
pctl.SetLayer(F_Mask)
pctl.PlotLayer()
pctl.SetLayer(B_Paste)
pctl.PlotLayer()
pctl.SetLayer(F_Paste)
pctl.PlotLayer()
pctl.SetLayer(Edge_Cuts)
pctl.PlotLayer()

# Export the copper layers too... exporting one of them in filled mode with
# drill marks will put the marks in the WHITE later (since it tries to blank
# the pads...); these will be obviously great reference points for snap
# and stuff in the cad. A pctl function to only plot them would be
# better anyway...

#popt.SetMode(FILLED)
popt.SetDrillMarksType(PCB_PLOT_PARAMS.FULL_DRILL_SHAPE)
pctl.SetLayer(B_Cu)
pctl.PlotLayer()
popt.SetDrillMarksType(PCB_PLOT_PARAMS.NO_DRILL_SHAPE)
pctl.SetLayer(F_Cu)
pctl.PlotLayer()

# At the end you have to close the last plot, otherwise you don't know when
# the object will be recycled!
pctl.ClosePlot()
'''