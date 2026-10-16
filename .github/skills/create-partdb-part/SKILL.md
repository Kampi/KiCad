---
name: create-partdb-part
description: Create a component in Part-DB with the same structure as the existing components of its kind. Checks the part number, asks for the info source (e.g. Mouser), reads the existing parts as schema, creates the part with parameters, attachments, order details and stock lot through the REST API, generates a label with a matching label profile and prints it on the printer chosen by the user. Use when the user asks to add, create or import a component or part in Part-DB.
---

# Create Part-DB Part

Adds one component to Part-DB. The existing parts of the same kind are the schema: the new part gets the
same category, naming, parameters, attachments and EDA settings, so it looks like it was created by hand.
At the end a label of the part is generated and printed.

## Rules

- Never delete or overwrite anything in Part-DB without the explicit approval of the user. This includes parts,
  parameters, attachments, order details, prices and lots. [partdb_api.py](partdb_api.py) has no delete command
  on purpose, do not work around it.
- Only create. If the part already exists, stop and ask the user (step 2).
- The server address and the API token are secrets of the user. Never write them into this skill, a script, a
  tracked file of the repository, a commit message or a report. They are only read from the environment or from
  the file `.partdb.env` in the root of the repository, which is ignored by Git. Never add this file to a commit
  and never print its content.
- Do not invent values. Everything comes from the reference parts, the info source or the user.

## Questions to the User

Ask instead of guessing. Collect the open questions and ask them together where possible.

| Question                    | When                                                                                   |
| --------------------------- | -------------------------------------------------------------------------------------- |
| Info source                 | Always (step 4). Offer the active info providers of Part-DB and "another source"       |
| Part number                 | The number is not found exactly, found several times or contradicts the request (step 4) |
| Assignment of the part      | Category, footprint, manufacturer, storage location or the fields to use are not clear from the reference parts (step 5) |
| Label profile               | No profile matches the kind of the part, or several match (step 8)                     |
| Printer                     | Always (step 10). Offer the installed printers and "do not print"                      |

## Prerequisites

- `python3`
- The access to the server, as environment variables or as lines `NAME=value` in the file `.partdb.env` in the
  root of the repository. The environment has priority:

  | Variable          | Description                                            |
  | ----------------- | ------------------------------------------------------ |
  | `PARTDB_URL`      | Base URL of the Part-DB server, without `/api`         |
  | `PARTDB_TOKEN`    | API token with the level `edit`                        |
  | `PARTDB_INSECURE` | `1` if the server uses a self-signed certificate       |

  If a variable is missing, ask the user to set it. Only store a value in `.partdb.env`, and only when the user
  asks for it.

All requests are done with [partdb_api.py](partdb_api.py) from this directory:

```bash
API=.github/skills/create-partdb-part/partdb_api.py
python3 "$API" get '/api/tokens/current'
python3 "$API" post '/api/parts' part.json
python3 "$API" patch '/api/parts/123' -              # JSON body from stdin
python3 "$API" post '/api/labels/generate' - label.pdf   # store the response in a file
```

Every record of an answer contains its `id`. Write the JSON bodies and the label to a temporary directory
outside of the repository, or pass the bodies via stdin.

## Steps

Stop at the first failing step, report the error and do not continue.

### 1. Check the access

```bash
python3 "$API" get '/api/tokens/current'
```

`level` must be `2` or higher. Level `1` is read-only: stop and ask the user for a token with the level `edit`.

### 2. Check that the part does not exist

```bash
python3 "$API" get '/api/parts?name=<part number>'
```

An empty list means the part is new. Otherwise show the user the existing part and ask how to continue.
Do not change the existing part without approval.

### 3. Read the schema from the existing parts

List all parts and filter them locally. The list is paged, read pages until one has fewer than 100 entries:

```bash
python3 "$API" get '/api/parts?itemsPerPage=100&page=1'
python3 "$API" get '/api/categories?itemsPerPage=200'
```

Pick the reference parts in this order: same series (e.g. `RC0402FR-...` for `RC0603FR-...`), same manufacturer
and package, same category. If the series only exists in another package, take the package dependent values
(footprint, KiCad footprint, power rating notation) from a part of the same category in the requested package.
Read at least two reference parts completely, prefer the newest ones:

```bash
python3 "$API" get '/api/parts/<id>'
```

### 4. Choose the info source and check the part number

List the info providers that are active in Part-DB:

```bash
python3 "$API" get '/api/info_providers'
```

Ask the user which source to use: one of the active providers (e.g. Mouser) or another source. Always ask, also
if only one provider is active. For another source the user gives the data or the documents (datasheet,
product page), and the order details are created as the user says.

Search the part number in the chosen provider:

```bash
echo '{"keyword": "<part number>", "providers": ["<provider key>"]}' \
    | python3 "$API" post '/api/info_providers/search' -
```

The part number is correct when all of these are true:

- Exactly one result has an `mpn` that is identical to the requested number (compare without regard to case)
- Its manufacturer and description fit the part the user asked for
- The values coded in the number (package, value, tolerance) match the description of the provider. Decode the
  number with the naming scheme of the reference parts of the same series

Otherwise do not create the part. Show the user the requested number, the results of the provider and the
difference (no result, only similar numbers, several packaging variants, contradicting values) and ask which
number is meant. A similar number is never used without the confirmation of the user.

The result of the search contains the datasheet, the image, the mass, the order number, the product URL and
the prices.

### 5. Determine the values

Take from the reference parts:

| Field                                        | Use for the new part                                              |
| -------------------------------------------- | ----------------------------------------------------------------- |
| `category`, `footprint`, `manufacturer`      | The same records (their `id`)                                     |
| `name`, `manufacturer_product_number`        | Same pattern, usually the manufacturer part number in both        |
| `description`                                | Same pattern and notation (e.g. `2k8 100mW 1%`)                   |
| `manufacturing_status`, `tags`, `comment`    | Same pattern                                                      |
| `eda_info`                                   | Same prefix, `value` in the same notation. Symbol and footprint: see below |
| `parameters`                                 | Same names, symbols and units. Values of the new part             |
| `attachments`, `master_picture_attachment`   | Same names and attachment types, URLs from the info source        |
| `orderdetails`, `pricedetails`               | Same supplier, order number and prices from the info source       |
| `partLots`                                   | Same storage location, amount `0` unless the user gives a stock   |

If the reference parts differ in a point (e.g. unit `Ohm` or `kOhm`), use the notation of the newest parts.

**KiCad symbol and footprint.** The own library of the user has priority over the libraries that are shipped
with KiCad. Check it for every part, also when the reference parts use a shipped library:

1. Read the global `sym-lib-table` and `fp-lib-table` of the newest KiCad version of the user (KiCad
   configuration directory). The own libraries are the entries whose `uri` does not point into the KiCad
   installation (`${KICAD<n>_SYMBOL_DIR}`, `${KICAD<n>_FOOTPRINT_DIR}`), e.g. the ones below `${KICAD_LIBRARY}`.
2. Search the files of these libraries (`*.kicad_sym`, `*.pretty/*.kicad_mod`) for the part: the part number
   without packaging suffix, the series and the name of the manufacturer. Search symbols and footprints
   separately, often only one of them exists.
3. If a matching symbol and / or footprint exists, use it as `<nickname>:<name>` with the nickname from the
   library table, not the file name. Check that it really fits the part (pin count, package, variant).
4. Only for what is missing in the own library, use the symbol and footprint of the reference parts or of the
   libraries shipped with KiCad. Check that the name exists in the installed version.

A library file that is not listed in the library table can not be used by KiCad: do not enter it, report it.
Report for the symbol and for the footprint whether it comes from the own or a shipped library (step 11).

Ask the user when the assignment is not clear, for example:

- Several symbols or footprints of the own library fit the part

- No reference part of this kind exists, or the reference parts are in different categories
- The category of the info source fits several categories of Part-DB, or none
- The footprint, the manufacturer or the supplier does not exist in Part-DB yet. Do not create these records
  without asking
- The reference parts use different storage locations

### 6. Create the part

Create the records in this order. Every answer contains the `id` of the new record.

**Part.** Related records are given as path, e.g. `"/api/categories/<id>"`:

```json
{
  "name": "...",
  "description": "...",
  "category": "/api/categories/<id>",
  "footprint": "/api/footprints/<id>",
  "manufacturer": "/api/manufacturers/<id>",
  "manufacturer_product_number": "...",
  "manufacturing_status": "active",
  "mass": 0.0,
  "eda_info": {
    "reference_prefix": "...",
    "value": "...",
    "visibility": true,
    "exclude_from_bom": false,
    "exclude_from_board": false,
    "exclude_from_sim": false,
    "kicad_symbol": "...",
    "kicad_footprint": "..."
  }
}
```

```bash
python3 "$API" post '/api/parts' part.json
```

**Parameters**, one request each. `_type` and `element` assign the parameter to the part:

```json
{"_type": "Part", "element": "/api/parts/<id>", "name": "...", "symbol": "...", "value_typical": 0.0, "unit": "..."}
```

```bash
python3 "$API" post '/api/parameters' parameter.json
```

**Attachments** (datasheet, image), one request each:

```json
{"_type": "Part", "element": "/api/parts/<id>", "name": "...", "attachment_type": "/api/attachment_types/<id>", "url": "..."}
```

```bash
python3 "$API" post '/api/attachments' attachment.json
```

Set the image as preview picture of the part:

```bash
echo '{"master_picture_attachment": "/api/attachments/<id>"}' | python3 "$API" patch '/api/parts/<id>' -
```

**Order details and prices.** One order detail per supplier, then one price per price break.
`price` is a string, `currency` is omitted for the base currency:

```json
{"part": "/api/parts/<id>", "supplier": "/api/suppliers/<id>", "supplierpartnr": "...", "supplier_product_url": "...", "prices_includes_vat": true, "obsolete": false}
```

```json
{"orderdetail": "/api/orderdetails/<id>", "price": "0.086", "min_discount_quantity": 1, "price_related_quantity": 1}
```

```bash
python3 "$API" post '/api/orderdetails' orderdetail.json
python3 "$API" post '/api/pricedetails' price.json
```

**Stock lot:**

```json
{"part": "/api/parts/<id>", "storage_location": "/api/storage_locations/<id>", "amount": 0}
```

```bash
python3 "$API" post '/api/part_lots' lot.json
```

If a request fails after the part was created, do not delete anything. Report which records exist and which are
missing, and ask the user how to continue.

### 7. Verify the result

```bash
python3 "$API" get '/api/parts/<id>'
```

Compare the new part field by field with a reference part: same fields set, same number and names of the
parameters and attachments, preview picture set, order details with all price breaks, lot with the storage location.

### 8. Choose the label profile

```bash
python3 "$API" get '/api/label_profiles'
```

Choose the profile whose name fits the kind of the part: the category of the part or one of its parent
categories (e.g. profile `Widerstand` for the category `Widerstand → Dickfilmwiderstand`), otherwise the
function of the part (e.g. profile `LDO` for a linear regulator).

Ask the user which profile to use when no profile fits, when several fit or when the match is only a guess.
Offer the existing profiles and "no label". Do not create or change label profiles.

### 9. Generate the label

```bash
echo '{"profileId": <profile id>, "elementIds": "<part id>"}' \
    | python3 "$API" post '/api/labels/generate' - label.pdf
```

The answer is a PDF. Check that the file starts with `%PDF` and look at it: the label must show the values of
the new part. If it is empty or shows wrong values, do not print it and report the problem.

### 10. Print the label

List the installed printers and ask the user which one to use. Always ask, also if there is a default printer
or only one printer. Offer "do not print" as well.

```bash
# Windows (PowerShell)
Get-Printer | Select-Object Name, DriverName, PrinterStatus
# Linux / macOS
lpstat -p -d
```

Print the label on the chosen printer:

```bash
# Windows (PowerShell): uses the program that is registered for PDF files
Start-Process -FilePath label.pdf -Verb PrintTo -ArgumentList '"<printer name>"' -WindowStyle Hidden
# Linux / macOS
lp -d '<printer name>' label.pdf
```

Check the print queue afterwards (`Get-PrintJob -PrinterName '<printer name>'` or `lpstat -o`). A job that left
the queue was sent to the printer, the agent can not see whether the label was actually printed. Report an
error state of the printer or a job that stays in the queue.

If the user does not want to print, tell them where the PDF is stored.

### 11. Report

Report the name and the ID of the new part, the values that were set and where they come from (reference part,
info source or user), every value that differs from the reference parts, the label profile and the printer.
Do not include the server address or the token in the report.

In KiCad the part appears after the HTTP library is reloaded (restart KiCad).

## Notes

- Git Bash on Windows converts arguments that start with `/` to Windows paths, so `/api/parts/123` does not reach
  the server (`getaddrinfo failed`). Set `MSYS_NO_PATHCONV=1` for the calls or use PowerShell.
- PowerShell pipes text with a byte order mark, `partdb_api.py` accepts it. Characters outside of ASCII (e.g. the
  `±` of a tolerance parameter) are only kept when the body is UTF-8.
- The filter `?category=` of `/api/parts` does not return results. Filter the complete list locally.
- The info provider search needs a token of a user that is allowed to use the info providers.
- On Windows the program that prints the PDF (e.g. Acrobat) can stay open after printing. Do not close programs
  of the user.
