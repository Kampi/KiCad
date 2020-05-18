#
# \file ExportBOM.py
#
# \brief BOM export into a Mouser shopping cart.
#
# Copyright (C) Daniel Kampert, 2020
#	Website: www.kampis-elektroecke.de
#
# GNU GENERAL PUBLIC LICENSE:
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# Errors and commissions should be reported to DanielKampert@kampis-elektroecke.de

import os
import csv
import json
import random
import requests
import argparse

# Command line parser
Parser = argparse.ArgumentParser()
Parser.add_argument("-i", "--input", help = "Path to BOM as CSV file.", type = str, required = True)
Parser.add_argument("-k", "--key", help = "Mouser API key.", type = str, required = True)
Parser.add_argument("-c", "--cart", help = "Mouser cart key. Set this value to 0 or let it empty to use a random number.", default = 0, type = int)
args = Parser.parse_args()

if(__name__ == "__main__"):
    # Check if the file exist
    if(not(os.path.exists(args.input))):
        print("[ERROR] File {} doesn´t exist!".format(args.input))
        exit()
    
    # Create a random cart key
    if(args.cart == 0):
        CartKey = random.randrange(99999999)
    else:
        CartKey = args.cart

    # Parse the CSV file
    CartItems = list()
    with open(args.input, "r") as File:
        Reader = csv.DictReader(File, delimiter = ";")
        for row in Reader:
            if(row["Distributor"] == "Mouser"):
                CartItems.append(
                    { "MouserPartNumber": row["Order Number"],
                      "Quantity": row["Qnty"]
                    })

    # Create the request
    JSON = {"CartKey" : "{:03d}-0000-0000-0000-000000000000".format(CartKey),
            "CartItems" : CartItems
            }
    Headers = {"Content-Type": "text/json"}
    Request = requests.post("https://api.mouser.com/api/v1.0/cart?apiKey={}".format(args.key), data = json.dumps(JSON), headers = Headers)

    if(Request.status_code == requests.codes.ok):
       print("[INFO] Export successful!")
    else:
        print("[ERROR] Export failed. Error: {}".format(Request.status_code))
