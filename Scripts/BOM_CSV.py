"""
    @package
    Generate a HTML BOM list.
    Components are sorted by ref and grouped by value
    Fields are (if exist)
    Ref, Quantity, Value, Footprint, Description, Manufacturer, Manufacturer Part Number, Mouser Part Number

    Command line:
    python "pathToFile/BOM_HTML.py" "%I" "%O"
"""
from __future__ import print_function

import kicad_netlist_reader
import kicad_utils
import os
import sys

net = kicad_netlist_reader.netlist(sys.argv[1])

try:
	with open(sys.argv[2] + ".csv", "w") as f:
		components = net.getInterestingComponents()
		f.write("Ref;Description;Value;Footprint;Mfr.;Mfr. Part Nr.;Distributor;Order Number;Qnty" + "\n")
		
		for group in net.groupComponents(components):
			refs = ""
			for component in group:
				if(len(refs) > 0):
					refs += ", "
				refs += component.getRef()
				c = component

			row = str(refs) + ";"
			row += c.getDescription() + ";"
			row += str(c.getValue()) + ";"
			
			Temp = c.getFootprint().split(":")
			if(len(Temp) > 1):
				row += str(Temp[1]) + ";"
			else:
				row += str(Temp[0]) + ";"
			
			row += c.getField("Mfr.") + ";"
			row += c.getField("Mfr. No.") + ";"
			row += c.getField("Distributor") + ";"
			row += c.getField("Order Number") + ";"
			row += str(len(group)) + ";"

			f.write(row + "\n")

except IOError:
	e = "Can`t open output file for writing: " + sys.argv[2]
	print(__file__, ":", e, file = sys.stderr)