This breaks in three ways. Customer details repeat on every transaction row. A customer with a third card needs a new column. Changing a phone number means updating many rows. The schema avoids these problems by splitting the data into the 8 tables below.

## First Normal Form (1NF): atomic values, no repeating groups

Every column holds a single value, and there are no repeating column groups.

Cards are rows in cards, not columns like card_last4_1 and card_last4_2.
A customer's several accounts are rows in accounts, not extra columns.
KYC resubmissions are rows in kyc_records, so one customer can have many.
Each row has a primary key (customer_id, account_id, and so on).
## Second Normal Form (2NF): no partial dependency on a composite key

2NF only matters where a key has more than one column. Most tables use a single-column surrogate key, so they satisfy 2NF automatically. The tables with composite candidate keys need a closer look:

ledger_entries has the candidate key (transaction_id, account_id, direction). amount and balance_after describe that specific line, so they depend on the whole key.
beneficiaries has the candidate key (customer_id, bank_name, account_number). See the exception noted under 3NF below.
## Third Normal Form (3NF): no transitive dependency

Non-key columns depend on the key and nothing else.

accounts stores customer_id only. Name, email and phone live in customers, not copied onto each account.
cards stores account_id only, with no customer details.
fraud_flags stores transaction_id only, with no transaction details.
ledger_entries resolves the many-to-many relationship between accounts and transactions (an account has many entries, a transaction has at least two).