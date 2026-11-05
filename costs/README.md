# Resilience cost data

This folder turns WFP's cost workbook into a clean table, groups the activities and links the costs to the surveys.

```bash
Rscript costs/prepare_cost_data.R     # from the repository's root, before app/prepare_app_data.R
```

The script reads WFP's two files and the merged survey file, all read-only. It writes to `cost data clean/`, next to the data and outside this repository. The cost lines stay out of the repository and the dashboard, because activity texts name villages.

## Rules

- **Currency.** Costs are in XAF. The composition file's values per person per month are in USD. They are not converted: no exchange rate was provided.
- **2020.** January to March (activities) and April to December (lump sums per partner, because of COVID-19) stay separate periods. Lump sums are never split across activities: the amount sits on a partner's first row, which says nothing about that row's activity.
- **Totals.** Subtotal rows are left out, including Farchana's unlabelled ones. In 2019 the workbook's `TOTAL GENERAL` formula leaves out Farchana (211,503,517 XAF), so the reconciled total is higher. To confirm with WFP.
- **Stops.** The script stops if a subtotal disagrees with its lines, a department has no crosswalk entry, a table loses money or the survey link loses households.

## Editable rules

| File | Content |
|---|---|
| [`department_crosswalk.csv`](department_crosswalk.csv) | Each department in the cost sheets, its survey departments and OCHA codes, and how sure the link is |
| [`activity_categories.csv`](activity_categories.csv) | Keyword rules for the activity categories, in order: the first match wins |

Two links are assumed and need confirming with WFP: Ennedi Est to Wadi Hawar, and Sila to Kimiti. "Iriba, Dougouba" matches no surveyed department. Categories come from keywords, so they need review. To audit them, set `WFP_COST_AUDIT=1`: the script then prints the unclear rows and the largest lines of each category.

## Limits of the link

Costs link to surveys by cost area and year, not by household. Combined areas, such as Guera + Mangalme, hold one amount for two departments. Surveyed departments with no cost data: Aboudeia, Bahr-Azoum, Barh-El-Gazel Ouest, Fitri, Nord Kanem and Wayi. WFP's household figures are not used for a cost per household: they are missing in some periods and can count a household under several activities.
