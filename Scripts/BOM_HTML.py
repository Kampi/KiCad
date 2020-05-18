"""
    @package
    Generate a HTML BOM list.
    Components are sorted by ref and grouped by value
    Fields are (if exist)
    Ref, Quantity, Value, Part, Datasheet, Description, Vendor

    Command line:
    python "pathToFile/BOM_HTML.py" "%I" "%O"
"""
from __future__ import print_function

import sys
import kicad_netlist_reader

# Start with a basic html template
html = """
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    </head>
    <body>
    <h1><!--SOURCE--></h1>
    <p><!--DATE--></p>
    <p><!--TOOL--></p>
    <p><!--COMPCOUNT--></p>
    <table>
    <!--TABLEROW-->
    </table>
    </body>
</html>
    """

net = kicad_netlist_reader.netlist(sys.argv[1])

try:
	f = open(sys.argv[2] + ".html", "w")
except IOError:
	e = "Can`t open output file for writing: " + sys.argv[2]
	print(__file__, ":", e, file=sys.stderr)
	f = sys.stdout

components = net.getInterestingComponents()

# Output a set of rows for a header providing general information
html = html.replace("<!--SOURCE-->", net.getSource())
html = html.replace("<!--DATE-->", net.getDate())
html = html.replace("<!--COMPCOUNT-->", "<b>Component Count:</b>" + str(len(components)))

row = "<tr>"
row += "<th>Ref</th>"
row += "<th>Description</th>"
row += "<th>Value</th>"
row += "<th>Footprint</th>"
row += "<th>Mfr.</th>" 
row += "<th>Mfr. Part Nr.</th>" 
row += "<th>Distributor</th>" 
row += "<th>Order Number</th>"
row += "<th>Qnty</th>"
row += "</tr>"

html = html.replace("<!--TABLEROW-->", row + "<!--TABLEROW-->")

# Get all of the components in groups of matching parts + values
# (see kicad_netlist_reader.py)
grouped = net.groupComponents(components)

# Output all of the component information
for group in grouped:
	refs = ""

	# Add the reference of every component in the group and keep a reference
	# to the component so that the other data can be filled in once per group
	for component in group:
		if len(refs) > 0:
			refs += ", "
		refs += component.getRef()
		c = component

	row = "<tr><td>" + refs
	row += "</td><td>" + c.getDescription()
	row += "</td><td>" + c.getValue()
	
	Temp = c.getFootprint().split(":")
	if(len(Temp) > 1):
		row += "</td><td>" + Temp[1]
	else:
		row += "</td><td>" + Temp[0]
	
	row += "</td><td>" + c.getField("Mfr.")
	row += "</td><td>" + c.getField("Mfr. No.")
	row += "</td><td>" + c.getField("Distributor")
	row += "</td><td>" + c.getField("Order Number")
	row += "</td><td>" + str(len(group))
	row += "</td></tr>"

	html = html.replace("<!--TABLEROW-->", row + "<!--TABLEROW-->")

print(html, file = f)