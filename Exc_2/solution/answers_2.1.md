# Exercise 2 — Results and Discussion

## Activity 2.1 — PostgreSQL Analytical Queries (E-commerce)

Dataset: 1,000,000 generated orders.

### A. Order with the highest unit price

The order with the highest `price_per_unit` was:

- **Order ID:** 841292
- **Customer:** Emma Brown
- **Product category:** Automotive
- **Quantity:** 3
- **Price per unit:** 2,000.00
- **Order date:** 2024-10-11
- **Country:** Italy


### B. Top 3 product categories by total quantity sold

| Product category | Total quantity sold |
|:-----------------|--------------------:|
| Health & Beauty  |             300,842 |
| Electronics      |             300,804 |
| Toys             |             300,598 |

### C. Total revenue per product category

Revenue was calculated as `price_per_unit × quantity`, summed across orders.


| Product category | Total revenue |
|:-----------------|--------------:|
| Automotive       | 306,589,798.86 |
| Electronics      | 241,525,009.45 |
| Home & Garden    | 78,023,780.09 |
| Sports           | 61,848,990.83 |
| Health & Beauty  | 46,599,817.89 |
| Office Supplies  | 38,276,061.64 |
| Fashion          | 31,566,368.22 |
| Toys             | 23,271,039.02 |
| Grocery          | 15,268,355.66 |
| Books            | 12,731,976.04 |

### D. Top 5 customers by total spending

| Customer       | Total spending |
|:---------------|---------------:|
| Carol Taylor   |     991,179.18 |
| Nina Lopez     |     975,444.95 |
| Daniel Jackson |     959,344.48 |
| Carol Lewis    |     947,708.57 |
| Daniel Young   |     946,030.14 |

### E. Observations about customer spending

The five highest spending names each appear in approximately 940–1,030 orders. Their total spending is relatively similar, and ti ranges from about 946,000 to 991,000.

The dataset generator creates a new random customer name for every order. It chooses a first name from a list of 32 and a last name from a list of 33, allowing at most 1,056 different name combinations - the same name is reused across many independently generated orders.

| Customer | Number of orders | Total spending |
|:---------|-----------------:|---------------:|
| Carol Taylor | 1,028 | 991,179.18 |
| Nina Lopez | 980 | 975,444.95 |
| Daniel Jackson | 1,033 | 959,344.48 |
| Carol Lewis | 943 | 947,708.57 |
| Daniel Young | 973 | 946,030.14 |

Quantity, category, price, date, and country are also randomly generated for each order, so repeated names do not necesserily represent persistent real world customers with consistent purchasing histories. The spending totals reflect repeated random name combinations in a large synthetic dataset.

### Dataset verification

The `orders` table contains 1,000,000 rows. The category count query returned 10 product categories, with around 100,000 orders in each category.
