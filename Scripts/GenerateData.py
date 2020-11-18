import os
import datetime

from pcbnew import *
from zipfile import ZipFile

Board = LoadBoard("C:/Users/Daniel.Kampert/Desktop/Git/Boost-Converter/hardware/BoostConverter.kicad_pcb")
#board = pcbnew.GetBoard()
OutputPath = "C:/Users/Daniel.Kampert/Desktop/Git/Boost-Converter/production"
PlotController = PLOT_CONTROLLER(Board)
PlotOptions = PlotController.GetPlotOptions()
DrillWriter = EXCELLON_WRITER(Board)

# ToDo:
#   - Update the date in the frames
#   - Add frame to the sheets (not possible with KiCAD 5.16)

def CreateDocumentation(Path):
    PlotOptions.SetOutputDirectory(Path)
    PlotOptions.SetPlotFrameRef(True)
    PlotOptions.SetLineWidth(FromMM(0.35))
    PlotOptions.SetUseGerberAttributes(True)
    PlotOptions.SetExcludeEdgeLayer(False)
    PlotOptions.SetUseAuxOrigin(False)
    PlotOptions.SetSubtractMaskFromSilk(False)
    PlotOptions.SetAutoScale(False)
    PlotOptions.SetScale(1)

    DocumentationFiles = [
        ("Ref_Top", F_Fab, "Placement top"),
        ("Mechanical", Cmts_User, "User comments"),
        ("Mechanical", Dwgs_User, "User drawings"),
    ]

    # Check if the bottom side contains components
    BottomUsed = False
    for Component in Board.GetModules():
        if(Component.GetLayer() == 31):
            BottomUsed = True

    if(BottomUsed):
        print("[INFO] Generate documentation for both sides")
        DocumentationFiles += ("Ref_Bot", B_Fab, "Placement bottom"),
    else:
        print("[INFO] Generate documentation for top sides")

    # Generate the production documentation
    for File in DocumentationFiles:
        # Mirror the output for bottom files
        if("bot" in File[0].lower()):
            PlotOptions.SetMirror(True)
        else: 
            PlotOptions.SetMirror(False)

        # Print the file
        PlotController.SetLayer(File[1])
        PlotController.OpenPlotfile(File[0], PLOT_FORMAT_PDF, File[2])
        PlotController.SetColorMode(True)
        PlotController.PlotLayer()

    PlotController.ClosePlot()

def CreateGerber(Path):
    PlotOptions.SetOutputDirectory(Path)
    PlotOptions.SetPlotFrameRef(False)
    PlotOptions.SetPlotValue(True)
    PlotOptions.SetPlotReference(True)
    PlotOptions.SetPlotInvisibleText(True)
    PlotOptions.SetPlotViaOnMaskLayer(True)
    PlotOptions.SetExcludeEdgeLayer(False)
    PlotOptions.SetMirror(False)
    PlotOptions.SetAutoScale(False)
    PlotOptions.SetScale(1)

    # Generate the gerber files
    GerberFiles = [
            ( "F.Cu", F_Cu, "Top copper layer"),
            ( "B.Cu", B_Cu, "Bottom cooper layer"),
            ( "F.Paste", F_Paste, "Top paste layer" ),
            ( "B.Paste", B_Paste, "Bottom paste layer"),
            ( "F.SilkS", F_SilkS, "Top silkscreen layer"),
            ( "B.SilkS", B_SilkS, "Bottom silkscreen layer"),
            ( "F.Mask", F_Mask, "Top solder mask layer"),
            ( "B.Mask", B_Mask, "Bottom solder mask layer"),
            ( "Edge.Cuts", Edge_Cuts, "Edge cuts layer"),
            ( "Eco1.User", Eco1_User, "Eco1 User"),
            ( "Eco2.User", Eco2_User, "Eco1 User"),
        ]

    for Layer in GerberFiles:
        PlotController.SetLayer(Layer[1])
        PlotController.OpenPlotfile(Layer[0], PLOT_FORMAT_GERBER, Layer[2])
        PlotController.PlotLayer()
        
    PlotController.ClosePlot()

def CreateDrillFiles(Path):
    # Set the Excellon format
    #   - Use a metric format
    #   - Use the decimal format
    #   - 3 digits for the left side
    #   - 3 digits for the right side
    DrillWriter.SetFormat(True, GENDRILL_WRITER_BASE.DECIMAL_FORMAT, 3, 3)

    # Set the Excellon options
    #   - Disable mirror
    #   - Enable a minimal header
    #   - Set the offset to 0, 0
    #   - Disable merging of the PTH and NPTH file
    DrillWriter.SetOptions(False, True, wxPoint(0, 0), False)

    # Create the drill files
    #   - Set the output path
    #   - Generate a drill file
    #   - Generate a map file
    #   - Don´t use a reporter
    DrillWriter.CreateDrillandMapFilesSet(Path, True, True, None)

def CreatePickAndPlace(Path):
    # Create pick and place file
    # Create BOM
    if(not(os.path.exists(Path))):
        os.makedirs(Path)

    pass

def CreateBOM(Path):
    pass

def Create3D():
    pass

def CreatePackage(InputPath, OutputPath):
    FilesList = [] 

    # Get all files
    for Root, Directories, Files in os.walk(InputPath):
        for FileName in Files: 
            FilesList.append(os.path.join(Root, FileName))

    with ZipFile(OutputPath + ".zip", "w") as ZIP: 
        for File in FilesList: 
            ZIP.write(File, os.path.basename(File)) 

# Generate all necessary output files
#   - Gerber files
#   - Drill files
#   - Pack the Gerber and Drill files as ZIP and rename them to "Gerber_YYYYMMDD"
#   - PDF documentation
#       - Mechanical.pdf
#           - Edge.Cuts
#           - Cmts.User
#           - Dwgs.User
#       - Ref_Top.pdf
#           - Edge.Cuts
#           - F.Fab
#       - Ref_Bot.pdf
#           - Edge.Cuts
#           - B.Fab
#   - Generate Pick & Place
#   - Generate BOM
if(__name__ == "__main__"):
    # Create the output directory
    if(not(os.path.exists(OutputPath))):
        os.makedirs(OutputPath)

    # Generate the Gerber files
    CreateGerber(os.path.join(OutputPath, "gerber"))

    # Generate the Drill files
    CreateDrillFiles(os.path.join(OutputPath, "gerber"))

    # Compress the Gerber and the Drill files
    CreatePackage(os.path.join(OutputPath, "gerber"), os.path.join(OutputPath, "Gerber_" + datetime.date.today().strftime("%Y%m%d")))

    # Generate the PDF documentation
    CreateDocumentation(os.path.join(OutputPath, "docs"))

    CreatePickAndPlace(os.path.join(OutputPath, "production"))

    # Generate the BOM
    CreateBOM(os.path.join(OutputPath, "production"))
