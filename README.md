# Superstore Sales Analysis (SQL)

A SQL project where I dug into the Sample Superstore dataset to figure out where the business is actually making money, where it's bleeding it, and what's driving the difference. Built entirely in MySQL, with the idea of eventually hooking it up to Power BI for a visual layer.

## Why I picked this dataset

I wanted something that felt like a real retail business rather than a toy dataset — order dates, ship dates, discounts, multiple categories, regions, customers. It's small enough to work with comfortably (~9,700 rows after cleaning) but has enough going on that you can actually ask interesting questions of it.

## Tools used

- MySQL 8.0 (MySQL Workbench)
- Excel (for cleaning up inconsistent date formats before loading — more on that below)

## A quick note on the data

The raw CSV had order dates in two different formats mixed within the same column (some rows `DD-MM-YYYY`, some `MM/DD/YYYY`), which caused a bunch of import failures at first. Ended up fixing that in Excel with Text-to-Columns before loading it into MySQL. Small thing, but it's the kind of real-world mess you don't get with a perfectly clean dataset.

## What I actually wanted to find out

Rather than just writing random queries, I tried to follow a line of questioning like an analyst actually would:

1. How's the business doing overall?
2. Which categories/regions are carrying the business, and which aren't?
3. Is there a reason some categories underperform (spoiler: yes — discounting)?
4. Is there a pattern over time?
5. Who are the customers actually worth paying attention to?

---

## 1. Overall performance

```sql
SELECT 
    SUM(sales) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders;
```

**Result:** ₹22,72,450 revenue | ₹2,82,858 profit | **12.45% margin**

This is the baseline number everything else gets compared against.

## 2. Category-wise breakdown

```sql
SELECT 
    category, 
    SUM(sales) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders 
GROUP BY category
ORDER BY total_revenue DESC;
```

| Category | Revenue | Profit | Margin |
|---|---|---|---|
| Technology | 8,35,900 | 1,45,387 | 17.39% |
| Furniture | 7,33,047 | 16,980 | **2.32%** |
| Office Supplies | 7,03,502 | 1,20,489 | 17.13% |

This is the first real red flag. Furniture brings in revenue almost on par with Technology, but the margin is nowhere close. Something's off specifically with Furniture, not the business as a whole.

## 3. Why is Furniture's margin so low?

Hypothesis: heavy discounting. Checked average discount per category against margin:

```sql
SELECT 
    category,
    ROUND(AVG(discount) * 100, 2) AS avg_discount_pct,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders
GROUP BY category
ORDER BY avg_discount_pct DESC;
```

| Category | Avg Discount | Margin |
|---|---|---|
| Furniture | 17.44% | 2.32% |
| Office Supplies | 15.56% | 17.13% |
| Technology | 13.22% | 17.39% |

Confirmed. Furniture gets discounted the most and makes the least. Went one level deeper into Furniture's sub-categories to find the actual culprit:

```sql
SELECT 
    sub_category,
    ROUND(AVG(discount) * 100, 2) AS avg_discount_pct,
    SUM(sales) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders
WHERE category = 'Furniture'
GROUP BY sub_category
ORDER BY profit_margin_pct ASC;
```

| Sub-category | Avg Discount | Profit | Margin |
|---|---|---|---|
| Tables | 26.13% | **-17,725** | **-8.56%** |
| Bookcases | 21.11% | **-3,472** | **-3.02%** |
| Chairs | 17.02% | 26,590 | 8.10% |
| Furnishings | 13.76% | 11,588 | 14.00% |

Tables and Bookcases are actually being sold at a loss. Every table sold is losing the company money, mostly because of a 26% average discount on them. That's the actual finding here — not "Furniture is bad," but specifically "Tables and Bookcases are being discounted way past the point where they're profitable."

## 4. Region-wise sales

```sql
SELECT region, SUM(sales) AS total_sales
FROM orders
GROUP BY region
ORDER BY total_sales DESC;
```

West leads (₹7,13,471), followed by East, Central, and South (₹3,88,983) trailing well behind. Worth digging into why South underperforms so much if I extend this project later — could be a discount pattern like Furniture, or just genuinely smaller market presence.

## 5. Monthly sales trend

```sql
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS months,
    SUM(sales) AS total_sales
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY months ASC;
```

48 months of data (4 years). A few things stood out — Feb consistently comes in weak across multiple years, and Nov/Dec tend to spike, which lines up with a fairly normal retail holiday-season pattern.

## 6. Month-over-month growth %

This is where it got more interesting — wanted to actually quantify the swings month to month instead of eyeballing the trend.

```sql
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS months,
    SUM(sales) AS total_sales,
    LAG(SUM(sales)) OVER (ORDER BY DATE_FORMAT(order_date, '%Y-%m')) AS previous_month_sales,
    ROUND(
        (SUM(sales) - LAG(SUM(sales)) OVER (ORDER BY DATE_FORMAT(order_date, '%Y-%m'))) 
        / LAG(SUM(sales)) OVER (ORDER BY DATE_FORMAT(order_date, '%Y-%m')) * 100
    , 2) AS growth_pct
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY months ASC;
```

Some of the swings are huge — a -70% drop in Feb 2014 followed by a +1247% jump in March. The percentage looks dramatic mostly because Feb's base is so small, but the underlying pattern (Feb dips, March recovers) shows up more than once across the years, which makes it look like a real seasonal effect rather than noise.

## 7. Customers — sales vs. profit

Ran two versions of the same question to see if they'd actually agree with each other.

**Top 10 by sales:**
```sql
SELECT customer_name, SUM(sales) AS total_sales
FROM orders
GROUP BY customer_name
ORDER BY total_sales DESC
LIMIT 10;
```
Sean Miller comes out on top with ₹25,043.

**Top 10 by profit:**
```sql
SELECT customer_name, SUM(profit) AS total_profit
FROM orders
GROUP BY customer_name
ORDER BY total_profit DESC
LIMIT 10;
```
Sean Miller doesn't even show up here. Tamara Chand and Raymond Buch top this list instead — and they also happen to rank in the top 5 for sales, which makes them the customers actually worth paying attention to. Sean Miller driving high sales but not high profit is the customer-level version of the same story as the Furniture category — high revenue doesn't always mean high value.

---

## What I'd take away from this if I were presenting it to a manager

- Overall the business runs at a 12.45% margin, but that number hides a lot — Technology and Office Supplies are both doing fine at ~17%, and it's Furniture, specifically Tables and Bookcases, dragging the average down.
- The Furniture problem isn't really a "Furniture problem," it's a discounting problem. Capping discounts on Tables and Bookcases (or re-pricing them) would probably do more for the bottom line than any other single change here.
- Sales has a repeatable seasonal dip in February and pickup in March — useful for planning inventory/promotions around that time instead of getting surprised by it every year.
- Not every high-sales customer is a high-value customer. Sean Miller vs. Tamara Chand is a good illustration of why profit, not revenue, should be the metric that decides who gets the loyalty perks.

## What's next

- Build this out in Power BI — a discount-vs-margin chart and a monthly trend line would make the Furniture/seasonality findings a lot easier to show at a glance.
- Look into why the South region underperforms — same discount-driven angle worth checking.
- Add a running/cumulative sales total to see growth trajectory rather than just month-to-month noise.
