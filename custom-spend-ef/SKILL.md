---
name: custom-spend-ef
description: Research a spend-based emission factor for a particular company. Use this when a user asks about the emissions for that company. This will return the emissions per dollar of revenue for that company.
license: MIT
metadata:
    author: Planet FWD
    version: 1.0.0
---

# custom-spend-ef

## Instructions

### Step 1: Confirm the company name

Make sure you are clear on the company that needs to be researched. This might
involve looking up the website or place of business of the company that has been
requested.

### Step 2: Find emissions from sustainability report

Sustainability reports are somewhat fragmented today but can usually be found on
the company's website. We are looking for the total carbon footprint (greenhouse
gas emissions) of that company, including Scopes 1, 2 and 3. Sometimes not all
of these scopes are reported. Please note which scopes are reported and provide
links to the source documentation for validation. 

Please also note the `time_period` that the emissions correspond with. This will
be needed in the next step.

If the company does not have a sustainability report, let the user know that it
is not possible to infer the emissions for this company.

### Step 3: Find revenue for the company

Using publicly available information, find the revenue for that company in the
`time_period` that is consistent with the sustainability report in Step 2.
Please be sure to document the source of the information. Some good potential
sources of information might include:
- [XBRL](https://filings.xbrl.org/)
- SEC filings
- IMF
- Corporate websites

### Step 4: Summarize and document

Please summarize the result and share it in JSON format that includes the
`company_name`, `time_period`, `revenue`, `emissions`, `emission_scopes`,
`documentation` in a format that looks like this:

```json
{
    "company_name": "Apple",
    "time_period": 2024,
    "revenue": {"magnitude": 245122000000, "units": "USD"},
    "emissions": {"magnitude": 15543000, "units": "Mt"},
    "documentation": {
        "revenue": ["https://www.microsoft.com/investor/reports/ar24/"],
        "emissions": ["https://cdn-dynmedia-1.microsoft.com/is/content/microsoftcorp/microsoft/msc/documents/presentations/CSR/2025-Microsoft-Environmental-Data-Fact-Sheet-PDF.pdf"]
    }
}
```