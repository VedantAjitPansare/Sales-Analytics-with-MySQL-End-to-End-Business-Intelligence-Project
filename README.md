# Campfly Sales Analytics — MySQL Project

A GitHub-ready MySQL analytics project for a sales orders CSV. It imports the CSV into MySQL and answers **40 manager-level business questions** using SQL.

## Project contents

```text
campfly-sales-analytics-mysql/
├── data/
│   └── sales_orders.csv
├── docs/
│   ├── business_questions_40.md
│   └── markdown_structure_guide.md
├── sql/
│   ├── 00_setup_import.sql
│   └── 01_analysis_queries_40.sql
├── .gitignore
└── README.md
```

## Dataset

The dataset is a single sales orders table with these fields:

| CSV column | SQL column | Meaning |
|---|---|---|
| `OrderNumber` | `order_number` | Unique order ID |
| `OrderDate` | `order_date` | Order date |
| `Ship Date` | `ship_date` | Shipment date |
| `Customer Name Index` | `customer_name_index` / `customer_id` | Customer identifier |
| `Channel` | `channel` | Sales channel |
| `Currency Code` | `currency_code` | Transaction currency |
| `Warehouse Code` | `warehouse_code` | Fulfilment warehouse |
| `Delivery Region Index` | `delivery_region_index` / `region_id` | Delivery region identifier |
| `Product Description Index` | `product_description_index` / `product_id` | Product identifier |
| `Order Quantity` | `order_quantity` | Units ordered |
| `Unit Price` | `unit_price` | Selling price per unit |
| `Total Unit Cost` | `unit_cost` | Cost per unit in this project |
| `Total Revenue` | `total_revenue` | Order revenue |

## Business logic

The setup script creates a clean view called `vw_sales_orders` with derived fields:

- `total_cost = unit_cost * order_quantity`
- `profit = total_revenue - total_cost`
- `profit_margin = profit / total_revenue`
- `shipping_delay_days = ship_date - order_date`
- `month_start`, `order_year`, `order_quarter`

Important: the source question document mentions `Profit = Total Revenue - Total Unit Cost`, but the CSV field behaves like a per-unit cost. So the main project uses the safer business formula above. The view also includes `profit_using_pdf_formula` if you need the literal version.

## Requirements

- MySQL 8.0 or above
- MySQL client with `LOCAL INFILE` enabled

## How to run

From the repository root:

```bash
mysql --local-infile=1 -u root -p < sql/00_setup_import.sql
```

Then run all 40 analysis queries:

```bash
mysql -u root -p campfly_sales_analytics < sql/01_analysis_queries_40.sql
```

If MySQL blocks CSV import, log in as an admin user and run:

```sql
SET GLOBAL local_infile = 1;
```

Then reconnect using:

```bash
mysql --local-infile=1 -u root -p
```

## If you use MySQL Workbench

1. Open `sql/00_setup_import.sql`.
2. Replace `data/sales_orders.csv` inside the `LOAD DATA LOCAL INFILE` command with the absolute path of your CSV file.
3. Run the full setup script.
4. Open and run `sql/01_analysis_queries_40.sql`.

## Selected question sections

The source document has more than 40 questions. This project uses 8 manager-priority sections with 5 questions each:

1. Revenue & Sales Performance
2. Customer Analytics
3. Product Analytics
4. Sales Channel Analysis
5. Warehouse Performance
6. Shipping & Operations Analytics
7. Regional Analysis
8. Time-Series Analysis

## Markdown reporting instructions

Use `docs/business_questions_40.md` as the main report file. For each question, keep this order:

1. Question
2. Why this matters
3. SQL query
4. Result table after running the query
5. Manager takeaway

This makes the project readable both for GitHub and for a company manager reviewing the analysis.
